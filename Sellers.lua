-- Add a contact button to the auction house to collect and display seller names

local function collectSellerNames()
    local buyFrame = AuctionHouseFrame and AuctionHouseFrame.ItemBuyFrame
    if not buyFrame then return {} end

    local itemKey = buyFrame.itemKey
    if not itemKey then return {} end

    local names = {}
    local seen = {}

    for idx = 1, C_AuctionHouse.GetNumItemSearchResults(itemKey) do
        local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, idx)

        if result and result.owners then
            for _, owner in ipairs(result.owners) do
                if owner and owner ~= "" and not seen[owner] then
                    seen[owner] = true
                    names[#names + 1] = owner
                end
            end
        end
    end

    return names
end

local sellerBtn

-- Attach seller contact button onto the auction house panel to expose name collection

local function setupAuctionHouse()
    if not AuctionHouseFrame or sellerBtn then return end

    local btn = GetInTouch.createActionButton(AuctionHouseFrame, "Contact Players", 120, function()
        if InCombatLockdown() then return end

        GetInTouch_NamesDialog.Hide()
        local names = collectSellerNames()

        if #names > 0 then
            GetInTouch_NamesDialog.Show(names)
        end
    end, 25)

    btn:SetPoint("RIGHT", AuctionHouseFrame.ItemBuyFrame.ItemList.RefreshFrame, "LEFT", -5, 0)
    btn:SetFrameStrata("HIGH")
    btn:Hide()

    sellerBtn = btn

    local buyFrame = AuctionHouseFrame.ItemBuyFrame

    if buyFrame then
        buyFrame:HookScript("OnShow", function() sellerBtn:Show() end)
        buyFrame:HookScript("OnHide", function() sellerBtn:Hide() end)
    end
end

-- Hook auction house addon load event to defer setup until the UI exists

local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("ADDON_LOADED")
evtFrame:SetScript("OnEvent", function(_, _, addon)
    if addon == "Blizzard_AuctionHouseUI" then
        C_Timer.After(0, setupAuctionHouse)
    end
end)
