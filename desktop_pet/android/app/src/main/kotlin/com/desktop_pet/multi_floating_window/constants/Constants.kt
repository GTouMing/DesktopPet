package com.desktop_pet.multi_floating_window.constants

/**
 * Multi Floating Window Constants
 */
object Constants {
    // Method name constants
    const val GET_PLATFORM_VERSION = "getPlatformVersion"
    const val IS_PERMISSION_GRANTED = "isPermissionGranted"
    const val REQUEST_PERMISSION = "requestPermission"
    const val SHOW_OVERLAY = "showOverlay"
    const val CLOSE_OVERLAY = "closeOverlay"
    const val CLOSE_ALL_OVERLAYS = "closeAllOverlays"
    const val UPDATE_FLAG = "updateFlag"
    const val RESIZE_OVERLAY = "resizeOverlay"
    const val MOVE_OVERLAY = "moveOverlay"

    const val START_DRAGGING = "startDragging"
    const val GET_OVERLAY_POSITION = "getOverlayPosition"
    const val GET_SCREEN_SIZE = "getScreenSize"
    const val SHARE_DATA = "shareData"
    const val OPEN_MAIN_APP = "openMainApp"
    const val CLOSE_OVERLAY_FROM_OVERLAY = "close"
    const val OVERLAY_CONTROL_CHANNEL = "multi_floating_window_android/overlay_control"
    const val IS_SHOWING = "isShowing"
    const val IS_OVERLAY_SHOWING = "isOverlayShowing"
    const val GET_OVERLAY_IDS = "getOverlayIds"
    const val IS_MAIN_APP_RUNNING = "isMainAppRunning"

    /** 主窗口写入 MMKV 后调用，通知所有悬浮窗刷新设置 */
    const val SEND_SETTINGS_UPDATED = "sendSettingsUpdated"

    // Event channels
    const val OVERLAY_EVENT_CHANNEL = "multi_floating_window_android/overlay_listener"

    /** MethodChannel on each overlay engine for native→Dart gesture events */
    const val GESTURE_METHOD_CHANNEL = "multi_floating_window_android/gesture_events"

    // Parameter constants
    const val OVERLAY_ID = "overlayId"
    const val HEIGHT = "height"
    const val WIDTH = "width"
    const val FLAG = "flag"
    const val ENABLE_DRAG = "enableDrag"
    const val START_POSITION = "startPosition"
    const val X = "x"
    const val Y = "y"
    const val DATA = "data"

    // Overlay flag constants
    const val CLICK_THROUGH = "clickThrough"
    const val DEFAULT_FLAG = "defaultFlag"
    const val FOCUS_POINTER = "focusPointer"

    // Window size constants
    const val MATCH_PARENT = -1
    const val WRAP_CONTENT = -2

    // Notification channel
    const val NOTIFICATION_CHANNEL_ID = "multi_floating_window_channel"
    const val NOTIFICATION_CHANNEL_NAME = "Multi Floating Window Notification"

    // ── Gesture event channel keys ─────────────────────────────────────────
    /** Key for the gesture event type in the EventChannel payload */
    const val GESTURE_EVENT_KEY = "event"
    const val GESTURE_EVENT_OVERLAY_ID = "overlayId"
    const val GESTURE_EVENT_X = "x"
    const val GESTURE_EVENT_Y = "y"
    const val GESTURE_EVENT_DX = "dx"
    const val GESTURE_EVENT_DY = "dy"

    // ── Gesture event type values ──────────────────────────────────────────
    const val GESTURE_DRAG_START = "dragStart"
    const val GESTURE_DRAG_MOVE  = "dragMove"
    const val GESTURE_DRAG_END   = "dragEnd"
    const val GESTURE_TAP        = "tap"

    /** Minimum movement in px to consider a touch as a drag */
    const val DRAG_THRESHOLD = 10f
}
