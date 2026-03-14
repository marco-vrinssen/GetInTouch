-- Shared UI primitives, copy popup, and scrollable names dialog

CopyAllTheNames = CopyAllTheNames or {}

local namesDialog
local rowPool      = {}
local copyPopup
local currentNames = {}

local ROW_HEIGHT = 34

local TOOLTIP_BACKDROP = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true,
    tileSize = 8,
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function ApplyTooltipStyle(frame)
    frame:SetBackdrop(TOOLTIP_BACKDROP)
    frame:SetBackdropColor(0.06, 0.06, 0.06, 0.97)
    frame:SetBackdropBorderColor(0.8, 0.8, 0.8, 0.9)
end

local function ApplyClassicButtonStyle(btn)
    local normal    = btn:GetNormalTexture()
    local pushed    = btn:GetPushedTexture()
    local highlight = btn:GetHighlightTexture()
    local disabled  = btn:GetDisabledTexture()

    if normal    then normal:SetAtlas("UI-Panel-Button-Up", true) end
    if pushed    then pushed:SetAtlas("UI-Panel-Button-Down", true) end
    if highlight then highlight:SetAtlas("UI-Panel-Button-Highlight", true) end
    if disabled  then disabled:SetAtlas("UI-Panel-Button-Disabled", true) end

    if normal then normal:SetTexCoord(0, 1, 0, 1) end
    if pushed then pushed:SetTexCoord(0, 1, 0, 1) end

    btn:GetFontString():SetTextColor(1, 0.82, 0)
end

local function CreateActionButton(parent, label, width, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, 22)
    btn:SetText(label)
    btn:SetScript("OnClick", onClick)
    ApplyClassicButtonStyle(btn)
    return btn
end

local function CreateSeparator(parent, layer, fromPoint, toPoint, offsetY)
    local line = parent:CreateTexture(nil, layer or "OVERLAY")
    line:SetHeight(1)
    line:SetPoint(fromPoint, parent, fromPoint,  8, offsetY)
    line:SetPoint(toPoint,   parent, toPoint,   -8, offsetY)
    line:SetColorTexture(0.8, 0.8, 0.8, 0.15)
    return line
end

--------------------------------------------------------------------------------
-- Row button width — measure Whisper (widest label) and apply to all buttons
--------------------------------------------------------------------------------

local BTN_PADDING   = 20
local ROW_BTN_WIDTH = (function()
    local probe = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate")
    probe:SetText("Whisper")
    local width = probe:GetFontString():GetStringWidth() + BTN_PADDING
    probe:Hide()
    return math.max(width, 70)
end)()

--------------------------------------------------------------------------------
-- Copy popup
--------------------------------------------------------------------------------

function CopyAllTheNames.OpenCopyPopup(name)
    if not copyPopup then
        copyPopup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        copyPopup:SetSize(300, 110)
        copyPopup:SetPoint("CENTER")
        copyPopup:SetFrameStrata("TOOLTIP")
        copyPopup:SetMovable(true)
        copyPopup:EnableMouse(true)
        copyPopup:RegisterForDrag("LeftButton")
        copyPopup:SetScript("OnDragStart", copyPopup.StartMoving)
        copyPopup:SetScript("OnDragStop",  copyPopup.StopMovingOrSizing)
        ApplyTooltipStyle(copyPopup)

        local titleText = copyPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("TOP", copyPopup, "TOP", 0, -10)
        titleText:SetText("Copy Player Name")

        local closeButton = CreateFrame("Button", nil, copyPopup, "UIPanelCloseButton")
        closeButton:SetSize(24, 24)
        closeButton:SetPoint("TOPRIGHT", copyPopup, "TOPRIGHT", 4, 4)
        closeButton:SetFrameLevel(copyPopup:GetFrameLevel() + 10)
        closeButton:SetScript("OnClick", function() copyPopup:Hide() end)

        CreateSeparator(copyPopup, "OVERLAY", "TOPLEFT",    "TOPRIGHT",    -26)
        CreateSeparator(copyPopup, "OVERLAY", "BOTTOMLEFT", "BOTTOMRIGHT",  22)

        -- Edit box vertically centered between the two separators
        -- Top separator at -26 from top, bottom separator at +22 from bottom (110-22=88 from top)
        -- Mid point of zone = (26+88)/2 = 57px from top; frame center = 55px; offset = 55-57 = -2
        local editBox = CreateFrame("EditBox", nil, copyPopup, "InputBoxTemplate")
        editBox:SetSize(260, 24)
        editBox:SetPoint("CENTER", copyPopup, "CENTER", 0, -2)
        editBox:SetAutoFocus(true)
        editBox:SetScript("OnEscapePressed", function() copyPopup:Hide() end)
        editBox:SetScript("OnEnterPressed",  function() copyPopup:Hide() end)
        editBox:SetScript("OnKeyDown", function(_, key)
            if key == "C" and (IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())) then
                C_Timer.After(0, function() copyPopup:Hide() end)
            end
        end)
        copyPopup.editBox = editBox

        local hintText = copyPopup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hintText:SetPoint("BOTTOM", copyPopup, "BOTTOM", 0, 8)
        hintText:SetText("Ctrl + C (Windows)  |  Cmd + C (Mac)")
        hintText:SetTextColor(1, 1, 1, 1)
    end

    copyPopup.editBox:SetText(name)
    copyPopup.editBox:HighlightText()
    copyPopup:Show()
