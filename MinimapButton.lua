local _, ns = ...

function ns:InitMinimapButton()
    local LDB = LibStub("LibDataBroker-1.1")
    local icon = LibStub("LibDBIcon-1.0")

    local dataObj = LDB:NewDataObject("AHNotify", {
        type = "launcher",
        text = "AHNotify",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        OnClick = function(self, button)
            if button == "LeftButton" then
                ns:ToggleAuctionListFrame()
            elseif button == "MiddleButton" then
                ns:ToggleNotificationLogFrame()
            elseif button == "RightButton" then
                -- Toggle minimap icon lock
                if ns.db.minimap.lock then
                    icon:Unlock("AHNotify")
                    ns:Print("Minimap icon unlocked.")
                else
                    icon:Lock("AHNotify")
                    ns:Print("Minimap icon locked.")
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cff33aaffAHNotify|r")
            local count = ns:GetActiveAuctionCount()
            local notifCount = ns:GetNotificationCount()
            tooltip:AddLine("Active auctions: " .. count, 1, 1, 1)
            tooltip:AddLine("Notifications: " .. notifCount, 1, 1, 1)
            if ns:IsAHOpen() then
                tooltip:AddLine("|cff00ff00AH is open - scanning|r")
            else
                tooltip:AddLine("|cff888888AH is closed|r")
            end
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff00ff00Left-click:|r Toggle auction list")
            tooltip:AddLine("|cff00ff00Middle-click:|r Toggle notifications")
            tooltip:AddLine("|cff00ff00Right-click:|r Lock/unlock icon")
        end,
    })

    icon:Register("AHNotify", dataObj, ns.db.minimap)
end
