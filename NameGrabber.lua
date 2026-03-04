-- Add copy full name to right-click menus and player name list to PvP scoreboards

local finderTags = {
    MENU_LFG_FRAME_SEARCH_ENTRY = true,
    MENU_LFG_FRAME_MEMBER_APPLY = true,
}
local playerTypes = {
    PLAYER = true, PARTY = true, RAID_PLAYER = true,
    FRIEND = true, FRIEND_OFFLINE = true, FRIEND_ONLINE = true,
    BN_FRIEND = true, SELF = true, OTHER_PLAYER = true,
    ENEMY_PLAYER = true, TARGET = true, FOCUS = true,
    GUILD = true, COMMUNITIES_GUILD_MEMBER = true,
    COMMUNITIES_MEMBER = true, COMMUNITIES_WOW_MEMBER = true,
    PVP_SCOREBOARD = true,
}

local function SplitNameRealm(full)
    if not full then return nil, nil end
    local name, realm = full:match("^([^-]+)-(.+)$")
    return name or full, realm or GetRealmName()

end

local function ResolveFinder(owner)
    if not owner then return nil, nil end
    if owner.resultID and C_LFGList then
        local result = C_LFGList.GetSearchResultInfo(owner.resultID)
        if result and result.leaderName then return SplitNameRealm(result.leaderName) end
    end
    if owner.memberIdx then
        local parent = owner:GetParent()
        if parent and parent.applicantID and C_LFGList then
            local name = C_LFGList.GetApplicantMemberInfo(parent.applicantID, owner.memberIdx)
            if name then return SplitNameRealm(name) end
        end
    end
    return nil, nil
end

local function ResolvePlayer(owner, root, ctx)
    if not ctx then
        if root and root.tag and finderTags[root.tag] then return ResolveFinder(owner) end
        return nil, nil
    end
    if ctx.name and ctx.server then return ctx.name, ctx.server end
    if ctx.which == "PVP_SCOREBOARD" and ctx.unit and C_PvP then
        local scoreInfo = C_PvP.GetScoreInfoByPlayerGuid(ctx.unit)
        if scoreInfo and scoreInfo.name then return SplitNameRealm(scoreInfo.name) end
    end
    if ctx.unit and UnitExists(ctx.unit) then
        local unitName = UnitName(ctx.unit)
        if unitName then
            local playerName, realmName = SplitNameRealm(unitName)
            return playerName, ctx.server or realmName
        end
    end
    if ctx.accountInfo and ctx.accountInfo.gameAccountInfo then
        local gameAccount = ctx.accountInfo.gameAccountInfo
        return gameAccount.characterName, gameAccount.realmName
    end
    if ctx.name then return SplitNameRealm(ctx.name) end
    if ctx.friendsList and C_FriendList then
        local friendInfo = C_FriendList.GetFriendInfoByIndex(ctx.friendsList)
        if friendInfo and friendInfo.name then return SplitNameRealm(friendInfo.name) end
    end
    if ctx.chatTarget then return SplitNameRealm(ctx.chatTarget) end
    return nil, nil
end

local function ShowCopyDialog(name)
    local dialog = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(500, 150)
    dialog:SetPoint("CENTER")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:SetFrameStrata("TOOLTIP")
    dialog:SetFrameLevel(9999)
    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dialog.title:SetPoint("TOP", dialog.TitleBg, "TOP", 0, -5)
    dialog.title:SetText("Copy Full Name")
    local input = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    input:SetSize(460, 30)
    input:SetPoint("CENTER", dialog, "CENTER", 0, 10)
    input:SetText(name or "")
    input:SetAutoFocus(true)
    input:HighlightText()
    input:SetScript("OnEscapePressed", function() dialog:Hide() end)
    input:SetScript("OnEnterPressed", function() dialog:Hide() end)
    input:SetScript("OnKeyDown", function(_, key)
        if key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
            input:HighlightText()
            input:SetFocus()
            C_Timer.After(0, function() if dialog:IsShown() then dialog:Hide() end end)
        end
    end)
    local hint = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 20)
    hint:SetText("Ctrl+C / Cmd+C to copy")
    dialog:Show()
