-- Core.lua — 虚空任务提醒：数据库、重置逻辑、事件监听、弹窗UI
local addonName = "VoidQuestReminder"
local L = _G["VoidQuestReminder_Locale"] or {}

-- ===================== 默认模板（AlterEgo 模式）=====================
local DEFAULT_DB = {
    version = 3,
    chars = {},
    config = {
        worldQuestIds = { 96548, 96400 },
        remindEvenIfCompleted = false,
    },
    nextWeekReset = nil,
    framePos = nil,
}

local DEFAULT_CHAR = {
    dontRemindThisWeek = false,
    weekStart = nil,
    loginSuppressed = false,
    remindEvenIfCompleted = false,
}

-- ===================== 角色标识 =====================
local function GetCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

-- ===================== 常量 =====================
local VOID_PARENT_MAP = 2405
local VOID_ZONE_IDS = { [2600] = true, [2599] = true }
local VOID_CONFRONTATION_IDS = { 96717, 96718, 96713, 96714 }

-- ===================== 版本迁移（AlterEgo 递归模式）=====================
local function MigrateDB()
    if type(VoidQuestReminderDB.version) ~= "number" then
        VoidQuestReminderDB.version = 1
    end

    -- v1/v2 → v3：角色级字段迁入 chars
    if VoidQuestReminderDB.version < 3 then
        local oldRem = VoidQuestReminderDB.reminder
        if oldRem then
            local charKey = GetCharKey()
            VoidQuestReminderDB.chars = VoidQuestReminderDB.chars or {}
            VoidQuestReminderDB.chars[charKey] = VoidQuestReminderDB.chars[charKey] or {}
            local ch = VoidQuestReminderDB.chars[charKey]
            if ch.dontRemindThisWeek == nil then
                ch.dontRemindThisWeek = oldRem.dontRemindThisWeek or false
            end
            if ch.weekStart == nil then
                ch.weekStart = oldRem.weekStart
            end
            if ch.loginSuppressed == nil then
                ch.loginSuppressed = oldRem.loginSuppressed or false
            end
            if VoidQuestReminderDB.nextWeekReset == nil then
                VoidQuestReminderDB.nextWeekReset = oldRem.nextWeekReset
            end
            if VoidQuestReminderDB.config.weekDay == nil and oldRem.weekDay then
                VoidQuestReminderDB.config.weekDay = oldRem.weekDay
            end
            VoidQuestReminderDB.reminder = nil
        end
    end

    VoidQuestReminderDB.version = 3
end

-- ===================== 初始化 =====================
local function Initialize()
    VoidQuestReminderDB = VoidQuestReminderDB or {}
    VoidQuestReminderDB.version = VoidQuestReminderDB.version or 1
    VoidQuestReminderDB.chars = VoidQuestReminderDB.chars or {}
    VoidQuestReminderDB.config = VoidQuestReminderDB.config or {}

    for k, v in pairs(DEFAULT_DB.config) do
        if VoidQuestReminderDB.config[k] == nil then
            VoidQuestReminderDB.config[k] = v
        end
    end

    MigrateDB()

    local charKey = GetCharKey()
    VoidQuestReminderDB.chars[charKey] = VoidQuestReminderDB.chars[charKey] or {}
    for k, v in pairs(DEFAULT_CHAR) do
        if VoidQuestReminderDB.chars[charKey][k] == nil then
            VoidQuestReminderDB.chars[charKey][k] = v
        end
    end
end

-- ===================== 每周重置（官方 API 返回的服务器周重置起点）=====================
local function GetCurrentWeekStart()
    return C_DateAndTime.GetWeeklyResetStartTime()
end

-- ===================== 每周重置（AlterEgo 时间戳模式）=====================
local function TaskWeeklyReset()
    local db = VoidQuestReminderDB
    local ch = db.chars[GetCharKey()]
    local weekStart = GetCurrentWeekStart()

    if not db.nextWeekReset or db.nextWeekReset <= time() then
        ch.dontRemindThisWeek = false
        ch.loginSuppressed = false
        ch.weekStart = weekStart
    end

    db.nextWeekReset = weekStart + 7 * 86400
