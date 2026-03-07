local _, ns = ...

local NUM_ROWS = 12
local ROW_HEIGHT = 20
local rows = {}
local sortedKeys = {}

-- Quality colors (WoW item quality)
local QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor (gray)
    [1] = { r = 1.00, g = 1.00, b = 1.00 }, -- Common (white)
    [2] = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon (green)
    [3] = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare (blue)
    [4] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic (purple)
    [5] = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary (orange)
}

local function GetQualityColor(quality)
    return QUALITY_COLORS[quality] or QUALITY_COLORS[1]
end

-- Create row frames for the scroll list
local function CreateRows(parent, scrollFrame)
    for i = 1, NUM_ROWS do
        local row = CreateFrame("Button", "AHNotifyRow" .. i, parent)
        row:SetHeight(ROW_HEIGHT)
        row:SetWidth(510)
        row:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -((i - 1) * ROW_HEIGHT))

        -- Highlight on hover
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        -- Icon
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(ROW_HEIGHT - 2, ROW_HEIGHT - 2)
        row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)

        -- Item name
        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        row.nameText:SetWidth(210)
        row.nameText:SetJustifyH("LEFT")

        -- Quantity
        row.qtyText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.qtyText:SetPoint("LEFT", row, "LEFT", 248, 0)
        row.qtyText:SetWidth(40)
        row.qtyText:SetJustifyH("CENTER")

        -- Price
        row.priceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.priceText:SetPoint("LEFT", row, "LEFT", 290, 0)
        row.priceText:SetWidth(120)
        row.priceText:SetJustifyH("LEFT")

        -- Time left
        row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.timeText:SetPoint("LEFT", row, "LEFT", 412, 0)
        row.timeText:SetWidth(45)
        row.timeText:SetJustifyH("CENTER")

        -- Status
        row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.statusText:SetPoint("LEFT", row, "LEFT", 458, 0)
        row.statusText:SetWidth(50)
        row.statusText:SetJustifyH("CENTER")

        -- Tooltip on hover
        row:SetScript("OnEnter", function(self)
            if self.itemLink then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        rows[i] = row
    end
end

-- Sort auction keys by name
local function SortAuctionKeys(auctions)
    local keys = {}
    for k in pairs(auctions) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        local ga, gb = auctions[a], auctions[b]
        if ga.name == gb.name then
            return ga.buyoutPrice < gb.buyoutPrice
        end
        return ga.name < gb.name
    end)
    return keys
end

-- Update the displayed rows
local function UpdateList()
    local auctions = ns:GetCurrentAuctions()
    sortedKeys = SortAuctionKeys(auctions)
    local numItems = #sortedKeys

    local scrollFrame = AHNotifyListFrameScrollFrame
    FauxScrollFrame_Update(scrollFrame, numItems, NUM_ROWS, ROW_HEIGHT)

    local offset = FauxScrollFrame_GetOffset(scrollFrame)
    for i = 1, NUM_ROWS do
        local idx = i + offset
        local row = rows[i]
        if idx <= numItems then
            local key = sortedKeys[idx]
            local group = auctions[key]
            local color = GetQualityColor(group.quality)

            row.icon:SetTexture(group.texture)
            row.nameText:SetText(group.name)
            row.nameText:SetTextColor(color.r, color.g, color.b)
            row.qtyText:SetText(group.numAuctions .. "x")
            row.qtyText:SetTextColor(1, 1, 1)
            row.priceText:SetText(ns:FormatMoney(group.buyoutPrice))
            row.timeText:SetText(ns:FormatTimeLeft(group.timeLeft))

            -- Status display
            if group.activeCount == 0 and group.soldCount > 0 then
                row.statusText:SetText("SOLD")
                row.statusText:SetTextColor(0, 1, 0)
            elseif group.soldCount > 0 then
                row.statusText:SetText(group.soldCount .. " sold")
                row.statusText:SetTextColor(1, 0.8, 0)
            else
                row.statusText:SetText("Active")
                row.statusText:SetTextColor(0.5, 0.5, 0.5)
            end

            row.itemLink = group.itemLink
            row:Show()
        else
            row:Hide()
        end
    end
end

-- Initialize
function ns:InitAuctionListFrame()
    local frame = AHNotifyListFrame
    if not frame then return end

    -- Set backdrop via Lua (BackdropTemplateMixin)
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
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, _, relPoint, x, y = self:GetPoint()
        ns.db.framePos = { point = point, relPoint = relPoint, x = x, y = y }
    end)

    -- Restore saved position
    if ns.db.framePos then
        frame:ClearAllPoints()
        frame:SetPoint(ns.db.framePos.point, UIParent, ns.db.framePos.relPoint, ns.db.framePos.x, ns.db.framePos.y)
    end

    -- Create scroll list rows (parent to main frame, position relative to scroll frame)
    CreateRows(frame, AHNotifyListFrameScrollFrame)

    -- Scroll frame handler
    AHNotifyListFrameScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UpdateList)
    end)

    -- Summary text at bottom
    frame.summaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.summaryText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 16)
    frame.summaryText:SetTextColor(0.7, 0.7, 0.7)

    -- Notifications button
    local notifBtn = CreateFrame("Button", "AHNotifyNotifButton", frame, "UIPanelButtonTemplate")
    notifBtn:SetSize(110, 22)
    notifBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 12)
    notifBtn:SetText("Notifications")
    notifBtn:SetScript("OnClick", function()
        ns:ToggleNotificationLogFrame()
    end)
    frame.notifButton = notifBtn
end

function ns:ToggleAuctionListFrame()
    local frame = AHNotifyListFrame
    if not frame then return end
    if frame:IsShown() then
        frame:Hide()
    else
        UpdateList()
        frame:Show()
    end
end

function ns:UpdateAuctionListFrame()
    if AHNotifyListFrame and AHNotifyListFrame:IsShown() then
        UpdateList()
        -- Update summary
        local auctions = ns:GetCurrentAuctions()
        local totalActive = 0
        local totalSold = 0
        local totalGroups = 0
        for _, group in pairs(auctions) do
            totalGroups = totalGroups + 1
            totalActive = totalActive + group.activeCount
            totalSold = totalSold + group.soldCount
        end
        if AHNotifyListFrame.summaryText then
            AHNotifyListFrame.summaryText:SetText(
                totalGroups .. " groups | " .. totalActive .. " active | " .. totalSold .. " sold"
            )
        end
    end
end
