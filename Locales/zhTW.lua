local L = {}

L.VQR_QUEST_ACTIVE = "已啟動"
L.VQR_TIME_LEFT = "%d分%d秒"
L.VQR_EXPIRING_SOON = "即將結束"
L.VQR_TIME_UNAVAILABLE = "剩餘時間獲取中…"
L.VQR_NOT_ACTIVE = "暫未啟動"
L.VQR_REACQUIRING = "正在重新取得任務狀態…"

L.REMINDER_TITLE = "虛空任務提醒"
L.REMINDER_TEXT = "%s: %s: %s"
L.TOOLTIP_DONT_REMIND_WEEK = "本週不再提醒（當前角色）"
L.TOOLTIP_DONT_REMIND_LOGIN = "本次登入不再提醒"
L.TOOLTIP_SETTINGS = "設定"
L.SETTING_REMIND_EVEN_IF_COMPLETED = "任務完成仍提醒（所有角色）"
L.SETTING_REMIND_EVEN_IF_COMPLETED_CHAR = "任務完成仍提醒（當前角色）"
L.SETTING_REMIND_EVEN_IF_COMPLETED_NONE = "不額外提醒"
L.MSG_NO_WORLD_QUEST = "未設定世界任務ID"
L.MSG_WORLD_QUEST_COMPLETED = "虛空決戰已完成，無需提醒"
L.MSG_ADDON_LOADED = "|cFF00FF00[虛空提醒] 插件已載入|r"

L.HUNT_REMINDER_TEXT = "方唐鏡已啟動"
L.HUNT_TEST_MAP_NAMES = { "永歌森林", "祖阿曼", "虛影風暴", "哈籟恩達爾", "盤卷蛇島" }
L.HUNT_BTN_SET_MARKER = "設定標記點"
L.HUNT_TOOLTIP_SET_MARKER = "在地圖上設定方唐鏡標記點（感謝阿落分享）"
L.HUNT_TOOLTIP_DONT_REMIND_TODAY = "今日不再提醒（當前角色）"
L.HUNT_TOOLTIP_DONT_REMIND_LOGIN = "本次登入不再提醒"

-- 任務/地圖名為繁中化近似，台服正式譯名待核對
L.VQR_QUEST_NAMES = {
    [96400] = "糾纏腐蝕",
    [96548] = "孢分榜首",
}

if GetLocale() == "zhTW" then
    _G["VoidQuestReminder_Locale"] = L
end