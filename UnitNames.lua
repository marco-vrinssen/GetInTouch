-- Add copy full name option to right-click context menus

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

local processed = {}

local function AddCopyButton(owner, root, context)
    if InCombatLockdown() then return end
    if not context then
        if not (root and root.tag and finderTags[root.tag]) then return end
    else
        if not (context.clubId or (context.which and playerTypes[context.which])) then return end
    end
    local name, realm = ResolvePlayer(owner, root, context)
    if not (name and realm and root and root.CreateButton) then return end
    name  = tostring(name)
    realm = tostring(realm)
    local key = tostring(root) .. name .. realm
    if processed[key] then return end
    processed[key] = true
    C_Timer.After(0.5, function() processed[key] = nil end)
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton("Copy Full Name", function()
        if not InCombatLockdown() then
            CopyAllTheNames.OpenCopyPopup(name .. "-" .. realm)
        end
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

local contextMenuFrame = CreateFrame("Frame")
contextMenuFrame:RegisterEvent("ADDON_LOADED")
contextMenuFrame:SetScript("OnEvent", function(_, _, addon)
    if addon == "Blizzard_PVPUI" then RegisterMenus() end
end)
