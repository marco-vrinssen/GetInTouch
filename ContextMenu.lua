-- Add copy full name option to right-click context menus to simplify name copying because default UI has no copy option


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

-- Split name-realm string into separate values to handle cross-realm players because WoW formats them as "Name-Realm"

local function SplitNameRealm(full)
    if not full then return nil, nil end
    local name, realm = full:match("^([^-]+)-(.+)$")
    return name or full, realm or GetRealmName()
end

-- Resolve player name from LFG finder frames to extract leader or applicant info because finder context differs from unit context


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


-- Resolve player name and realm from various menu context sources to handle all unit menu types because each provides data differently


local function ResolvePlayer(owner, root, context)
    if not context then
        if root and root.tag and finderTags[root.tag] then return ResolveFinder(owner) end
        return nil, nil
    end
    if context.name and context.server then return context.name, context.server end
    if context.which == "PVP_SCOREBOARD" and context.unit and C_PvP then
        local scoreInfo = C_PvP.GetScoreInfoByPlayerGuid(context.unit)
        if scoreInfo and scoreInfo.name then return SplitNameRealm(scoreInfo.name) end
    end
    if context.unit and UnitExists(context.unit) then
        local unitName = UnitName(context.unit)
        if unitName then
            local playerName, realmName = SplitNameRealm(unitName)
            return playerName, context.server or realmName
        end
    end
    if context.accountInfo and context.accountInfo.gameAccountInfo then
        local gameAccount = context.accountInfo.gameAccountInfo
        return gameAccount.characterName, gameAccount.realmName
    end
    if context.name then return SplitNameRealm(context.name) end
    if context.friendsList and C_FriendList then
        local friendInfo = C_FriendList.GetFriendInfoByIndex(context.friendsList)
        if friendInfo and friendInfo.name then return SplitNameRealm(friendInfo.name) end
    end
    if context.chatTarget then return SplitNameRealm(context.chatTarget) end
    return nil, nil
end

-- Show small copy dialog sized to fit the player name because WoW has no clipboard API

local function ShowCopyDialog(name)
    -- Measure text width before creating dialog to derive a snug frame size
    local measurer = UIParent:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    measurer:SetText(name or "")
    local textWidth = measurer:GetStringWidth()
    measurer:SetText("")

    local inputPadding  = 24   -- InputBoxTemplate internal left + right gutter
    local dialogPadding = 44   -- inset border + visual margin on each side
    local inputWidth    = math.max(160, textWidth + inputPadding)
    local dialogWidth   = inputWidth + dialogPadding

    local dialog = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(dialogWidth, 80)
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
    input:SetSize(inputWidth, 26)
    input:SetPoint("CENTER", dialog, "CENTER", 0, -8)
    input:SetText(name or "")
    input:SetAutoFocus(true)
    input:HighlightText()
    input:SetScript("OnEscapePressed", function() dialog:Hide() end)
    input:SetScript("OnEnterPressed",  function() dialog:Hide() end)
    input:SetScript("OnKeyDown", function(_, key)
        if key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
            input:HighlightText()
            input:SetFocus()
            C_Timer.After(0, function() if dialog:IsShown() then dialog:Hide() end end)
        end
    end)

    dialog:Show()
end


-- Track processed menu entries to prevent duplicate copy buttons from appearing because ModifyMenu fires multiple times


local processed = {}


-- Add copy full name button to context menu to enable one-click name copying because default menus lack this option


local function AddCopyButton(owner, root, context)
    if InCombatLockdown() then return end
    if not context then
        if not (root and root.tag and finderTags[root.tag]) then return end
    else
        if not (context.clubId or (context.which and playerTypes[context.which])) then return end
    end
    local name, realm = ResolvePlayer(owner, root, context)
    if not (name and realm and root and root.CreateButton) then return end
    name = tostring(name)
    realm = tostring(realm)
    local key = tostring(root) .. name .. realm
    if processed[key] then return end
    processed[key] = true
    C_Timer.After(0.5, function() processed[key] = nil end)
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton("Copy Full Name", function()
        if not InCombatLockdown() then ShowCopyDialog(name .. "-" .. realm) end
    end)
end


-- Register copy button on all relevant menu tags to cover every player interaction context because menus use different tag identifiers


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


-- Attempt menu registration with retry to handle late Menu API availability because the API may not exist at initial load


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


-- Re-register menus when PvP UI loads to cover PvP-specific menu tags because they only become available after Blizzard_PVPUI loads


local contextMenuFrame = CreateFrame("Frame")
contextMenuFrame:RegisterEvent("ADDON_LOADED")
contextMenuFrame:SetScript("OnEvent", function(_, _, addon)
    if addon == "Blizzard_PVPUI" then
        RegisterMenus()
    end
end)
