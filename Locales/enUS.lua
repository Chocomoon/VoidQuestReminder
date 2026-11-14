local L = {}

L.VQR_QUEST_ACTIVE = "Active"
L.VQR_TIME_LEFT = "%d min %d sec left"
L.VQR_EXPIRING_SOON = "expires soon"
L.VQR_TIME_UNAVAILABLE = "Fetching time remaining…"
L.VQR_NOT_ACTIVE = "Not active"
L.VQR_REACQUIRING = "Re-acquiring quest status…"
L.VQR_COMPLETED_SUFFIX = " (completed)"

L.REMINDER_TITLE = "Void Quest Reminder"
L.TOOLTIP_DONT_REMIND_WEEK = "Don't remind this week"
L.TOOLTIP_DONT_REMIND_LOGIN = "Don't remind this login"
L.TOOLTIP_SETTINGS = "Settings"
L.SETTING_REMIND_EVEN_IF_COMPLETED = "Remind even if completed (all characters)"
L.SETTING_REMIND_EVEN_IF_COMPLETED_CHAR = "Remind even if completed (this character)"
L.SETTING_REMIND_EVEN_IF_COMPLETED_NONE = "No extra reminder"
L.HINT_MANUAL_SHOW = "Manually shown - drag to reposition"

-- Popup button feedback
L.MSG_SUPPRESS_WEEK = "|cFF00FF00[VoidQuestReminder] Won't remind this week (this character). /vqr show reopens the popup, /vqr reset re-enables it.|r"
L.MSG_SUPPRESS_LOGIN = "|cFF00FF00[VoidQuestReminder] Won't remind this login. /vqr show reopens the popup, /vqr reset re-enables it.|r"

-- Slash command feedback
L.MSG_SHOW_FORCED = "|cFF00FF00[VoidQuestReminder] Popup force-shown (conditions ignored)|r"
L.MSG_HIDDEN = "|cFF00FF00[VoidQuestReminder] Popup hidden|r"
L.MSG_RESET_DONE = "|cFF00FF00[VoidQuestReminder] Reminder settings reset for this character|r"
L.MSG_RESETPOS_DONE = "|cFF00FF00[VoidQuestReminder] Popup position reset to default|r"

-- /vqr status
L.STATUS_HEADER = "|cFF00FF00[VoidQuestReminder] Status:|r"
L.STATUS_WORLD = "  Void world: %s"
L.STATUS_QUEST_ID = "  Void WQ ID: %s"
L.STATUS_QUEST_ACTIVE = "  Void WQ active: %s"
L.STATUS_CONFRONTATION = "  Void Confrontation: %s"
L.STATUS_SUPPRESS_WEEK = "  Suppressed this week: %s"
L.STATUS_SUPPRESS_LOGIN = "  Suppressed this login: %s"
L.STATUS_FORCE_SHOW = "  Forced display: %s"
L.STATUS_REMIND_ALL = "  Remind when completed (all characters): %s"
L.STATUS_REMIND_CHAR = "  Remind when completed (this character): %s"

L.VAL_NONE = "none"
L.VAL_YES = "yes"
L.VAL_NO = "no"
L.VAL_DONE = "completed"
L.VAL_UNDONE = "not completed"

-- Help
L.HELP_HEADER = "|cFF00FF00[VoidQuestReminder] Commands:|r"
L.HELP_SHOW = "  /vqr show - force-show the popup (conditions ignored)"
L.HELP_HIDE = "  /vqr hide - hide the popup"
L.HELP_STATUS = "  /vqr status - show current status"
L.HELP_RESET = "  /vqr reset - reset this character's reminder settings"
L.HELP_RESETPOS = "  /vqr resetpos - reset popup position to default"

L.VQR_QUEST_NAMES = {
    [96400] = "Entangling Corruption",
    [96548] = "Spore",
}

if GetLocale() == "enUS" or GetLocale() == "enGB" then
    _G["VoidQuestReminder_Locale"] = L
end
