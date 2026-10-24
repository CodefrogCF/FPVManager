package com.codefrog.fpvmanager

import android.app.Activity
import android.content.Context
import android.hardware.input.InputManager
import android.os.Handler
import android.os.Looper
import android.view.InputDevice
import android.view.KeyEvent
import android.view.MotionEvent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.sign

/** Process-local input only; physical devices never control a real aircraft. */
class NavigationInputHandler(private val activity: Activity, messenger: BinaryMessenger) : InputManager.InputDeviceListener {
    private val manager = activity.getSystemService(Context.INPUT_SERVICE) as InputManager
    private val handler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var enabled = false
    private var deviceId: Int? = null
    private var leftX = 0.0
    private var leftY = 0.0
    private var rightX = 0.0
    private var rightY = 0.0
    private var leftTrigger = 0.0
    private var rightTrigger = 0.0
    private val buttons = mutableSetOf<Int>()
    private val channel = MethodChannel(messenger, "com.codefrog.fpvmanager/navigation_input")
    private val events = EventChannel(messenger, "com.codefrog.fpvmanager/navigation_events")
    private val heartbeat = object : Runnable {
        override fun run() {
            if (enabled && activity.hasWindowFocus()) emit()
            if (enabled) handler.postDelayed(this, 33)
        }
    }
    init {
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) { sink = eventSink }
            override fun onCancel(arguments: Any?) { sink = null; updateEnabled(false) }
        })
        channel.setMethodCallHandler { call, result ->
            if (call.method != "setEnabled") { result.notImplemented() }
            else { updateEnabled(call.argument<Boolean>("enabled") == true); result.success(null) }
        }
        manager.registerInputDeviceListener(this, handler)
    }
    private fun updateEnabled(value: Boolean) {
        handler.removeCallbacks(heartbeat)
        enabled = value
        clear()
        if (enabled) handler.post(heartbeat)
    }
    private fun clear() {
        deviceId = null; leftX = 0.0; leftY = 0.0; rightX = 0.0; rightY = 0.0
        leftTrigger = 0.0; rightTrigger = 0.0; buttons.clear(); emit()
    }
    fun pause() { updateEnabled(false) }
    fun focusChanged(focused: Boolean) { if (!focused) clear() }
    private fun pressed(code: Int) = if (buttons.contains(code)) 1.0 else 0.0
    private fun emit() {
        sink?.success(mapOf(
            "forward" to (-leftY + pressed(KeyEvent.KEYCODE_DPAD_UP) - pressed(KeyEvent.KEYCODE_DPAD_DOWN)).coerceIn(-1.0,1.0),
            "right" to (leftX + pressed(KeyEvent.KEYCODE_DPAD_RIGHT) - pressed(KeyEvent.KEYCODE_DPAD_LEFT)).coerceIn(-1.0,1.0),
            "yaw" to rightX, "pitch" to rightY,
            "vertical" to (rightTrigger-leftTrigger+pressed(KeyEvent.KEYCODE_BUTTON_R1)-pressed(KeyEvent.KEYCODE_BUTTON_L1)).coerceIn(-1.0,1.0),
            "reset" to buttons.contains(KeyEvent.KEYCODE_BUTTON_A),
            "exit" to buttons.contains(KeyEvent.KEYCODE_BUTTON_B), "connected" to (deviceId != null)))
    }
    private fun centered(event: MotionEvent, axis: Int): Double {
        val value = event.getAxisValue(axis).toDouble()
        if (!value.isFinite()) return 0.0
        val flat = max(.15, event.device?.getMotionRange(axis,event.source)?.flat?.toDouble() ?: .15)
        return if (abs(value) <= flat || flat >= 1) 0.0 else (sign(value)*(abs(value)-flat)/(1-flat)).coerceIn(-1.0,1.0)
    }
    fun motion(event: MotionEvent): Boolean {
        if (!enabled || sink == null || !activity.hasWindowFocus() || !event.isFromSource(InputDevice.SOURCE_JOYSTICK)) return false
        if (event.action != MotionEvent.ACTION_MOVE) return false
        if (deviceId != null && deviceId != event.deviceId) clear()
        deviceId = event.deviceId
        leftX = centered(event,MotionEvent.AXIS_X)
        leftY = centered(event,MotionEvent.AXIS_Y)
        if (leftX == 0.0) leftX = centered(event,MotionEvent.AXIS_HAT_X)
        if (leftY == 0.0) leftY = centered(event,MotionEvent.AXIS_HAT_Y)
        rightX = centered(event,if (event.device?.getMotionRange(MotionEvent.AXIS_Z,event.source) != null) MotionEvent.AXIS_Z else MotionEvent.AXIS_RX)
        rightY = centered(event,if (event.device?.getMotionRange(MotionEvent.AXIS_RZ,event.source) != null) MotionEvent.AXIS_RZ else MotionEvent.AXIS_RY)
        fun trigger(axis: Int, fallback: Int): Double {
            val selected = if (event.device?.getMotionRange(axis,event.source) != null) axis else fallback
            val value = event.getAxisValue(selected).toDouble()
            return if (value.isFinite()) value.coerceIn(0.0,1.0) else 0.0
        }
        leftTrigger = trigger(MotionEvent.AXIS_LTRIGGER,MotionEvent.AXIS_BRAKE)
        rightTrigger = trigger(MotionEvent.AXIS_RTRIGGER,MotionEvent.AXIS_GAS)
        return true
    }
    fun key(event: KeyEvent): Boolean {
        if (!enabled || sink == null || !activity.hasWindowFocus() ||
            !(event.isFromSource(InputDevice.SOURCE_GAMEPAD) || event.isFromSource(InputDevice.SOURCE_JOYSTICK) || event.isFromSource(InputDevice.SOURCE_DPAD))) return false
        val supported = setOf(KeyEvent.KEYCODE_BUTTON_A,KeyEvent.KEYCODE_BUTTON_B,KeyEvent.KEYCODE_BUTTON_L1,
            KeyEvent.KEYCODE_BUTTON_R1,KeyEvent.KEYCODE_DPAD_UP,KeyEvent.KEYCODE_DPAD_DOWN,KeyEvent.KEYCODE_DPAD_LEFT,KeyEvent.KEYCODE_DPAD_RIGHT)
        if (!supported.contains(event.keyCode)) return false
        if (deviceId != null && deviceId != event.deviceId) clear()
        deviceId = event.deviceId
        if (event.action == KeyEvent.ACTION_DOWN) buttons.add(event.keyCode) else buttons.remove(event.keyCode)
        return true
    }
    override fun onInputDeviceRemoved(id: Int) { if (deviceId == id) clear() }
    override fun onInputDeviceAdded(id: Int) {}
    override fun onInputDeviceChanged(id: Int) { if (deviceId == id) clear() }
    fun dispose() {
        handler.removeCallbacks(heartbeat); manager.unregisterInputDeviceListener(this)
        enabled = false; clear(); sink = null; events.setStreamHandler(null); channel.setMethodCallHandler(null)
    }
}
