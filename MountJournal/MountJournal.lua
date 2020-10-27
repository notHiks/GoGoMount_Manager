local ADDON_NAME, JournalFilter = ...

GoGoMount_Manager = LibStub("AceAddon-3.0"):GetAddon("GoGoMount_Manager")
local JournalFilter = GoGoMount_Manager.JournalFilter
local L = LibStub("AceLocale-3.0"):GetLocale("GoGoMount_Manager", silent)
JournalFilter.hooks = {}
JournalFilter.indexMap = {}

---------
local function SearchIsActive()
---------
	local searchString = MountJournal.searchBox:GetText()
	if (not searchString or string.len(searchString) == 0) then
		return false
	end

	return true
end


--region C_MountJournal Hooks
---------
function JournalFilter:MapIndex(index)
---------
	-- index=0 => SummonRandomButton
	if (SearchIsActive() or index == 0) then
		return index
	end

	if (not self.indexMap) then
		self:UpdateIndexMap()
	end

	return self.indexMap[index]
end


---------
local function C_MountJournal_GetNumDisplayedMounts()
---------
	if SearchIsActive() then
		return GoGoMount_Manager.hooks[C_MountJournal]["GetNumDisplayedMounts"]()
	end

	if (not JournalFilter.indexMap) then
		JournalFilter:UpdateIndexMap()
	end

	return #JournalFilter.indexMap
end


---------
local function C_MountJournal_GetDisplayedMountInfo(index)
---------
	local creatureName, spellId, icon, active, isUsable, sourceType, isFavorite, isFaction, faction, hideOnChar, isCollected, mountID, a, b, c, d, e, f, g, h
	local mappedIndex = JournalFilter:MapIndex(index)
	if nil ~= mappedIndex then
		creatureName, spellId, icon, active, isUsable, sourceType, isFavorite, isFaction, faction, hideOnChar, isCollected, mountID, a, b, c, d, e, f, g, h = GoGoMount_Manager.hooks[C_MountJournal]["GetDisplayedMountInfo"](mappedIndex)
	end

	isUsable = isUsable and IsUsableSpell(spellId)

	return creatureName, spellId, icon, active, isUsable, sourceType, isFavorite, isFaction, faction, hideOnChar, isCollected, mountID, a, b, c, d, e, f, g, h
end


---------
local function C_MountJournal_GetDisplayedMountInfoExtra(index)
---------
	local _, _, _, _, _, _, _, _, _, _, _, mountId = C_MountJournal.GetDisplayedMountInfo(index)
	if (not mountId) then
		return nil
	end

	return C_MountJournal.GetMountInfoExtraByID(mountId)
end


---------
local function RegisterMountJournalHooks()
---------
	GoGoMount_Manager:RawHook(C_MountJournal, "GetNumDisplayedMounts", C_MountJournal_GetNumDisplayedMounts, true)
	GoGoMount_Manager:RawHook(C_MountJournal, "GetDisplayedMountInfo", C_MountJournal_GetDisplayedMountInfo, true)
	GoGoMount_Manager:RawHook(C_MountJournal, "GetDisplayedMountInfoExtra", C_MountJournal_GetDisplayedMountInfoExtra, true)
	GoGoMount_Manager:RawHook(C_MountJournal, "SetIsFavorite", function(index, isFavored)
		local result = GoGoMount_Manager.hooks[C_MountJournal].SetIsFavorite(index,isFavored)
		JournalFilter:UpdateIndexMap()
		return result
	end, true)
	GoGoMount_Manager:RawHook(C_MountJournal, "GetIsFavorite", function(index)
		return GoGoMount_Manager.hooks[C_MountJournal].GetIsFavorite(index)
	end, true)
	GoGoMount_Manager:RawHook(C_MountJournal, "Pickup", function(index)
		return GoGoMount_Manager.hooks[C_MountJournal].Pickup(index)
	end, true)
end

--endregion Hooks


---------
function JournalFilter:UpdateIndexMap()
---------
	local indexMap = {}

	if not SearchIsActive() then
		for i = 1, GoGoMount_Manager.hooks[C_MountJournal].GetNumDisplayedMounts() do
		   if (JournalFilter:FilterMount(i)) then
				indexMap[#indexMap + 1] = i
			end
		end
	end

	self.indexMap = indexMap
end

-- reset default filter settings
C_MountJournal.SetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_COLLECTED, true)
C_MountJournal.SetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED, true)
C_MountJournal.SetCollectedFilterSetting(LE_MOUNT_JOURNAL_FILTER_UNUSABLE, true)
C_MountJournal.SetAllSourceFilters(true)
C_MountJournal.SetSearch("")


MountJournalEnhancedSettings = MountJournalEnhancedSettings or {}
local defaultFilterStates

---------
function JournalFilter:ResetFilterSettings()
---------
	JournalFilter.settings.filter = CopyTable(defaultFilterStates)
end


---------
local function PrepareDefaults()
---------

	local defaultSettings = {
		debugMode = false,
		showShopButton = false,
		compactMountList = true,
		favoritePerChar = false,
		favoredMounts = {},
		hiddenMounts = {},
		filter = {
			collected = true,
			notCollected = true,
			onlyFavorites = false,
			onlyUsable = false,
			onlyPerfered = false,
			source = {},
			faction = {
				alliance = true,
				horde = true,
				noFaction = true,
			},
			mountType = {
				ground = true,
				flying = true,
				waterWalking = true,
				underwater = true,
				transform = true,
				repair = true,
				passenger = true,
			},
			hidden = false,
		},
	}

	for categoryName, _ in pairs(JournalFilter.MountSourceList) do
		defaultSettings.filter.source[categoryName] = true
   end

	return defaultSettings
end


---------
local function CombineSettings(settings, defaultSettings)
---------
	for key, value in pairs(defaultSettings) do
		if (settings[key] == nil) then
			settings[key] = value;
		elseif (type(value) == "table") and next(value) ~= nil then
			if type(settings[key]) ~= "table" then
				settings[key] = {}
			end
			CombineSettings(settings[key], value);
		end
	end

	-- cleanup old still existing settings
	for key, _ in pairs(settings) do
		if (defaultSettings[key] == nil) then
			settings[key] = nil;
		end
	end
end


---------
function JournalFilter:OnLogin()
---------
	local defaultSettings = PrepareDefaults()
	defaultFilterStates = CopyTable(defaultSettings.filter)
	CombineSettings(MountJournalEnhancedSettings, defaultSettings)
	JournalFilter.settings = MountJournalEnhancedSettings
end


---------
function JournalFilter:OnEvent()
---------
	if (CollectionsJournal:IsShown()) then
		JournalFilter:UpdateIndexMap()
		MountJournal_UpdateMountList()
	end

end


---------
function JournalFilter:LoadUI()
---------
	PetJournal:HookScript("OnShow", function()
		if (not PetJournalPetCard.petID) then
			PetJournal_ShowPetCard(1)
		end
	end)

	RegisterMountJournalHooks()
	self:UpdateIndexMap()
	MountJournal_UpdateMountList()

	GoGoMount_Manager:RegisterEvent("SPELL_UPDATE_USABLE", JournalFilter.OnEvent)
	GoGoMount_Manager:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED", JournalFilter.OnEvent)
	GoGoMount_Manager:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED", JournalFilter.OnEvent)
end
