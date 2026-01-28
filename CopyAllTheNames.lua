local finderTags = {MENU_LFG_FRAME_SEARCH_ENTRY = true, MENU_LFG_FRAME_MEMBER_APPLY = true}
local playerTypes = {PLAYER=true, PARTY=true, RAID_PLAYER=true, FRIEND=true, FRIEND_OFFLINE=true, FRIEND_ONLINE=true, BN_FRIEND=true, SELF=true, OTHER_PLAYER=true, ENEMY_PLAYER=true, TARGET=true, FOCUS=true, GUILD=true, COMMUNITIES_GUILD_MEMBER=true, COMMUNITIES_MEMBER=true, COMMUNITIES_WOW_MEMBER=true, PVP_SCOREBOARD=true}

local function parseNameRealm(full)
    if not full then return nil, nil end
    local n, r = full:match("^([^-]+)-(.+)$")
    return n or full, r or GetRealmName()
end

local function extractFinder(owner)
    if not owner then return nil, nil end
    if owner.resultID and C_LFGList then
        local r = C_LFGList.GetSearchResultInfo(owner.resultID)
        if r and r.leaderName then return parseNameRealm(r.leaderName) end
    end
    if owner.memberIdx then
        local p = owner:GetParent()
        if p and p.applicantID and C_LFGList then
            local n = C_LFGList.GetApplicantMemberInfo(p.applicantID, owner.memberIdx)
            if n then return parseNameRealm(n) end
        end
    end
    return nil, nil
end

local function resolvePlayer(owner, root, ctx)
    if not ctx then
        if root and root.tag and finderTags[root.tag] then return extractFinder(owner) end
        return nil, nil
    end
    if ctx.name and ctx.server then return ctx.name, ctx.server end
    if ctx.which == "PVP_SCOREBOARD" and ctx.unit and C_PvP then
        local i = C_PvP.GetScoreInfoByPlayerGuid(ctx.unit)
        if i and i.name then return parseNameRealm(i.name) end
    end
    if ctx.unit and UnitExists(ctx.unit) then
        local n = UnitName(ctx.unit)
        if n then local pn, rn = parseNameRealm(n); return pn, ctx.server or rn end
    end
    if ctx.accountInfo and ctx.accountInfo.gameAccountInfo then
        local g = ctx.accountInfo.gameAccountInfo
        return g.characterName, g.realmName
    end
    if ctx.name then return parseNameRealm(ctx.name) end
    if ctx.friendsList and C_FriendList then
        local f = C_FriendList.GetFriendInfoByIndex(ctx.friendsList)
        if f and f.name then return parseNameRealm(f.name) end
    end
    if ctx.chatTarget then return parseNameRealm(ctx.chatTarget) end
    return nil, nil
end

local function showCopyDialog(name)
    local d = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    d:SetSize(500, 150); d:SetPoint("CENTER"); d:SetMovable(true); d:EnableMouse(true)
    d:RegisterForDrag("LeftButton"); d:SetScript("OnDragStart", d.StartMoving); d:SetScript("OnDragStop", d.StopMovingOrSizing)
    d:SetFrameStrata("TOOLTIP"); d:SetFrameLevel(9999)
    d.title = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.title:SetPoint("TOP", d.TitleBg, "TOP", 0, -5); d.title:SetText("Copy Full Name")
    local e = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
    e:SetSize(460, 30); e:SetPoint("CENTER", d, "CENTER", 0, 10)
    e:SetText(name or ""); e:SetAutoFocus(true); e:HighlightText()
    e:SetScript("OnEscapePressed", function() d:Hide() end)
    e:SetScript("OnEnterPressed", function() d:Hide() end)
    e:SetScript("OnKeyDown", function(_, k)
        if k == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
            e:HighlightText(); e:SetFocus()
            C_Timer.After(0, function() if d:IsShown() then d:Hide() end end)
        end
    end)
    local h = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("BOTTOM", d, "BOTTOM", 0, 20); h:SetText("Ctrl+C / Cmd+C to copy")
    d:Show()
end

local processed = {}
local function addCopyBtn(owner, root, ctx)
    if InCombatLockdown() then return end
    if not ctx then
        if not (root and root.tag and finderTags[root.tag]) then return end
    else
        if not (ctx.clubId or (ctx.which and playerTypes[ctx.which])) then return end
    end
    local n, r = resolvePlayer(owner, root, ctx)
    if not (n and r and root and root.CreateButton) then return end
    local key = tostring(root) .. n .. r
    if processed[key] then return end
    processed[key] = true
    C_Timer.After(0.5, function() processed[key] = nil end)
    if root.CreateDivider then root:CreateDivider() end
    root:CreateButton("Copy Full Name", function()
        if not InCombatLockdown() then showCopyDialog(n .. "-" .. r) end
    end)
end

