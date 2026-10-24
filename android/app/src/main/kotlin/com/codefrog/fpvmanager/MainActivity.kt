package com.codefrog.fpvmanager

import io.flutter.embedding.android.FlutterActivity
import android.app.Activity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingExport: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null
    private val exportRequest = 58031

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.codefrog.fpvmanager/route_files").setMethodCallHandler { call, result ->
            if (call.method != "saveRoute") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingExport != null) {
                result.error("busy", "A route export is already open", null)
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            val name = call.argument<String>("name")
            val mime = call.argument<String>("mimeType")
            if (bytes == null || bytes.size > 4 * 1024 * 1024 || name == null ||
                name.length > 130 || name.contains('/') || name.contains('\\') ||
                mime !in listOf("application/geo+json", "application/gpx+xml")) {
                result.error("invalid", "Invalid route file", null)
                return@setMethodCallHandler
            }
            pendingExport = result
            exportBytes = bytes
            try {
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mime
                    putExtra(Intent.EXTRA_TITLE, name)
                }
                startActivityForResult(intent, exportRequest)
            } catch (error: Exception) {
                pendingExport = null
                exportBytes = null
                result.error("save_failed", "Unable to open file destination", null)
            }
        }
    }

    @Deprecated("Android activity result callback required by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != exportRequest) return
        val result = pendingExport ?: return
        val bytes = exportBytes
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) {
            pendingExport = null
            exportBytes = null
            result.success(false)
            return
        }
        Thread {
            try {
                val stream = contentResolver.openOutputStream(uri, "w")
                    ?: throw IllegalStateException("No file destination")
                stream.use { it.write(bytes) }
                runOnUiThread {
                    if (pendingExport === result) {
                        pendingExport = null
                        exportBytes = null
                        result.success(true)
                    }
                }
            } catch (error: Exception) {
                runOnUiThread {
                    if (pendingExport === result) {
                        pendingExport = null
                        exportBytes = null
                        result.error("save_failed", "Unable to write route file", null)
                    }
                }
            }
        }.start()
    }

    override fun onDestroy() {
        pendingExport?.error("cancelled", "Route export interrupted", null)
        pendingExport = null
        exportBytes = null
        super.onDestroy()
    }
}
