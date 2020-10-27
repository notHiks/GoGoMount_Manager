local ADDON_NAME, JournalFilter = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GoGoMount_Manager", silent)
GoGoMount_Manager = LibStub("AceAddon-3.0"):GetAddon("GoGoMount_Manager")
local JournalFilter = GoGoMount_Manager.JournalFilter

---------
local function CreateFilterInfo(text, filterKey, filterSettings, callback)
---------
    local info = MSA_DropDownMenu_CreateInfo()
    info.keepShownOnClick = true
    info.isNotRadio = true
    info.hasArrow = false
    info.text = text

    if filterKey then
        if not filterSettings then
            filterSettings = JournalFilter.settings.filter
        end
        info.arg1 = filterSettings
        info.notCheckable = false
        info.checked = function(self) return self.arg1[filterKey] end
        info.func = function(_, arg1, _, value)
            arg1[filterKey] = value
            JournalFilter:UpdateIndexMap()
            MountJournal_UpdateMountList()
            if (MSA_DROPDOWNMENU_MENU_LEVEL > 1) then
                for i=1, MSA_DROPDOWNMENU_MENU_LEVEL do
                    MSA_DropDownMenu_Refresh(_G[ADDON_NAME .. "FilterMenu"], nil, i)
                end
            end

            if callback then
                callback(value)
            end
        end
    else
        info.notCheckable = true
    end

    return info
end


---------
local function CreateFilterCategory(text, value)
---------
    local info = CreateFilterInfo(text)
    info.hasArrow = true
    info.value = value

    return info
end


---------
local function CheckSetting(settings)
---------
    local hasTrue, hasFalse = false, false
    for _, v in pairs(settings) do
        if (v == true) then
            hasTrue = true
        elseif v == false then
            hasFalse = true
        end
        if hasTrue and hasFalse then
            break
        end
    end

    return hasTrue, hasFalse
end


---------
local function SetAllSubFilters(settings, switch)
---------
    for key, value in pairs(settings) do
        if type(value) == "table" then
            for subKey, _ in pairs(value) do
                settings[key][subKey] = switch
            end
        else
            settings[key] = switch
        end
    end

    if (MSA_DROPDOWNMENU_MENU_LEVEL ~= 2) then
        MSA_DropDownMenu_Refresh(_G[ADDON_NAME .. "FilterMenu"], nil, 2)
    end
    MSA_DropDownMenu_Refresh(_G[ADDON_NAME .. "FilterMenu"])
    JournalFilter:UpdateIndexMap()
    MountJournal_UpdateMountList()
end


---------
function JournalFilter:SetAllSubFilters(settings, switch)
---------
	return SetAllSubFilters(settings, switch)
end


---------
local function RefreshCategoryButton(button, isNotRadio)
---------
    local buttonName = button:GetName()
    local buttonCheck = _G[buttonName .. "Check"]

    if isNotRadio then
        buttonCheck:SetTexCoord(0.0, 0.5, 0.0, 0.5);
    else
        buttonCheck:SetTexCoord(0.0, 0.5, 0.5, 1.0);
    end

    button.isNotRadio = isNotRadio
end


---------
local function CreateInfoWithMenu(text, filterKey, settings, dropdownLevel)
---------
    local info = MSA_DropDownMenu_CreateInfo()
    info.text = text
    info.value = filterKey
    info.keepShownOnClick = true
    info.notCheckable = false
    info.hasArrow = true

    local hasTrue, hasFalse = CheckSetting(settings)
    info.isNotRadio = not hasTrue or not hasFalse

    info.checked = function(button)
        local hasTrue, hasFalse = CheckSetting(settings)
        RefreshCategoryButton(button, not hasTrue or not hasFalse)
        return hasTrue
    end
    info.func = function(button, _, _, value)
        if button.isNotRadio == value then
            SetAllSubFilters(settings, true)
        elseif true == button.isNotRadio and false == value then
            SetAllSubFilters(settings, false)
        end
    end

    return info
end


---------
local function AddCheckAllAndNoneInfo(settings, level)
---------
    local info = CreateFilterInfo(CHECK_ALL)
    info.func = function()
        SetAllSubFilters(settings, true)
    end
    MSA_DropDownMenu_AddButton(info, level)

    info = CreateFilterInfo(UNCHECK_ALL)
    info.func = function()
        SetAllSubFilters(settings, false)
    end
    MSA_DropDownMenu_AddButton(info, level)
end


