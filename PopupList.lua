-- Initialize global namespace for the addon to share functions between modules because the addon uses multiple separate Lua files

SuperContact = SuperContact or {}

-- Declare local variables for UI components and row pooling to manage state because frames should be reused avoiding memory leaks
local namesDialog
local rowPool = {}
local copyPopup
local currentNames = {}

-- Define consistent row height for the scrollable list to calculate offsets because dynamically sizing rows is inefficient
local rowHeight = 34

-- Define backdrop configuration for tooltips and dialogs to ensure consistent styling because default frame borders look outdated
local tooltipBackdrop = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

-- Apply the dark tooltip style to a given frame to match modern UI aesthetics because standard dialog backgrounds are too bright
local function applyTooltipStyle(frame)
    frame:SetBackdrop(tooltipBackdrop)
    frame:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.9)
end

-- Force button textures to use the classic styling atlas to maintain visual coherence because the UI mixes old and new widget styles
local function applyClassicButtonStyle(buttonFrame)
    local normalTexture = buttonFrame:GetNormalTexture()
    local pushedTexture = buttonFrame:GetPushedTexture()
    local highlightTexture = buttonFrame:GetHighlightTexture()
    local disabledTexture = buttonFrame:GetDisabledTexture()

    if normalTexture then normalTexture:SetAtlas("UI-Panel-Button-Up", true) end
    if pushedTexture then pushedTexture:SetAtlas("UI-Panel-Button-Down", true) end
    if highlightTexture then highlightTexture:SetAtlas("UI-Panel-Button-Highlight", true) end
    if disabledTexture then disabledTexture:SetAtlas("UI-Panel-Button-Disabled", true) end

    if normalTexture then normalTexture:SetTexCoord(0, 1, 0, 1) end
    if pushedTexture then pushedTexture:SetTexCoord(0, 1, 0, 1) end

    buttonFrame:GetFontString():SetTextColor(1, 0.82, 0)
end

-- Create a standard action button with the classic style applied to simplify UI creation because writing this logic inline clutters layouts
local function createActionButton(parentFrame, labelText, buttonWidth, clickHandler, buttonHeight)
    local buttonFrame = CreateFrame("Button", nil, parentFrame, "UIPanelButtonTemplate")

    buttonFrame:SetSize(buttonWidth, buttonHeight or 22)
    buttonFrame:SetText(labelText)
    buttonFrame:SetScript("OnClick", clickHandler)

    applyClassicButtonStyle(buttonFrame)

    return buttonFrame
end

-- Create a subtle horizontal line texture to divide sections visually because floating elements without borders lack grouping
local function createSeparator(parentFrame, textureLayer, anchorFrom, anchorTo, verticalOffset)
    local separatorLine = parentFrame:CreateTexture(nil, textureLayer or "OVERLAY")

    separatorLine:SetHeight(1)
    separatorLine:SetPoint(anchorFrom, parentFrame, anchorFrom, 8, verticalOffset)
    separatorLine:SetPoint(anchorTo, parentFrame, anchorTo, -8, verticalOffset)
    separatorLine:SetColorTexture(0.8, 0.8, 0.8, 0.15)

    return separatorLine
end

-- Measure the width of the longest action button label to size all row buttons uniformly because misaligned interface buttons look unprofessional
local buttonPadding = 20
local rowButtonWidth = (function()
    local probe = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    probe:SetText("Whisper")

    local width = probe:GetStringWidth() + buttonPadding

    probe:Hide()

    return math.max(width, 70)
end)()

-- Open a text input dialog framing the provided string to facilitate copying because the user cannot highlight standard font strings
function SuperContact.openCopyPopup(playerName)
    if not copyPopup then
        copyPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        copyPopup:SetSize(300, 110)
        copyPopup:SetPoint("CENTER")
        copyPopup:SetFrameStrata("TOOLTIP")
        copyPopup:SetMovable(true)
        copyPopup:EnableMouse(true)
        copyPopup:RegisterForDrag("LeftButton")
        copyPopup:SetScript("OnDragStart", copyPopup.StartMoving)
        copyPopup:SetScript("OnDragStop", copyPopup.StopMovingOrSizing)

        applyTooltipStyle(copyPopup)

        local titleText = copyPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("TOP", copyPopup, "TOP", 0, -10)
        titleText:SetText("Copy Player Name")

        local closeButton = CreateFrame("Button", nil, copyPopup, "UIPanelCloseButton")
        closeButton:SetSize(24, 24)
        closeButton:SetPoint("TOPRIGHT", copyPopup, "TOPRIGHT", 4, 4)
        closeButton:SetFrameLevel(copyPopup:GetFrameLevel() + 10)
        closeButton:SetScript("OnClick", function() copyPopup:Hide() end)

        createSeparator(copyPopup, "OVERLAY", "TOPLEFT", "TOPRIGHT", -26)
        createSeparator(copyPopup, "OVERLAY", "BOTTOMLEFT", "BOTTOMRIGHT", 22)

        local editBox = CreateFrame("EditBox", nil, copyPopup, "InputBoxTemplate")
        editBox:SetSize(260, 24)
        editBox:SetPoint("CENTER", copyPopup, "CENTER", 0, -2)
        editBox:SetAutoFocus(true)
        editBox:SetScript("OnEscapePressed", function() copyPopup:Hide() end)
        editBox:SetScript("OnEnterPressed", function() copyPopup:Hide() end)

        editBox:SetScript("OnKeyDown", function(_, keyPress)
            if keyPress == "C" and (IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())) then
                C_Timer.After(0, function() copyPopup:Hide() end)
            end
        end)

        copyPopup.editBox = editBox

        local hintText = copyPopup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hintText:SetPoint("BOTTOM", copyPopup, "BOTTOM", 0, 8)
        hintText:SetText("Ctrl + C (Windows)  |  Cmd + C (Mac)")
        hintText:SetTextColor(1, 1, 1, 1)
    end

    copyPopup.editBox:SetText(playerName)
    copyPopup.editBox:HighlightText()
    copyPopup:Show()
