package com.rallypoint.rally_point

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rallypoint/location"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startLocationService" -> {
                        LocationService.startService(this)
                        result.success(true)
                    }
                    "stopLocationService" -> {
                        LocationService.stopService(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
