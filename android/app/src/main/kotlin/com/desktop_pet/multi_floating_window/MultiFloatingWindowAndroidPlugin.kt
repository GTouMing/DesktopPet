package com.desktop_pet.multi_floating_window

import android.app.Activity
import android.content.Context
import android.content.Intent
import com.desktop_pet.multi_floating_window.constants.Constants
import com.desktop_pet.multi_floating_window.manager.OverlayManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

/**
 * Multi Floating Window Android Plugin
 *
 * 只暴露桌宠悬浮窗真正需要的方法；每只桌宠一个系统悬浮窗。
 */
class MultiFloatingWindowAndroidPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private val overlayManager: OverlayManager by lazy { OverlayManager(context) }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, Constants.MAIN_CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            Constants.REQUEST_PERMISSION -> {
                if (activity != null) {
                    val intent = overlayManager.requestPermission()
                    activity?.startActivity(intent)
                    result.success(true)
                } else {
                    result.error("NO_ACTIVITY", "Activity is not available", null)
                }
            }

            Constants.HAS_PERMISSION -> {
                result.success(overlayManager.hasPermission())
            }

            Constants.SHOW_OVERLAY -> {
                try {
                    val overlayId = call.argument<String>(Constants.OVERLAY_ID) ?: "default"
                    val height = call.argument<Int>(Constants.HEIGHT) ?: Constants.MATCH_PARENT
                    val width = call.argument<Int>(Constants.WIDTH) ?: Constants.MATCH_PARENT
                    val flag = call.argument<String>(Constants.FLAG) ?: Constants.DEFAULT_FLAG
                    val startPosition = call.argument<Map<String, Any>>(Constants.START_POSITION)

                    // Start foreground service (notification is mandatory)
                    val serviceIntent = Intent(context, OverlayService::class.java)
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }

                    // Show floating window
                    overlayManager.showOverlay(
                        overlayId = overlayId,
                        height = height,
                        width = width,
                        flag = flag,
                        startPosition = startPosition
                    )

                    result.success(true)
                } catch (e: Exception) {
                    result.error("SHOW_OVERLAY_ERROR", e.message, null)
                }
            }

            Constants.CLOSE_OVERLAY -> {
                try {
                    val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                    if (overlayId != null) {
                        overlayManager.closeOverlay(overlayId)

                        // If no overlays left, stop service
                        if (!overlayManager.isShowing()) {
                            if (OverlayService.isRunning()) {
                                context.stopService(Intent(context, OverlayService::class.java))
                            }
                        }
                    }
                    result.success(true)
                } catch (e: Exception) {
                    result.error("CLOSE_OVERLAY_ERROR", e.message, null)
                }
            }

            Constants.UPDATE_FLAG -> {
                try {
                    val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                    val flag = call.argument<String>(Constants.FLAG) ?: Constants.DEFAULT_FLAG
                    val success = if (overlayId != null) {
                        overlayManager.updateFlag(overlayId, flag)
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
                        overlayManager.resizeOverlay(overlayId, width, height)
                    } else {
                        false
                    }
                    result.success(success)
                } catch (e: Exception) {
                    result.error("RESIZE_OVERLAY_ERROR", e.message, null)
                }
            }

            Constants.START_DRAGGING -> {
                try {
                    val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                    if (overlayId != null) {
                        overlayManager.startDragging(overlayId, result)
                    } else {
                        result.error("INVALID_OVERLAY_ID", "overlayId is null", null)
                    }
                } catch (e: Exception) {
                    result.error("START_DRAGGING_ERROR", e.message, null)
                }
            }

            Constants.MOVE_OVERLAY -> {
                try {
                    val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                    val x = call.argument<Int>(Constants.X) ?: 0
                    val y = call.argument<Int>(Constants.Y) ?: 0
                    val success = if (overlayId != null) {
                        overlayManager.moveOverlay(overlayId, x, y)
                    } else {
                        false
                    }
                    result.success(success)
                } catch (e: Exception) {
                    result.error("MOVE_OVERLAY_ERROR", e.message, null)
                }
            }

            Constants.GET_OVERLAY_POSITION -> {
                try {
                    val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                    val position = if (overlayId != null) {
                        overlayManager.getOverlayPosition(overlayId)
                    } else {
                        mapOf(Constants.X to 0, Constants.Y to 0)
                    }
                    result.success(position)
                } catch (e: Exception) {
                    result.error("GET_OVERLAY_POSITION_ERROR", e.message, null)
                }
            }

            Constants.IS_OVERLAY_SHOWING -> {
                val overlayId = call.argument<String>(Constants.OVERLAY_ID)
                val isShowing = if (overlayId != null) {
                    overlayManager.isOverlayShowing(overlayId)
                } else {
                    false
                }
                result.success(isShowing)
            }

            Constants.SEND_SETTINGS_UPDATED -> {
                overlayManager.sendSettingsUpdated()
                result.success(true)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