end

-- Check whether a battleground is still in progress to prevent whispering tainted names because score data is secret during active matches
local function isMatchStillActive()
    local isInBattlefield = C_PvP and C_PvP.IsBattleground and C_PvP.IsBattleground()

    if not isInBattlefield then return false end

    return GetBattlefieldWinner() == nil
end

-- Warn the user to wait until the match ends to prevent taint errors because Blizzard restricts name access during active PvP
local function printMatchActiveWarning()
    print("|cffff9900SuperContact:|r Match is still active. Wait until it ends to whisper players.")
end

-- Define slash command to whisper all collected names to support bulk communication because manually whispering list members is slow
SLASH_SUPERCONTACT_WHISPERALL1 = "/whisperall"
SlashCmdList["SUPERCONTACT_WHISPERALL"] = function(chatMessage)
    if not chatMessage or chatMessage == "" then
        print("|cffff9900SuperContact:|r Usage: /whisperall <message>")
        return
    end

    if isMatchStillActive() then
        printMatchActiveWarning()
        return
    end

    if #currentNames == 0 then
        print("|cffff9900SuperContact:|r No players in the current list.")
        return
    end

    -- Defer each whisper into a separate timer callback to break the taint chain because synchronous calls taint Blizzard's chat history tables
    for nameIndex, targetPlayerName in ipairs(currentNames) do
        C_Timer.After(nameIndex * 0.1, function()
            SendChatMessage(chatMessage, "WHISPER", nil, targetPlayerName)
        end)
    end
end

-- Store generic handlers for list interaction buttons to populate row actions dynamically because duplicating button configuration code is error prone
local actionDefinitions = {
    { label = "Copy", handler = function(targetName) SuperContact.openCopyPopup(targetName) end },
    { label = "Whisper", handler = function(targetName)
        if isMatchStillActive() then
            printMatchActiveWarning()
            return
        end
        ChatFrame_OpenChat("/w " .. targetName .. " ", DEFAULT_CHAT_FRAME)
    end },
    { label = "Invite", handler = function(targetName)
        if isMatchStillActive() then
            printMatchActiveWarning()
            return
        end
        pcall(C_PartyInfo.ConfirmInviteUnit, targetName)
    end, isCombatLocked = true },
}

