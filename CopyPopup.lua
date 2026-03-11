-- Shared UI primitives, copy popup, and scrollable names dialog

CopyAllTheNames = CopyAllTheNames or {}

local namesDialog
local rowPool = {}
local copyPopup

local ROW_HEIGHT = 28

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

local function OpenCopyPopup(name)
    if not copyPopup then
        copyPopup = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
        copyPopup:SetSize(280, 60)
        copyPopup:SetPoint("CENTER")
        copyPopup:SetFrameStrata("TOOLTIP")
        copyPopup:SetMovable(true)
        copyPopup:EnableMouse(true)
        copyPopup:RegisterForDrag("LeftButton")
        copyPopup:SetScript("OnDragStart", copyPopup.StartMoving)
        copyPopup:SetScript("OnDragStop",  copyPopup.StopMovingOrSizing)

        local editBox = CreateFrame("EditBox", nil, copyPopup, "InputBoxTemplate")
        editBox:SetSize(240, 24)
        editBox:SetPoint("CENTER", copyPopup, "CENTER", 0, -6)
        editBox:SetAutoFocus(true)
        editBox:SetScript("OnEscapePressed", function() copyPopup:Hide() end)
        editBox:SetScript("OnEnterPressed",  function() copyPopup:Hide() end)
        editBox:SetScript("OnKeyDown", function(_, key)
            if key == "C" and (IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())) then
                C_Timer.After(0, function() copyPopup:Hide() end)
            end
        end)

        copyPopup.editBox = editBox
    end

    copyPopup.editBox:SetText(name)
    copyPopup.editBox:HighlightText()
    copyPopup:Show()
end

-- Row definitions are declared once here; combatLocked avoids string comparison at runtime
local ROW_DEFINITIONS = {
    { label = "Copy",    handler = function(n) OpenCopyPopup(n) end },
    { label = "Whisper", handler = function(n) pcall(ChatFrame_OpenChat, "/w " .. n .. " ", DEFAULT_CHAT_FRAME) end },
    { label = "Invite",  handler = function(n) pcall(C_PartyInfo.ConfirmInviteUnit, n) end, combatLocked = true },
}

local function CreatePlayerRow(scrollChild, rowIndex)
    local row = CreateFrame("Frame", nil, scrollChild)
    row:SetSize(scrollChild:GetWidth(), ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(rowIndex - 1) * ROW_HEIGHT)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 5, 0)
    label:SetJustifyH("LEFT")
    row.nameLabel = label

    local btnWidth   = 60
    local btnSpacing = 3

    row.actionButtons = {}

    for i = #ROW_DEFINITIONS, 1, -1 do
        local def = ROW_DEFINITIONS[i]
        local offset = (#ROW_DEFINITIONS - i) * (btnWidth + btnSpacing)
        local btn = CreateActionButton(row, def.label, btnWidth, function()
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
    local scrollChild = namesDialog.scrollChild
    local count = #names

    for i = 1, count do
        local row = rowPool[i]
        if not row then
            row = CreatePlayerRow(scrollChild, i)
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
        local dialog = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
        dialog:SetSize(450, 400)
        dialog:SetPoint("CENTER")
        dialog:SetMovable(true)
        dialog:EnableMouse(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop",  dialog.StopMovingOrSizing)
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog:SetFrameLevel(1000)

        local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", dialog.TitleBg, "TOP", 0, -5)
        title:SetText("Player Names")

        local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT",     dialog, "TOPLEFT",      12,  -30)
        scrollFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -30,   10)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(scrollFrame:GetWidth() - 20)
        scrollChild:SetHeight(1)
        scrollFrame:SetScrollChild(scrollChild)

        dialog.scrollFrame = scrollFrame
        dialog.scrollChild = scrollChild
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
