-- Show scrollable name list dialog on PvP scoreboards to display all player names because scoreboard has no bulk copy option

local namesDialog

-- Show or toggle scrollable names dialog to display collected player names because WoW has no native bulk name copy

local function ShowNamesDialog(names)
    if namesDialog and namesDialog:IsShown() then
        namesDialog:Hide()
        return
    end
    if namesDialog then
        namesDialog.input:SetText(table.concat(names, "\n"))
        namesDialog.input:SetCursorPosition(0)
        namesDialog:Show()
        return
    end

    local dialog = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(500, 400)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetFrameLevel(1000)
    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dialog.title:SetPoint("TOP", dialog.TitleBg, "TOP", 0, -5)
    dialog.title:SetText("Player Names")
    local scrollFrame = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", dialog, "TOPLEFT", 12, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -30, 50)
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetWidth(scrollFrame:GetWidth() - 20)
    editBox:SetHeight(5000)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function() dialog:Hide() end)
    scrollFrame:SetScrollChild(editBox)
    editBox:SetText(table.concat(names, "\n"))
    editBox:SetCursorPosition(0)

    dialog.input = editBox
    namesDialog = dialog
    dialog:Show()
end

-- Store ShowNamesDialog in global addon table to share with Auction module because both features need the same dialog

CopyAllTheNames_NamesDialog = {
    Show = ShowNamesDialog,
    Hide = function() if namesDialog then namesDialog:Hide() namesDialog = nil end end,
}

-- Extract player names from scoreboard scroll children to build copyable list because the UI only shows names inline

local function ExtractNames(contentFrame, callback)
    if not contentFrame then callback({}) return end
    local names, found = {}, {}
    local ignore = { Name = true, Deaths = true, All = true, Progress = true }
    local scrollBox = contentFrame.scrollBox or contentFrame.ScrollBox
    if not scrollBox or not scrollBox.ScrollTarget then callback({}) return end
    for _, child in ipairs({ scrollBox.ScrollTarget:GetChildren() }) do
        if child then
            for _, grandChild in ipairs({ child:GetChildren() }) do
                if grandChild and grandChild.text and type(grandChild.text) == "table" and grandChild.text.GetText then
                    local text = tostring(grandChild.text:GetText())
                    if text and text ~= "" and not ignore[text] and not found[text] and not text:match("%d") then
                        found[text] = true
                        names[#names + 1] = text
                    end
                end
            end
        end
    end
    callback(names)
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
        C_Timer.After(0.2, function()
            ExtractNames(contentFrame, function(names)
                if #names > 0 then ShowNamesDialog(names) end
            end)
        end)
    end)
    panel.namesBtn = button
end

-- Setup scoreboard buttons and hook OnShow to handle late frame creation because PvP frames load lazily via Blizzard_PVPUI

local function SetupScoreboard()
    if PVPMatchScoreboard then CreateNamesButton(PVPMatchScoreboard) end
    if PVPMatchResults then CreateNamesButton(PVPMatchResults) end
end

local battlegroundFrame = CreateFrame("Frame")
battlegroundFrame:RegisterEvent("ADDON_LOADED")
battlegroundFrame:SetScript("OnEvent", function(_, _, addon)
    if addon == "Blizzard_PVPUI" then
        SetupScoreboard()
        if PVPMatchScoreboard then
            PVPMatchScoreboard:HookScript("OnShow", function() CreateNamesButton(PVPMatchScoreboard) end)
        end
        if PVPMatchResults then
            PVPMatchResults:HookScript("OnShow", function() CreateNamesButton(PVPMatchResults) end)
        end
    end
end)

SetupScoreboard()
