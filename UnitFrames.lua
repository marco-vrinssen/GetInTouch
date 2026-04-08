-- Inject a copy-name action into native right-click context menus to avoid manual typing

local finderTags = {
    MENU_LFG_FRAME_SEARCH_ENTRY = true,
    MENU_LFG_FRAME_MEMBER_APPLY = true,
}

local playerTypes = {
    PLAYER = true, PARTY = true, RAID_PLAYER = true, RAID = true,
    FRIEND = true, FRIEND_OFFLINE = true, FRIEND_ONLINE = true,
    BN_FRIEND = true, BN_FRIEND_OFFLINE = true,
    SELF = true, OTHER_PLAYER = true,
    ENEMY_PLAYER = true, ARENAENEMY = true, TARGET = true, FOCUS = true,
    GUILD = true, GUILD_OFFLINE = true, COMMUNITIES_GUILD_MEMBER = true,
    COMMUNITIES_MEMBER = true, COMMUNITIES_WOW_MEMBER = true,
    PVP_SCOREBOARD = true, NEIGHBORHOOD_ROSTER = true,
    RECENT_ALLY = true, RECENT_ALLY_OFFLINE = true,
}

-- Split a combined name-realm string into separate components

local function splitNameRealm(combined)
    if not combined then return nil, nil end

    local name, realm = combined:match("^([^-]+)-(.+)$")

    return name or combined, realm or GetRealmName()
end

-- Query the LFG API to resolve leader or applicant identity from group finder context

local function resolveFinderCtx(owner)
    if not owner then return nil, nil end

    if owner.resultID and C_LFGList then
        local info = C_LFGList.GetSearchResultInfo(owner.resultID)

        if info and info.leaderName then
            return splitNameRealm(info.leaderName)
        end
    end

    if owner.memberIdx then
        local parent = owner:GetParent()

        if parent and parent.applicantID and C_LFGList then
            local appName = C_LFGList.GetApplicantMemberInfo(parent.applicantID, owner.memberIdx)

            if appName then
                return splitNameRealm(appName)
            end
        end
    end

    return nil, nil
end

-- Extract a uniform player identity from the active context source across different panel types

local function resolveIdentity(owner, root, ctx)
    if not ctx then
        if root and root.tag and finderTags[root.tag] then
            return resolveFinderCtx(owner)
        end
        return nil, nil
    end

    if ctx.name and ctx.server and not issecretvalue(ctx.name) and not issecretvalue(ctx.server) then
        return ctx.name, ctx.server
    end

    if ctx.which == "PVP_SCOREBOARD" and ctx.unit and C_PvP then
        -- ctx.unit may be a secret/protected value in scoreboard menus; skip GUID lookup to avoid taint
        if not issecretvalue(ctx.unit) then
            local info = C_PvP.GetScoreInfoByPlayerGuid(ctx.unit)

            if info and info.name then
                return splitNameRealm(info.name)
            end
        end
    end

    if ctx.unit and UnitExists(ctx.unit) then
        local unitName = UnitName(ctx.unit)

        if unitName then
            local name, realm = splitNameRealm(unitName)
            return name, ctx.server or realm
        end
    end

    if ctx.accountInfo and ctx.accountInfo.gameAccountInfo then
        local gameInfo = ctx.accountInfo.gameAccountInfo
        return gameInfo.characterName, gameInfo.realmName
    end

    if ctx.name and not issecretvalue(ctx.name) then
        return splitNameRealm(ctx.name)
    end

    if ctx.friendsList and C_FriendList then
        local info = C_FriendList.GetFriendInfoByIndex(ctx.friendsList)

        if info and info.name then
            return splitNameRealm(info.name)
        end
    end

    if ctx.chatTarget and not issecretvalue(ctx.chatTarget) then
        return splitNameRealm(ctx.chatTarget)
    end

    return nil, nil
end

local menuCache = {}

-- Attach the copy action to a generated dropdown for valid player context menus

local function addCopyBtn(owner, root, ctx)
    if InCombatLockdown() then return end

    if not ctx then
        if not (root and root.tag and finderTags[root.tag]) then return end
    elseif not (ctx.clubId or (ctx.which and playerTypes[ctx.which])) then
        return
    end

    local name, realm = resolveIdentity(owner, root, ctx)

    if not (name and realm and root and root.CreateButton) then return end

    name = tostring(name)
    realm = tostring(realm)

    local cacheKey = tostring(root) .. name .. realm

    if menuCache[cacheKey] then return end

    menuCache[cacheKey] = true
    C_Timer.After(0.5, function() menuCache[cacheKey] = nil end)

    if root.CreateDivider then root:CreateDivider() end

    root:CreateButton("Copy Full Name", function()
        if not InCombatLockdown() then
            GetInTouch.openCopyPopup(name .. "-" .. realm)
        end
    end)
end

local menuTags = {
    "MENU_LFG_FRAME_SEARCH_ENTRY", "MENU_LFG_FRAME_MEMBER_APPLY",
    "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID",
    "MENU_UNIT_FRIEND", "MENU_UNIT_FRIEND_OFFLINE", "MENU_UNIT_FRIEND_ONLINE",
    "MENU_UNIT_BN_FRIEND", "MENU_UNIT_BN_FRIEND_OFFLINE",
    "MENU_UNIT_SELF", "MENU_UNIT_OTHER_PLAYER",
    "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_ARENAENEMY", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS",
    "MENU_UNIT_GUILD", "MENU_UNIT_GUILD_OFFLINE", "MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
    "MENU_UNIT_COMMUNITIES_MEMBER", "MENU_UNIT_COMMUNITIES_WOW_MEMBER",
    "MENU_PVP_SCOREBOARD", "MENU_UNIT_PVP_SCOREBOARD",
    "MENU_BATTLEGROUND_SCOREBOARD", "MENU_CHAT_LOG_LINK", "MENU_CHAT_LOG_FRAME",
    "MENU_UNIT_NEIGHBORHOOD_ROSTER", "MENU_UNIT_RECENT_ALLY", "MENU_UNIT_RECENT_ALLY_OFFLINE",
}

-- Hook menu generation for all mapped tags to intercept construction at build time

local function registerHooks()
    if not Menu or not Menu.ModifyMenu then return false end

    for _, tag in ipairs(menuTags) do
        Menu.ModifyMenu(tag, addCopyBtn)
    end

    return true
end

-- Retry hook registration if Menu isn't ready yet due to lazy loading

if not registerHooks() then
    local attempts = 0

    C_Timer.NewTicker(0.5, function(ticker)
        attempts = attempts + 1

        if registerHooks() or attempts >= 10 then
            ticker:Cancel()
        end
    end)
end

-- Re-register hooks when PVP UI loads to catch delayed scoreboard menu generation

local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("ADDON_LOADED")
evtFrame:SetScript("OnEvent", function(_, _, addon)
    if addon == "Blizzard_PVPUI" then
        C_Timer.After(0, registerHooks)
    end
end)