end

-- ===================== 虚空世界检测 =====================
local function ResolveActiveWorld()
    if not C_AreaPoiInfo or not C_AreaPoiInfo.GetAreaPOIForMap then
        return nil
    end

    local pois = C_AreaPoiInfo.GetAreaPOIForMap(VOID_PARENT_MAP) or {}
    for _, poiID in ipairs(pois) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(VOID_PARENT_MAP, poiID)
        if info and info.name then
            for mapID in pairs(VOID_ZONE_IDS) do
                local mapInfo = C_Map.GetMapInfo(mapID)
                local mapName = mapInfo and mapInfo.name or nil
                if mapName and info.name:find(mapName, 1, true) then
                    local secondsLeft = nil
                    if C_AreaPoiInfo.GetAreaPOISecondsLeft then
                        secondsLeft = C_AreaPoiInfo.GetAreaPOISecondsLeft(poiID)
                    end
                    return mapID, mapName, secondsLeft
                end
            end
        end
    end
    return nil
end

local function GetActiveWorldQuestId()
    local mapID = ResolveActiveWorld()
    if not mapID then return nil end
    local questIds = VoidQuestReminderDB.config.worldQuestIds or DEFAULT_DB.config.worldQuestIds
    local index = (mapID == 2600) and 1 or (mapID == 2599) and 2
    return questIds and questIds[index] or nil
end

-- ===================== 虚空决战完成判断 =====================
local function IsVoidConfrontationCompleted()
    if not C_QuestLog then return false end
    for _, qid in ipairs(VOID_CONFRONTATION_IDS) do
        if C_QuestLog.IsQuestFlaggedCompleted(qid) then
            return true
        end
    end
    return false
end

-- ===================== 提醒抑制判断 =====================
local function IsReminderSuppressed()
    local ch = VoidQuestReminderDB.chars[GetCharKey()]
    if ch.loginSuppressed then
        return true
    end
    if ch.dontRemindThisWeek then
        local currentWeekStart = GetCurrentWeekStart()
        if ch.weekStart == currentWeekStart then
            return true
        end
        ch.dontRemindThisWeek = false
    end
    return false
end

-- ===================== 综合条件判断 =====================
local function ShouldRemindEvenIfCompleted()
    return VoidQuestReminderDB.config.remindEvenIfCompleted
        or VoidQuestReminderDB.chars[GetCharKey()].remindEvenIfCompleted
end

local function ShouldShowReminder()
    if IsReminderSuppressed() then return false end

    local qid = GetActiveWorldQuestId()
    if not qid or qid <= 0 then return false end

    if not C_TaskQuest or not C_TaskQuest.IsActive then return false end
    local active = C_TaskQuest.IsActive(qid)
    if not active then return false end

    if not ShouldRemindEvenIfCompleted() then
        if IsVoidConfrontationCompleted() then return false end
    end

    return true
end

-- ===================== 弹窗UI =====================
local popupFrame = nil
local ticker = nil
local forceShow = false
local questLostSince = nil
local popupShowTime = 0
local MIN_DISPLAY_TIME = 5

local function CreateFlatButton(parent, size, text, tooltipText, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(size, size)
    btn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = false,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    btn:SetBackdropColor(0.25, 0.25, 0.25, 0.8)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(0.75, 0.75, 0.75)
    btn:SetFontString(label)

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.4, 0.4, 0.4, 0.9)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tooltipText)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.25, 0.8)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", onClick)
    return btn
end

