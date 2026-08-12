package com.iflixify.iflixify

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val BRIGHTNESS_CHANNEL = "iflixify/brightness"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BRIGHTNESS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBrightness" -> {
                    val brightness = call.argument<Double>("brightness")?.toFloat() ?: 0.5f
                    val layoutParams = window.attributes
                    layoutParams.screenBrightness = brightness.coerceIn(0.01f, 1.0f)
                    window.attributes = layoutParams
                    result.success(null)
                }
                "getBrightness" -> {
                    val brightness = window.attributes.screenBrightness
                    result.success(if (brightness < 0) 0.5 else brightness.toDouble())
                }
                else -> result.notImplemented()
            }
        }
    }
}
