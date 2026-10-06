package com.desktop_pet.pet_floating_window.constants

/**
 * Pet Floating Window Constants
 *
 * 只保留 Dart 侧仍会调用的方法名/参数名。通用多悬浮窗库遗留的能力
 * (shareData / openMainApp / 事件总线 / isShowing / getOverlayIds /
 * focusPointer / dragThreshold 等)已作为死代码移除。
 */
object Constants {
    /** 主通道名(与 Dart `Constants.channelName` 一致) */
    const val MAIN_CHANNEL = "pet_floating_window"

    // Method name constants
    const val REQUEST_PERMISSION = "requestPermission"
    const val HAS_PERMISSION = "hasPermission"
    const val SHOW_OVERLAY = "showOverlay"
    const val CLOSE_OVERLAY = "closeOverlay"
    const val UPDATE_FLAG = "updateFlag"
    const val RESIZE_OVERLAY = "resizeOverlay"
    const val MOVE_OVERLAY = "moveOverlay"
    const val START_DRAGGING = "startDragging"
    const val GET_OVERLAY_POSITION = "getOverlayPosition"
    const val GET_SCREEN_SIZE = "getScreenSize"
    const val IS_OVERLAY_SHOWING = "isOverlayShowing"

    /** 主窗口写入 MMKV 后调用，通知所有悬浮窗刷新设置 */
    const val SEND_SETTINGS_UPDATED = "sendSettingsUpdated"

    /** 原生 → 悬浮窗:设置已更新(与 Dart `Constants.settingsUpdatedEvent` 一致) */
    const val SETTINGS_UPDATED_EVENT = "settings_updated"

    // Parameter constants
    const val OVERLAY_ID = "overlayId"
    const val HEIGHT = "height"
    const val WIDTH = "width"
    const val FLAG = "flag"
    const val START_POSITION = "startPosition"
    const val X = "x"
    const val Y = "y"

    // Overlay flag constants
    const val CLICK_THROUGH = "clickThrough"
    const val DEFAULT_FLAG = "defaultFlag"

    // Window size constants
    const val MATCH_PARENT = -1
    const val WRAP_CONTENT = -2

    // Notification channel
    const val NOTIFICATION_CHANNEL_ID = "pet_floating_window_channel"
    const val NOTIFICATION_CHANNEL_NAME = "Pet Floating Window Notification"
}
