package com.desktop_pet.multi_floating_window.manager

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.provider.Settings
import android.util.Size
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.core.net.toUri
import com.desktop_pet.multi_floating_window.constants.Constants
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel


/**
 * Data class to hold overlay information
 */
data class OverlayInfo(
    val overlayId: String,
    var overlayView: FrameLayout,
    var flutterEngine: FlutterEngine,
    var flutterView: FlutterView,
    var windowParams: WindowManager.LayoutParams,
    var currentX: Int = 0,
    var currentY: Int = 0,
)

/**
 * Multi Floating Window Manager - Uses Map to store multiple overlays
 */
class OverlayManager(
    private val context: Context
) {
    private val windowManager: WindowManager by lazy {
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    // Map to store multiple overlays by overlayId
    private val overlays: MutableMap<String, OverlayInfo> = mutableMapOf()
    private var eventSink: EventChannel.EventSink? = null

    companion object {
        // No preloaded engine functionality - removed for simplicity
    }

    /**
     * Check floating window permission
     */
    fun isPermissionGranted(): Boolean {
        return Settings.canDrawOverlays(context)
    }

    /**
     * Request floating window permission
     */
    fun requestPermission(): Intent {
        return Intent(
            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
            "package:${context.packageName}".toUri()
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    /**
     * Show floating window with specific overlayId
     */
    fun showOverlay(
        overlayId: String,
        height: Int = Constants.MATCH_PARENT,
        width: Int = Constants.MATCH_PARENT,
        flag: String = Constants.DEFAULT_FLAG,
        startPosition: Map<String, Any>? = null
    ) {
        // If overlay already exists, close it first
        if (overlays.containsKey(overlayId)) {
            closeOverlay(overlayId)
        }

        // Create a new Flutter engine for this overlay
        val flutterEngine = FlutterEngine(context)

        flutterEngine.let { engine ->
            // ── 通过 dartEntrypointArgs 传递 overlayId 和真实 density ──────
            val defaultEntrypoint = DartExecutor.DartEntrypoint.createDefault()
            val density = context.resources.displayMetrics.density
            val arg = listOf(overlayId, density.toString())
            engine.dartExecutor.executeDartEntrypoint(defaultEntrypoint, arg)
            // Always cache the current engine for overlay control
            FlutterEngineCache.getInstance().put("overlay_engine_$overlayId", engine)

            // Set up dedicated method channel for the overlay engine
            val overlayControlChannel = MethodChannel(
                engine.dartExecutor.binaryMessenger, Constants.OVERLAY_CONTROL_CHANNEL)
            overlayControlChannel.setMethodCallHandler { call, result ->
                if (call.method == Constants.CLOSE_OVERLAY_FROM_OVERLAY) {
                    val overlayIdToClose = call.argument<String>(Constants.OVERLAY_ID)
                    if (overlayIdToClose != null) {
                        closeOverlay(overlayIdToClose)
                    }
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }

            // Also register the main channel for the overlay engine
            // This allows overlay to call methods like getOverlayPosition, moveOverlay, etc.
            val mainChannel = MethodChannel(
                engine.dartExecutor.binaryMessenger, "multi_floating_window_android")
            mainChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    Constants.GET_OVERLAY_POSITION -> {
                        try {
                            val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                            val position = if (overlayId != null) {
                                getOverlayPosition(overlayId)
                            } else {
                                mapOf(Constants.X to 0, Constants.Y to 0)
                            }
                            result.success(position)
                        } catch (e: Exception) {
                            result.error("GET_OVERLAY_POSITION_ERROR", e.message, null)
                        }
                    }
                    Constants.MOVE_OVERLAY -> {
                        try {
                            val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                            val x = call.argument<Int>(Constants.X) ?: 0
                            val y = call.argument<Int>(Constants.Y) ?: 0
                            val success = if (overlayId != null) {
                                moveOverlay(overlayId, x, y)
                            } else {
                                false
                            }
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("MOVE_OVERLAY_ERROR", e.message, null)
                        }
                    }
                    Constants.UPDATE_FLAG -> {
                        try {
                            val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                            val flag = call.argument<String>(Constants.FLAG) ?: Constants.DEFAULT_FLAG
                            val success = if (overlayId != null) {
                                updateFlag(overlayId, flag)
                            } else {
                                false
                            }
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("UPDATE_FLAG_ERROR", e.message, null)
                        }
                    }
                    Constants.RESIZE_OVERLAY -> {
                        try {
                            val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                            val width = call.argument<Int>(Constants.WIDTH) ?: Constants.MATCH_PARENT
                            val height = call.argument<Int>(Constants.HEIGHT) ?: Constants.MATCH_PARENT
                            val success = if (overlayId != null) {
                                resizeOverlay(overlayId, width, height)
                            } else {
                                false
                            }
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("RESIZE_OVERLAY_ERROR", e.message, null)
                        }
                    }
                    Constants.IS_OVERLAY_SHOWING -> {
                        val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                        val isShowing = if (overlayId != null) {
                            isOverlayShowing(overlayId)
                        } else {
                            false
                        }
                        result.success(isShowing)
                    }
                    Constants.GET_SCREEN_SIZE -> {
                        try {
                            result.success(getScreenSize())
                        } catch (e: Exception) {
                            result.error("GET_SCREEN_SIZE_ERROR", e.message, null)
                        }
                    }
                    Constants.START_DRAGGING -> {
                        val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                        if (overlayId != null) {
                            startDragging(overlayId, result)
                        } else {
                            result.error("INVALID_OVERLAY_ID", "overlayId is null", null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

            // Register a MethodChannel on the overlay engine for native→Dart
            // gesture events (mirrors window_manager's architecture).

            // Android 13 上 FlutterTextureView 在悬浮窗中 surface 会被系统销毁重建
            // 导致闪烁。改用 FlutterSurfaceView + zOrderOnTop 绕开此问题。
            val surfaceView = FlutterSurfaceView(context)
            surfaceView.setZOrderOnTop(true)
            surfaceView.holder?.setFormat(PixelFormat.TRANSLUCENT)
            val flutterView = FlutterView(context, surfaceView)
            flutterView.attachToFlutterEngine(engine)

            // Create overlay view
            val overlayView = FrameLayout(context)
            flutterView.let {
                overlayView.addView(
                    it,
                    FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                )
            }

            // Set up window parameters
            val windowParams = setupWindowParams(height, width, flag)

            val overlayInfo = OverlayInfo(
                overlayId = overlayId,
                overlayView = overlayView,
                flutterEngine = engine,
                flutterView = flutterView,
                windowParams = windowParams,
            )

            // Set initial position
            if (startPosition != null) {
                overlayInfo.currentX = (startPosition[Constants.X] as? Number)?.toInt() ?: 0
                overlayInfo.currentY = (startPosition[Constants.Y] as? Number)?.toInt() ?: 0
                windowParams.x = overlayInfo.currentX
                windowParams.y = overlayInfo.currentY
            }

            // Add to window and store in map
            try {
                windowManager.addView(overlayView, windowParams)
                overlays[overlayId] = overlayInfo

                triggerContinuousRendering(overlayInfo, engine)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    /**
     * 通知 Flutter engine 应用可见，确保渲染管线启动。
     */
    private fun triggerContinuousRendering(overlayInfo: OverlayInfo, engine: FlutterEngine) {
        overlayInfo.overlayView.post {
            engine.lifecycleChannel.appIsResumed()
            overlayInfo.flutterView.invalidate()
        }
    }

    /**
     * Set up window parameters
     */
    private fun setupWindowParams(
        height: Int,
        width: Int,
        flag: String
    ): WindowManager.LayoutParams {
        val params = WindowManager.LayoutParams().apply {
            format = PixelFormat.TRANSLUCENT

            // Set flags based on flag and enableDrag
            flags = when (flag) {
                Constants.CLICK_THROUGH -> {
                    // Click through: window doesn't receive any events
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                }
                Constants.FOCUS_POINTER -> {
                    // Focus pointer: allows external events, self-interactive (remove NOT_FOCUSABLE)
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                }
                else -> { // defaultFlag
                    // For system gesture compatibility, use a combination of flags that:
                    // 1. Allow system gestures to work properly
                    // 2. Prevent the overlay from blocking system navigation
                    // 3. Still allow interaction with the overlay content
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
                }
            }

            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            this.width = when (width) {
                Constants.MATCH_PARENT -> {
                    WindowManager.LayoutParams.MATCH_PARENT
                }
                Constants.WRAP_CONTENT -> {
                    WindowManager.LayoutParams.WRAP_CONTENT
                }
                else -> {
                    width
                }
            }

            this.height = when (height) {
                Constants.MATCH_PARENT -> {
                    WindowManager.LayoutParams.MATCH_PARENT
                }
                Constants.WRAP_CONTENT -> {
                    WindowManager.LayoutParams.WRAP_CONTENT
                }
                else -> {
                    height
                }
            }

            gravity = Gravity.TOP or Gravity.START
            
            x = 0
            y = 0
        }

        return params
    }

    /**
     * Close specific floating window by overlayId
     */
    fun closeOverlay(overlayId: String) {
        val overlayInfo = overlays[overlayId] ?: return

        // Clean up dedicated channel
        overlayInfo.flutterEngine.dartExecutor.binaryMessenger.let { messenger ->
            MethodChannel(messenger, Constants.OVERLAY_CONTROL_CHANNEL).setMethodCallHandler(null)
        }

        try {
            windowManager.removeView(overlayInfo.overlayView)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Handle FlutterView
        overlayInfo.flutterView.detachFromFlutterEngine()

        // Handle Flutter engine - destroy it
        overlayInfo.flutterEngine.destroy()
        FlutterEngineCache.getInstance().remove("overlay_engine_$overlayId")

        // Remove from map
        overlays.remove(overlayId)
    }

    /**
     * Close all floating windows
     */
    fun closeAllOverlays() {
        val overlayIdsToClose = overlays.keys.toList()
        for (overlayId in overlayIdsToClose) {
            closeOverlay(overlayId)
        }
    }

    /**
     * Update floating window flag for specific overlay
     */
    fun updateFlag(overlayId: String, flag: String): Boolean {
        val overlayInfo = overlays[overlayId] ?: return false

        overlayInfo.windowParams.flags = when (flag) {
            Constants.CLICK_THROUGH -> {
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
            }
            Constants.FOCUS_POINTER -> {
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
            }
            else -> { // defaultFlag
                // Use the same flag combination as setupWindowParams for consistency
                // This ensures system gestures work properly across all scenarios
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
            }
        }

        try {
            windowManager.updateViewLayout(overlayInfo.overlayView, overlayInfo.windowParams)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return false
    }

    /**
     * Resize specific floating window
     */
    fun resizeOverlay(overlayId: String, width: Int, height: Int): Boolean {
        val overlayInfo = overlays[overlayId] ?: return false

        overlayInfo.windowParams.width = when (width) {
            Constants.MATCH_PARENT -> {
                WindowManager.LayoutParams.MATCH_PARENT
            }
            Constants.WRAP_CONTENT -> {
                WindowManager.LayoutParams.WRAP_CONTENT
            }
            else -> {
                width
            }
        }

        overlayInfo.windowParams.height = when (height) {
            Constants.MATCH_PARENT -> {
                WindowManager.LayoutParams.MATCH_PARENT
            }
            Constants.WRAP_CONTENT -> {
                WindowManager.LayoutParams.WRAP_CONTENT
            }
            else -> {
                height
            }
        }

        try {
            windowManager.updateViewLayout(overlayInfo.overlayView, overlayInfo.windowParams)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return false
    }

    /**
     * Move specific floating window position
     */
    fun moveOverlay(overlayId: String, x: Int, y: Int): Boolean {
        val overlayInfo = overlays[overlayId] ?: return false

        overlayInfo.windowParams.x = x
        overlayInfo.windowParams.y = y
        overlayInfo.currentX = x
        overlayInfo.currentY = y

        try {
            windowManager.updateViewLayout(overlayInfo.overlayView, overlayInfo.windowParams)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return false
    }

    @SuppressLint("ClickableViewAccessibility")
    fun startDragging(overlayId: String, dragResult: MethodChannel.Result) {
        val overlayInfo = overlays[overlayId]
        if (overlayInfo == null) {
            dragResult.error("OVERLAY_NOT_FOUND", "Overlay $overlayId not found", null)
            return
        }

        var firstMove = true
        var baseRawX = 0f
        var baseRawY = 0f
        val baseX = overlayInfo.currentX
        val baseY = overlayInfo.currentY

        val dragListener = View.OnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_MOVE -> {
                    if (firstMove) {
                        baseRawX = event.rawX
                        baseRawY = event.rawY
                        firstMove = false
                    }
                    val dx = (event.rawX - baseRawX).toInt()
                    val dy = (event.rawY - baseRawY).toInt()
                    overlayInfo.windowParams.x = baseX + dx
                    overlayInfo.windowParams.y = baseY + dy
                    try {
                        windowManager.updateViewLayout(
                            overlayInfo.overlayView, overlayInfo.windowParams)
                    } catch (_: Exception) {}
                    overlayInfo.currentX = overlayInfo.windowParams.x
                    overlayInfo.currentY = overlayInfo.windowParams.y
                    false  // pass through → Flutter gesture arena still receives events
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    overlayInfo.flutterView.setOnTouchListener(null)
                    dragResult.success(true)
                    false
                }
                else -> false
            }
        }

        overlayInfo.flutterView.setOnTouchListener(dragListener)
    }

    /**
     * Get current specific floating window position
     */
    fun getOverlayPosition(overlayId: String): Map<String, Int> {
        val overlayInfo = overlays[overlayId]
        return if (overlayInfo != null) {
            mapOf(
                Constants.X to (overlayInfo.windowParams.x),
                Constants.Y to (overlayInfo.windowParams.y)
            )
        } else {
            mapOf(Constants.X to 0, Constants.Y to 0)
        }
    }

    /**
     * Check if specific overlay is showing
     */
    fun isOverlayShowing(overlayId: String): Boolean {
        return overlays.containsKey(overlayId) && overlays[overlayId]?.overlayView?.isAttachedToWindow == true
    }

    /**
     * Check if any overlay is showing
     */
    fun isShowing(): Boolean {
        return overlays.isNotEmpty()
    }

    /**
     * Get all active overlay ids
     */
    fun getOverlayIds(): List<String> {
        return overlays.keys.toList()
    }

    /**
     * Share data between floating window and main app
     */
    fun shareData(data: Any?): Boolean {
        if (eventSink == null) {
            return false
        }

        eventSink?.success(data)
        return true
    }

    /**
     * Set event sink
     */
    fun setEventSink(sink: EventChannel.EventSink?) {
        this.eventSink = sink
    }

    /**
     * 向所有悬浮窗引擎推送 settings_updated 消息，触发即时刷新。
     *
     * 主窗口写入 MMKV 后调用此方法，悬浮窗 Dart 侧收到后调用 refreshSettings()。
     */
    fun sendSettingsUpdated() {
        for ((_, overlayInfo) in overlays) {
            try {
                val channel = MethodChannel(
                    overlayInfo.flutterEngine.dartExecutor.binaryMessenger,
                    "multi_floating_window_android"
                )
                channel.invokeMethod("settings_updated", null)
            } catch (_: Exception) {
                // 单窗口失败不影响其他
            }
        }
    }

    /**
     * Get real screen size（返回逻辑像素）
     */
    fun getScreenSize(): Map<String?, Int?> {
        val displayMetrics = android.content.res.Resources.getSystem().displayMetrics
        val size = Size(displayMetrics.widthPixels, displayMetrics.heightPixels)
        val sizeMap: MutableMap<String?, Int?> = HashMap()
        sizeMap["width"] = size.width
        sizeMap["height"] = size.height
        return sizeMap
    }
}
