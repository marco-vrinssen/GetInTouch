local function GetMouseoverText()
    local texts        = {}
    local currentFrame = nil
    repeat
        currentFrame = EnumerateFrames(currentFrame)
        if currentFrame then
            for _, region in next, { currentFrame:GetRegions() } do
                if region.GetText then
                    local isVisible = region:IsVisible()
                    if canaccessvalue(isVisible) and isVisible then
                        local success, isOver = pcall(MouseIsOver, region)
                        if success and canaccessvalue(isOver) and isOver then
                            local text = region:GetText()
                            if canaccessvalue(text) and text then
                                texts[#texts + 1] = text
                            end
                        end
                    end
                end
            end
        end
    until not currentFrame
    return #texts > 0 and table.concat(texts, "\n") or nil
end

SLASH_COPYALLTHENAMES_COPYTEXT1 = "/c"
SlashCmdList["COPYALLTHENAMES_COPYTEXT"] = function()
    local text = GetMouseoverText()
    if text then
        CopyAllTheNames.OpenCopyPopup(text)
    else
        print("|cffff9900CopyAllTheNames:|r No text found under cursor.")
    end
end
