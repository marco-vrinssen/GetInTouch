-- Provide shared UI components for name listing, copying, and bulk whisper across modules

GetInTouch = GetInTouch or {}

-- Declare local state for UI frames and pooled rows to manage lifecycle across reuse

local namesDialog
local rowPool = {}
local copyPopup
local currentNames = {}

-- Define constant row height for the scroll list to calculate vertical offsets

local rowHeight = 34

-- Define backdrop config for all dialogs to enforce consistent dark-frame styling

local tooltipBackdrop = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true,
    tileSize = 8,
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
}

-- Apply dark backdrop to a frame to match the addon's visual theme

local function applyTooltipStyle(frame)
    frame:SetBackdrop(tooltipBackdrop)
    frame:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.9)
end

-- Remap all button textures to classic atlas entries to unify widget style

local function applyClassicButtonStyle(btn)
    local normal   = btn:GetNormalTexture()
    local pushed   = btn:GetPushedTexture()
    local highlight = btn:GetHighlightTexture()
    local disabled = btn:GetDisabledTexture()

    if normal    then normal:SetAtlas("UI-Panel-Button-Up", true)        end
    if pushed    then pushed:SetAtlas("UI-Panel-Button-Down", true)      end
    if highlight then highlight:SetAtlas("UI-Panel-Button-Highlight", true) end
    if disabled  then disabled:SetAtlas("UI-Panel-Button-Disabled", true) end

    if normal  then normal:SetTexCoord(0, 1, 0, 1)  end
    if pushed  then pushed:SetTexCoord(0, 1, 0, 1)  end

    btn:GetFontString():SetTextColor(1, 0.82, 0)
end

-- Create a styled action button parented to a frame to reduce inline layout noise

local function createActionButton(parent, label, width, onClick, height)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")

    btn:SetSize(width, height or 22)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)

    applyClassicButtonStyle(btn)

    return btn
end

-- Create a hairline separator texture anchored within a frame to divide content sections

local function createSeparator(parent, layer, anchorA, anchorB, yOffset)
    local line = parent:CreateTexture(nil, layer or "OVERLAY")

    line:SetHeight(1)
    line:SetPoint(anchorA, parent, anchorA, 8, yOffset)
    line:SetPoint(anchorB, parent, anchorB, -8, yOffset)
    line:SetColorTexture(0.8, 0.8, 0.8, 0.15)

    return line
end

-- Measure the widest row-button label once to size all buttons uniformly

local btnPadding = 20
local rowBtnWidth = (function()
    local probe = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    probe:SetText("Whisper")

    local w = probe:GetStringWidth() + btnPadding

    probe:Hide()

    return math.max(w, 70)
end)()

-- Open a draggable copy popup for a player name to allow text selection and copy

function GetInTouch.openCopyPopup(playerName)
    if not copyPopup then
        local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")

        frame:SetSize(300, 110)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("TOOLTIP")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        applyTooltipStyle(frame)

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", frame, "TOP", 0, -10)
        title:SetText("Copy Player Name")

        local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        closeBtn:SetSize(24, 24)
        closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 4)
        closeBtn:SetFrameLevel(frame:GetFrameLevel() + 10)
        closeBtn:SetScript("OnClick", function() frame:Hide() end)

        createSeparator(frame, "OVERLAY", "TOPLEFT", "TOPRIGHT", -26)
        createSeparator(frame, "OVERLAY", "BOTTOMLEFT", "BOTTOMRIGHT", 22)

        local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        editBox:SetSize(260, 24)
        editBox:SetPoint("CENTER", frame, "CENTER", 0, -2)
        editBox:SetAutoFocus(true)
        editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
        editBox:SetScript("OnEnterPressed",  function() frame:Hide() end)
        editBox:SetScript("OnKeyDown", function(_, key)
            if key == "C" and (IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())) then
                C_Timer.After(0, function() frame:Hide() end)
            end
        end)

        local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 8)
        hint:SetText("Ctrl + C (Windows)  |  Cmd + C (Mac)")
        hint:SetTextColor(1, 1, 1, 1)

        frame.editBox = editBox
        copyPopup = frame
    end

    copyPopup.editBox:SetText(playerName)
    copyPopup.editBox:HighlightText()
    copyPopup:Show()
end

-- Check whether the player is in an active battleground to gate taint-sensitive actions

local function isBgActive()
    if not (C_PvP and C_PvP.IsBattleground and C_PvP.IsBattleground()) then return false end
    return GetBattlefieldWinner() == nil
end

-- Print a standardised warning when an action is blocked by an active match

local function warnBgActive()
    print("|cffff9900GetInTouch:|r Match is still active. Wait until it ends to whisper players.")
end

-- Register /whisperall to broadcast a message to every collected name via deferred timers

SLASH_GETINTOUCH_WHISPERALL1 = "/whisperall"
SlashCmdList["GETINTOUCH_WHISPERALL"] = function(msg)
    if not msg or msg == "" then
        print("|cffff9900GetInTouch:|r Usage: /whisperall <message>")
        return
    end

    if isBgActive() then warnBgActive() return end

    if #currentNames == 0 then
        print("|cffff9900GetInTouch:|r No players in the current list.")
        return
    end

    -- Stagger each whisper by 0.1 s to avoid tainting Blizzard's chat history tables
    for idx, name in ipairs(currentNames) do
        C_Timer.After(idx * 0.1, function()
            SendChatMessage(msg, "WHISPER", nil, name)
        end)
    end
