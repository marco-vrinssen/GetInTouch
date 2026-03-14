-- Integrate list button into the battleground scoreboard to parse and collect player names because writing them out manually is tedious

local isSecretValueChecked = issecretvalue or function() return false end

local isPendingShow = false

-- Iterate through the battleground api to aggregate unique player names because the api doesn't offer a direct list of active combatants

local function collectPlayerNames()
    local playerNamesList = {}
    local foundNamesList = {}

    for eventIndex = 1, GetNumBattlefieldScores() do
        local scoreInformation = C_PvP.GetScoreInfo(eventIndex)

        if scoreInformation
        and scoreInformation.name
        and not isSecretValueChecked(scoreInformation.name)
        and scoreInformation.name ~= ""
        then
            local parsedName = tostring(scoreInformation.name)

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

-- Attach a user trigger action button onto an existing match panel to invoke extraction because the default UI offers no export action

local function createNamesButton(scoreboardPanel)
    if not scoreboardPanel or scoreboardPanel.namesButtonTrigger then return end

    local interactionContent = scoreboardPanel.Content or scoreboardPanel.content
    if not interactionContent then return end

    local interactionButton = CreateFrame("Button", nil, interactionContent, "UIPanelButtonTemplate")

    interactionButton:SetSize(120, 25)
    interactionButton:SetText("Player Names")
    interactionButton:SetPoint("BOTTOMRIGHT", interactionContent, "BOTTOMRIGHT", -10, 10)

    CopyAllTheNames.applyClassicButtonStyle(interactionButton)

    interactionButton:SetScript("OnClick", function()
        if CopyAllTheNames_NamesDialog.IsShown() then
            CopyAllTheNames_NamesDialog.Hide()
            return
        end
        showWhenDataReady()
    end)

    scoreboardPanel:HookScript("OnShow", function()
        RequestBattlefieldScoreData()
    end)

    scoreboardPanel.namesButtonTrigger = interactionButton
end

-- Apply UI adaptations to all supported scoreboard variants to hook the player view because retail WoW switches panel types conditionally

local function setupScoreboardHooks()
    if PVPMatchScoreboard then createNamesButton(PVPMatchScoreboard) end
    if PVPMatchResults then createNamesButton(PVPMatchResults) end
end

-- Intercept PvP phase transitions to fetch match numbers ahead of rendering because preloading data prevents empty dialog lists

local eventListenerFrame = CreateFrame("Frame")

eventListenerFrame:RegisterEvent("ADDON_LOADED")
eventListenerFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
eventListenerFrame:RegisterEvent("PVP_MATCH_COMPLETE")

eventListenerFrame:SetScript("OnEvent", function(_, dispatchedEvent, matchedAddon)
    if dispatchedEvent == "ADDON_LOADED" and matchedAddon == "Blizzard_PVPUI" then
        setupScoreboardHooks()

        if PVPMatchScoreboard then
            PVPMatchScoreboard:HookScript("OnShow", function() createNamesButton(PVPMatchScoreboard) end)
        end

        if PVPMatchResults then
            PVPMatchResults:HookScript("OnShow", function() createNamesButton(PVPMatchResults) end)
        end

    elseif dispatchedEvent == "PVP_MATCH_COMPLETE" then
        RequestBattlefieldScoreData()

    elseif dispatchedEvent == "UPDATE_BATTLEFIELD_SCORE" then
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
