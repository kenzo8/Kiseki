package com.kenzo.kien

import android.content.res.Resources
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.kenzo.kien/system_locales"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "getSystemLocales") {
                try {
                    val tags = getSystemLocaleTags()
                    result.success(tags)
                } catch (e: Exception) {
                    result.error("ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    /**
     * Returns the system-wide preferred locale list (language order from Settings).
     * Uses system Configuration.locales for all API 24+ (including 33+).
     */
    private fun getSystemLocaleTags(): List<String> {
        @Suppress("DEPRECATION")
        val localeList = Resources.getSystem().configuration.locales
        val list = mutableListOf<String>()
        for (i in 0 until localeList.size()) {
            list.add(localeList[i].toLanguageTag())
        }
        return list
    }
}
