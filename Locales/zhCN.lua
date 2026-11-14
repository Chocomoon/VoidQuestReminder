local L = {}

L.VQR_QUEST_ACTIVE = "已激活"
L.VQR_TIME_LEFT = "%d分%d秒"
L.VQR_EXPIRING_SOON = "即将过期"
L.VQR_TIME_UNAVAILABLE = "剩余时间获取中…"
L.VQR_NOT_ACTIVE = "暂未激活"
L.VQR_REACQUIRING = "正在重新获取任务状态…"
L.VQR_COMPLETED_SUFFIX = "（已完成）"

L.REMINDER_TITLE = "虚空任务提醒"
L.TOOLTIP_DONT_REMIND_WEEK = "本周不再提醒（当前角色）"
L.TOOLTIP_DONT_REMIND_LOGIN = "本次登录不再提醒"
L.TOOLTIP_SETTINGS = "设置"
L.SETTING_REMIND_EVEN_IF_COMPLETED = "任务完成仍提醒（所有角色）"
L.SETTING_REMIND_EVEN_IF_COMPLETED_CHAR = "任务完成仍提醒（当前角色）"
L.SETTING_REMIND_EVEN_IF_COMPLETED_NONE = "不额外提醒"
L.HINT_MANUAL_SHOW = "【手动显示】拖拽调整位置"

-- 弹窗按钮反馈
L.MSG_SUPPRESS_WEEK = "|cFF00FF00[虚空提醒] 本周不再提醒（当前角色），重新打开弹窗请输入 /vqr show，需重新提醒请输入 /vqr reset|r"
L.MSG_SUPPRESS_LOGIN = "|cFF00FF00[虚空提醒] 本次登录不再提醒，重新打开弹窗请输入 /vqr show，需重新提醒请输入 /vqr reset|r"

-- 斜杠命令反馈
L.MSG_SHOW_FORCED = "|cFF00FF00[虚空提醒] 已强制显示弹窗（无视条件）|r"
L.MSG_HIDDEN = "|cFF00FF00[虚空提醒] 已隐藏弹窗|r"
L.MSG_RESET_DONE = "|cFF00FF00[虚空提醒] 当前角色提醒设置已重置|r"
L.MSG_RESETPOS_DONE = "|cFF00FF00[虚空提醒] 弹窗位置已重置到默认|r"

-- /vqr status
L.STATUS_HEADER = "|cFF00FF00[虚空提醒] 状态:|r"
L.STATUS_WORLD = "  虚空世界: %s"
L.STATUS_QUEST_ID = "  逃课任务ID: %s"
L.STATUS_QUEST_ACTIVE = "  逃课任务激活: %s"
L.STATUS_CONFRONTATION = "  虚空决战: %s"
L.STATUS_SUPPRESS_WEEK = "  本周不再提醒: %s"
L.STATUS_SUPPRESS_LOGIN = "  本次登录不再提醒: %s"
L.STATUS_FORCE_SHOW = "  强制显示中: %s"
L.STATUS_REMIND_ALL = "  已完成仍提醒（所有角色）: %s"
L.STATUS_REMIND_CHAR = "  已完成仍提醒（当前角色）: %s"

L.VAL_NONE = "无"
L.VAL_YES = "是"
L.VAL_NO = "否"
L.VAL_DONE = "已完成"
L.VAL_UNDONE = "未完成"

-- 帮助
L.HELP_HEADER = "|cFF00FF00[虚空提醒] 命令:|r"
L.HELP_SHOW = "  /vqr show - 强制显示弹窗（无视条件）"
L.HELP_HIDE = "  /vqr hide - 隐藏弹窗"
L.HELP_STATUS = "  /vqr status - 查看当前状态"
L.HELP_RESET = "  /vqr reset - 重置当前角色提醒设置"
L.HELP_RESETPOS = "  /vqr resetpos - 重置弹窗位置到默认"

L.VQR_QUEST_NAMES = {
    [96400] = "纠缠腐蚀",
    [96548] = "孢分榜首",
}

-- 简体中文作为默认兜底：无条件注册，供其它无本地化的语言客户端使用
_G["VoidQuestReminder_Locale"] = L
