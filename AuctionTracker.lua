local _, ns = ...

local SCAN_INTERVAL = 10
local isAHOpen = false
local scanTimer = nil
local scanScheduled = false
local isFirstScan = true
local previousAuctions = {}  -- keyed by groupKey -> {name, texture, quality, count, buyoutPrice, timeLeft, itemLink, soldCount}
local currentAuctions = {}
local lastSortAsc = true  -- toggle sort direction to force AUCTION_OWNED_LIST_UPDATE

-- Group key: name + buyoutPrice per unit
local function MakeGroupKey(name, buyoutPrice)
    return (name or "?") .. ":" .. (buyoutPrice or 0)
end

-- Scan all owner auctions and build grouped snapshot
local function ScanOwnerAuctions()
    local numBatch, numTotal = GetNumAuctionItems("owner")

    -- If server returns 0 but we had auctions before, it's likely
    -- stale/unloaded data. Skip this scan and let the next timer retry.
    if numTotal == 0 and next(previousAuctions) and not isFirstScan then
        return
    end

    local snapshot = {}
    for i = 1, numTotal do
        local name, texture, count, quality, canUse, level, levelColHeader,
              minBid, minIncrement, buyoutPrice, bidAmount, highBidder,
              bidderFullName, owner, ownerFullName, saleStatus, itemId, hasAllInfo
              = GetAuctionItemInfo("owner", i)

        local timeLeft = GetAuctionItemTimeLeft("owner", i)
        local itemLink = GetAuctionItemLink("owner", i)

        if name then
            local groupKey = MakeGroupKey(name, buyoutPrice)
            if not snapshot[groupKey] then
                snapshot[groupKey] = {
                    name = name,
                    texture = texture,
                    quality = quality or 1,
                    count = 0,
                    numAuctions = 0,
                    buyoutPrice = buyoutPrice or 0,
                    timeLeft = timeLeft,
                    itemLink = itemLink,
                    soldCount = 0,
                    activeCount = 0,
                }
            end

            local group = snapshot[groupKey]
            group.count = group.count + (count or 1)
            group.numAuctions = group.numAuctions + 1

            -- saleStatus: 0 = active, 1 = sold (waiting to be collected)
            if saleStatus == 1 then
                group.soldCount = group.soldCount + 1
            else
                group.activeCount = group.activeCount + 1
            end

            -- Keep the shortest time left for the group
            if timeLeft and (not group.timeLeft or timeLeft < group.timeLeft) then
                group.timeLeft = timeLeft
            end
        end
    end

    currentAuctions = snapshot

    -- First scan after AH open: just store baseline, don't compare
    if isFirstScan then
        isFirstScan = false
        previousAuctions = ns:CopySnapshot(currentAuctions)
        local count = 0
        for _ in pairs(currentAuctions) do count = count + 1 end
        ns:Print("Found " .. count .. " auction group(s).")
    else
        ns:CompareAndNotify(previousAuctions, currentAuctions)
        previousAuctions = ns:CopySnapshot(currentAuctions)
    end

    ns:UpdateAuctionListFrame()
end

-- Deep copy a snapshot table
function ns:CopySnapshot(src)
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = {}
        for kk, vv in pairs(v) do
            copy[k][kk] = vv
        end
    end
    return copy
end

-- Get current auctions for UI
function ns:GetCurrentAuctions()
    return currentAuctions
end

-- Get total active auction count
function ns:GetActiveAuctionCount()
    local count = 0
    for _, group in pairs(currentAuctions) do
        count = count + group.activeCount
    end
    return count
end

-- Schedule next scan
local function ScheduleScan()
    if not isAHOpen or scanScheduled then return end
    scanScheduled = true
    scanTimer = C_Timer.After(SCAN_INTERVAL, function()
        scanScheduled = false
        if isAHOpen then
            -- Toggle sort direction to force server to resend data
            -- and fire AUCTION_OWNED_LIST_UPDATE
            lastSortAsc = not lastSortAsc
            SortAuctionItems("owner", "duration")
            -- Fallback: if event doesn't fire within 2s, scan directly
            C_Timer.After(2, function()
                if isAHOpen and not scanScheduled then
                    ScanOwnerAuctions()
                    ScheduleScan()
                end
            end)
        end
    end)
end

-- Event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")
frame:SetScript("OnEvent", function(self, event)
    if event == "AUCTION_HOUSE_SHOW" then
        isAHOpen = true
        isFirstScan = true
        ns:Print("Auction House opened. Scanning your auctions...")
        -- Trigger owner list load by sorting, which fires AUCTION_OWNED_LIST_UPDATE
        SortAuctionItems("owner", "duration")
    elseif event == "AUCTION_HOUSE_CLOSED" then
        isAHOpen = false
        scanScheduled = false
        scanTimer = nil
        isFirstScan = true
        ns:Print("Auction House closed. Scanning stopped.")
    elseif event == "AUCTION_OWNED_LIST_UPDATE" then
        if isAHOpen then
            ScanOwnerAuctions()
            ScheduleScan()
        end
    end
end)

function ns:InitTracker()
    -- Tracker is ready (events already registered above)
end

function ns:IsAHOpen()
    return isAHOpen
end
