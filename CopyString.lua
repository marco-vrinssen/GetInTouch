-- Retrieve text from under the mouse cursor to allow copying unselectable strings because default WoW frames do not support text selection

-- Notify the user about the slash command on login because the feature is not surfaced anywhere in the UI

local introFrame = CreateFrame("Frame")
introFrame:RegisterEvent("PLAYER_LOGIN")
introFrame:SetScript("OnEvent", function()
    print("|cffFFFF00CopyAllTheNames: Type /ct to copy the text under your cursor to the clipboard.|r")
end)

local function collectRegionText(frame, texts)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetText then
            local ok, text = pcall(region.GetText, region)
            if ok and text and text ~= "" then
                texts[#texts + 1] = text
            end
        end
    end
end

local function getMouseoverText()
    local texts = {}

    local foci = GetMouseFoci()
    local focus = foci and foci[1]

    if not focus or focus == WorldFrame or focus == UIParent then
        return nil
    end

    pcall(collectRegionText, focus, texts)

    local parent = focus:GetParent()
    if parent and parent ~= UIParent and parent ~= WorldFrame then
        pcall(collectRegionText, parent, texts)
    end

    return #texts > 0 and table.concat(texts, "\n") or nil
end

-- Bind the copy text slash command to open the copy popup dialog because users need a quick way to capture tooltips or frames via macro

SLASH_COPYALLTHENAMES_COPYTEXT1 = "/ct"
SlashCmdList["COPYALLTHENAMES_COPYTEXT"] = function()
    local text = getMouseoverText()

    if text then
        CopyAllTheNames.openCopyPopup(text)
    else
        print("|cffff9900CopyAllTheNames:|r No text found under cursor.")
    end
end
