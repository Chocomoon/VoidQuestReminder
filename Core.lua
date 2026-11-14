-- Core.lua — 虚空任务提醒：数据库、重置逻辑、事件监听、弹窗UI
local addonName = "VoidQuestReminder"
local L = _G["VoidQuestReminder_Locale"] or {}

-- 命令输出统一走语言文件（三语文件必须齐备）。缺键/格式坏都在聊天框里点名，
-- 而不是让 /vqr 整个命令抛 bad argument 中断
local function Say(key, ...)
    local tmpl = L[key]
    if type(tmpl) ~= "string" then
        print("|cFF00FF00[VoidQuestReminder] missing locale key: " .. key .. "|r")
        return
    end
    if select("#", ...) == 0 then
        print(tmpl)
        return
    end
    -- 直接透传可变参数，不走 unpack（5.2+ 已移除该全局，测试用的 fengari 就跑不起来）
    local ok, text = pcall(string.format, tmpl, ...)
    print(ok and text or ("|cFF00FF00[VoidQuestReminder] bad locale format: " .. key .. "|r"))
end

-- ===================== 默认模板（AlterEgo 模式）=====================
-- 只有 config 会被逐键合并进存档；chars / version / framePos 等运行时字段
-- 由 Initialize / MigrateDB 自行建立，不在此声明（避免"模板里有、实际不生效"的误解）
local DEFAULT_DB = {
    config = {
        worldQuestIds = { 96548, 96400 },
        remindEvenIfCompleted = false,
    },
}

local DEFAULT_CHAR = {
    dontRemindThisWeek = false,
    loginSuppressed = false,
    remindEvenIfCompleted = false,
    -- 不写 weekStart：DEFAULT_CHAR 是按 pairs 逐个补默认值的，值为 nil 的键根本不会被遍历到，
    -- 写了也只是看起来"有默认值"。该字段在任何一次周重置/点击"本周不再提醒"时才会落盘
}

-- ===================== 角色标识 =====================
local function GetCharKey()
    return UnitName("player") .. "-" .. GetRealmName()
end

-- ===================== 常量 =====================
local VOID_PARENT_MAP = 2405

-- 虚空世界 mapID → config.worldQuestIds 的下标。
-- 既是"是不是我们认识的虚空世界"的成员表，也是任务 ID 的索引表：
-- 新增虚空世界只改这一处（旧写法是三张同 id 的表 + 两处 `(mapID == 2600) and 1 or ...`）
local VOID_ZONE_QUEST_INDEX = { [2600] = 1, [2599] = 2 }

