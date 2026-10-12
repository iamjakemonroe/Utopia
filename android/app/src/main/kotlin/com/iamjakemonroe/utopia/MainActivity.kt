package com.iamjakemonroe.utopia

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlin.math.abs

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferSixtyHertz()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NowPlayingChannel(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
    }

    /**
     * Asks for the screen's 60 Hz mode. Utopia's world is always moving, and
     * on 90/120 Hz phones that would mean drawing it up to twice as often,
     * which warms the phone and drains the battery for no visible gain. The
     * iPhone build is capped the same way (CADisableMinimumFrameDurationOnPhone).
     */
    private fun preferSixtyHertz() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        } ?: return
        val current = display.mode
        val sixty = display.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .minByOrNull { abs(it.refreshRate - 60f) } ?: return
        window.attributes = window.attributes.apply {
            preferredDisplayModeId = sixty.modeId
        }
    }
}
