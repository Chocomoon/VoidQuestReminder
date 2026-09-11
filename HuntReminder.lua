-- HuntReminder.lua — 方唐镜刷新提醒（独立模块，不依赖核心逻辑）
local addonName = "VoidQuestReminder"
local L = _G["VoidQuestReminder_Locale"] or {}

-- ===================== 常量 =====================
-- 被遗弃的营地（狩猎世界任务）沿永歌森林/祖阿曼/盘卷蛇岛/哈籁恩达尔/虚影风暴 5图轮换
local HUNT_WQ_IDS = { 95974, 96596, 96597, 96598, 96599 }

-- 5图轮换地图（Midnight mapID 已核实）；顺序与 HUNT_TEST_MAP_NAMES 一致，坐标为百分比（/way 风格）
local HUNT_MAPS = {
    { uiMapID = 2395, zh = "永歌森林",   en = "Eversong Woods", x = 45.7, y = 55.1 },
    { uiMapID = 2437, zh = "祖阿曼",     en = "Zul'Aman",       x = 43.0, y = 30.0 },
    { uiMapID = 2405, zh = "虚影风暴",   en = "Voidstorm",      x = 43.3, y = 69.0 },
    { uiMapID = 2413, zh = "哈籁恩达尔", en = "Harandar",       x = 53.0, y = 34.0 },
    { uiMapID = 2512, zh = "盘卷蛇岛",   en = "Coiled Isle",    x = 52.0, y = 43.0 },
}