-- 多语言地图名（用于 POI fallback 匹配，新增语言时按需追加）
local VOID_ZONE_NAMES = {
    [2600] = { "奈格塔尔", "奈格塔爾", "Naigtal" },
    [2599] = { "瓦尔", "瓦爾", "Val" },
}

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
            -- oldRem.weekDay 曾经迁到 config.weekDay，但该字段全代码零读取，已停止迁移（见 Initialize 的清理）
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

    -- 遗留字段清理（读侧早已没有，避免长期占着存档）：
    --   config.weekDay —— v1/v2 的"每周几重置"设定，改用官方周重置 API 后失效
    --   huntReminder   —— 1.0.x 方唐镜狩猎模块的全部状态
    VoidQuestReminderDB.config.weekDay = nil
    VoidQuestReminderDB.huntReminder = nil
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
-- 通过父地图上的虚空入口 POI 判定当前激活的虚空世界（同一时间只有一个入口，
-- 可避免两个虚空世界任务同时激活时误判）。地图判定优先用 POI 的 linkedUiMapID
--（不依赖任何本地化文本），不可用时按多语言名列表做 fallback 匹配。
local function ResolveActiveWorld()
    if not C_AreaPoiInfo or not C_AreaPoiInfo.GetAreaPOIForMap then
        return nil
    end

    local function GetSecondsLeft(poiID)
        if C_AreaPoiInfo.GetAreaPOISecondsLeft then
            return C_AreaPoiInfo.GetAreaPOISecondsLeft(poiID)
        end
        return nil
    end

    local pois = C_AreaPoiInfo.GetAreaPOIForMap(VOID_PARENT_MAP) or {}
    for _, poiID in ipairs(pois) do
        local info = C_AreaPoiInfo.GetAreaPOIInfo(VOID_PARENT_MAP, poiID)
        if info then
            -- 首选：linkedUiMapID（不依赖任何文本）
            local linkedID = info.linkedUiMapID
            if linkedID and VOID_ZONE_QUEST_INDEX[linkedID] then
                local mapInfo = C_Map.GetMapInfo(linkedID)
                return linkedID, mapInfo and mapInfo.name or nil, GetSecondsLeft(poiID)
            end
            -- fallback：多语言名列表匹配
            if info.name then
                for mapID, names in pairs(VOID_ZONE_NAMES) do
                    for _, name in ipairs(names) do
                        if name and info.name:find(name, 1, true) then
                            local mapInfo = C_Map.GetMapInfo(mapID)
                            return mapID, mapInfo and mapInfo.name or nil, GetSecondsLeft(poiID)
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- 由虚空世界 mapID 取对应的世界任务 ID（mapID 未识别时返回 nil）。
-- 单独抽出，是为了让"判定该弹哪个任务的框"和"框里显示哪个任务"共用同一次地图解析结果
local function GetWorldQuestIdForMap(mapID)
    local index = VOID_ZONE_QUEST_INDEX[mapID]
    if not index then return nil end
    local questIds = VoidQuestReminderDB.config.worldQuestIds or DEFAULT_DB.config.worldQuestIds
    return questIds and questIds[index] or nil
end