end

local processed = {}

local function AddCopyButton(owner, root, ctx)
    if InCombatLockdown() then return end
    if not ctx then
        if not (root and root.tag and finderTags[root.tag]) then return end
    else
        if not (ctx.clubId or (ctx.which and playerTypes[ctx.which])) then return end
    end
    local name, realm = ResolvePlayer(owner, root, ctx)
    if not (name and realm and root and root.CreateButton) then return end
    local key = tostring(root) .. name .. realm
    if processed[key] then return end
    processed[key] = true
    C_Timer.After(0.5, function() processed[key] = nil end)
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton("Copy Full Name", function()
        if not InCombatLockdown() then ShowCopyDialog(name .. "-" .. realm) end
    end)
end

local menuTags = {
    "MENU_LFG_FRAME_SEARCH_ENTRY", "MENU_LFG_FRAME_MEMBER_APPLY",
    "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER",
    "MENU_UNIT_FRIEND", "MENU_UNIT_FRIEND_OFFLINE", "MENU_UNIT_FRIEND_ONLINE",
    "MENU_UNIT_BN_FRIEND", "MENU_UNIT_SELF", "MENU_UNIT_OTHER_PLAYER",
    "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS",
    "MENU_UNIT_GUILD", "MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
    "MENU_UNIT_COMMUNITIES_MEMBER", "MENU_UNIT_COMMUNITIES_WOW_MEMBER",
    "MENU_PVP_SCOREBOARD", "MENU_UNIT_PVP_SCOREBOARD",
    "MENU_BATTLEGROUND_SCOREBOARD", "MENU_CHAT_LOG_LINK", "MENU_CHAT_LOG_FRAME",
}

local function RegisterMenus()
    if not Menu or not Menu.ModifyMenu then return false end
    for _, tag in ipairs(menuTags) do
        Menu.ModifyMenu(tag, AddCopyButton)
    end
    return true
end

if not RegisterMenus() then
    local attempts = 0
    C_Timer.NewTicker(0.5, function(ticker)
        attempts = attempts + 1
        if RegisterMenus() or attempts >= 10 then ticker:Cancel() end
    end)
end

-- Show scrollable name list dialog for PvP scoreboard panels

local namesDialog

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
    local hint = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("BOTTOM", dialog, "BOTTOM", 0, 20)
    hint:SetText("Ctrl+C / Cmd+C to copy")
    dialog.input = editBox
    namesDialog = dialog
    dialog:Show()
end

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
                    local text = grandChild.text:GetText()
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
        if namesDialog then namesDialog:Hide() namesDialog = nil end
        C_Timer.After(0.2, function()
            ExtractNames(contentFrame, function(names)
                if #names > 0 then ShowNamesDialog(names) end
            end)
        end)
    end)
    panel.namesBtn = button
end

local function SetupScoreboard()
    if PVPMatchScoreboard then CreateNamesButton(PVPMatchScoreboard) end
    if PVPMatchResults then CreateNamesButton(PVPMatchResults) end
end

local pvpUIFrm = CreateFrame("Frame")
pvpUIFrm:RegisterEvent("ADDON_LOADED")
pvpUIFrm:SetScript("OnEvent", function(_, _, addon)
    if addon == "Blizzard_PVPUI" then
        SetupScoreboard()
        RegisterMenus()
        if PVPMatchScoreboard then
            PVPMatchScoreboard:HookScript("OnShow", function() CreateNamesButton(PVPMatchScoreboard) end)
        end
        if PVPMatchResults then
            PVPMatchResults:HookScript("OnShow", function() CreateNamesButton(PVPMatchResults) end)
        end
        pvpUIFrm:UnregisterEvent("ADDON_LOADED")
    end
end)
SetupScoreboard()
