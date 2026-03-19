-- Integrate list button into the battleground scoreboard to parse and collect player names because writing them out manually is tedious

local isPendingShow = false
local isMatchComplete = false

-- Check whether the current match has finished to safely access score data because GetScoreInfo returns secret values during active matches

local function updateMatchCompleteState()
    if C_PvP.IsMatchComplete() then
        isMatchComplete = true
    elseif C_PvP.GetActiveMatchState() <= Enum.PvPMatchState.Waiting then
        isMatchComplete = false
    end
end

-- Iterate through the battleground api to aggregate unique player names only after match ends because the api returns secret tainted values during active matches

local function collectPlayerNames()
    if not isMatchComplete then return {} end

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

-- Fetch the latest match metrics from the api to refresh the open name frame because players may join or leave during battlegrounds

local function refreshPlayerList()
    if not CopyAllTheNames_NamesDialog.IsShown() then return end

    local playerNamesList = collectPlayerNames()

    if #playerNamesList > 0 then
        CopyAllTheNames_NamesDialog.Update(playerNamesList)
    end
end

-- Attempt to render the collected list or defer execution until data arrives because querying the server has an asynchronous delay

local function showWhenDataReady()
    local playerNamesList = collectPlayerNames()

    if #playerNamesList > 0 then
        CopyAllTheNames_NamesDialog.Show(playerNamesList)
        return
    end

    isPendingShow = true
    RequestBattlefieldScoreData()

    C_Timer.After(2.0, function()
        if not isPendingShow then return end

        isPendingShow = false
        CopyAllTheNames_NamesDialog.Show(collectPlayerNames())
    end)
end

-- Update button visibility based on match state to hide during active matches because score data is secret and causes taint errors

local function updateButtonVisibility(scoreboardPanel)
    if not scoreboardPanel or not scoreboardPanel.namesButtonTrigger then return end
    if isMatchComplete then
        scoreboardPanel.namesButtonTrigger:Show()
    else
        scoreboardPanel.namesButtonTrigger:Hide()
    end
end

local function updateAllButtonVisibility()
    if PVPMatchScoreboard then updateButtonVisibility(PVPMatchScoreboard) end
    if PVPMatchResults then updateButtonVisibility(PVPMatchResults) end
end

-- Attach a user trigger action button onto an existing match panel to invoke extraction because the default UI offers no export action

local function createNamesButton(scoreboardPanel)
    if not scoreboardPanel or scoreboardPanel.namesButtonTrigger then return end

    local interactionContent = scoreboardPanel.Content or scoreboardPanel.content
    if not interactionContent then return end

    local interactionButton = CopyAllTheNames.createActionButton(interactionContent, "Player Names", 120, function()
        if CopyAllTheNames_NamesDialog.IsShown() then
            CopyAllTheNames_NamesDialog.Hide()
            return
        end
        showWhenDataReady()
    end, 25)

    interactionButton:SetPoint("BOTTOMRIGHT", interactionContent, "BOTTOMRIGHT", -10, 10)

    scoreboardPanel:HookScript("OnShow", function()
        if isMatchComplete then
            RequestBattlefieldScoreData()
        end
        updateButtonVisibility(scoreboardPanel)
    end)

    scoreboardPanel.namesButtonTrigger = interactionButton

    -- Hide by default until match is confirmed complete
    if not isMatchComplete then
        interactionButton:Hide()
    end
end

-- Apply UI adaptations to all supported scoreboard variants to hook the player view because retail WoW switches panel types conditionally

local function setupScoreboardHooks()
    if PVPMatchScoreboard then createNamesButton(PVPMatchScoreboard) end
    if PVPMatchResults then createNamesButton(PVPMatchResults) end
end

-- Intercept PvP phase transitions to manage button visibility and data collection because score data is only safe to access after match ends

local eventListenerFrame = CreateFrame("Frame")

eventListenerFrame:RegisterEvent("ADDON_LOADED")
eventListenerFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
eventListenerFrame:RegisterEvent("PVP_MATCH_COMPLETE")
eventListenerFrame:RegisterEvent("PVP_MATCH_ACTIVE")
eventListenerFrame:RegisterEvent("PVP_MATCH_INACTIVE")
eventListenerFrame:RegisterEvent("PLAYER_JOINED_PVP_MATCH")

eventListenerFrame:SetScript("OnEvent", function(_, dispatchedEvent, matchedAddon)
    if dispatchedEvent == "ADDON_LOADED" and matchedAddon == "Blizzard_PVPUI" then
        setupScoreboardHooks()

        if PVPMatchScoreboard then
            PVPMatchScoreboard:HookScript("OnShow", function() createNamesButton(PVPMatchScoreboard) end)
        end

        if PVPMatchResults then
            PVPMatchResults:HookScript("OnShow", function() createNamesButton(PVPMatchResults) end)
        end

    elseif dispatchedEvent == "PVP_MATCH_ACTIVE" or dispatchedEvent == "PLAYER_JOINED_PVP_MATCH" then
        isMatchComplete = false
        updateAllButtonVisibility()
        CopyAllTheNames_NamesDialog.Hide()

    elseif dispatchedEvent == "PVP_MATCH_INACTIVE" then
        isMatchComplete = false
        updateAllButtonVisibility()

    elseif dispatchedEvent == "PVP_MATCH_COMPLETE" then
        isMatchComplete = true
        RequestBattlefieldScoreData()
        updateAllButtonVisibility()

    elseif dispatchedEvent == "UPDATE_BATTLEFIELD_SCORE" then
        if not isMatchComplete then return end

        if isPendingShow then
            isPendingShow = false
            CopyAllTheNames_NamesDialog.Show(collectPlayerNames())
        else
            refreshPlayerList()
        end
    end
end)

-- Execute the binding setup preemptively to capture immediately available structures because load order may outpace our frame initialization

setupScoreboardHooks()