local function CreatePopupIfNeeded()
    if popupFrame then return end

    popupFrame = CreateFrame("Frame", "VoidQuestReminderPopup", UIParent, "BackdropTemplate")
    popupFrame:SetSize(370, 56)
    popupFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -60)

    popupFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = false,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    popupFrame:SetBackdropColor(0.08, 0.08, 0.12, 0.92)

    popupFrame:SetMovable(true)
    popupFrame:EnableMouse(true)
    popupFrame:RegisterForDrag("LeftButton")
    popupFrame:SetFrameStrata("DIALOG")

    -- 拖拽 + 保存位置
    popupFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    popupFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left = self:GetLeft()
        local top = self:GetTop()
        local parentTop = UIParent:GetTop()
        if left and top and parentTop then
            VoidQuestReminderDB.framePos = { x = left, y = top - parentTop }
        end
    end)

    -- 文本
    local title = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -8)
    title:SetPoint("BOTTOMRIGHT", -12, 8)
    title:SetJustifyH("LEFT")
    title:SetJustifyV("MIDDLE")
    title:SetText(L.REMINDER_TITLE or "虚空任务提醒")
    title:SetTextColor(1, 1, 1)
    popupFrame.text = title

    local debugHint = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    debugHint:SetPoint("BOTTOM", popupFrame, "TOP", 0, 4)
    debugHint:SetText("")
    debugHint:Hide()
    popupFrame.debugHint = debugHint

    -- 按钮1：本周不再提醒（-）
    local weekBtn = CreateFlatButton(popupFrame, 24, "-",
        L.TOOLTIP_DONT_REMIND_WEEK or "本周不再提醒（当前角色）",
        function()
            forceShow = false
            local ch = VoidQuestReminderDB.chars[GetCharKey()]
            ch.dontRemindThisWeek = true
            ch.weekStart = GetCurrentWeekStart()
            popupFrame:Hide()
            print("|cFF00FF00[虚空提醒] 本周不再提醒（当前角色），重新打开弹窗请输入 /vqr show，需重新提醒请输入 /vqr reset|r")
        end)

    -- 按钮2：本次登录不再提醒（×）
    local loginBtn = CreateFlatButton(popupFrame, 24, "×",
        L.TOOLTIP_DONT_REMIND_LOGIN or "本次登录不再提醒",
        function()
            forceShow = false
            VoidQuestReminderDB.chars[GetCharKey()].loginSuppressed = true
            popupFrame:Hide()
            print("|cFF00FF00[虚空提醒] 本次登录不再提醒，重新打开弹窗请输入 /vqr show，需重新提醒请输入 /vqr reset|r")
        end)

    loginBtn:SetPoint("TOPRIGHT", popupFrame, "TOPRIGHT", -6, -4)
    weekBtn:SetPoint("RIGHT", loginBtn, "LEFT", -4, 0)

    -- ===================== 设置下拉框（齿轮按钮）=====================
    local settingsDropdown
    local settingsBlocker
    local settingsOrder = {
        { state = "char", label = L.SETTING_REMIND_EVEN_IF_COMPLETED_CHAR or "任务完成仍提醒（当前角色）" },
        { state = "all", label = L.SETTING_REMIND_EVEN_IF_COMPLETED or "任务完成仍提醒（所有角色）" },
        { state = "none", label = L.SETTING_REMIND_EVEN_IF_COMPLETED_NONE or "不额外提醒" },
    }

    local function GetRemindScope()
        local config = VoidQuestReminderDB.config
        local ch = VoidQuestReminderDB.chars[GetCharKey()]
        if config.remindEvenIfCompleted then
            return "all"
        elseif ch.remindEvenIfCompleted then
            return "char"
        end
        return "none"
    end

    local function RefreshSettingsCheckmarks()
        local active = GetRemindScope()
        for _, item in ipairs(settingsOrder) do
            item.check:SetShown(item.state == active)
        end
    end

    local function HideSettingsDropdown()
        if settingsDropdown then settingsDropdown:Hide() end
        if settingsBlocker then settingsBlocker:Hide() end
    end

    local function ToggleSettingsDropdown()
        if settingsDropdown and settingsDropdown:IsShown() then
            HideSettingsDropdown()
        else
            RefreshSettingsCheckmarks()
            if settingsDropdown then settingsDropdown:Show() end
            if settingsBlocker then settingsBlocker:Show() end
        end
    end

    local gearBtn = CreateFrame("Button", nil, popupFrame, "BackdropTemplate")
    gearBtn:SetSize(24, 24)
    gearBtn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = false,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    gearBtn:SetBackdropColor(0.25, 0.25, 0.25, 0.8)
    local gearTex = gearBtn:CreateTexture(nil, "OVERLAY")
    gearTex:SetSize(16, 16)
    gearTex:SetTexture("Interface\\WorldMap\\GEAR_64GREY")
    gearTex:SetVertexColor(0.75, 0.75, 0.75)
    gearTex:SetPoint("CENTER")
    gearBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.4, 0.4, 0.4, 0.9)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.TOOLTIP_SETTINGS or "设置")
        GameTooltip:Show()
    end)
    gearBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.25, 0.25, 0.25, 0.8)
        GameTooltip:Hide()
    end)
    gearBtn:SetScript("OnClick", ToggleSettingsDropdown)
    gearBtn:SetPoint("RIGHT", weekBtn, "LEFT", -4, 0)

    settingsDropdown = CreateFrame("Frame", "VoidQuestReminderSettingsDropdown", UIParent, "BackdropTemplate")
    settingsDropdown:SetFrameStrata("DIALOG")
    settingsDropdown:SetFrameLevel(10)
    settingsDropdown:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = false,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    settingsDropdown:SetBackdropColor(0.12, 0.12, 0.14, 0.95)
    settingsDropdown:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)

    local rowH = 30
    settingsDropdown:SetSize(250, #settingsOrder * rowH + 8)
    local prevRow
    for i, item in ipairs(settingsOrder) do
        local row = CreateFrame("Button", nil, settingsDropdown, "BackdropTemplate")
        row:SetSize(242, rowH)
        if i == 1 then
            row:SetPoint("TOPLEFT", settingsDropdown, "TOPLEFT", 4, -4)
        else
            row:SetPoint("TOP", prevRow, "BOTTOM", 0, 0)
        end
        row:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            tile = false,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        row:SetBackdropColor(0, 0, 0, 0)
        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.3, 0.3, 0.6)
        end)
        row:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0, 0, 0, 0)
        end)

        local check = row:CreateTexture(nil, "ARTWORK")
        check:SetSize(16, 16)
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        check:SetPoint("LEFT", 12, 0)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", check, "RIGHT", 8, 0)
        label:SetJustifyH("LEFT")
        label:SetText(item.label)
        label:SetTextColor(0.9, 0.9, 0.9)

        item.check = check
        row:SetScript("OnClick", function()
            local config = VoidQuestReminderDB.config
            local ch = VoidQuestReminderDB.chars[GetCharKey()]
            if item.state == "all" then
                config.remindEvenIfCompleted = true
                ch.remindEvenIfCompleted = false
            elseif item.state == "char" then
                config.remindEvenIfCompleted = false
                ch.remindEvenIfCompleted = true
            else
                config.remindEvenIfCompleted = false
                ch.remindEvenIfCompleted = false
            end
            RefreshSettingsCheckmarks()
        end)
        prevRow = row
    end
    settingsDropdown:SetPoint("TOPLEFT", gearBtn, "BOTTOMRIGHT", -24, 0)
    settingsDropdown:Hide()

    settingsBlocker = CreateFrame("Frame", nil, UIParent)
    settingsBlocker:SetFrameStrata("DIALOG")
    settingsBlocker:SetFrameLevel(5)
    settingsBlocker:EnableMouse(true)
    settingsBlocker:SetAllPoints(UIParent)
    settingsBlocker:SetScript("OnMouseDown", HideSettingsDropdown)
    settingsBlocker:Hide()

    popupFrame:SetScript("OnHide", HideSettingsDropdown)

    -- 恢复保存的位置
    if VoidQuestReminderDB.framePos then
        local savedX = VoidQuestReminderDB.framePos.x or 60
        local savedY = VoidQuestReminderDB.framePos.y or -60
        if savedY > 0 then
            savedY = -60
        end
        popupFrame:ClearAllPoints()
        popupFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", savedX, savedY)
    end
