-- Collect and display auction house seller names to enable bulk copying because default UI only shows names inline

-- Collect unique seller names from auction house item search results to build a copyable list because the UI has no bulk copy option

local function CollectSellerNames()
    local itemBuyFrame = AuctionHouseFrame and AuctionHouseFrame.ItemBuyFrame
    if not itemBuyFrame then return {} end

    local itemKey = itemBuyFrame.itemKey
    if not itemKey then return {} end

    local resultCount = C_AuctionHouse.GetNumItemSearchResults(itemKey)
    local sellerNames = {}
    local foundNames = {}

    for resultIndex = 1, resultCount do
        local resultInfo = C_AuctionHouse.GetItemSearchResultInfo(itemKey, resultIndex)
        if resultInfo and resultInfo.owners then
            for _, ownerName in ipairs(resultInfo.owners) do
                if ownerName and ownerName ~= "" and not foundNames[ownerName] then
                    foundNames[ownerName] = true
                    sellerNames[#sellerNames + 1] = ownerName
                end
            end
        end
    end

    return sellerNames
end

-- Create seller names button on auction house bottom edge to enable bulk copying because default UI only shows names inline

local sellerNamesButton

local function SetupAuctionHouse()
    if not AuctionHouseFrame then return end
    if sellerNamesButton then return end

    local button = CreateFrame("Button", nil, AuctionHouseFrame, "UIPanelButtonTemplate")
    button:SetSize(140, 22)
    button:SetText("Copy Seller Names")
    button:SetPoint("RIGHT", AuctionHouseFrame.ItemBuyFrame.ItemList.RefreshFrame, "LEFT", -5, 0)
    button:SetFrameStrata("HIGH")

    button:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        CopyAllTheNames_NamesDialog.Hide()

        local names = CollectSellerNames()
        if #names > 0 then
            CopyAllTheNames_NamesDialog.Show(names)
        end
    end)

    button:Hide()
    sellerNamesButton = button

    local itemBuyFrame = AuctionHouseFrame.ItemBuyFrame

    if itemBuyFrame then
        itemBuyFrame:HookScript("OnShow", function() sellerNamesButton:Show() end)
        itemBuyFrame:HookScript("OnHide", function() sellerNamesButton:Hide() end)
    end
end

-- Register for auction house addon load to attach button at the right time because the frame loads lazily

local auctionFrame = CreateFrame("Frame")
auctionFrame:RegisterEvent("ADDON_LOADED")
auctionFrame:SetScript("OnEvent", function(_, _, addon)
    if addon == "Blizzard_AuctionHouseUI" then
        C_Timer.After(0, SetupAuctionHouse)
    end
end)