local function GetActiveWorldQuestId()
    return GetWorldQuestIdForMap(ResolveActiveWorld())
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

    -- 拖拽 + 保存位置（带屏幕边界钳制，防止拖出屏幕无法恢复）
    popupFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    popupFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left = self:GetLeft()
        local top = self:GetTop()
        local parentTop = UIParent:GetTop()
        if left and top and parentTop then
            local width = self:GetWidth()
            local height = self:GetHeight()
            local screenRight = UIParent:GetRight()
            if width and height and screenRight and width <= screenRight and height <= parentTop then
                left = math.max(0, math.min(left, screenRight - width))
                top = math.max(height, math.min(top, parentTop))
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, top - parentTop)
            end
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
            Say("MSG_SUPPRESS_WEEK")
        end)

    -- 按钮2：本次登录不再提醒（×）
    local loginBtn = CreateFlatButton(popupFrame, 24, "×",
        L.TOOLTIP_DONT_REMIND_LOGIN or "本次登录不再提醒",
        function()
            forceShow = false
            VoidQuestReminderDB.chars[GetCharKey()].loginSuppressed = true
            popupFrame:Hide()
            Say("MSG_SUPPRESS_LOGIN")
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

-- resolvedMapID / resolvedZoneName：调用方已解析过虚空世界时传入，避免同一帧里重复扫 POI
local function UpdatePopupText(extraText, resolvedMapID, resolvedZoneName)
    if not popupFrame then return end

    local completed = IsVoidConfrontationCompleted()
    popupFrame:SetSize(completed and 400 or 370, 56)

    local mapID, zoneName = resolvedMapID, resolvedZoneName
    if not mapID then
        mapID, zoneName = ResolveActiveWorld()
    end

    local zonePrefix = zoneName and ("【" .. zoneName .. "】") or ""
    local qid = GetWorldQuestIdForMap(mapID)
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

    if completed then
        statusText = statusText .. (L.VQR_COMPLETED_SUFFIX or "（已完成）")
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
        local mapID, zoneName = ResolveActiveWorld()
        local qid = GetWorldQuestIdForMap(mapID)
        if qid and C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(qid) then
            if not ShouldRemindEvenIfCompleted()
                and not forceShow
                and IsVoidConfrontationCompleted() then
                popupFrame:Hide()
                return
            end
            questLostSince = nil
            UpdatePopupText(nil, mapID, zoneName)
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
    popupFrame.debugHint:SetText(L.HINT_MANUAL_SHOW or "【手动显示】拖拽调整位置")
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
        TaskWeeklyReset()
        lastCheck = 0
        CheckAndNotify()
        C_Timer.NewTicker(POLL_INTERVAL, PollCheck)

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- 「本次登录不再提醒」只在真正登录时清空。/reload 也会触发 PLAYER_ENTERING_WORLD，
        -- 但此时 isInitialLogin 为 false：玩家刚点过×，重载界面不该让弹窗又冒出来
        local isInitialLogin = ...
        if isInitialLogin then
            VoidQuestReminderDB.chars[GetCharKey()].loginSuppressed = false
        end
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
    -- 统一去空白 + 转小写："/vqr  Show" 这类多空格/大写输入以前会掉进帮助分支
    msg = (msg or ""):lower():match("^%s*(.-)%s*$") or ""

    if msg == "show" then
        lastCheck = 0
        ShowReminderForce()
        Say("MSG_SHOW_FORCED")
    elseif msg == "hide" then
        forceShow = false
        HideReminder()
        Say("MSG_HIDDEN")
    elseif msg == "status" then
        local ch = VoidQuestReminderDB.chars[GetCharKey()]
        local _, zoneName = ResolveActiveWorld()
        local completed = IsVoidConfrontationCompleted()
        local qid = GetActiveWorldQuestId()
        local questActive = false
        if qid and C_TaskQuest and C_TaskQuest.IsActive then
            questActive = C_TaskQuest.IsActive(qid) or false
        end
        Say("STATUS_HEADER")
        Say("STATUS_WORLD", zoneName or L.VAL_NONE)
        Say("STATUS_QUEST_ID", qid and tostring(qid) or L.VAL_NONE)
        Say("STATUS_QUEST_ACTIVE", questActive and L.VAL_YES or L.VAL_NO)
        Say("STATUS_CONFRONTATION", completed and L.VAL_DONE or L.VAL_UNDONE)
        Say("STATUS_SUPPRESS_WEEK", ch.dontRemindThisWeek and L.VAL_YES or L.VAL_NO)
        Say("STATUS_SUPPRESS_LOGIN", ch.loginSuppressed and L.VAL_YES or L.VAL_NO)
        Say("STATUS_FORCE_SHOW", forceShow and L.VAL_YES or L.VAL_NO)
        Say("STATUS_REMIND_ALL", VoidQuestReminderDB.config.remindEvenIfCompleted and L.VAL_YES or L.VAL_NO)
        Say("STATUS_REMIND_CHAR", ch.remindEvenIfCompleted and L.VAL_YES or L.VAL_NO)
    elseif msg == "reset" then
        local ch = VoidQuestReminderDB.chars[GetCharKey()]
        ch.dontRemindThisWeek = false
        ch.weekStart = nil
        ch.loginSuppressed = false
        -- forceShow 是 /vqr show 留下的会话内状态，不在这里清掉的话
        -- 弹窗会一直停在"强制显示"模式，自动隐藏逻辑整晚失效
        forceShow = false
        lastCheck = 0
        Say("MSG_RESET_DONE")
        CheckAndNotify()
    elseif msg == "resetpos" then
        VoidQuestReminderDB.framePos = nil
        if popupFrame then
            popupFrame:ClearAllPoints()
            popupFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 60, -60)
        end
        Say("MSG_RESETPOS_DONE")
    else
        Say("HELP_HEADER")
        Say("HELP_SHOW")
        Say("HELP_HIDE")
        Say("HELP_STATUS")
        Say("HELP_RESET")
        Say("HELP_RESETPOS")
    end
end
