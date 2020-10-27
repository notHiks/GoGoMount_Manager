local ADDON_NAME, JournalFilter = ...
GoGoMount_Manager = LibStub("AceAddon-3.0"):GetAddon("GoGoMount_Manager")
local JournalFilter = GoGoMount_Manager.JournalFilter


JournalFilter.MountTypeList = {
	ground = {
		typeIDs = {230, 231, 241, 269, 284}
	},
	flying = {
		typeIDs = {247, 248}
	},
	waterWalking = {
		typeIDs = {269},
	},
	underwater = {
		typeIDs = {232, 254},
		[30174] = true, -- Riding Turtle
		[64731] = true, -- Sea Turtle
	},
	repair = {
		[61425] = true, -- Traveler's Tundra Mammoth
		[122708] = true, -- Grand Expedition Yak
		[264058] = true, -- Mighty Caravan Brutosaur
	},
	passenger = {
		[61425] = true, -- Traveler's Tundra Mammoth
		[122708] = true, -- Grand Expedition Yak
		[61469] = true, -- Grand Ice Mammoth
		[61470] = true, -- Grand Ice Mammoth
		[61465] = true, -- Grand Black War Mammoth
		[61467] = true, -- Grand Black War Mammoth
		[121820] = true, -- Obsidian Nightwing
		[93326] = true, -- Sandstone Drake
		[55531] = true, -- Mechano-Hog
		[60424] = true, -- Mekgineer's Chopper
		[75973] = true, -- X-53 Touring Rocket
		[245723] = true, -- Stormwind Skychaser - Blizzcon 2017
		[245725] = true, -- Orgrimmar Interceptor - Blizzcon 2017
		[264058] = true, -- Mighty Caravan Brutosaur
	},
}

JournalFilter.MountSourceList = {
	["Reputation"] = {},
	["Misc"] = {sourceType = {0},},
	["Drop"] = {sourceType = {1},},
	["Quest"] = {sourceType = {2},},
	["Vendor"] = {sourceType = {3},},
	["Profession"] = {sourceType = {4},},
	["Achievement"] = {sourceType = {6},},
	["World Event"] = {sourceType = {7},},
	["Shop"] = {sourceType = {10},},
	["Promotion"] = {sourceType = {8,9},},
}

local MountSourceList = JournalFilter.MountSourceList
local MountTypeList = JournalFilter.MountTypeList

---------
local function CheckAllSettings(settings)
---------
	local allDisabled = true
	local allEnabled = true
	for _, value in pairs(settings) do
		if type(value) == "table" then
			local subResult = CheckAllSettings(value)
			if (subResult ~= false) then
				allDisabled = false
			elseif (subResult ~= true) then
				allEnabled = false
			end
		elseif (value) then
			allDisabled = false
		else
			allEnabled = false
		end

		if allEnabled == false and false == allDisabled then
			break
		end
	end

	if allEnabled then
		return true
	elseif allDisabled then
		return false
	end

	return nil
end


---------
local function CheckMountInList(settings, sourceData, spellId)
---------
	local isInList = false

	for setting, value in pairs(settings) do
		if type(value) == "table" then
			local subResult = CheckMountInList(value, sourceData[setting], spellId)
			if subResult then
				return true
			elseif subResult == false then
				isInList = true
			end
		elseif sourceData[setting] and sourceData[setting][spellId] then
			if (value) then
				return true
			else
				isInList = true
			end
		end
	end

	if isInList then
		return false
	end

	return nil
end


---------
local function BuildSourceList()
---------
	if (GetNumCompanions("MOUNT") >= 1) then
			local mountIDs = C_MountJournal.GetMountIDs()
			for i, id in pairs(mountIDs) do
				local _, spellID, _, _, isUsable, _, _, isFactionSpecific, faction, _, isCollected, _ = C_MountJournal.GetMountInfoByID(id)
				local creatureDisplayID, descriptionText, sourceText, isSelfMount, mountType, uiModelScene = C_MountJournal.GetMountInfoExtraByID(id)
				GoGoMount_Manager.spell_to_id [spellID] = id
				if string.match(sourceText, FACTION) then
					JournalFilter.MountSourceList["Reputation"][spellID] = true
				end

				if string.match(sourceText, TRANSMOG_SOURCE_6) then
					JournalFilter.MountSourceList["Profession"][spellID] = true
				end
			end
	end