end

-- Define per-row action definitions to drive button creation and click dispatch

local actionDefs = {
    {
        label   = "Copy",
        handler = function(name) GetInTouch.openCopyPopup(name) end,
    },
    {
        label   = "Whisper",
        handler = function(name)
            if isBgActive() then warnBgActive() return end
            ChatFrame_OpenChat("/w " .. name .. " ", DEFAULT_CHAT_FRAME)
        end,
    },
    {
        label          = "Invite",
        isCombatLocked = true,
        handler        = function(name)
            if isBgActive() then warnBgActive() return end
            pcall(C_PartyInfo.ConfirmInviteUnit, name)
        end,
    },
}

-- Build a poolable player row frame with a name label and action buttons

local function createPlayerRow(scrollChild, rowIdx)
    local row = CreateFrame("Frame", nil, scrollChild)

    row:SetSize(scrollChild:GetWidth(), rowHeight)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(rowIdx - 1) * rowHeight)

    local sep = row:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  4, 0)
    sep:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
    sep:SetColorTexture(0.8, 0.8, 0.8, 0.08)

    local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameLabel:SetPoint("LEFT", row, "LEFT", 8, 0)
    nameLabel:SetJustifyH("LEFT")

    row.nameLabel    = nameLabel
    row.actionButtons = {}

    local btnSpacing = 4

    for i = #actionDefs, 1, -1 do
        local def    = actionDefs[i]
        local xOff   = (#actionDefs - i) * (rowBtnWidth + btnSpacing)

        local btn = createActionButton(row, def.label, rowBtnWidth, function()
            if def.isCombatLocked and InCombatLockdown() then return end
            if row.playerName then def.handler(row.playerName) end
        end)

        btn:SetPoint("RIGHT", row, "RIGHT", -xOff, 0)
        row.actionButtons[i] = btn
    end

    return row
end

-- Refresh the scroll list from a names table, reusing pooled rows to avoid frame churn

local function updateNamesDialog(namesList)
    if not namesDialog then return end

    currentNames = namesList

    local scrollChild = namesDialog.scrollChild
    local count       = #namesList

    for i = 1, count do
        local row = rowPool[i]

        if not row then
            row = createPlayerRow(scrollChild, i)
            rowPool[i] = row
        end

        row.playerName = namesList[i]
        row.nameLabel:SetText(namesList[i])
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * rowHeight)
        row:Show()
    end

    for i = count + 1, #rowPool do
        rowPool[i]:Hide()
    end

    scrollChild:SetHeight(math.max(count * rowHeight, 1))
end

-- Build and show the main names dialog, initialising it on first call

local function showNamesDialog(namesList)
    if not namesDialog then
        local dlg = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")

        dlg:SetSize(450, 420)
        dlg:SetPoint("CENTER")
        dlg:SetMovable(true)
        dlg:EnableMouse(true)
        dlg:RegisterForDrag("LeftButton")
        dlg:SetScript("OnDragStart", dlg.StartMoving)
        dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
        dlg:SetFrameStrata("FULLSCREEN_DIALOG")
        dlg:SetFrameLevel(1000)

        applyTooltipStyle(dlg)

        local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", dlg, "TOP", 0, -10)
        title:SetText("Player Names")

        local closeBtn = CreateFrame("Button", nil, dlg, "UIPanelCloseButton")
        closeBtn:SetSize(24, 24)
        closeBtn:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", 4, 4)
        closeBtn:SetFrameLevel(dlg:GetFrameLevel() + 10)
        closeBtn:SetScript("OnClick", function() dlg:Hide() end)

        createSeparator(dlg, "OVERLAY", "TOPLEFT", "TOPRIGHT", -26)
        createSeparator(dlg, "OVERLAY", "BOTTOMLEFT", "BOTTOMRIGHT", 40)

        local scrollFrame = CreateFrame("ScrollFrame", nil, dlg, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT",     dlg, "TOPLEFT",     8, -32)
        scrollFrame:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -26, 46)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(scrollFrame:GetWidth())
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)

        dlg.scrollFrame = scrollFrame
        dlg.scrollChild = scrollChild

        local whisperAllBtn = createActionButton(dlg, "Whisper All", 120, function()
            if #currentNames == 0 then return end
            ChatFrame_OpenChat("/whisperall ", DEFAULT_CHAT_FRAME)
        end)
        whisperAllBtn:SetPoint("BOTTOM", dlg, "BOTTOM", 0, 12)

        namesDialog = dlg
    end

    updateNamesDialog(namesList)
    namesDialog:Show()
end

-- Expose style helpers publicly so other modules can style their own buttons consistently

GetInTouch.applyClassicButtonStyle = applyClassicButtonStyle
GetInTouch.createActionButton      = createActionButton

-- Expose the names dialog interface so feature modules can drive it without direct frame access

GetInTouch_NamesDialog = {
    Show    = showNamesDialog,
    Hide    = function() if namesDialog then namesDialog:Hide() end end,
    Update  = updateNamesDialog,
    IsShown = function() return namesDialog and namesDialog:IsShown() end,
}
