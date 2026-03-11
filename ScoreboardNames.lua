-- Battleground scoreboard player list integration

local issecretvalue = issecretvalue or function() return false end

local pendingShow = false

local function CollectPlayerNames()
    local names      = {}
    local foundNames = {}

    for i = 1, GetNumBattlefieldScores() do
        local info = C_PvP.GetScoreInfo(i)
        if info
        and info.name
        and not issecretvalue(info.name)
        and info.name ~= ""
        then
            local name = tostring(info.name)
            if not foundNames[name] then
                foundNames[name] = true
                names[#names + 1] = name
            end
        end
    end

    return names
end

local function RefreshPlayerList()
    if not CopyAllTheNames_NamesDialog.IsShown() then return end
    local names = CollectPlayerNames()
    if #names > 0 then
        CopyAllTheNames_NamesDialog.Update(names)
    end
end

local function ShowWhenReady()
    local names = CollectPlayerNames()
    if #names > 0 then
        CopyAllTheNames_NamesDialog.Show(names)
        return
    end

    pendingShow = true
    RequestBattlefieldScoreData()

    C_Timer.After(2.0, function()
        if not pendingShow then return end
        pendingShow = false
        CopyAllTheNames_NamesDialog.Show(CollectPlayerNames())
    end)
end

local function CreateNamesButton(panel)
    if not panel or panel.namesBtn then return end
    local content = panel.Content or panel.content
    if not content then return end

    local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btn:SetSize(120, 25)
    btn:SetText("Player Names")
    btn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 10)
    CopyAllTheNames.ApplyClassicButtonStyle(btn)

    btn:SetScript("OnClick", function()
        if CopyAllTheNames_NamesDialog.IsShown() then
            CopyAllTheNames_NamesDialog.Hide()
            return
        end
        ShowWhenReady()
    end)

    -- Pre-fetch score data the moment the panel is shown so it is
    -- warm before the user clicks the button
    panel:HookScript("OnShow", function()
        RequestBattlefieldScoreData()
    end)

    panel.namesBtn = btn
end

local function SetupScoreboard()
    if PVPMatchScoreboard then CreateNamesButton(PVPMatchScoreboard) end
    if PVPMatchResults    then CreateNamesButton(PVPMatchResults) end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
frame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == "Blizzard_PVPUI" then
        SetupScoreboard()
        if PVPMatchScoreboard then
            PVPMatchScoreboard:HookScript("OnShow", function() CreateNamesButton(PVPMatchScoreboard) end)
        end
        if PVPMatchResults then
            PVPMatchResults:HookScript("OnShow", function() CreateNamesButton(PVPMatchResults) end)
        end
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        if pendingShow then
            pendingShow = false
            CopyAllTheNames_NamesDialog.Show(CollectPlayerNames())
        else
            RefreshPlayerList()
        end
    end
end)

SetupScoreboard()