end

local function FormatTimeLeft(totalSeconds)
    if not totalSeconds or totalSeconds <= 0 then return nil end
    local m = math.floor(totalSeconds / 60)
    local s = totalSeconds % 60
    return string.format(L.VQR_TIME_LEFT or "%d分%d秒", m, s)
end

local function UpdatePopupText(extraText)
    if not popupFrame then return end

    local popupWidth = IsVoidConfrontationCompleted() and 400 or 370
    popupFrame:SetSize(popupWidth, 56)

    local mapID, zoneName, secondsLeft = ResolveActiveWorld()
    local zonePrefix = zoneName and ("【" .. zoneName .. "】") or ""
    local questIds = VoidQuestReminderDB.config.worldQuestIds
    local index = (mapID == 2600) and 1 or (mapID == 2599) and 2
    local qid = questIds and questIds[index]
    local nameMap = L.VQR_QUEST_NAMES or {}

    local questName = (qid and nameMap[qid]) or (qid and tostring(qid)) or "?"
    local statusText = extraText or ""

    if not extraText then
        if qid and C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(qid) then
            local activePrefix = (L.VQR_QUEST_ACTIVE or "已激活") .. " · "
            if C_TaskQuest.GetQuestTimeLeftSeconds then
                local remainder = C_TaskQuest.GetQuestTimeLeftSeconds(qid)
                local remaining = FormatTimeLeft(remainder)
                if remaining then
                    statusText = activePrefix .. remaining
                elseif remainder then
                    statusText = activePrefix .. (L.VQR_EXPIRING_SOON or "即将过期")
                else
                    statusText = activePrefix .. (L.VQR_TIME_UNAVAILABLE or "剩余时间获取中…")
                end
            else
                statusText = activePrefix .. (L.VQR_TIME_UNAVAILABLE or "剩余时间获取中…")
            end
        elseif qid then
            statusText = L.VQR_NOT_ACTIVE or "暂未激活"
        end
    end

    if IsVoidConfrontationCompleted() then
        statusText = statusText .. " （已完成）"
    end

    local displayText = string.format(
        "%s %s: %s",
        zonePrefix,
        questName,
        statusText
    )
    popupFrame.text:SetText(displayText)
