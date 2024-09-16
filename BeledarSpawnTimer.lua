-- Load libraries
local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

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
        tooltip:AddLine(" ")
        tooltip:AddLine(L["beledartimer"])
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

-- Create the minimap button
LDBIcon:Register("BeledarSpawnTimer", broker, BeledarTimerDB)

-- Function to update the minimap button state
local function UpdateMinimapButtonState()
    if BeledarTimerDB and BeledarTimerDB.minimap and BeledarTimerDB.minimap.hide then
        LDBIcon:Hide("BeledarSpawnTimer")
    else
        LDBIcon:Show("BeledarSpawnTimer")
    end
end

-- Frame to listen for the PLAYER_LOGIN event
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")

-- OnEvent handler to ensure the saved variables are loaded before checking the minimap button state
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        -- At this point, the SavedVariables should be loaded
        UpdateMinimapButtonState()
    end
end)

-- Chat command to toggle minimap button visibility
SLASH_BELEDARTIMER1 = "/beledartimer"
SlashCmdList["BELEDARTIMER"] = function(msg)
    if msg:lower() == "minimap" then
        BeledarTimerDB.minimap.hide = not BeledarTimerDB.minimap.hide
        if BeledarTimerDB.minimap.hide then
            LDBIcon:Hide("BeledarSpawnTimer")
            print(L["minimapHide"])
        else
            LDBIcon:Show("BeledarSpawnTimer")
            print(L["minimapShow"])
        end
    else
        print(L["beledartimer"])
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
