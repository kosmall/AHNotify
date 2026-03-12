local _, ns = ...

local NUM_LOG_ROWS = 12
local LOG_ROW_HEIGHT = 20
local logRows = {}
local filteredLog = {}

-- Filter state: only restock enabled by default
local filters = {
    sold    = false,
    restock = true,
    expired = false,
    new     = false,
}

-- Type icon colors
local TYPE_COLORS = {
    sold    = { r = 0.00, g = 1.00, b = 0.00 },
    restock = { r = 1.00, g = 0.53, b = 0.00 },
    expired = { r = 1.00, g = 0.00, b = 0.00 },
    new     = { r = 0.00, g = 0.80, b = 1.00 },
}

local TYPE_LABELS = {
    sold    = "SOLD",
    restock = "RESTOCK",
    expired = "EXPIRED",
    new     = "NEW",
}

-- Rebuild filtered list from full log
local function RebuildFilteredLog()
    wipe(filteredLog)
    local log = ns:GetNotificationLog()
    for i = 1, #log do
        if filters[log[i].logType] then
            table.insert(filteredLog, log[i])
        end
    end
end

local function CreateLogRows(parent, scrollFrame)
    for i = 1, NUM_LOG_ROWS do
        local row = CreateFrame("Frame", "AHNotifyLogRow" .. i, parent)
        row:SetHeight(LOG_ROW_HEIGHT)
        row:SetWidth(410)
        row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((i - 1) * LOG_ROW_HEIGHT))

        -- Timestamp
        row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.timeText:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.timeText:SetWidth(50)
        row.timeText:SetJustifyH("LEFT")
        row.timeText:SetTextColor(0.6, 0.6, 0.6)

        -- Type badge
        row.typeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.typeText:SetPoint("LEFT", row, "LEFT", 55, 0)
        row.typeText:SetWidth(60)
        row.typeText:SetJustifyH("CENTER")

        -- Search button (for restock entries)
        row.searchBtn = CreateFrame("Button", "AHNotifyLogRowSearch" .. i, row, "UIPanelButtonTemplate")
        row.searchBtn:SetSize(20, LOG_ROW_HEIGHT)
        row.searchBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.searchBtn:SetText("\124TInterface\\COMMON\\UI-Searchbox-Icon:14:14\124t")
        row.searchBtn:SetScript("OnClick", function()
            local itemLink = row.entryItemLink
            if itemLink then
                HandleModifiedItemClick(itemLink)
            end
            -- Remove this entry from the log
            if row.entryRef then
                ns:RemoveFromLog(row.entryRef)
            end
        end)
        row.searchBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Search in AH", 1, 1, 1)
            GameTooltip:Show()
        end)
        row.searchBtn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row.searchBtn:Hide()

        -- Message
        row.msgText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.msgText:SetPoint("LEFT", row, "LEFT", 120, 0)
        row.msgText:SetPoint("RIGHT", row.searchBtn, "LEFT", -2, 0)
        row.msgText:SetJustifyH("LEFT")
        row.msgText:SetWordWrap(false)

        logRows[i] = row
    end
end

local function UpdateLogList()
    RebuildFilteredLog()
    local numItems = #filteredLog

    local scrollFrame = AHNotifyLogFrameScrollFrame
    FauxScrollFrame_Update(scrollFrame, numItems, NUM_LOG_ROWS, LOG_ROW_HEIGHT)

    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    for i = 1, NUM_LOG_ROWS do
        -- Show newest first
        local idx = numItems - (i + offset) + 1
        local row = logRows[i]
        if idx >= 1 and idx <= numItems then
            local entry = filteredLog[idx]
            local typeColor = TYPE_COLORS[entry.logType] or TYPE_COLORS.new

            row.timeText:SetText(entry.timestamp)
            row.typeText:SetText(TYPE_LABELS[entry.logType] or entry.logType)
            row.typeText:SetTextColor(typeColor.r, typeColor.g, typeColor.b)
            row.msgText:SetText(entry.text)

            -- Show search button only for restock entries with an item link
            if entry.logType == "restock" and entry.itemLink then
                row.entryItemLink = entry.itemLink
                row.entryRef = entry
                row.searchBtn:Show()
            else
                row.entryItemLink = nil
                row.entryRef = nil
                row.searchBtn:Hide()
            end

            row:Show()
        else
            row:Hide()
            row.searchBtn:Hide()
            row.entryRef = nil
        end
    end

    -- Update counter in title
    local totalLog = #(ns:GetNotificationLog())
    if AHNotifyLogFrameTitle then
        AHNotifyLogFrameTitle:SetText("AHNotify - Notifications (" .. numItems .. "/" .. totalLog .. ")")
    end
