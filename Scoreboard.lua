-- Integrate list button into the match results panel to parse and collect player names because writing them out manually is tedious

local isPendingShow = false

-- Iterate through the battleground api to aggregate unique player names
local function collectPlayerNames()
    local playerNamesList = {}
    local foundNamesList = {}

    for eventIndex = 1, GetNumBattlefieldScores() do
        local scoreInformation = C_PvP.GetScoreInfo(eventIndex)

        if scoreInformation
        and scoreInformation.name
        and scoreInformation.name ~= ""
        then
            local parsedName = scoreInformation.name

            if not foundNamesList[parsedName] then
                foundNamesList[parsedName] = true
                playerNamesList[#playerNamesList + 1] = parsedName
            end
        end
    end

    return playerNamesList
end

-- Fetch the latest match metrics from the api to refresh the open name frame
local function refreshPlayerList()
    if not SuperContact_NamesDialog.IsShown() then return end

    local playerNamesList = collectPlayerNames()

    if #playerNamesList > 0 then
        SuperContact_NamesDialog.Update(playerNamesList)
    end
end

-- Attempt to render the collected list or defer execution until data arrives because querying the server has an asynchronous delay
local function showWhenDataReady()
    local playerNamesList = collectPlayerNames()

    if #playerNamesList > 0 then
        SuperContact_NamesDialog.Show(playerNamesList)
        return
    end

    isPendingShow = true
    RequestBattlefieldScoreData()

    C_Timer.After(2.0, function()
        if not isPendingShow then return end

        isPendingShow = false
        local names = collectPlayerNames()
        if #names > 0 then
            SuperContact_NamesDialog.Show(names)
        end
    end)
end

-- Attach a user trigger action button onto the match results panel to invoke extraction because the default UI offers no export action
local function createNamesButton()
    if not PVPMatchResults or PVPMatchResults.namesButtonTrigger then return end

    local interactionButton = SuperContact.createActionButton(PVPMatchResults, "Contact Players", 120, function()
        if SuperContact_NamesDialog.IsShown() then
            SuperContact_NamesDialog.Hide()
            return
        end
        showWhenDataReady()
    end, 25)

    interactionButton:SetPoint("LEFT", PVPMatchResults.leaveButton, "RIGHT", 10, 0)

    PVPMatchResults:HookScript("OnShow", function()
        RequestBattlefieldScoreData()
    end)

    PVPMatchResults.namesButtonTrigger = interactionButton
end

-- Listen for score data updates to fulfil pending show requests and refresh the open dialog
local eventListenerFrame = CreateFrame("Frame")
eventListenerFrame:RegisterEvent("ADDON_LOADED")
eventListenerFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
eventListenerFrame:SetScript("OnEvent", function(_, dispatchedEvent, matchedAddon)
    if dispatchedEvent == "ADDON_LOADED" and matchedAddon == "Blizzard_PVPUI" then
        createNamesButton()

    elseif dispatchedEvent == "UPDATE_BATTLEFIELD_SCORE" then
        if isPendingShow then
            isPendingShow = false
            local names = collectPlayerNames()
            if #names > 0 then
                SuperContact_NamesDialog.Show(names)
            end
        else
            refreshPlayerList()
        end
    end
end)
