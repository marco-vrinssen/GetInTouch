-- Inject a copy full name action into the native right-click context menus because manual typing is prone to spelling errors

local acceptableFinderTags = {
    MENU_LFG_FRAME_SEARCH_ENTRY = true,
    MENU_LFG_FRAME_MEMBER_APPLY = true,
}

local acceptablePlayerTypes = {
    PLAYER = true, PARTY = true, RAID_PLAYER = true,
    FRIEND = true, FRIEND_OFFLINE = true, FRIEND_ONLINE = true,
    BN_FRIEND = true, SELF = true, OTHER_PLAYER = true,
    ENEMY_PLAYER = true, TARGET = true, FOCUS = true,
    GUILD = true, COMMUNITIES_GUILD_MEMBER = true,
    COMMUNITIES_MEMBER = true, COMMUNITIES_WOW_MEMBER = true,
    PVP_SCOREBOARD = true,
}

-- Separate a combined string into name and realm components to normalize formats because WoW passes mixed representations via the UI API

local function splitNameRealm(fullIdentifierString)
    if not fullIdentifierString then return nil, nil end

    local extractedName, extractedRealm = fullIdentifierString:match("^([^-]+)-(.+)$")

    return extractedName or fullIdentifierString, extractedRealm or GetRealmName()
end

-- Query the looking for group API to find a leader or applicant identity because group finder context menus don't directly supply standard names

local function resolveFinderIdentity(menuOwnerTarget)
    if not menuOwnerTarget then return nil, nil end

    if menuOwnerTarget.resultID and C_LFGList then
        local searchResultInformation = C_LFGList.GetSearchResultInfo(menuOwnerTarget.resultID)

        if searchResultInformation and searchResultInformation.leaderName then
            return splitNameRealm(searchResultInformation.leaderName)
        end
    end

    if menuOwnerTarget.memberIdx then
        local parentFrame = menuOwnerTarget:GetParent()

        if parentFrame and parentFrame.applicantID and C_LFGList then
            local applicantName = C_LFGList.GetApplicantMemberInfo(parentFrame.applicantID, menuOwnerTarget.memberIdx)

            if applicantName then
                return splitNameRealm(applicantName)
            end
        end
    end

    return nil, nil
end

-- Interrogate the active context source to extract a uniform player identifier because different panels supply names through completely different properties

local function resolvePlayerIdentity(menuOwnerTarget, menuRootComponent, contextData)
    if not contextData then
        if menuRootComponent and menuRootComponent.tag and acceptableFinderTags[menuRootComponent.tag] then
            return resolveFinderIdentity(menuOwnerTarget)
        end
        return nil, nil
    end

    if contextData.name and contextData.server then
        return contextData.name, contextData.server
    end

    if contextData.which == "PVP_SCOREBOARD" and contextData.unit and C_PvP then
        -- contextData.unit is a secret/protected value in scoreboard context menus; passing it
        -- to GetScoreInfoByPlayerGuid from tainted addon code raises a security error, so skip
        -- the GUID lookup and fall through to the name-based resolution paths below
        if not issecretvalue(contextData.unit) then
            local scoreInformation = C_PvP.GetScoreInfoByPlayerGuid(contextData.unit)

            if scoreInformation and scoreInformation.name then
                return splitNameRealm(scoreInformation.name)
            end
        end
    end

    if contextData.unit and UnitExists(contextData.unit) then
        local targetUnitName = UnitName(contextData.unit)

        if targetUnitName then
            local extractedName, extractedRealm = splitNameRealm(targetUnitName)

            return extractedName, contextData.server or extractedRealm
        end
    end

    if contextData.accountInfo and contextData.accountInfo.gameAccountInfo then
        local gameAccountStructure = contextData.accountInfo.gameAccountInfo

        return gameAccountStructure.characterName, gameAccountStructure.realmName
    end

    if contextData.name then
        return splitNameRealm(contextData.name)
    end

    if contextData.friendsList and C_FriendList then
        local storedFriendInformation = C_FriendList.GetFriendInfoByIndex(contextData.friendsList)

        if storedFriendInformation and storedFriendInformation.name then
            return splitNameRealm(storedFriendInformation.name)
        end
    end

    if contextData.chatTarget then
        return splitNameRealm(contextData.chatTarget)
    end

    return nil, nil
end

local processedMenuInjections = {}

-- Attach the supplemental copy action to the generated dropdown assuming it is a valid player because non-player entities should not have a copy option

local function addCopyButton(menuOwnerTarget, menuRootComponent, contextData)
    if InCombatLockdown() then return end

    if not contextData then
        if not (menuRootComponent and menuRootComponent.tag and acceptableFinderTags[menuRootComponent.tag]) then return end
    else
        if not (contextData.clubId or (contextData.which and acceptablePlayerTypes[contextData.which])) then return end
    end

    local extractedName, extractedRealm = resolvePlayerIdentity(menuOwnerTarget, menuRootComponent, contextData)

    if not (extractedName and extractedRealm and menuRootComponent and menuRootComponent.CreateButton) then return end

    extractedName = tostring(extractedName)
    extractedRealm = tostring(extractedRealm)

    local deduplicationKey = tostring(menuRootComponent) .. extractedName .. extractedRealm

    if processedMenuInjections[deduplicationKey] then return end

    processedMenuInjections[deduplicationKey] = true
    C_Timer.After(0.5, function() processedMenuInjections[deduplicationKey] = nil end)

    if menuRootComponent.CreateDivider then menuRootComponent:CreateDivider() end

    menuRootComponent:CreateButton("Copy Full Name", function()
        if not InCombatLockdown() then
            CopyAllTheNames.openCopyPopup(extractedName .. "-" .. extractedRealm)
        end
    end)
end

local supportedMenuTags = {
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

-- Hook the menu generation lifecycle for all mapped tags to intercept construction because WoW context menus are generated dynamically per interaction

local function registerMenuHooks()
    if not Menu or not Menu.ModifyMenu then return false end

    for _, validMenuTag in ipairs(supportedMenuTags) do
        Menu.ModifyMenu(validMenuTag, addCopyButton)
    end

    return true
end

-- Ensure hooks apply sequentially even if Menu isn't immediately ready because some addons or layouts load context menus lazily

if not registerMenuHooks() then
    local retryAttempts = 0

    C_Timer.NewTicker(0.5, function(tickerFrame)
        retryAttempts = retryAttempts + 1

        if registerMenuHooks() or retryAttempts >= 10 then
            tickerFrame:Cancel()
        end
    end)
end

-- Refresh hooks when PVP UI modules load to catch delayed battleground scoreboard generation because they bypass standard initial loading

local eventListenerFrame = CreateFrame("Frame")

eventListenerFrame:RegisterEvent("ADDON_LOADED")

eventListenerFrame:SetScript("OnEvent", function(_, _, matchedAddon)
    if matchedAddon == "Blizzard_PVPUI" then
        registerMenuHooks()
    end
end)
