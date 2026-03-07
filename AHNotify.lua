local ADDON_NAME, ns = ...

-- Default saved variables
local defaults = {
    minimap = { hide = false, minimapPos = 225 },
    framePos = nil,
}

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
    if addon ~= ADDON_NAME then return end

    -- Initialize saved variables
    if not AHNotifyDB then
        AHNotifyDB = {}
    end
    for k, v in pairs(defaults) do
        if AHNotifyDB[k] == nil then
            if type(v) == "table" then
                AHNotifyDB[k] = {}
                for kk, vv in pairs(v) do
                    AHNotifyDB[k][kk] = vv
                end
            else
                AHNotifyDB[k] = v
            end
        end
    end

    ns.db = AHNotifyDB

    -- Initialize modules
    if ns.InitNotifications then ns:InitNotifications() end
    if ns.InitTracker then ns:InitTracker() end
    if ns.InitMinimapButton then ns:InitMinimapButton() end
    if ns.InitAuctionListFrame then ns:InitAuctionListFrame() end
    if ns.InitNotificationLogFrame then ns:InitNotificationLogFrame() end

    ns:Print("|cff00ff00AHNotify loaded.|r Type /ahnotify to toggle the auction list.")

    self:UnregisterEvent("ADDON_LOADED")
end)

-- Slash command
SLASH_AHNOTIFY1 = "/ahnotify"
SLASH_AHNOTIFY2 = "/ahn"
SlashCmdList["AHNOTIFY"] = function(msg)
    if ns.ToggleAuctionListFrame then
        ns:ToggleAuctionListFrame()
    end
end

-- Utility: print to chat
function ns:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33aaff[AHNotify]|r " .. msg)
end

-- Utility: format money
function ns:FormatMoney(copper)
    if not copper or copper == 0 then return "0c" end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    local str = ""
    if gold > 0 then str = str .. "|cffffd700" .. gold .. "g|r " end
    if silver > 0 then str = str .. "|cffc7c7cf" .. silver .. "s|r " end
    if cop > 0 then str = str .. "|cffeda55f" .. cop .. "c|r" end
    return str
end

-- Utility: duration text from timeLeft index (1=short, 2=medium, 3=long, 4=very long)
function ns:FormatTimeLeft(timeLeft)
    if timeLeft == 1 then return "|cffff0000<30m|r"
    elseif timeLeft == 2 then return "|cffff8800<2h|r"
    elseif timeLeft == 3 then return "|cffffff0012h+|r"
    elseif timeLeft == 4 then return "|cff00ff0048h|r"
    else return "?" end
end
