local L = {}

L.VQR_QUEST_ACTIVE = "已啟動"
L.VQR_TIME_LEFT = "%d分%d秒"
L.VQR_EXPIRING_SOON = "即將結束"
L.VQR_TIME_UNAVAILABLE = "剩餘時間獲取中…"
L.VQR_NOT_ACTIVE = "暫未啟動"
L.VQR_REACQUIRING = "正在重新取得任務狀態…"
L.VQR_COMPLETED_SUFFIX = "（已完成）"

L.REMINDER_TITLE = "虛空任務提醒"
L.TOOLTIP_DONT_REMIND_WEEK = "本週不再提醒（當前角色）"
L.TOOLTIP_DONT_REMIND_LOGIN = "本次登入不再提醒"
L.TOOLTIP_SETTINGS = "設定"
L.SETTING_REMIND_EVEN_IF_COMPLETED = "任務完成仍提醒（所有角色）"
L.SETTING_REMIND_EVEN_IF_COMPLETED_CHAR = "任務完成仍提醒（當前角色）"
L.SETTING_REMIND_EVEN_IF_COMPLETED_NONE = "不額外提醒"
L.HINT_MANUAL_SHOW = "【手動顯示】拖曳調整位置"

-- 彈窗按鈕回饋
L.MSG_SUPPRESS_WEEK = "|cFF00FF00[虛空提醒] 本週不再提醒（當前角色），重新開啟彈窗請輸入 /vqr show，需重新提醒請輸入 /vqr reset|r"
L.MSG_SUPPRESS_LOGIN = "|cFF00FF00[虛空提醒] 本次登入不再提醒，重新開啟彈窗請輸入 /vqr show，需重新提醒請輸入 /vqr reset|r"

-- 斜線指令回饋
L.MSG_SHOW_FORCED = "|cFF00FF00[虛空提醒] 已強制顯示彈窗（無視條件）|r"
L.MSG_HIDDEN = "|cFF00FF00[虛空提醒] 已隱藏彈窗|r"
L.MSG_RESET_DONE = "|cFF00FF00[虛空提醒] 當前角色提醒設定已重置|r"
L.MSG_RESETPOS_DONE = "|cFF00FF00[虛空提醒] 彈窗位置已重置為預設|r"

-- /vqr status
L.STATUS_HEADER = "|cFF00FF00[虛空提醒] 狀態:|r"
L.STATUS_WORLD = "  虛空世界: %s"
L.STATUS_QUEST_ID = "  逃課任務ID: %s"
L.STATUS_QUEST_ACTIVE = "  逃課任務啟動: %s"
L.STATUS_CONFRONTATION = "  虛空決戰: %s"
L.STATUS_SUPPRESS_WEEK = "  本週不再提醒: %s"
L.STATUS_SUPPRESS_LOGIN = "  本次登入不再提醒: %s"
L.STATUS_FORCE_SHOW = "  強制顯示中: %s"
L.STATUS_REMIND_ALL = "  已完成仍提醒（所有角色）: %s"
L.STATUS_REMIND_CHAR = "  已完成仍提醒（當前角色）: %s"

L.VAL_NONE = "無"
L.VAL_YES = "是"
L.VAL_NO = "否"
L.VAL_DONE = "已完成"
L.VAL_UNDONE = "未完成"

-- 說明
L.HELP_HEADER = "|cFF00FF00[虛空提醒] 指令:|r"
L.HELP_SHOW = "  /vqr show - 強制顯示彈窗（無視條件）"
L.HELP_HIDE = "  /vqr hide - 隱藏彈窗"
L.HELP_STATUS = "  /vqr status - 查看目前狀態"
L.HELP_RESET = "  /vqr reset - 重置當前角色提醒設定"
L.HELP_RESETPOS = "  /vqr resetpos - 重置彈窗位置為預設"

-- 任務/地圖名為繁中化近似，台服正式譯名待核對
L.VQR_QUEST_NAMES = {
    [96400] = "糾纏腐蝕",
    [96548] = "孢分榜首",
}

if GetLocale() == "zhTW" then
    _G["VoidQuestReminder_Locale"] = L
end
