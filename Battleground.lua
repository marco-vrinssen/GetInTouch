-- Show scrollable player list with action buttons on PvP scoreboards to enable per-player interactions because scoreboard has no bulk action options

local namesDialog
local rowPool = {}

-- Collect unique player names from battleground scoreboard to populate the player list because WoW provides no bulk name export

local function CollectPlayerNames()
    local playerNames = {}
    local foundNames = {}
    local scoreCount = GetNumBattlefieldScores()

    for scoreIndex = 1, scoreCount do
        local scoreInfo = C_PvP.GetScoreInfo(scoreIndex)

        if scoreInfo and scoreInfo.name and scoreInfo.name ~= "" then
            local cleanName = tostring(scoreInfo.name)

            if not foundNames[cleanName] then
                foundNames[cleanName] = true
                playerNames[#playerNames + 1] = cleanName
            end
        end
    end

    return playerNames
end

-- Copy player name to clipboard to enable pasting in external apps because WoW has no native name export

local function CopyPlayerName(playerName)
    pcall(CopyToClipboard, playerName)
end

-- Open whisper chat addressed to player to enable direct messaging because manually typing names is error-prone

local function WhisperPlayer(playerName)
    pcall(ChatFrame_OpenChat, "/w " .. playerName .. " ", DEFAULT_CHAT_FRAME)
end

-- Invite player to party to enable quick group forming because manually inviting from scoreboard is cumbersome

local function InvitePlayer(playerName)
    pcall(C_PartyInfo.ConfirmInviteUnit, playerName)
end

-- Target player in battleground to enable quick focusing because finding players in large groups is difficult

local function TargetPlayer(playerName)
    pcall(TargetUnit, playerName)
end

-- Add player as friend to enable post-match contact because battleground players are lost after leaving

local function AddPlayer(playerName)
    pcall(C_FriendList.AddFriend, playerName)
end

-- Create action button for player row to handle a specific interaction because each button needs consistent sizing and taint-free behavior

local function CreateActionButton(parentRow, labelText, buttonWidth, onClick)
    local actionButton = CreateFrame("Button", nil, parentRow)
    actionButton:SetSize(buttonWidth, 18)
    actionButton:SetNormalFontObject(GameFontHighlightSmall)
    actionButton:SetHighlightFontObject(GameFontHighlightSmall)

    local background = actionButton:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.15, 0.15, 0.15, 0.8)

    local highlight = actionButton:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.1)

    actionButton:SetText(labelText)
    actionButton:SetScript("OnClick", onClick)
    return actionButton
end

-- Create single player row with name and action buttons to display one player entry because each scoreboard player needs interactive controls

local function CreatePlayerRow(scrollChild, rowIndex)
    local playerRow = CreateFrame("Frame", nil, scrollChild)
    playerRow:SetSize(scrollChild:GetWidth(), 20)
    playerRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(rowIndex - 1) * 20)

    local nameLabel = playerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameLabel:SetPoint("LEFT", playerRow, "LEFT", 5, 0)
    nameLabel:SetJustifyH("LEFT")
    playerRow.nameLabel = nameLabel

    local buttonWidth = 55
    local buttonSpacing = 2
    local buttonDefinitions = {
        { label = "Copy", handler = CopyPlayerName },
        { label = "Whisper", handler = WhisperPlayer },
        { label = "Invite", handler = InvitePlayer },
        { label = "Target", handler = TargetPlayer },
        { label = "Add", handler = AddPlayer },
    }

    playerRow.actionButtons = {}

    for buttonIndex = #buttonDefinitions, 1, -1 do
        local definition = buttonDefinitions[buttonIndex]
        local reverseIndex = #buttonDefinitions - buttonIndex
        local actionButton = CreateActionButton(playerRow, definition.label, buttonWidth, function()
            if InCombatLockdown() then return end
            local currentName = playerRow.playerName
            if currentName then definition.handler(currentName) end
        end)
        actionButton:SetPoint("RIGHT", playerRow, "RIGHT", -(reverseIndex * (buttonWidth + buttonSpacing)), 0)
        playerRow.actionButtons[buttonIndex] = actionButton
    end

    return playerRow
end

