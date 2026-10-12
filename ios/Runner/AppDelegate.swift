import AVFoundation
import Flutter
import MediaPlayer
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets local notifications show while the app is open too.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "UtopiaNowPlaying") {
      NowPlayingChannel.register(with: registrar.messenger())
    }
  }
}

/// What the player is listening to, for Chip to vibe along.
///
/// iOS only shares the song (and lets us control it) for Apple Music, the
/// built-in Music app, once the player allows it. For any other app we can
/// still tell that something is playing, just not what.
enum NowPlayingChannel {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "utopia/now_playing", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let player = MPMusicPlayerController.systemMusicPlayer
      switch call.method {
      case "read":
        let args = call.arguments as? [String: Any]
        result(read(withArt: (args?["art"] as? Bool) ?? false))
      case "requestAccess":
        MPMediaLibrary.requestAuthorization { status in
          DispatchQueue.main.async { result(status == .authorized) }
        }
      case "openSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
        result(nil)
      case "play":
        player.play()
        result(nil)
      case "pause":
        player.pause()
        result(nil)
      case "next":
        player.skipToNextItem()
        result(nil)
      case "previous":
        player.skipToPreviousItem()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func read(withArt: Bool) -> [String: Any] {
    var out: [String: Any] = [:]
    out["otherAudio"] = AVAudioSession.sharedInstance().isOtherAudioPlaying
    let status = MPMediaLibrary.authorizationStatus()
    switch status {
    case .authorized: out["access"] = "granted"
    case .notDetermined: out["access"] = "unknown"
    default: out["access"] = "denied"
    }
    guard status == .authorized else { return out }
    let player = MPMusicPlayerController.systemMusicPlayer
    guard let item = player.nowPlayingItem else { return out }
    out["id"] = String(item.persistentID)
    out["title"] = item.title ?? ""
    out["artist"] = item.artist ?? ""
    out["album"] = item.albumTitle ?? ""
    out["playing"] = player.playbackState == .playing
    out["source"] = "Music"
    out["controls"] = true
    // What kind of thing it is, so Chip can tell a song from a podcast.
    let type = item.mediaType
    if type.contains(.podcast) || type.contains(.videoPodcast) {
      out["kind"] = "podcast"
    } else if type.contains(.audioBook) {
      out["kind"] = "audiobook"
    } else if type.contains(.anyVideo) {
      out["kind"] = "video"
    } else if type.contains(.music) {
      out["kind"] = "music"
    }
    out["genre"] = item.genre ?? ""
    out["durationMs"] = Int(item.playbackDuration * 1000)
    if let show = item.podcastTitle, !show.isEmpty { out["show"] = show }
    if withArt,
       let image = item.artwork?.image(at: CGSize(width: 240, height: 240)),
       let data = image.jpegData(compressionQuality: 0.8) {
      out["art"] = FlutterStandardTypedData(bytes: data)
    }
    return out
  }
}
