-- Auction house seller name collector

local function CollectSellerNames()
    local itemBuyFrame = AuctionHouseFrame and AuctionHouseFrame.ItemBuyFrame
    if not itemBuyFrame then return {} end

    local itemKey = itemBuyFrame.itemKey
    if not itemKey then return {} end

    local names      = {}
    local foundNames = {}

    for i = 1, C_AuctionHouse.GetNumItemSearchResults(itemKey) do
        local info = C_AuctionHouse.GetItemSearchResultInfo(itemKey, i)
        if info and info.owners then
            for _, owner in ipairs(info.owners) do
                if owner and owner ~= "" and not foundNames[owner] then
                    foundNames[owner] = true
                    names[#names + 1] = owner
                end
            end
        end
    end

    return names
end

local sellerNamesButton

local function SetupAuctionHouse()
    if not AuctionHouseFrame or sellerNamesButton then return end

    local btn = CreateFrame("Button", nil, AuctionHouseFrame, "UIPanelButtonTemplate")
    btn:SetSize(120, 25)
    btn:SetText("Player Names")
    btn:SetPoint("RIGHT", AuctionHouseFrame.ItemBuyFrame.ItemList.RefreshFrame, "LEFT", -5, 0)
    btn:SetFrameStrata("HIGH")
    btn:Hide()
    CopyAllTheNames.ApplyClassicButtonStyle(btn)

    btn:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        CopyAllTheNames_NamesDialog.Hide()
        local names = CollectSellerNames()
        if #names > 0 then
            CopyAllTheNames_NamesDialog.Show(names)
        end
    end)

    sellerNamesButton = btn

    local itemBuyFrame = AuctionHouseFrame.ItemBuyFrame
    if itemBuyFrame then
        itemBuyFrame:HookScript("OnShow", function() sellerNamesButton:Show() end)
        itemBuyFrame:HookScript("OnHide", function() sellerNamesButton:Hide() end)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, _, addon)
    if addon == "Blizzard_AuctionHouseUI" then
        C_Timer.After(0, SetupAuctionHouse)
    end
end)