end

-- Create a filter checkbox
local function CreateFilterCheckbox(parent, logType, label, xOffset)
    local color = TYPE_COLORS[logType]
    local cb = CreateFrame("CheckButton", "AHNotifyFilter_" .. logType, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, -38)
    cb:SetChecked(filters[logType])

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", cb, "RIGHT", 0, 1)
    text:SetText(label)
    text:SetTextColor(color.r, color.g, color.b)
    cb.label = text

    cb:SetScript("OnClick", function(self)
        filters[logType] = self:GetChecked() and true or false
        UpdateLogList()
    end)

    return cb
end

function ns:InitNotificationLogFrame()
    local frame = AHNotifyLogFrame
    if not frame then return end

    -- Set backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })

    -- Make draggable
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Filter checkboxes
    CreateFilterCheckbox(frame, "sold",    "Sold",    16)
    CreateFilterCheckbox(frame, "restock", "Restock", 100)
    CreateFilterCheckbox(frame, "expired", "Expired", 200)
    CreateFilterCheckbox(frame, "new",     "New",     300)

    -- Create rows (parent to main frame, position relative to scroll frame)
    CreateLogRows(frame, AHNotifyLogFrameScrollFrame)

    -- Scroll handler
    AHNotifyLogFrameScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, LOG_ROW_HEIGHT, UpdateLogList)
    end)

    -- Clear button
    AHNotifyLogFrameClearButton:SetScript("OnClick", function()
        ns:ClearNotificationLog()
        UpdateLogList()
    end)
end

function ns:ToggleNotificationLogFrame()
    local frame = AHNotifyLogFrame
    if not frame then return end
    if frame:IsShown() then
        frame:Hide()
    else
        UpdateLogList()
        frame:Show()
    end
end

-- Persistent global button for /click AHNotifyRestockFirst macro support
-- Created once with the proper name so /click can find it; OnClick updated dynamically
local restockFirstBtn = CreateFrame("Button", "AHNotifyRestockFirst", UIParent)
restockFirstBtn:SetSize(1, 1)
restockFirstBtn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
restockFirstBtn:SetAlpha(0)
restockFirstBtn:EnableMouse(false)
restockFirstBtn:RegisterForClicks("AnyDown", "AnyUp")
restockFirstBtn:Show()

local function UpdateRestockFirstGlobal()
    local log = ns:GetNotificationLog()
    -- Find the newest restock entry with an item link
    local found = nil
    for i = #log, 1, -1 do
        if log[i].logType == "restock" and log[i].itemLink then
            found = log[i]
            break
        end
    end
    restockFirstBtn.entryItemLink = found and found.itemLink or nil
    restockFirstBtn.entryRef = found
    restockFirstBtn:SetScript("OnClick", function()
        if restockFirstBtn.entryItemLink then
            HandleModifiedItemClick(restockFirstBtn.entryItemLink)
        end
        if restockFirstBtn.entryRef then
            ns:RemoveFromLog(restockFirstBtn.entryRef)
        end
    end)
end

function ns:UpdateNotificationLogFrame()
    UpdateRestockFirstGlobal()
    if AHNotifyLogFrame and AHNotifyLogFrame:IsShown() then
        UpdateLogList()
    end
end