end

function ShowReminder()
    if ticker then ticker:Cancel(); ticker = nil end
    CreatePopupIfNeeded()
    questLostSince = nil
    popupShowTime = time()

    UpdatePopupText()
    popupFrame:Show()

    ticker = C_Timer.NewTicker(1, function()
        if not popupFrame or not popupFrame:IsShown() then
            if ticker then ticker:Cancel(); ticker = nil end
            return
        end
        local qid = GetActiveWorldQuestId()
        if qid and C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(qid) then
            if not ShouldRemindEvenIfCompleted()
                and not forceShow
                and IsVoidConfrontationCompleted() then
                popupFrame:Hide()
                return
            end
            questLostSince = nil
            UpdatePopupText()
        else
            local now = time()
            if not questLostSince then
                questLostSince = now
            end
            if (now - questLostSince) >= 10 and not forceShow then
                popupFrame:Hide()
            else
                popupFrame.text:SetText(L.VQR_REACQUIRING or "正在重新获取任务状态…")
            end
        end
    end)
end

function HideReminder()
    if ticker then ticker:Cancel(); ticker = nil end
    if popupFrame then
        if popupFrame.debugHint then popupFrame.debugHint:Hide() end
        popupFrame:Hide()
    end
end

function ShowReminderForce()
    if ticker then ticker:Cancel(); ticker = nil end
    CreatePopupIfNeeded()

    forceShow = true
    questLostSince = nil
    popupShowTime = time()
    popupFrame.debugHint:SetText("【手动显示】拖拽调整位置")
    popupFrame.debugHint:Show()

    UpdatePopupText()
    popupFrame:Show()

    ticker = C_Timer.NewTicker(1, function()
        if not popupFrame or not popupFrame:IsShown() then
            if ticker then ticker:Cancel(); ticker = nil end
            return
        end
        UpdatePopupText()
    end)
