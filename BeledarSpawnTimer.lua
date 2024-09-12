-- Load LibDataBroker
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")

-- Saved variable to store minimap button visibility state
BeledarTimerDB = BeledarTimerDB or { minimap = { hide = false } }

-- EU Spawn Times: Every 3 hours from 01:00 to 22:00
local EU_times = {
    "01:00", "04:00", "07:00", "10:00", "13:00", "16:00", "19:00", "22:00"
}

-- NA Spawn Times: Every 3 hours from 00:00 to 21:00
local NA_times = {
    "00:00", "03:00", "06:00", "09:00", "12:00", "15:00", "18:00", "21:00"
}

-- Detect player region (1 = NA, 3 = EU)
local regionID = GetCurrentRegion()
local isEU = (regionID == 3)
local spawnTimes = isEU and EU_times or NA_times

-- Helper function to calculate time difference
local function GetTimeDifference(hours, minutes, spawnHour, spawnMinute)
    local currentTotalMinutes = hours * 60 + minutes
    local spawnTotalMinutes = tonumber(spawnHour) * 60 + tonumber(spawnMinute)

    if spawnTotalMinutes < currentTotalMinutes then
        -- If the spawn time has already passed today, calculate the time until the next day's spawn
        spawnTotalMinutes = spawnTotalMinutes + 24 * 60
    end

    local diffMinutes = spawnTotalMinutes - currentTotalMinutes
    local diffHours = math.floor(diffMinutes / 60)
    diffMinutes = diffMinutes % 60

    return string.format("%02dh %02dm", diffHours, diffMinutes)
end

-- Function to get the time until the next spawn
local function GetTimeUntilNextSpawn(timesArray)
    local hours, minutes = GetGameTime() -- Get current server time
    for _, spawnTime in ipairs(timesArray) do
        local spawnHour, spawnMinute = spawnTime:match("(%d%d):(%d%d)")
        local timeUntil = GetTimeDifference(hours, minutes, spawnHour, spawnMinute)
        
        local spawnTotalMinutes = tonumber(spawnHour) * 60 + tonumber(spawnMinute)
        if spawnTotalMinutes > (hours * 60 + minutes) then
            return timeUntil -- Return the time until the next spawn
        end
    end

    -- If no future spawn time found, calculate time until first spawn the next day
    local spawnHour, spawnMinute = timesArray[1]:match("(%d%d):(%d%d)")
    return GetTimeDifference(hours, minutes, spawnHour, spawnMinute)
end

-- Find the General chat index
local function FindGeneralChatChannel()
    local channels = { GetChannelList() }
    for i = 1, #channels, 2 do
        local channelID = channels[i]
        local channelName = channels[i + 1]
        if channelName:find("General") then
            return channelID
        end
    end
    return nil
end

-- Create a broker object
local broker = LDB:NewDataObject(L["Spawn Timer"], {
    type = "data source",
    text = L["Spawn Timer"],
    icon = "Interface\\Icons\\Inv_shadowelementalmount_purple", -- Updated icon
    OnTooltipShow = function(tooltip)
        tooltip:AddLine(L["Spawn Timer"])
        tooltip:AddLine(L["Next spawn in"] .. ": " .. GetTimeUntilNextSpawn(spawnTimes))
        tooltip:AddLine(L["Click to send to General chat."])
        tooltip:AddLine(L["Hold Alt and click to send to Guild chat."])
    end,
    OnClick = function(_, button)
        local timeUntilNextSpawn = GetTimeUntilNextSpawn(spawnTimes)

        if IsAltKeyDown() and button == "LeftButton" then
            -- Send the message to guild chat
            if IsInGuild() then
                SendChatMessage(L["Next spawn in"] .. ": " .. timeUntilNextSpawn, "GUILD")
            else
                print(L["You are not in a guild!"])
            end
        elseif button == "LeftButton" then
            -- Send the message to General chat
            local generalChannel = FindGeneralChatChannel()
            if generalChannel then
                SendChatMessage(L["Next spawn in"] .. ": " .. timeUntilNextSpawn, "CHANNEL", nil, generalChannel)
            else
                print(L["Could not find the General chat channel."])
            end
        end
    end
})

-- Function to update the broker display
local function UpdateDisplay()
    local timeUntilNextSpawn = GetTimeUntilNextSpawn(spawnTimes)
    broker.text = L["Next spawn in"] .. ": " .. timeUntilNextSpawn
end

-- Create custom minimap button
local minimapButton = CreateFrame("Button", "BeledarTimerMinimapButton", Minimap)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetWidth(32)
minimapButton:SetHeight(32)
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 52 - (80 * cos(45)), (80 * sin(45)) - 52)

minimapButton:SetScript("OnClick", function(self, button)
    broker.OnClick(self, button)
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    broker.OnTooltipShow(GameTooltip)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Set the button icon
minimapButton.icon = minimapButton:CreateTexture(nil, "BACKGROUND")
minimapButton.icon:SetTexture("Interface\\Icons\\Inv_shadowelementalmount_purple")
minimapButton.icon:SetWidth(20)
minimapButton.icon:SetHeight(20)
minimapButton.icon:SetPoint("CENTER")

-- Function to move the minimap button
local function MoveMinimapButton(angle)
    local xOffset = 52 - (80 * cos(angle))
    local yOffset = (80 * sin(angle)) - 52
    minimapButton:SetPoint("TOPLEFT", Minimap, "TOPLEFT", xOffset, yOffset)
end

-- Update minimap button position based on saved variables
local function UpdateMinimapButtonPosition()
    if BeledarTimerDB.minimapButtonPosition then
        MoveMinimapButton(BeledarTimerDB.minimapButtonPosition)
    end
end

-- Function to show/hide minimap button
local function ToggleMinimapButton()
    if BeledarTimerDB.minimap.hide then
        minimapButton:Hide()
    else
        minimapButton:Show()
        UpdateMinimapButtonPosition()
    end
end

-- Chat command to toggle minimap button visibility
SLASH_BELEDARTIMER1 = "/beledartimer"
SlashCmdList["BELEDARTIMER"] = function(msg)
    if msg:lower() == "minimap" then
        BeledarTimerDB.minimap.hide = not BeledarTimerDB.minimap.hide
        ToggleMinimapButton()
        if BeledarTimerDB.minimap.hide then
            print("Minimap button hidden.")
        else
            print("Minimap button shown.")
        end
    else
        print("Usage: /beledartimer minimap - Toggle minimap button visibility")
    end
end

-- Set up a repeating timer to update the display every minute
local f = CreateFrame("Frame")
f:SetScript("OnUpdate", function(self, elapsed)
    if not self.lastUpdate then self.lastUpdate = 0 end
    self.lastUpdate = self.lastUpdate + elapsed
    if self.lastUpdate > 60 then
        UpdateDisplay()
        self.lastUpdate = 0
    end
end)

-- Update the display when the addon is loaded
UpdateDisplay()

-- Show/hide the minimap button when the addon is loaded
ToggleMinimapButton()
