local L = {}

L.VQR_QUEST_ACTIVE = "Active"
L.VQR_TIME_LEFT = "%d min %d sec left"
L.VQR_EXPIRING_SOON = "expires soon"
L.VQR_TIME_UNAVAILABLE = "Fetching time remaining…"
L.VQR_NOT_ACTIVE = "Not active"
L.VQR_REACQUIRING = "Re-acquiring quest status…"

L.REMINDER_TITLE = "Void Quest Reminder"
L.REMINDER_TEXT = "%s: %s: %s"
L.TOOLTIP_DONT_REMIND_WEEK = "Don't remind this week"
L.TOOLTIP_DONT_REMIND_LOGIN = "Don't remind this login"
L.TOOLTIP_SETTINGS = "Settings"
L.SETTING_REMIND_EVEN_IF_COMPLETED = "Remind even if completed (all characters)"
L.SETTING_REMIND_EVEN_IF_COMPLETED_CHAR = "Remind even if completed (this character)"
L.SETTING_REMIND_EVEN_IF_COMPLETED_NONE = "No extra reminder"
L.MSG_NO_WORLD_QUEST = "No world quest IDs configured"
L.MSG_WORLD_QUEST_COMPLETED = "Void Confrontation already completed"
L.MSG_ADDON_LOADED = "|cFF00FF00[VoidQuestReminder] Loaded|r"

L.VQR_QUEST_NAMES = {
    [96400] = "Entangling Corruption",
    [96548] = "Spore",
}

if GetLocale() == "enUS" or GetLocale() == "enGB" then
    _G["VoidQuestReminder_Locale"] = L
end