-- Create a new reusable list row containing a name and interaction buttons to display entries because the dialog needs to handle variable lengths
local function createPlayerRow(scrollChildFrame, rowIndex)
    local playerRow = CreateFrame("Frame", nil, scrollChildFrame)

    playerRow:SetSize(scrollChildFrame:GetWidth(), rowHeight)
    playerRow:SetPoint("TOPLEFT", scrollChildFrame, "TOPLEFT", 0, -(rowIndex - 1) * rowHeight)

    local rowSeparator = playerRow:CreateTexture(nil, "ARTWORK")
    rowSeparator:SetHeight(1)
    rowSeparator:SetPoint("BOTTOMLEFT", playerRow, "BOTTOMLEFT", 4, 0)
    rowSeparator:SetPoint("BOTTOMRIGHT", playerRow, "BOTTOMRIGHT", -4, 0)
    rowSeparator:SetColorTexture(0.8, 0.8, 0.8, 0.08)

    local nameLabel = playerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameLabel:SetPoint("LEFT", playerRow, "LEFT", 8, 0)
    nameLabel:SetJustifyH("LEFT")

    playerRow.nameLabel = nameLabel
    playerRow.actionButtons = {}

    local buttonSpacing = 4

    for buttonIndex = #actionDefinitions, 1, -1 do
        local definition = actionDefinitions[buttonIndex]
        local horizontalOffset = (#actionDefinitions - buttonIndex) * (rowButtonWidth + buttonSpacing)

        local actionButton = createActionButton(playerRow, definition.label, rowButtonWidth, function()
            if definition.isCombatLocked and InCombatLockdown() then return end
            if playerRow.playerName then definition.handler(playerRow.playerName) end
        end)

        actionButton:SetPoint("RIGHT", playerRow, "RIGHT", -horizontalOffset, 0)
        playerRow.actionButtons[buttonIndex] = actionButton
    end

    return playerRow
end

-- Populate the scroll list with collected names reusing frame object references to render the interface efficiently because making frames each time hurts performance
local function updateNamesDialog(playerNamesList)
    if not namesDialog then return end

    currentNames = playerNamesList

    local scrollChild = namesDialog.scrollChild
    local listCount = #playerNamesList

    for entryIndex = 1, listCount do
        local playerRow = rowPool[entryIndex]

        if not playerRow then
            playerRow = createPlayerRow(scrollChild, entryIndex)
            rowPool[entryIndex] = playerRow
        end

        playerRow.playerName = playerNamesList[entryIndex]
        playerRow.nameLabel:SetText(playerNamesList[entryIndex])
        playerRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(entryIndex - 1) * rowHeight)
        playerRow:Show()
    end

    for unusedIndex = listCount + 1, #rowPool do
        rowPool[unusedIndex]:Hide()
    end

    scrollChild:SetHeight(math.max(listCount * rowHeight, 1))
end

-- Initialize and display the main interface containing collected names to provide bulk actions because viewing multiple scraped names requires a dedicated window
local function showNamesDialog(playerNamesList)
    if not namesDialog then
        local mainDialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")

        mainDialog:SetSize(450, 420)
        mainDialog:SetPoint("CENTER")
        mainDialog:SetMovable(true)
        mainDialog:EnableMouse(true)
        mainDialog:RegisterForDrag("LeftButton")
        mainDialog:SetScript("OnDragStart", mainDialog.StartMoving)
        mainDialog:SetScript("OnDragStop", mainDialog.StopMovingOrSizing)
        mainDialog:SetFrameStrata("FULLSCREEN_DIALOG")
        mainDialog:SetFrameLevel(1000)

        applyTooltipStyle(mainDialog)

        local titleText = mainDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("TOP", mainDialog, "TOP", 0, -10)
        titleText:SetText("Player Names")

        local closeButton = CreateFrame("Button", nil, mainDialog, "UIPanelCloseButton")
        closeButton:SetSize(24, 24)
        closeButton:SetPoint("TOPRIGHT", mainDialog, "TOPRIGHT", 4, 4)
        closeButton:SetFrameLevel(mainDialog:GetFrameLevel() + 10)
        closeButton:SetScript("OnClick", function() mainDialog:Hide() end)

        createSeparator(mainDialog, "OVERLAY", "TOPLEFT", "TOPRIGHT", -26)
        createSeparator(mainDialog, "OVERLAY", "BOTTOMLEFT", "BOTTOMRIGHT", 40)

        local dialogScrollFrame = CreateFrame("ScrollFrame", nil, mainDialog, "UIPanelScrollFrameTemplate")
        dialogScrollFrame:SetPoint("TOPLEFT", mainDialog, "TOPLEFT", 8, -32)
        dialogScrollFrame:SetPoint("BOTTOMRIGHT", mainDialog, "BOTTOMRIGHT", -26, 46)

        local dialogScrollChild = CreateFrame("Frame", nil, dialogScrollFrame)
        dialogScrollChild:SetWidth(dialogScrollFrame:GetWidth())
        dialogScrollChild:SetHeight(1)
        dialogScrollFrame:SetScrollChild(dialogScrollChild)

        mainDialog.scrollFrame = dialogScrollFrame
        mainDialog.scrollChild = dialogScrollChild

        local whisperAllButton = createActionButton(mainDialog, "Whisper All", 120, function()
            if #currentNames == 0 then return end
            ChatFrame_OpenChat("/whisperall ", DEFAULT_CHAT_FRAME)
        end)
        whisperAllButton:SetPoint("BOTTOM", mainDialog, "BOTTOM", 0, 12)

        namesDialog = mainDialog
    end

    updateNamesDialog(playerNamesList)
    namesDialog:Show()
end

-- Expose UI generation routines and main dialog references publicly to allow other files to attach scraping hooks because logic is divided into feature modules
SuperContact.applyClassicButtonStyle = applyClassicButtonStyle
SuperContact.createActionButton = createActionButton

SuperContact_NamesDialog = {
    Show = showNamesDialog,
    Hide = function() if namesDialog then namesDialog:Hide() end end,
    Update = updateNamesDialog,
    IsShown = function() return namesDialog and namesDialog:IsShown() end,
}