end

-- ===================== 检查并提醒 =====================
local lastCheck = 0
local CHECK_COOLDOWN = 2
local POLL_INTERVAL = 10

local function CheckAndNotify()
    local now = time()
    if now - lastCheck < CHECK_COOLDOWN then
        return
    end
    lastCheck = now

    if ShouldShowReminder() then
        ShowReminder()
    elseif not forceShow then
        if popupFrame and popupFrame:IsShown() and (now - popupShowTime) < MIN_DISPLAY_TIME then
            return
        end
        HideReminder()
    end
end

local function PollCheck()
    if popupFrame and popupFrame:IsShown() then return end
    CheckAndNotify()
end

-- ===================== 事件监听 =====================
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("QUEST_POI_UPDATE")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            Initialize()
        end

    elseif event == "PLAYER_LOGIN" then
        VoidQuestReminderDB.chars[GetCharKey()].loginSuppressed = false
        TaskWeeklyReset()
        lastCheck = 0
        CheckAndNotify()
        C_Timer.NewTicker(POLL_INTERVAL, PollCheck)

    elseif event == "PLAYER_ENTERING_WORLD" then
        lastCheck = 0
        CheckAndNotify()

    elseif event == "QUEST_TURNED_IN" then
        lastCheck = 0
        CheckAndNotify()

    elseif event == "QUEST_POI_UPDATE"
        or event == "QUEST_LOG_UPDATE"
        or event == "ZONE_CHANGED_NEW_AREA"
    then
        CheckAndNotify()
    end
end)

-- ===================== 斜杠命令 =====================
SLASH_VOIDQUESTREMINDER1 = "/vqr"
SLASH_VOIDQUESTREMINDER2 = "/voidquest"
SlashCmdList["VOIDQUESTREMINDER"] = function(msg)
    if msg == "show" then
        lastCheck = 0
        ShowReminderForce()
        print("|cFF00FF00[虚空提醒] 已强制显示弹窗（无视条件）|r")
    elseif msg == "hide" then
        forceShow = false
        HideReminder()
        print("|cFF00FF00[虚空提醒] 已隐藏弹窗|r")
    elseif msg == "status" then
        local ch = VoidQuestReminderDB.chars[GetCharKey()]
        local mapID, zoneName = ResolveActiveWorld()
        local completed = IsVoidConfrontationCompleted()
        local qid = GetActiveWorldQuestId()
        local questActive = false
        if qid and C_TaskQuest and C_TaskQuest.IsActive then
            questActive = C_TaskQuest.IsActive(qid) or false
        end
        print("|cFF00FF00[虚空提醒] 状态:|r")
        print("  虚空世界: " .. (zoneName or "无"))
        print("  逃课任务ID: " .. (qid and tostring(qid) or "无"))
        print("  逃课任务激活: " .. (questActive and "是" or "否"))
        print("  虚空决战: " .. (completed and "已完成" or "未完成"))
        print("  本周不再提醒: " .. tostring(ch.dontRemindThisWeek))
        print("  本次登录不再提醒: " .. tostring(ch.loginSuppressed))
        print("  已完成仍提醒(所有角色): " .. tostring(VoidQuestReminderDB.config.remindEvenIfCompleted))
        print("  已完成仍提醒(当前角色): " .. tostring(VoidQuestReminderDB.chars[GetCharKey()].remindEvenIfCompleted))
    elseif msg == "reset" then
        local ch = VoidQuestReminderDB.chars[GetCharKey()]
        ch.dontRemindThisWeek = false
        ch.weekStart = nil
        ch.loginSuppressed = false
        lastCheck = 0
        print("|cFF00FF00[虚空提醒] 当前角色提醒设置已重置|r")
    else
        print("|cFF00FF00[虚空提醒] 命令:|r")
        print("  /vqr show - 强制显示弹窗（无视条件）")
        print("  /vqr hide - 隐藏弹窗")
        print("  /vqr status - 查看当前状态")
        print("  /vqr reset - 重置当前角色提醒设置")
    end
end
