local _, ns = ...

local COLORS = {
    sold    = "|cff00ff00",  -- green
    expired = "|cffff0000",  -- red
    restock = "|cffff8800",  -- orange
    new     = "|cff00ccff",  -- cyan
    reset   = "|r",
}

-- Notification history log
local notificationLog = {}

function ns:AddToLog(logType, text)
    table.insert(notificationLog, {
        logType = logType,
        text = text,
        timestamp = date("%H:%M:%S"),
    })
    if ns.UpdateNotificationLogFrame then
        ns:UpdateNotificationLogFrame()
    end
end

function ns:GetNotificationLog()
    return notificationLog
end

function ns:ClearNotificationLog()
    wipe(notificationLog)
    if ns.UpdateNotificationLogFrame then
        ns:UpdateNotificationLogFrame()
    end
end

function ns:GetNotificationCount()
    return #notificationLog
end

-- Compare previous and current auction snapshots, fire notifications
function ns:CompareAndNotify(prev, curr)
    -- Skip first scan (no previous data to compare)
    if not next(prev) and not next(curr) then return end

    -- Check for sold/reduced auctions
    for groupKey, prevGroup in pairs(prev) do
        local currGroup = curr[groupKey]
        if not currGroup then
            -- Group disappeared entirely from owner tab.
            -- This happens when sold auctions are collected from mailbox
            -- or auctions expire. We can't reliably distinguish, so only
            -- notify if previous state had active auctions (likely sold out).
            if prevGroup.activeCount > 0 then
                local itemRef = prevGroup.itemLink or prevGroup.name
                local soldDelta = prevGroup.activeCount
                local revenue = prevGroup.buyoutPrice * soldDelta
                self:NotifySold(itemRef, soldDelta, revenue)
                self:NotifyRestock(itemRef, prevGroup.buyoutPrice, soldDelta)
            end
        else
            -- Check if active count decreased (items sold)
            local soldDelta = prevGroup.activeCount - currGroup.activeCount
            if soldDelta > 0 then
                local itemRef = currGroup.itemLink or currGroup.name
                local revenue = currGroup.buyoutPrice * soldDelta
                self:NotifySold(itemRef, soldDelta, revenue)
            end

            -- Check if entire group is now fully sold (all activeCount = 0)
            -- but only when soldCount increased (confirms sale, not expiry)
            if currGroup.activeCount == 0 and prevGroup.activeCount > 0
               and currGroup.soldCount > prevGroup.soldCount then
                local itemRef = currGroup.itemLink or currGroup.name
                self:NotifyRestock(itemRef, currGroup.buyoutPrice, prevGroup.activeCount)
            end
        end
    end

    -- Check for new auctions that appeared
    for groupKey, currGroup in pairs(curr) do
        if not prev[groupKey] then
            local itemRef = currGroup.itemLink or currGroup.name
            self:NotifyNew(itemRef, currGroup.activeCount, currGroup.buyoutPrice)
        end
    end
end

function ns:NotifySold(itemRef, count, totalPrice)
    local msg = COLORS.sold .. "Sold!|r " .. itemRef
    if count > 1 then
        msg = msg .. " x" .. count
    end
    msg = msg .. " for " .. self:FormatMoney(totalPrice)
    self:AddToLog("sold", msg)
    PlaySound(SOUNDKIT.AUCTION_WINDOW_CLOSE or 5594)
end

function ns:NotifyRestock(itemRef, buyoutPrice, soldCount)
    local msg = COLORS.restock .. "RESTOCK NEEDED!|r " .. itemRef
    msg = msg .. " - all " .. soldCount .. " auction(s) sold!"
    msg = msg .. " (was " .. self:FormatMoney(buyoutPrice) .. " each)"
    self:Print(msg)
    self:AddToLog("restock", msg)
    PlaySound(SOUNDKIT.RAID_WARNING or 8959)
end

function ns:NotifyExpired(itemRef, count)
    local msg = COLORS.expired .. "Expired!|r " .. itemRef
    if count > 1 then
        msg = msg .. " x" .. count
    end
    self:AddToLog("expired", msg)
end

function ns:NotifyNew(itemRef, count, buyoutPrice)
    local msg = COLORS.new .. "New auction detected:|r " .. itemRef
    if count > 1 then
        msg = msg .. " x" .. count
    end
    msg = msg .. " at " .. self:FormatMoney(buyoutPrice)
    self:AddToLog("new", msg)
end

function ns:InitNotifications()
    -- Notifications module ready
end
