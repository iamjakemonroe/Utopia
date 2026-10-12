package com.iamjakemonroe.utopia

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * What the player is listening to in another app, and its play, pause,
 * next and previous buttons, for Chip to vibe along on the home screen.
 * Needs notification access (see [UtopiaMediaListener]).
 */
class NowPlayingChannel(private val context: Context) {

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "utopia/now_playing").setMethodCallHandler { call, result ->
            when (call.method) {
                "read" -> result.success(read(call.argument<Boolean>("art") ?: false))
                "requestAccess", "openSettings" -> {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(false)
                }
                "play" -> { session()?.transportControls?.play(); result.success(null) }
                "pause" -> { session()?.transportControls?.pause(); result.success(null) }
                "next" -> { session()?.transportControls?.skipToNext(); result.success(null) }
                "previous" -> { session()?.transportControls?.skipToPrevious(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasAccess(): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false
        return enabled.contains(context.packageName)
    }

    /** The other app's session that's playing, or the latest one. */
    private fun session(): MediaController? {
        if (!hasAccess()) return null
        val manager = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
        val sessions = try {
            manager.getActiveSessions(ComponentName(context, UtopiaMediaListener::class.java))
        } catch (e: SecurityException) {
            return null
        }
        val others = sessions.filter { it.packageName != context.packageName }
        return others.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
            ?: others.firstOrNull()
    }

    /**
     * Whether another app is playing music or video right now. Android tells
     * any app this much without asking (just not what it is), so Chip knows
     * something's on even before notification access is switched on. Only
     * players actually playing are listed, and Utopia's own sounds are
     * marked as game audio, so they never count.
     */
    private fun otherMediaPlaying(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return try {
            audio.activePlaybackConfigurations.any {
                it.audioAttributes.usage == AudioAttributes.USAGE_MEDIA
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun read(withArt: Boolean): Map<String, Any?> {
        val out = HashMap<String, Any?>()
        out["access"] = if (hasAccess()) "granted" else "unknown"
        val otherMedia = otherMediaPlaying()
        out["otherAudio"] = otherMedia
        val controller = session() ?: return out
        val metadata = controller.metadata ?: return out
        val title = metadata.getString(MediaMetadata.METADATA_KEY_TITLE)
            ?: metadata.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE)
            ?: return out
        val artist = metadata.getString(MediaMetadata.METADATA_KEY_ARTIST)
            ?: metadata.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST)
            ?: metadata.getString(MediaMetadata.METADATA_KEY_DISPLAY_SUBTITLE)
            ?: ""
        val playing = controller.playbackState?.state == PlaybackState.STATE_PLAYING
        out["id"] = "${controller.packageName}|$title|$artist"
        out["title"] = title
        out["artist"] = artist
        out["album"] = metadata.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: ""
        out["playing"] = playing
        out["otherAudio"] = playing || otherMedia
        out["controls"] = true
        out["source"] = sourceName(controller.packageName)
        // Clues for Chip to tell a song from a video, podcast or sermon.
        out["package"] = controller.packageName
        out["genre"] = metadata.getString(MediaMetadata.METADATA_KEY_GENRE) ?: ""
        out["durationMs"] = metadata.getLong(MediaMetadata.METADATA_KEY_DURATION)
        out["mediaId"] = metadata.getString(MediaMetadata.METADATA_KEY_MEDIA_ID) ?: ""
        if (withArt) {
            val art = metadata.getBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART)
                ?: metadata.getBitmap(MediaMetadata.METADATA_KEY_ART)
                ?: metadata.getBitmap(MediaMetadata.METADATA_KEY_DISPLAY_ICON)
            if (art != null && art.width > 0) {
                val scaled = Bitmap.createScaledBitmap(art, 240, maxOf(1, 240 * art.height / art.width), true)
                val bytes = ByteArrayOutputStream()
                scaled.compress(Bitmap.CompressFormat.JPEG, 80, bytes)
                out["art"] = bytes.toByteArray()
            }
        }
        return out
    }

    /** A friendly name for the music app (other apps' labels aren't visible to us on newer Androids). */
    private fun sourceName(pkg: String): String? = when {
        pkg.startsWith("com.spotify") -> "Spotify"
        pkg == "com.google.android.apps.youtube.music" -> "YouTube Music"
        pkg == "com.google.android.youtube" -> "YouTube"
        pkg == "com.apple.android.music" -> "Apple Music"
        pkg.startsWith("com.aspiro.tidal") -> "Tidal"
        pkg.startsWith("deezer") || pkg.startsWith("com.deezer") -> "Deezer"
        pkg.startsWith("com.soundcloud") -> "SoundCloud"
        pkg.startsWith("com.amazon.mp3") -> "Amazon Music"
        pkg.startsWith("com.boomplaymusic") -> "Boomplay"
        pkg.startsWith("com.audiomack") -> "Audiomack"
        pkg.startsWith("au.com.shiftyjelly.pocketcasts") -> "Pocket Casts"
        pkg == "com.google.android.apps.podcasts" -> "Google Podcasts"
        pkg.startsWith("com.audible") -> "Audible"
        pkg.startsWith("fm.castbox") -> "Castbox"
        pkg.startsWith("com.netflix") -> "Netflix"
        pkg.startsWith("tv.twitch") -> "Twitch"
        pkg.startsWith("com.zhiliaoapp.musically") || pkg.startsWith("com.ss.android.ugc") -> "TikTok"
        pkg.startsWith("com.instagram") -> "Instagram"
        pkg.startsWith("com.facebook") -> "Facebook"
        pkg.startsWith("com.google.android.apps.youtube.kids") -> "YouTube Kids"
        else -> null
    }
}