local ROW_PITCH = 26
local POPUP_WIDTH = 370
local POPUP_HEIGHT = 56
local POPUP_TEST_HEIGHT = 8 + (#HUNT_MAPS - 1) * ROW_PITCH + ROW_PITCH + 8

-- ===================== 状态 =====================
local popupFrame = nil
local pollTicker = nil
local forceShow = false
local testMode = false
local episodeShown = false
local lastPreyQuest = nil
local lastDayStr = nil

local DEFAULT_X = 60
local DEFAULT_Y = -140

-- ===================== 角色状态 =====================
local function GetCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

local function GetCharState()
    local chars = VoidQuestReminderDB.huntReminder.chars
    local key = GetCharKey()
    chars[key] = chars[key] or {}
    local st = chars[key]
    if st.loginSuppressed == nil then
        st.loginSuppressed = false
    end
    return st
end

local function GetTodayStr()
    local t = date("*t")
    return string.format("%d-%02d-%02d", t.year, t.month, t.day)
end

local function IsDontRemindToday()
    return GetCharState().dontRemindDate == GetTodayStr()
end

-- ===================== 数据库初始化 =====================
local function InitDB()
    VoidQuestReminderDB = VoidQuestReminderDB or {}
    VoidQuestReminderDB.huntReminder = VoidQuestReminderDB.huntReminder or {}
    VoidQuestReminderDB.huntReminder.chars = VoidQuestReminderDB.huntReminder.chars or {}

    -- 清理旧版字段（本次刷新不再提醒）
    local s = VoidQuestReminderDB.huntReminder
    s.suppressRefresh = nil
    s.suppressWqId = nil
    s.suppressDownSince = nil
end

-- ===================== 条件判断 =====================
local function GetActivePreyQuest()
    if C_QuestLog and C_QuestLog.GetActivePreyQuest then
        return C_QuestLog.GetActivePreyQuest()
    end
    return nil
end

local function GetActiveAbandonedCampWqId()
    if not C_TaskQuest or not C_TaskQuest.IsActive then
        return nil
    end
    for _, qid in ipairs(HUNT_WQ_IDS) do
        if C_TaskQuest.IsActive(qid) then
            return qid
        end
    end
    return nil
end

local function IsAbandonedCampUp()
    return GetActiveAbandonedCampWqId() ~= nil
end

local function IsHuntOpportunity()
    return GetActivePreyQuest() ~= nil and IsAbandonedCampUp()
end

local function IsSuppressed()
    local st = GetCharState()
    return st.loginSuppressed or IsDontRemindToday()
end

-- 当前激活的被遗弃的营地所在地图
local function GetActiveCampMapId()
    local wqID = GetActiveAbandonedCampWqId()
    if not wqID or not GetQuestUiMapID then
        return nil
    end
    return GetQuestUiMapID(wqID)
end

local function GetActiveCampMapName()
    local mapID = GetActiveCampMapId()
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name or nil
end

-- 按客户端本地化地图名查找 HUNT_MAPS 条目（zh/en 均可）
local function FindMapEntryByLocalizedName(name)
    for _, entry in ipairs(HUNT_MAPS) do
        if entry.zh == name or entry.en == name then
            return entry
        end
    end
    return nil
end

-- 给定条目在对应地图上设置用户标记点（坐标百分比 /100 → 归一化）
local function SetWaypointByMapID(entry, displayName)
    local info = C_Map.GetMapInfo(entry.uiMapID)
    if info and info.name ~= entry.zh and info.name ~= entry.en then
        print("|cFF00FF00[狩猎提醒] mapID " .. entry.uiMapID .. " 名称不符（" .. tostring(info.name) .. "），跳过|r")
        return
    end
    if C_Map.CanSetUserWaypointOnMap(entry.uiMapID) then
        C_Map.SetUserWaypoint({ uiMapID = entry.uiMapID, position = { x = entry.x / 100, y = entry.y / 100 } })
        print("|cFF00FF00[狩猎提醒] 已在 " .. displayName .. " 设置方唐镜标记点|r")
    else
        print("|cFF00FF00[狩猎提醒] 该地图不支持用户标记点: " .. displayName .. "|r")
    end
end

-- 正常模式按钮：根据当前激活的被遗弃的营地所在地图设置标记点
local function SetWaypoint()
    local mapID = GetActiveCampMapId()
    if not mapID then
        print("|cFF00FF00[狩猎提醒] 无法确定被遗弃的营地的地图|r")
        return
    end
    local info = C_Map.GetMapInfo(mapID)
    local entry = info and FindMapEntryByLocalizedName(info.name)
    if not entry then
        print("|cFF00FF00[狩猎提醒] 该地图无标记点坐标: " .. tostring(info and info.name) .. "|r")
        return
    end
    SetWaypointByMapID(entry, info.name)
end

-- 刷新弹窗内容：正常单行（当前激活图）/ 测试5行预览，每行各带一个标记点按钮
local function UpdatePopupContent()
    if not popupFrame then
        return
    end
    local baseText = L.HUNT_REMINDER_TEXT or "方唐镜已激活"
    local rows = popupFrame.rows
    if testMode then
        local names = L.HUNT_TEST_MAP_NAMES or { "永歌森林", "祖阿曼", "虚影风暴", "哈籁恩达尔", "盘卷蛇岛" }
        for i, row in ipairs(rows) do
            row.text:SetText("【" .. (names[i] or HUNT_MAPS[i].zh) .. "】 " .. baseText)
            row.text:Show()
            row.btn:Show()
        end
        popupFrame:SetHeight(POPUP_TEST_HEIGHT)
    else
        local mapName = GetActiveCampMapName()
        rows[1].text:SetText(mapName and ("【" .. mapName .. "】 " .. baseText) or baseText)
        rows[1].text:Show()
        rows[1].btn:Show()
        for i = 2, #rows do
            rows[i].text:Hide()
            rows[i].btn:Hide()
        end
        popupFrame:SetHeight(POPUP_HEIGHT)
    end
end

-- ===================== 弹窗UI =====================
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

local function CreateFlatTextButton(parent, width, height, text, tooltipText, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        tile = false,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    btn:SetBackdropColor(0.25, 0.25, 0.25, 0.8)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(1, 1, 1)
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

    popupFrame = CreateFrame("Frame", "VoidQuestHuntReminderPopup", UIParent, "BackdropTemplate")
    popupFrame:SetSize(POPUP_WIDTH, POPUP_HEIGHT)
    popupFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", DEFAULT_X, DEFAULT_Y)

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

    -- 拖拽 + 保存位置（相对父框架顶部，与核心弹窗同一套坐标换算）
    popupFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    popupFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left = self:GetLeft()
        local top = self:GetTop()
        local parentTop = UIParent:GetTop()
        if left and top and parentTop then
            VoidQuestReminderDB.huntReminder.framePos = { x = left, y = top - parentTop }
        end
    end)

    -- 5行：每行 = 文案 + 一个标记点按钮；普通模式只用第1行（当前激活图），test 模式5行全显
    popupFrame.rows = {}
    for i = 1, #HUNT_MAPS do
        local entry = HUNT_MAPS[i]
        local rowTop = -8 - (i - 1) * ROW_PITCH
        local rowText = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        rowText:SetPoint("TOPLEFT", popupFrame, "TOPLEFT", 12, rowTop)
        rowText:SetPoint("BOTTOMLEFT", popupFrame, "TOPLEFT", 12, rowTop - 24)
        rowText:SetJustifyH("LEFT")
        rowText:SetJustifyV("MIDDLE")
        rowText:SetTextColor(1, 1, 1)

        local function OnRowClick()
            if i == 1 and not testMode then
                SetWaypoint()
            else
                local names = L.HUNT_TEST_MAP_NAMES
                local display = (names and names[i]) or entry.zh
                SetWaypointByMapID(entry, display)
            end
        end
        local rowBtn = CreateFlatTextButton(popupFrame, 96, 24,
            L.HUNT_BTN_SET_MARKER or "设置标记点",
            L.HUNT_TOOLTIP_SET_MARKER or "在地图上设置方唐镜标记点（感谢阿落分享）",
            OnRowClick)
        rowBtn:SetPoint("TOP", rowText, "TOP", 0, 0)
        rowBtn:SetPoint("LEFT", rowText, "RIGHT", 6, 0)

        popupFrame.rows[i] = { text = rowText, btn = rowBtn }
        if i > 1 then
            rowText:Hide()
            rowBtn:Hide()
        end
    end

    local debugHint = popupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    debugHint:SetPoint("BOTTOM", popupFrame, "TOP", 0, 4)
    debugHint:SetText("")
    debugHint:Hide()
    popupFrame.debugHint = debugHint

    -- 按钮1：今日不再提醒（当前角色）
local todayBtn = CreateFlatButton(popupFrame, 24, "-",
        L.HUNT_TOOLTIP_DONT_REMIND_TODAY or "今日不再提醒（当前角色）",
        function()
            forceShow = false
            testMode = false
            GetCharState().dontRemindDate = GetTodayStr()
            UpdatePopupContent()
            popupFrame:Hide()
            print("|cFF00FF00[狩猎方唐镜提醒] 今日不再提醒（当前角色），需重新提醒请输入 /ftj reset|r")
        end)

    -- 按钮2：本次登录不再提醒
local loginBtn = CreateFlatButton(popupFrame, 24, "×",
        L.HUNT_TOOLTIP_DONT_REMIND_LOGIN or "本次登录不再提醒",
        function()
            forceShow = false
            testMode = false
            GetCharState().loginSuppressed = true
            UpdatePopupContent()
            popupFrame:Hide()
            print("|cFF00FF00[狩猎方唐镜提醒] 本次登录不再提醒，需重新提醒请输入 /ftj reset|r")
        end)

    loginBtn:SetPoint("TOPRIGHT", popupFrame, "TOPRIGHT", -6, -4)
    todayBtn:SetPoint("RIGHT", loginBtn, "LEFT", -4, 0)

    -- 恢复保存的位置（旧脏数据 y>0 视为无效）
    if VoidQuestReminderDB.huntReminder.framePos then
        local savedX = VoidQuestReminderDB.huntReminder.framePos.x or DEFAULT_X
        local savedY = VoidQuestReminderDB.huntReminder.framePos.y or DEFAULT_Y
        if savedY > 0 then
            savedY = DEFAULT_Y
        end
        popupFrame:ClearAllPoints()
        popupFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", savedX, savedY)
    end
end

-- ===================== 刷新/触发 =====================
local function RefreshReminder()
    local today = GetTodayStr()
    local currentQuestID = GetActivePreyQuest()

    if today ~= lastDayStr then
        lastDayStr = today
        episodeShown = false
    end
    if currentQuestID and currentQuestID ~= lastPreyQuest then
        lastPreyQuest = currentQuestID
        episodeShown = false
    elseif not currentQuestID and lastPreyQuest then
        lastPreyQuest = nil
        episodeShown = false
    end

    if IsHuntOpportunity() then
        if forceShow or (not IsSuppressed() and not episodeShown) then
            CreatePopupIfNeeded()
            UpdatePopupContent()
            popupFrame:Show()
            episodeShown = true
        end
    else
        episodeShown = false
        if not forceShow and popupFrame and popupFrame:IsShown() then
            popupFrame:Hide()
        end
    end
end

-- ===================== 事件监听 =====================
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("QUEST_ACCEPTED")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("QUEST_TURNED_IN")
f:RegisterEvent("QUEST_POI_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
            InitDB()
        end

    elseif event == "PLAYER_LOGIN" then
        GetCharState().loginSuppressed = false
        if pollTicker then pollTicker:Cancel() end
        pollTicker = C_Timer.NewTicker(10, RefreshReminder)
        lastDayStr = GetTodayStr()
        RefreshReminder()

    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "QUEST_ACCEPTED"
        or event == "QUEST_LOG_UPDATE"
        or event == "QUEST_TURNED_IN"
        or event == "QUEST_POI_UPDATE"
        or event == "ZONE_CHANGED_NEW_AREA"
    then
        RefreshReminder()
    end
end)

-- ===================== 斜杠命令 =====================
SLASH_FTJ1 = "/ftj"
SlashCmdList["FTJ"] = function(msg)
    if msg == "test" then
        forceShow = true
        testMode = true
        CreatePopupIfNeeded()
        UpdatePopupContent()
        popupFrame.debugHint:SetText("【测试模式】拖拽调整位置")
        popupFrame.debugHint:Show()
        popupFrame:Show()
        print("|cFF00FF00[狩猎提醒] 已强制弹出方唐镜预览弹窗（/ftj hide 关闭）|r")
    elseif msg == "hide" then
        forceShow = false
        testMode = false
        if popupFrame then
            if popupFrame.debugHint then popupFrame.debugHint:Hide() end
            UpdatePopupContent()
            popupFrame:Hide()
        end
        print("|cFF00FF00[狩猎提醒] 已隐藏方唐镜刷新弹窗|r")
    elseif msg == "status" then
        local st = GetCharState()
        print("|cFF00FF00[狩猎提醒] 方唐镜提醒状态:|r")
        print("  狩猎契约: " .. (GetActivePreyQuest() and tostring(GetActivePreyQuest()) or "无"))
        print("  被遗弃的营地WQ: " .. (IsAbandonedCampUp() and "已刷新" or "未刷新"))
        print("  今日不再提醒(当前角色): " .. tostring(IsDontRemindToday()))
        print("  本次登录不再提醒: " .. tostring(st.loginSuppressed))
    elseif msg == "reset" then
        testMode = false
        local st = GetCharState()
        st.dontRemindDate = nil
        st.loginSuppressed = false
        episodeShown = false
        forceShow = false
        if popupFrame then UpdatePopupContent() end
        print("|cFF00FF00[狩猎提醒] 当前角色方唐镜提醒状态已重置|r")
        RefreshReminder()
    else
        print("|cFF00FF00[狩猎提醒] 方唐镜提醒命令:|r")
        print("  /ftj test - 强制显示弹窗（5图预览）")
        print("  /ftj hide - 隐藏弹窗")
        print("  /ftj status - 查看当前状态")
        print("  /ftj reset - 重置当前角色提醒状态")
    end
end