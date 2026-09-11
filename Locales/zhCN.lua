local L = {}

L.VQR_QUEST_ACTIVE = "已激活"
L.VQR_TIME_LEFT = "%d分%d秒"
L.VQR_EXPIRING_SOON = "即将过期"
L.VQR_TIME_UNAVAILABLE = "剩余时间获取中…"
L.VQR_NOT_ACTIVE = "暂未激活"
L.VQR_REACQUIRING = "正在重新获取任务状态…"

L.REMINDER_TITLE = "虚空任务提醒"
L.REMINDER_TEXT = "%s: %s: %s"
L.TOOLTIP_DONT_REMIND_WEEK = "本周不再提醒（当前角色）"
L.TOOLTIP_DONT_REMIND_LOGIN = "本次登录不再提醒"
L.TOOLTIP_SETTINGS = "设置"
L.SETTING_REMIND_EVEN_IF_COMPLETED = "任务完成仍提醒（所有角色）"
L.SETTING_REMIND_EVEN_IF_COMPLETED_CHAR = "任务完成仍提醒（当前角色）"
L.SETTING_REMIND_EVEN_IF_COMPLETED_NONE = "不额外提醒"
L.MSG_NO_WORLD_QUEST = "未配置世界任务ID"
L.MSG_WORLD_QUEST_COMPLETED = "虚空决战已完成，无需提醒"
L.MSG_ADDON_LOADED = "|cFF00FF00[虚空提醒] 插件已加载|r"

L.HUNT_REMINDER_TEXT = "方唐镜已激活"
L.HUNT_TEST_MAP_NAMES = { "永歌森林", "祖阿曼", "虚影风暴", "哈籁恩达尔", "盘卷蛇岛" }
L.HUNT_BTN_SET_MARKER = "设置标记点"
L.HUNT_TOOLTIP_SET_MARKER = "在地图上设置方唐镜标记点（感谢阿落分享）"
L.HUNT_TOOLTIP_DONT_REMIND_TODAY = "今日不再提醒（当前角色）"
L.HUNT_TOOLTIP_DONT_REMIND_LOGIN = "本次登录不再提醒"

L.VQR_QUEST_NAMES = {
    [96400] = "纠缠腐蚀",
    [96548] = "孢分榜首",
}

if GetLocale() == "zhCN" then
    _G["VoidQuestReminder_Locale"] = L
end