---------
local function MakeMultiColumnMenu(level, entriesPerColumn)
---------
    local listFrame = _G["MSA_DropDownList" .. level]
    local columnWidth = listFrame.maxWidth + 25

    local listFrameName = listFrame:GetName()
    local columnIndex = 0
    for index = entriesPerColumn + 1, listFrame.numButtons do
        columnIndex = math.ceil(index / entriesPerColumn)
        local button = _G[listFrameName .. "Button" .. index]
        local yPos = -((button:GetID() - 1 - entriesPerColumn * (columnIndex - 1)) * MSA_DROPDOWNMENU_BUTTON_HEIGHT) - MSA_DROPDOWNMENU_BORDER_HEIGHT

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", columnWidth * (columnIndex - 1), yPos)
        button:SetWidth(columnWidth)
    end

    listFrame:SetHeight((min(listFrame.numButtons, entriesPerColumn) * MSA_DROPDOWNMENU_BUTTON_HEIGHT) + (MSA_DROPDOWNMENU_BORDER_HEIGHT * 2))
    listFrame:SetWidth(columnWidth * columnIndex)

    GoGoMount_Manager:Hook("MSA_DropDownMenu_OnHide", function(sender)
        GoGoMount_Manager:Unhook(listFrame, "SetWidth")
        GoGoMount_Manager:Unhook("MSA_DropDownMenu_OnHide")
        MSA_DropDownMenu_OnHide(sender)
    end)
    GoGoMount_Manager:Hook(listFrame, "SetWidth", function() end)
end


---------
local function InitializeFilterDropDown(filterMenu, level)
---------
    local info

    if (level == 1) then
        info = CreateFilterInfo(COLLECTED, "collected", nil, function(value)
            if (value) then
                MSA_DropDownMenu_EnableButton(1, 2)
            else
                MSA_DropDownMenu_DisableButton(1, 2)
            end
        end)
        MSA_DropDownMenu_AddButton(info, level)

        info = CreateFilterInfo(FAVORITES_FILTER, "onlyFavorites")
        info.leftPadding = 16
        info.disabled = not JournalFilter.settings.filter.collected
        MSA_DropDownMenu_AddButton(info, level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(NOT_COLLECTED, "notCollected"), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(L["Only usable"], "onlyUsable"), level)
	MSA_DropDownMenu_AddButton(CreateFilterInfo("Perfered Mounts", "onlyPerfered"), level)
        MSA_DropDownMenu_AddButton(CreateFilterCategory(SOURCES, "source"), level)
        MSA_DropDownMenu_AddButton(CreateFilterCategory(TYPE, "mountType"), level)
        MSA_DropDownMenu_AddButton(CreateFilterCategory(FACTION, "faction"), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(L["Hidden"], "hidden"), level)
        info = CreateFilterInfo(L["Reset filters"])
        info.keepShownOnClick = false
        info.func = function(_, _, _, value)
            JournalFilter:ResetFilterSettings();
            JournalFilter:UpdateIndexMap()
            MountJournal_UpdateMountList()
        end
        MSA_DropDownMenu_AddButton(info, level)
    elseif (MSA_DROPDOWNMENU_MENU_VALUE == "source") then
        local settings = JournalFilter.settings.filter["source"]
        AddCheckAllAndNoneInfo(settings, level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(BATTLE_PET_SOURCE_1, "Drop", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(BATTLE_PET_SOURCE_2, "Quest", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(BATTLE_PET_SOURCE_3, "Vendor", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(BATTLE_PET_SOURCE_4, "Profession", settings), level)
       MSA_DropDownMenu_AddButton(CreateFilterInfo(REPUTATION, "Reputation", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(BATTLE_PET_SOURCE_6, "Achievement", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(BATTLE_PET_SOURCE_7, "World Event", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(BATTLE_PET_SOURCE_10, "Shop", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(BATTLE_PET_SOURCE_8, "Promotion", settings), level)
    elseif (MSA_DROPDOWNMENU_MENU_VALUE == "mountType") then
        local settings = JournalFilter.settings.filter["mountType"]
        AddCheckAllAndNoneInfo(settings, level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(L["Ground"], "ground", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(L["Flying"], "flying", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(L["Water Walking"], "waterWalking", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(L["Underwater"], "underwater", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(L["Transform"], "transform", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(MINIMAP_TRACKING_REPAIR, "repair", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(L["Passenger"], "passenger", settings), level)
    elseif (MSA_DROPDOWNMENU_MENU_VALUE == "faction") then
        local settings = JournalFilter.settings.filter["faction"]
        MSA_DropDownMenu_AddButton(CreateFilterInfo(FACTION_ALLIANCE, "alliance", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(FACTION_HORDE, "horde", settings), level)
        MSA_DropDownMenu_AddButton(CreateFilterInfo(NPC_NAMES_DROPDOWN_NONE, "noFaction", settings), level)
    end
end


---------
function JournalFilter:InitDropdown()
---------
    local menu = CreateFrame("Button", ADDON_NAME .. "FilterMenu", MountJournalFilterButton, "MSA_DropDownMenuTemplate")
    MSA_DropDownMenu_Initialize(menu, InitializeFilterDropDown, "MENU")
    MountJournalFilterButton:SetScript("OnClick", function(sender)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        MSA_ToggleDropDownMenu(1, nil, menu, sender, 74, 15)
	end)

end
