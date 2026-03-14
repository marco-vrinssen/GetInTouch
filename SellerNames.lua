-- Extract owner names from auction house search results to facilitate bulk communication because players often sell multiple items simultaneously

local function collectSellerNames()
    local itemBuyFrame = AuctionHouseFrame and AuctionHouseFrame.ItemBuyFrame
    if not itemBuyFrame then return {} end

    local currentItemKey = itemBuyFrame.itemKey
    if not currentItemKey then return {} end

    local playerNamesList = {}
    local foundNamesList = {}

    for searchIndex = 1, C_AuctionHouse.GetNumItemSearchResults(currentItemKey) do
        local resultInformation = C_AuctionHouse.GetItemSearchResultInfo(currentItemKey, searchIndex)

        if resultInformation and resultInformation.owners then
            for _, auctionOwner in ipairs(resultInformation.owners) do
                if auctionOwner and auctionOwner ~= "" and not foundNamesList[auctionOwner] then
                    foundNamesList[auctionOwner] = true
                    playerNamesList[#playerNamesList + 1] = auctionOwner
                end
            end
        end
    end

    return playerNamesList
end

local sellerNamesButton

-- Inject the seller collection button into the auction house interface to expose the feature because the default UI lacks native export capabilities

local function setupAuctionHouse()
    if not AuctionHouseFrame or sellerNamesButton then return end

    local playerNamesButton = CreateFrame("Button", nil, AuctionHouseFrame, "UIPanelButtonTemplate")

    playerNamesButton:SetSize(120, 25)
    playerNamesButton:SetText("Player Names")
    playerNamesButton:SetPoint("RIGHT", AuctionHouseFrame.ItemBuyFrame.ItemList.RefreshFrame, "LEFT", -5, 0)
    playerNamesButton:SetFrameStrata("HIGH")
    playerNamesButton:Hide()

    CopyAllTheNames.applyClassicButtonStyle(playerNamesButton)

    playerNamesButton:SetScript("OnClick", function()
        if InCombatLockdown() then return end

        CopyAllTheNames_NamesDialog.Hide()
        local playerNamesList = collectSellerNames()

        if #playerNamesList > 0 then
            CopyAllTheNames_NamesDialog.Show(playerNamesList)
        end
    end)

    sellerNamesButton = playerNamesButton

    local itemBuyFrame = AuctionHouseFrame.ItemBuyFrame

    if itemBuyFrame then
        itemBuyFrame:HookScript("OnShow", function() sellerNamesButton:Show() end)
        itemBuyFrame:HookScript("OnHide", function() sellerNamesButton:Hide() end)
    end
end

-- Wait for the auction house to load before applying modifications because Blizzard addons load dynamically on demand

local eventListenerFrame = CreateFrame("Frame")

eventListenerFrame:RegisterEvent("ADDON_LOADED")

eventListenerFrame:SetScript("OnEvent", function(_, _, matchedAddon)
    if matchedAddon == "Blizzard_AuctionHouseUI" then
        C_Timer.After(0, setupAuctionHouse)
    end
end)
