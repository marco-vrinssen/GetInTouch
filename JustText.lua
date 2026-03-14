-- Retrieve text from under the mouse cursor to allow copying unselectable strings because default WoW frames do not support text selection

local function getMouseoverText()
    local texts = {}
    local currentFrame = nil

    repeat
        currentFrame = EnumerateFrames(currentFrame)
        if currentFrame then
            for _, region in next, { currentFrame:GetRegions() } do
                if region.GetText then
                    local isVisible = region:IsVisible()

                    if canAccessValue(isVisible) and isVisible then
                        local isSuccess, isOver = pcall(MouseIsOver, region)

                        if isSuccess and canAccessValue(isOver) and isOver then
                            local text = region:GetText()

                            if canAccessValue(text) and text then
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

-- Bind the copy text slash command to open the copy popup dialog because users need a quick way to capture tooltips or frames via macro

SLASH_COPYALLTHENAMES_COPYTEXT1 = "/c"
SlashCmdList["COPYALLTHENAMES_COPYTEXT"] = function()
    local text = getMouseoverText()

    if text then
        CopyAllTheNames.openCopyPopup(text)
    else
        print("|cffff9900CopyAllTheNames:|r No text found under cursor.")
    end
end