-- Show or toggle scrollable player list dialog to display collected player names with action buttons because WoW has no native bulk player interaction

local function ShowNamesDialog(playerNames)
    if namesDialog and namesDialog:IsShown() then
        namesDialog:Hide()
        return
    end

    if not namesDialog then
        local dialog = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
        dialog:SetSize(550, 400)
        dialog:SetPoint("CENTER")
        dialog:SetMovable(true)
        dialog:EnableMouse(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog:SetFrameLevel(1000)

        local titleLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        titleLabel:SetPoint("TOP", dialog.TitleBg, "TOP", 0, -5)
        titleLabel:SetText("Player Names")

        local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", dialog, "TOPLEFT", 12, -30)
        scrollFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -30, 10)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(scrollFrame:GetWidth() - 20)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)

        dialog.scrollFrame = scrollFrame
        dialog.scrollChild = scrollChild
        namesDialog = dialog
    end

    local scrollChild = namesDialog.scrollChild
    local nameCount = #playerNames

    -- Create or reuse row frames from pool to avoid frame leaks because refreshing the list repeatedly would waste memory

    for rowIndex = 1, nameCount do
        local playerRow = rowPool[rowIndex]

        if not playerRow then
            playerRow = CreatePlayerRow(scrollChild, rowIndex)
            rowPool[rowIndex] = playerRow
        end

        playerRow.playerName = playerNames[rowIndex]
        playerRow.nameLabel:SetText(playerNames[rowIndex])
        playerRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(rowIndex - 1) * 20)
        playerRow:Show()
    end

    -- Hide excess row frames from previous refresh to prevent stale entries because the player count may decrease between refreshes

    for hideIndex = nameCount + 1, #rowPool do
        rowPool[hideIndex]:Hide()
    end

    scrollChild:SetHeight(math.max(nameCount * 20, 1))
    namesDialog:Show()
end

-- Store ShowNamesDialog in global addon table to share with Auction module because both features need the same dialog

CopyAllTheNames_NamesDialog = {
    Show = ShowNamesDialog,
    Hide = function() if namesDialog then namesDialog:Hide() namesDialog = nil end end,
}

-- Refresh player list from scoreboard data to update the dialog with current scores because players may join or leave during the match

local function RefreshPlayerList()
    local playerNames = CollectPlayerNames()
    if #playerNames > 0 then ShowNamesDialog(playerNames) end
end

-- Create player names button on scoreboard panel to trigger name extraction because default UI has no copy all option

local function CreateNamesButton(panel)
    if not panel or panel.namesBtn then return end
    local contentFrame = panel.Content or panel.content
    if not contentFrame then return end

    local button = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
    button:SetSize(120, 25)
    button:SetText("Player Names")
    button:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -10, 10)

    button:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        CopyAllTheNames_NamesDialog.Hide()
        C_Timer.After(0.2, RefreshPlayerList)
    end)

    panel.namesBtn = button
end

-- Setup scoreboard buttons and hook OnShow to handle late frame creation because PvP frames load lazily via Blizzard_PVPUI

local function SetupScoreboard()
    if PVPMatchScoreboard then CreateNamesButton(PVPMatchScoreboard) end
    if PVPMatchResults then CreateNamesButton(PVPMatchResults) end
end

-- Register events for scoreboard setup and auto-refresh to keep the list current because PvP frames load lazily and scores update dynamically

local battlegroundFrame = CreateFrame("Frame")
battlegroundFrame:RegisterEvent("ADDON_LOADED")
battlegroundFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
battlegroundFrame:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == "Blizzard_PVPUI" then
        SetupScoreboard()

        if PVPMatchScoreboard then
            PVPMatchScoreboard:HookScript("OnShow", function() CreateNamesButton(PVPMatchScoreboard) end)
        end

        if PVPMatchResults then
            PVPMatchResults:HookScript("OnShow", function() CreateNamesButton(PVPMatchResults) end)
        end
    end

    -- Auto-refresh player list when scores update to keep names current because players may join or leave mid-match

    if event == "UPDATE_BATTLEFIELD_SCORE" and namesDialog and namesDialog:IsShown() then
        RefreshPlayerList()
    end
end)

SetupScoreboard()