end

--------------------------------------------------------------------------------
-- /whisperall
--------------------------------------------------------------------------------

SLASH_COPYALLTHENAMES_WHISPERALL1 = "/whisperall"
SlashCmdList["COPYALLTHENAMES_WHISPERALL"] = function(message)
    if not message or message == "" then
        print("|cffff9900CopyAllTheNames:|r Usage: /whisperall <message>")
        return
    end
    if #currentNames == 0 then
        print("|cffff9900CopyAllTheNames:|r No players in the current list.")
        return
    end
    for _, playerName in ipairs(currentNames) do
        pcall(SendChatMessage, message, "WHISPER", nil, playerName)
    end
end

--------------------------------------------------------------------------------
-- Row definitions
--------------------------------------------------------------------------------

local ROW_DEFINITIONS = {
    { label = "Copy",    handler = function(n) CopyAllTheNames.OpenCopyPopup(n) end },
    { label = "Whisper", handler = function(n) pcall(ChatFrame_OpenChat, "/w " .. n .. " ", DEFAULT_CHAT_FRAME) end },
    { label = "Invite",  handler = function(n) pcall(C_PartyInfo.ConfirmInviteUnit, n) end, combatLocked = true },
}

local function CreatePlayerRow(scrollChild, rowIndex)
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetSize(scrollChild:GetWidth(), ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(rowIndex - 1) * ROW_HEIGHT)

    local separator = row:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(1)
    separator:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  4, 0)
    separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 0)
    separator:SetColorTexture(0.8, 0.8, 0.8, 0.08)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 8, 0)
    label:SetJustifyH("LEFT")
    row.nameLabel = label

    local btnSpacing  = 4
    row.actionButtons = {}

    for i = #ROW_DEFINITIONS, 1, -1 do
        local def    = ROW_DEFINITIONS[i]
        local offset = (#ROW_DEFINITIONS - i) * (ROW_BTN_WIDTH + btnSpacing)
        local btn    = CreateActionButton(row, def.label, ROW_BTN_WIDTH, function()
            if def.combatLocked and InCombatLockdown() then return end
            if row.playerName then def.handler(row.playerName) end
        end)
        btn:SetPoint("RIGHT", row, "RIGHT", -offset, 0)
        row.actionButtons[i] = btn
    end

    return row
end

local function UpdateNamesDialog(names)
    if not namesDialog then return end
    currentNames = names

    local scrollChild = namesDialog.scrollChild
    local count       = #names

    for i = 1, count do
        local row = rowPool[i]
        if not row then
            row        = CreatePlayerRow(scrollChild, i)
            rowPool[i] = row
        end
        row.playerName = names[i]
        row.nameLabel:SetText(names[i])
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row:Show()
    end

    for i = count + 1, #rowPool do
        rowPool[i]:Hide()
    end

    scrollChild:SetHeight(math.max(count * ROW_HEIGHT, 1))
end

local function ShowNamesDialog(names)
    if not namesDialog then
        local dialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        dialog:SetSize(450, 420)
        dialog:SetPoint("CENTER")
        dialog:SetMovable(true)
        dialog:EnableMouse(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop",  dialog.StopMovingOrSizing)
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog:SetFrameLevel(1000)
        ApplyTooltipStyle(dialog)

        local titleText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleText:SetPoint("TOP", dialog, "TOP", 0, -10)
        titleText:SetText("Player Names")

        local closeButton = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        closeButton:SetSize(24, 24)
        closeButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", 4, 4)
        closeButton:SetFrameLevel(dialog:GetFrameLevel() + 10)
        closeButton:SetScript("OnClick", function() dialog:Hide() end)

        CreateSeparator(dialog, "OVERLAY", "TOPLEFT",    "TOPRIGHT",    -26)
        CreateSeparator(dialog, "OVERLAY", "BOTTOMLEFT", "BOTTOMRIGHT",  40)

        local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT",     dialog, "TOPLEFT",      8,  -32)
        scrollFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -26,  46)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(scrollFrame:GetWidth())
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)

        dialog.scrollFrame = scrollFrame
        dialog.scrollChild = scrollChild

        local whisperAllButton = CreateActionButton(dialog, "Whisper All", 120, function()
            if #currentNames == 0 then return end
            ChatFrame_OpenChat("/whisperall ", DEFAULT_CHAT_FRAME)
        end)
        whisperAllButton:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 12)

        namesDialog = dialog
    end

    UpdateNamesDialog(names)
    namesDialog:Show()
end

-- Public interface consumed by Battleground.lua and Auction.lua
CopyAllTheNames.ApplyClassicButtonStyle = ApplyClassicButtonStyle
CopyAllTheNames.CreateActionButton      = CreateActionButton

CopyAllTheNames_NamesDialog = {
    Show    = ShowNamesDialog,
    Hide    = function() if namesDialog then namesDialog:Hide() end end,
    Update  = UpdateNamesDialog,
    IsShown = function() return namesDialog and namesDialog:IsShown() end,
}
