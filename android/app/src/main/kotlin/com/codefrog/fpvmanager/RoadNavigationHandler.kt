package com.codefrog.fpvmanager

import android.app.Activity
import android.speech.tts.TextToSpeech
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Foreground navigation only; speech uses an installed, offline German voice. */
class RoadNavigationHandler(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "com.codefrog.fpvmanager/road_navigation")
    private var speech: TextToSpeech? = null
    private var ready = false
    init {
        speech = TextToSpeech(activity) { status ->
            val engine = speech
            if (status == TextToSpeech.SUCCESS && engine != null) {
                val voice = engine.voices?.firstOrNull { it.locale.language == "de" && !it.isNetworkConnectionRequired }
                ready = voice != null && engine.setVoice(voice) == TextToSpeech.SUCCESS
            }
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "keepAwake" -> {
                    if (call.arguments == true) activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                "speak" -> {
                    val text = call.arguments as? String
                    if (!ready || text == null || text.length > 500 || !activity.hasWindowFocus()) result.success(false)
                    else result.success(speech?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "road-navigation") == TextToSpeech.SUCCESS)
                }
                "stopVoice" -> { speech?.stop(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    fun pause() {
        speech?.stop()
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
    fun dispose() {
        pause(); channel.setMethodCallHandler(null); speech?.shutdown(); speech = null; ready = false
    }
}
