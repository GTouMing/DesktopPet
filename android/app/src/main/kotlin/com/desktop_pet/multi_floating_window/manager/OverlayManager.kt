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
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
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

    /**
     * 所有悬浮窗引擎都从这一个分组创建。
     *
     * 每只桌宠仍是独立的引擎/isolate（它们是各自独立的系统悬浮窗，无法合并），
     * 但同组引擎共享 Dart VM 快照、字体与 GPU 上下文，单个悬浮窗的启动开销与
     * 显存占用都远低于各自 `FlutterEngine(context)` 从零启动。
     *
     * 分组由本类持有：它挂在主引擎的 plugin 上，生命周期长于任何单个悬浮窗。
     */
    private val engineGroup: FlutterEngineGroup by lazy {
        FlutterEngineGroup(context.applicationContext)
    }

    /**
     * 是否已授予"显示在其他应用上层"权限。
     *
     * Dart 侧只在**缺失**时才拉起设置页：否则每次启动都会把用户甩到系统设置里。
     */
    fun hasPermission(): Boolean = Settings.canDrawOverlays(context)

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
     *
     * [width]/[height] 与 [startPosition] 均为物理像素(由 Dart 侧换算)。
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

        // 没有权限时**不要建引擎**。
        //
        // 引擎一建好，它的 Dart 入口就会跑起来；此时 `addView` 必然抛异常，只能就地
        // 回收，而回收是共享分组里的引擎是有代价的：分组内引擎由第一个引擎的 shell
        // 派生，销毁它会连累同组的其它引擎（实测：先失败两个再重建，第二个悬浮窗
        // 拿不到 surface，`mDrawState=NO_SURFACE`、`visible=false`，且永不恢复）。
        //
        // 干脆不建：用户授予权限后由 Dart 侧重试（MainScreen 的 resumed 钩子）。
        if (!Settings.canDrawOverlays(context)) {
            android.util.Log.w(
                "OverlayManager",
                "showOverlay($overlayId): 缺少悬浮窗权限，跳过创建"
            )
            return
        }

        // 从共享分组创建本悬浮窗的引擎（overlayId 作为 Dart 入口参数传入）。
        //
        // createAndRunEngine 会自己执行入口点，因此不再需要手动
        // executeDartEntrypoint。
        val engineOptions = FlutterEngineGroup.Options(context)
            .setDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
            .setDartEntrypointArgs(listOf(overlayId))
        val flutterEngine = engineGroup.createAndRunEngine(engineOptions)!!

        flutterEngine.let { engine ->
            // 悬浮窗引擎内部的通道：供悬浮窗 Dart 侧回读/调整自己的窗口。
            val mainChannel = MethodChannel(
                engine.dartExecutor.binaryMessenger, Constants.MAIN_CHANNEL)
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
            } catch (e: Exception) {
                // 引擎与视图已经建好但不能进窗口：就地回收，避免留下一个无窗口的引擎。
                e.printStackTrace()
                flutterView.detachFromFlutterEngine()
                engine.destroy()
                return
            }

            overlays[overlayId] = overlayInfo

            triggerContinuousRendering(overlayInfo, engine)
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

            // Set flags based on flag
            flags = windowFlagsFor(flag)

            type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            this.width = resolveSize(width)
            this.height = resolveSize(height)

            gravity = Gravity.TOP or Gravity.START
            
            x = 0
            y = 0
        }

        return params
    }

    /**
     * 标志字符串 → WindowManager 标志位。
     *
     * 只区分"穿透"与"默认"两种；具体策略由 Dart 侧决定(见 OverlayFlag)。
     */
    private fun windowFlagsFor(flag: String): Int {
        return when (flag) {
            Constants.CLICK_THROUGH -> {
                // Click through: window doesn't receive any events
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
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
    }

    /** 尺寸哨兵值 → LayoutParams 尺寸。 */
    private fun resolveSize(value: Int): Int {
        return when (value) {
            Constants.MATCH_PARENT -> WindowManager.LayoutParams.MATCH_PARENT
            Constants.WRAP_CONTENT -> WindowManager.LayoutParams.WRAP_CONTENT
            else -> value
        }
    }

    /**
     * Close specific floating window by overlayId
     */
    fun closeOverlay(overlayId: String) {
        val overlayInfo = overlays[overlayId] ?: return

        try {
            windowManager.removeView(overlayInfo.overlayView)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Handle FlutterView
        overlayInfo.flutterView.detachFromFlutterEngine()

        // Handle Flutter engine - destroy it
        overlayInfo.flutterEngine.destroy()

        // Remove from map
        overlays.remove(overlayId)
    }

    /**
     * Update floating window flag for specific overlay
     */
    fun updateFlag(overlayId: String, flag: String): Boolean {
        val overlayInfo = overlays[overlayId] ?: return false

        overlayInfo.windowParams.flags = windowFlagsFor(flag)

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

        overlayInfo.windowParams.width = resolveSize(width)
        overlayInfo.windowParams.height = resolveSize(height)

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
     * Check if any overlay is showing（插件用它决定是否停掉前台服务）。
     */
    fun isShowing(): Boolean {
        return overlays.isNotEmpty()
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
                    Constants.MAIN_CHANNEL
                )
                channel.invokeMethod(Constants.SETTINGS_UPDATED_EVENT, null)
            } catch (_: Exception) {
                // 单窗口失败不影响其他
            }
        }
    }

    /**
     * Get real screen size（返回物理像素）
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