local menuTags = {"MENU_LFG_FRAME_SEARCH_ENTRY", "MENU_LFG_FRAME_MEMBER_APPLY", "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_FRIEND", "MENU_UNIT_FRIEND_OFFLINE", "MENU_UNIT_FRIEND_ONLINE", "MENU_UNIT_BN_FRIEND", "MENU_UNIT_SELF", "MENU_UNIT_OTHER_PLAYER", "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS", "MENU_UNIT_GUILD", "MENU_UNIT_COMMUNITIES_GUILD_MEMBER", "MENU_UNIT_COMMUNITIES_MEMBER", "MENU_UNIT_COMMUNITIES_WOW_MEMBER", "MENU_PVP_SCOREBOARD", "MENU_UNIT_PVP_SCOREBOARD", "MENU_BATTLEGROUND_SCOREBOARD", "MENU_CHAT_LOG_LINK", "MENU_CHAT_LOG_FRAME"}

local function registerMenus()
    if not Menu or not Menu.ModifyMenu then return false end
    for _, t in ipairs(menuTags) do Menu.ModifyMenu(t, addCopyBtn) end
    return true
end

if not registerMenus() then
    local a = 0
    C_Timer.NewTicker(0.5, function(t) a = a + 1; if registerMenus() or a >= 10 then t:Cancel() end end)
end

-- Scoreboard
local namesDialog
local function showNamesDialog(names)
    if namesDialog and namesDialog:IsShown() then namesDialog:Hide(); return end
    if namesDialog then
        namesDialog.input:SetText(table.concat(names, "\n"))
        namesDialog.input:SetCursorPosition(0)
        namesDialog:Show()
        return
    end
    local d = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    d:SetSize(500, 400); d:SetPoint("CENTER"); d:SetMovable(true); d:EnableMouse(true)
    d:RegisterForDrag("LeftButton"); d:SetScript("OnDragStart", d.StartMoving); d:SetScript("OnDragStop", d.StopMovingOrSizing)
    d:SetFrameStrata("FULLSCREEN_DIALOG"); d:SetFrameLevel(1000)
    d.title = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.title:SetPoint("TOP", d.TitleBg, "TOP", 0, -5); d.title:SetText("Player Names")
    local sf = CreateFrame("ScrollFrame", nil, d, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -30); sf:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -30, 50)
    local i = CreateFrame("EditBox", nil, sf)
    i:SetMultiLine(true); i:SetMaxLetters(0); i:SetFontObject(GameFontHighlight)
    i:SetWidth(sf:GetWidth() - 20); i:SetHeight(5000); i:SetAutoFocus(false)
    i:SetScript("OnEscapePressed", function() d:Hide() end)
    sf:SetScrollChild(i)
    i:SetText(table.concat(names, "\n")); i:SetCursorPosition(0)
    local h = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("BOTTOM", d, "BOTTOM", 0, 20); h:SetText("Ctrl+C / Cmd+C to copy")
    d.input = i; namesDialog = d; d:Show()
end

local function extractNames(cf, cb)
    if not cf then cb({}); return end
    local names, found = {}, {}
    local ignore = {Name=true, Deaths=true, All=true, Progress=true}
    local sb = cf.scrollBox or cf.ScrollBox
    if not sb or not sb.ScrollTarget then cb({}); return end
    for _, c in ipairs({sb.ScrollTarget:GetChildren()}) do
        if c then
            for _, gc in ipairs({c:GetChildren()}) do
                if gc and gc.text and type(gc.text) == "table" and gc.text.GetText then
                    local t = gc.text:GetText()
                    if t and t ~= "" and not ignore[t] and not found[t] and not t:match("%d") then
                        found[t] = true; names[#names+1] = t
                    end
                end
            end
        end
    end
    cb(names)
end

local function createNamesBtn(p)
    if not p or p.namesBtn then return end
    local cf = p.Content or p.content
    if not cf then return end
    local b = CreateFrame("Button", nil, cf, "UIPanelButtonTemplate")
    b:SetSize(120, 25); b:SetText("Player Names"); b:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -10, 10)
    b:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        if namesDialog then namesDialog:Hide(); namesDialog = nil end
        C_Timer.After(0.2, function() extractNames(cf, function(n) if #n > 0 then showNamesDialog(n) end end) end)
    end)
    p.namesBtn = b
end

local function setupScoreboard()
    if PVPMatchScoreboard then createNamesBtn(PVPMatchScoreboard) end
    if PVPMatchResults then createNamesBtn(PVPMatchResults) end
end

local ef = CreateFrame("Frame")
ef:RegisterEvent("ADDON_LOADED")
ef:SetScript("OnEvent", function(_, _, addon)
    if addon == "Blizzard_PVPUI" then
        setupScoreboard()
        registerMenus()
        if PVPMatchScoreboard then PVPMatchScoreboard:HookScript("OnShow", function() createNamesBtn(PVPMatchScoreboard) end) end
        if PVPMatchResults then PVPMatchResults:HookScript("OnShow", function() createNamesBtn(PVPMatchResults) end) end
        ef:UnregisterEvent("ADDON_LOADED")
    end
end)
setupScoreboard()
