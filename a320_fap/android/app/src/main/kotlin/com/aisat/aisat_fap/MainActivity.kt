package com.aisat.aisat_fap

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // ANDROID_ID stays the same when the app is uninstalled and installed
        // again (it changes only on a factory reset), so a license can be
        // restored on the same device.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fap/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "androidId") {
                    result.success(
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID),
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
