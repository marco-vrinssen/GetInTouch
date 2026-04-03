-- Integrate list button into the match results panel, via PvP score API, to collect player names

local pendingShow = false

-- Aggregate unique player names from the battleground score API

local function collectNames()
    local names = {}
    local seen = {}

    for idx = 1, GetNumBattlefieldScores() do
        local info = C_PvP.GetScoreInfo(idx)

        if info and info.name and info.name ~= "" and not seen[info.name] then
            seen[info.name] = true
            names[#names + 1] = info.name
        end
    end

    return names
end

-- Resolve a pending show request by displaying collected names

local function resolvePending()
    if not pendingShow then return end

    pendingShow = false
    local names = collectNames()

    if #names > 0 then
        GetInTouch_NamesDialog.Show(names)
    end
end

-- Refresh the open dialog with latest score data

local function refreshDialog()
    if not GetInTouch_NamesDialog.IsShown() then return end

    local names = collectNames()

    if #names > 0 then
        GetInTouch_NamesDialog.Update(names)
    end
end

-- Show names immediately if available, otherwise defer until score data arrives

local function showWhenReady()
    local names = collectNames()

    if #names > 0 then
        GetInTouch_NamesDialog.Show(names)
        return
    end

    pendingShow = true
    RequestBattlefieldScoreData()
    C_Timer.After(2.0, resolvePending)
end

-- Attach a trigger button onto the match results panel to invoke name extraction

local function createScoreBtn()
    if not PVPMatchResults or PVPMatchResults.namesBtn then return end

    local btn = GetInTouch.createActionButton(PVPMatchResults, "Contact Players", 120, function()
        if GetInTouch_NamesDialog.IsShown() then
            GetInTouch_NamesDialog.Hide()
            return
        end
        showWhenReady()
    end, 25)

    btn:SetPoint("LEFT", PVPMatchResults.leaveButton, "RIGHT", 10, 0)

    PVPMatchResults:HookScript("OnShow", function()
        RequestBattlefieldScoreData()
    end)

    PVPMatchResults.namesBtn = btn
end

-- Listen for score updates to resolve pending requests and refresh the open dialog

local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("ADDON_LOADED")
evtFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
evtFrame:SetScript("OnEvent", function(_, evt, arg1)
    if evt == "ADDON_LOADED" and arg1 == "Blizzard_PVPUI" then
        createScoreBtn()
    elseif evt == "UPDATE_BATTLEFIELD_SCORE" then
        if pendingShow then
            resolvePending()
        else
            refreshDialog()
        end
    end
end)
