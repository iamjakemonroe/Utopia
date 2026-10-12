package com.iamjakemonroe.utopia

import android.service.notification.NotificationListenerService

/**
 * Does nothing itself: Android only lets an app see other apps' media
 * sessions (the song playing in Spotify, YouTube Music...) while it holds a
 * notification listener the player has switched on in Settings.
 */
class UtopiaMediaListener : NotificationListenerService()