end

BuildSourceList()

---------
local function FilterHiddenMounts(spellId)
---------
	return JournalFilter.settings.filter.hidden or not JournalFilter.settings.hiddenMounts[spellId]
end


---------
local function FilterFavoriteMounts(isFavorite)
	return isFavorite or not JournalFilter.settings.filter.onlyFavorites or not JournalFilter.settings.filter.collected
end


---------
local function FilterUsableMounts(spellId, isUsable)
---------
	return not JournalFilter.settings.filter.onlyUsable or (isUsable and IsUsableSpell(spellId))
end


---------
local function FilterCollectedMounts(collected)
---------
	return (JournalFilter.settings.filter.collected and collected) or (JournalFilter.settings.filter.notCollected and not collected)
end


---------
function JournalFilter:FilterMountsBySource(spellId, sourceType)
---------

	local settingsResult = CheckAllSettings(self.settings.filter.source)
	if settingsResult then
		return true
	end

	local mountResult = CheckMountInList(self.settings.filter.source, MountSourceList, spellId)
	if mountResult ~= nil then
		return mountResult
	end

	for source, value in pairs(self.settings.filter.source) do
		if MountSourceList[source] and MountSourceList[source]["sourceType"]
				and tContains(MountSourceList[source]["sourceType"], sourceType) then
			return value
		end
	end

	return true
end


---------
local function FilterMountsByFaction(isFaction, faction)
---------
	return (JournalFilter.settings.filter.faction.noFaction and not isFaction or JournalFilter.settings.filter.faction.alliance and faction == 1 or JournalFilter.settings.filter.faction.horde and faction == 0)
end


---------
function JournalFilter:FilterMountsByType(spellId, mountID)
---------
	local settingsResult = CheckAllSettings(self.settings.filter.mountType)
	if settingsResult then
		return true
	end

	local mountResult = CheckMountInList(self.settings.filter.mountType, MountTypeList, spellId)
	if mountResult == true then
		return true
	end

	local _, _, _, isSelfMount, mountType = C_MountJournal.GetMountInfoExtraByID(mountID)

	if (self.settings.filter.mountType.transform and isSelfMount) then
		return true
	end

	local result
	for category, value in pairs(self.settings.filter.mountType) do
		if MountTypeList[category] and
				MountTypeList[category].typeIDs and
				tContains(MountTypeList[category].typeIDs, mountType) then
			result = result or value
		end
	end

	if result == nil then
		result = true
	end

	return result
end


---------
function JournalFilter:FilterMountsByPerferedMount(spellId)
---------

	if self.settings.filter.onlyPerfered and GoGoMount_Manager.db.profile.GlobalPrefs[spellId] then
		return true
	end

	local zone = GoGoMount_Manager:SelectedZone()
	if self.settings.filter.onlyPerfered and GoGoMount_Manager.db.profile.ZoneMountList[zone] and GoGoMount_Manager.db.profile.ZoneMountList[zone]["Preferred"][spellId] then
		return true
	end

	if self.settings.filter.onlyPerfered then
		return false
	else
		return true
	end

	return  false
end


---------
function JournalFilter:FilterMount(index)
---------
	local _, spellId, _, _, isUsable, sourceType, isFavorite, isFaction, faction, _, isCollected, mountId = GoGoMount_Manager.hooks[C_MountJournal]["GetDisplayedMountInfo"](index)

	if (FilterHiddenMounts(spellId) and
		FilterFavoriteMounts(isFavorite) and
		FilterUsableMounts(spellId, isUsable) and
		FilterCollectedMounts(isCollected) and
		FilterMountsByFaction(isFaction, faction) and
		self:FilterMountsBySource(spellId, sourceType) and
		self:FilterMountsByType(spellId, mountId)) and
		self:FilterMountsByPerferedMount(spellId) then

		return true
	end

	return false
end
