--	///////////////////////////////////////////////////////////////////////////////////////////
--
--	GoGoMount_Manager v3.1
--	Author: SLOKnightfall

--	GoGoMount_Manager: Integrates GoGoMounts Preferred and Excluded listing directly into the Mount List and adds profile support
--	///////////////////////////////////////////////////////////////////////////////////////////


GoGoMount_Manager = LibStub("AceAddon-3.0"):NewAddon("GoGoMount_Manager","AceEvent-3.0", "AceHook-3.0")
GoGoMount_Manager.spell_to_id = {}
GoGoMount_Manager.JournalFilter = {}
local private = {}

local spell_to_id = GoGoMount_Manager.spell_to_id
local L = LibStub("AceLocale-3.0"):GetLocale("GoGoMount_Manager", silent)

--Mirror of the GoGoMount pref settings
local GlobalPrefs = {}
local GlobalExclude = {}
local ZoneMountList = {}
local recentMounts = {}
local specialForms = {}
local ExtraPassengerMounts = {}

--Zone Based Settings globals
local EnableZoneEdit = false
local EnablePassengerEdit = false
local selectedCont = nil
local selectedZone = nil
local selectedProfile = nil

local continentZoneList = {
	[12]  = C_Map.GetMapInfo(12).name, -- Kalimdor
	[13]  = C_Map.GetMapInfo(13).name, -- Azeroth
	[101] = C_Map.GetMapInfo(101).name, -- Outlands
	[113] = C_Map.GetMapInfo(113).name, -- Northrend
	[424] = C_Map.GetMapInfo(424).name, -- Pandaria
	[572] = C_Map.GetMapInfo(572).name, -- Draenor
	[619] = C_Map.GetMapInfo(619).name, -- Broken Isles
	[875] = C_Map.GetMapInfo(875).name, -- Zandalar
	[876] = C_Map.GetMapInfo(876).name, -- Kul Tiras
}
local ZoneList = {}

--Mount Defaults
local MountDefaults = {
	[230] = {["type"] = "Ground Mount", [38] = true, [330]=true, [400]=true, [402]=true, [405]=true, [701]=true, [10001]=67, [10002]=160, [10004]=67},
	[231] = {["type"] = "Riding/sea turtle", [15] = true, [39] = true, [402]=true, [404]=true, [10001]=108, [10002]=100, [10004]=108},
	[232] = {["type"] = "Vashj'ir Seahorse", [36] = true, [53] = true, [401] = true, [10001]=371, [10004]=371},
	[241] = {["type"] = "AQ bugs", [38] = true, [201] = true, [330]=true, [402]=true, [10002]=160},
	[247] = {["type"] = "Red Flying Cloud", [9] = true, [38] = true, [300]=true, [301]=true, [330]=true, [400]=true, [402]=true, [403]=true, [405]=true, [701]=true, [10001]=67, [10002]=160, [10003]=250, [10004]=67},
	[248] = {["type"] = "Flying Mount", [9] = true, [38] = true, [300]=true, [301]=true, [330]=true, [400]=true, [402]=true, [403]=true, [405]=true, [701]=true, [10001]=67, [10002]=160, [10003]=250, [10004]=67},
	[254] = {["type"] = "Swimming Mount", [36] = true, [53] = true, [404] = true, [10001]=108, [10004]=108},
	[269] = {["type"] = "Striders", [38] = true, [330]=true, [400]=true, [402]=true, [405]=true, [701]=true, [10001]=67, [10002]=160, [10004]=200},
	[284] = {["type"] = "Chauffer", [38] = true, [330]=true, [400]=true, [402]=true, [405]=true, [701]=true, [10001]=67, [10002]=160, [10004]=67},
}

--Default Settings
local defaults = {
	profile = {
		GlobalPrefs = {},
		GlobalExclude = {},
		ZoneMountList = {},
		ExtraPassengerMounts = {},
		init = true,
		UseFix = true,
		AddMissingMounts = true,
		ForceRandom = true,
		HistorySize = 5,
 	}
}

--Ace3 Menu Settings
local options = {
	name = "GoGoMount_Manager",
	handler = GoGoMount_Manager,
	type = 'group',
	args = {
		settings = {
			name = "Settings",
			handler = GoGoMount_Manager,
			type = 'group',
			order = 0,
			args = {
				forceRandom = {
					name = "Rechoose mount if previously selected",
					desc = "Enables / disables bug fixes for GoGoMount",
					type = "toggle",
					set = function(info,val) GoGoMount_Manager.db.profile.ForceRandom = val end,
					get = function(info) return GoGoMount_Manager.db.profile.ForceRandom end,
					order = 1,
					width = "full",
				},
				forceRandomHistory = {
					name = "Number of mounts to keep history for",
					--desc = "Enables / disables bug fixes for GoGoMount",
					type = "range",
					set = function(info,val) GoGoMount_Manager.db.profile.HistorySize = val end,
					get = function(info) return GoGoMount_Manager.db.profile.HistorySize end,
					order = 1,
					width = "full",
					min = 1,
					max = 5,
					step = 1,
				},
				fixToggle = {
					name = "Enable GoGoMount Bug Fixes",
					desc = "Enables / disables bug fixes for GoGoMount",
					type = "toggle",
					set = function(info,val) GoGoMount_Manager.db.profile.UseFix = val, GoGoMount_Manager:ToggleFixes(val) end,
					get = function(info) return GoGoMount_Manager.db.profile.UseFix end,
					order = 1,
					width = "full",
				},
				missingMounts = {
					name = "Add Missing Mounts",
					desc = "Adds missing mounts to the GoGoMountDB with default values",
					type = "toggle",
					set = function(info,val) GoGoMount_Manager.db.profile.AddMissingMounts = val; if val then GoGoMount_Manager:AddMissingMounts() end; end,
					get = function(info) return GoGoMount_Manager.db.profile.AddMissingMounts end,
					order = 2,
					width = "full",
				},
			},
		},
	},
}






--Builds out list of zones in a given continent
---------
local function fillContinentZoneList(continent)
---------
	if not continent then return {} end

	wipe(ZoneList)
	local children = C_Map.GetMapChildrenInfo(continent)

	if children then
		for _, child in ipairs(children) do
			if child.mapType == Enum.UIMapType.Zone then
				ZoneList[child.mapID] = C_Map.GetMapInfo(child.mapID).name
			end
		end
	end
end


--Copies the global mounts of a profile to a selected zone
---------
local function CopyProfileToZone(profileName)
---------
	ZoneMountList[selectedZone] = {["Preferred"] = {}, ["Excluded"] = {},}

	if GoGoMount_Manager.db.profiles[profileName]["GlobalPrefs"] then
		for spellID, setting in pairs(GoGoMount_Manager.db.profiles[profileName]["GlobalPrefs"]) do
			ZoneMountList[selectedZone]["Preferred"][spellID] = setting
		end
	end

	if GoGoMount_Manager.db.profiles[profileName]["GlobalExclude"]  then
		for spellID, setting in pairs(GoGoMount_Manager.db.profiles[profileName]["GlobalExclude"]) do
			ZoneMountList[selectedZone]["Excluded"][spellID] = setting
		end

	end

	GoGoMount_Manager:UpdateCB()
	GoGoMount_Manager:UpdateGoGoMountPrefs()
end

--Ace3 Menu Settings for the Zone Settings window
local zone_options = {
    name = "GoGoMount_Manager_Zone",
    handler = GoGoMount_Manager,
    type = 'group',
    args = {
	zoneoptions={
			name = "Options",
			type = "group",
			--hidden = true,
			args={
				Topheader = {
					order = 0,
					type = "header",
					name = "GOGOMount_Manager",

				},

				filler1 = {
					order = 0.1,
					type = "description",
					name = "\n",

				},

				globalheader = {
					order = 0.5,
					type = "header",
					name = L.GLOBAL_HELPERS_HEADER,

				},
				clearglobalfav = {
					order = 1,
					type = "execute",
					name = L.CLEAR_GLOBAL_FAVORITES,
					func = function() GoGoMount_Manager:ClearGlobalFav() end,
					width = 1.6,

				},
				clearglobalexclude = {
					order = 2,
					type = "execute",
					name = L.CLEAR_GLOBAL_EXCLUDES,
					func = function() GoGoMount_Manager:ClearGlobalExclude() end,
					width = "full",

				},
				p_filler2 = {
					order = 2.1,
					type = "description",
					name = "\n",

				},
				passengerheader = {
					order = 2.2,
					type = "header",
					name = L.PASSENGER_HEADER,
					width = "full",

				},
				passengerMounts = {
					order = 2.3,
					type = "toggle",
					name = L.ENABLE_PASSENGER_SETTINGS,
					get = function(info)  return EnablePassengerEdit end,
					set = function(info, value) private.TogglePassengerSelection(value)  end,
					width = "full",
				},
				filler2 = {
					order = 2.4,
					type = "description",
					name = "\n",

				},
				zoneheader = {
					order = 2.5,
					type = "header",
					name = L.ZONE_SETTINGS_HEADER,
					width = "full",

				},
				item = {
					order = 3,
					type = "toggle",
					name = L.ENABLE_ZONE_SETTINGS,
					get = function(info)  return EnableZoneEdit end,
					set = function(info, value) EnableZoneEdit = value; GoGoMount_Manager:UpdateCB(); private.TogglePassengerSelection(false)  end,
					width = "full",


				},
				cont = {
					order = 4,
					type = "select",
					name = "Continent",
					get = function(info)  return selectedCont   end,
					set = function(info, value) selectedCont = value; fillContinentZoneList(value); selectedZone=nil  end,
					values = continentZoneList,
					disabled = function() return not EnableZoneEdit end,

				},
				zone = {
					order = 5,
					type = "select",
					name = "Zone",
					get = function(info) return selectedZone   end,
					set = function(info, value) selectedZone = value; ZoneMountList[value] = ZoneMountList[value] or{["Preferred"] = {},["Excluded"] = {},}; GoGoMount_Manager:UpdateCB() end,
					values = function() return ZoneList end,
					disabled = function() return not EnableZoneEdit end,
				},
				profile = {
					order = 6,
					type = "select",
					name = L.COPY_PROFILE ,
					get = function(info)  return selectedProfile    end,
					set = function(info, value) selectedProfile = GoGoMount_Manager.db:GetProfiles()[value]; CopyProfileToZone(selectedProfile) end,
					values = function() return GoGoMount_Manager.db:GetProfiles() end,
					disabled = function() return not EnableZoneEdit and not selectedZone end,
					width = "full",
				},
				filler3 = {
					order = 6.4,
					type = "description",
					name = "\n",

				},
				zoneheader_2 = {
					order = 6.5,
					type = "header",
					name = L.ZONE_HELPERS_HEADER,
					width = "full",

				},
				clearselectedzone = {
					order = 7,
					type = "execute",
					name = L.CLEAR_SELECTED_ZONE,
					func = function() GoGoMount_Manager:ClearZoneFavorites() end,
					width = "full",
				},
				clearallzone = {
					order = 8,
					type = "execute",
					name = L.CLEAR_ALL_ZONES,
					func = function() GoGoMount_Manager:ClearAllZoneFavorites() end,
					width = "full",
				},

			},
		},
	},
}



function private.TogglePassengerSelection(value)
	EnablePassengerEdit = value
	
	if value then 
		GoGoMount_Manager.JournalFilter:SetAllSubFilters(GoGoMount_Manager.JournalFilter.settings.filter["mountType"], false)
		GoGoMount_Manager.JournalFilter.settings.filter["mountType"]["passenger"] = true
		EnableZoneEdit = false

	else
		GoGoMount_Manager.JournalFilter:SetAllSubFilters(GoGoMount_Manager.JournalFilter.settings.filter["mountType"], true)

	end

	GoGoMount_Manager.JournalFilter:UpdateIndexMap()
	MountJournal_UpdateMountList()
	GoGoMount_Manager:UpdateCB()
end


---Updates our GlobalPrefs if changes are made via the GoGoMounts options
--Pram: spellID - spellID to set the table value for
---------
local function GoGo_GlobalPrefMount_update(spellID)
---------
	if GlobalPrefs[spellID] or GoGo_SearchTable(GoGo_Prefs.UnknownMounts, spellID) then
		GlobalPrefs[spellID]  = null
	else
		GlobalPrefs[spellID]  = true
	end
end


---Updates our GlobalExclude if changes are made via the GoGoMounts options
--Pram: spellID - spellID to set the table value for
---------
local function GoGo_GlobalExcludeMount_update(spellID)
---------
	if GlobalExclude[spellID] or GoGo_SearchTable(GoGo_Prefs.UnknownMounts, spellID) then
		GlobalExclude[spellID]  = null
	else
		GlobalExclude[spellID]  = true
	end
end


---Updates our GlobalPrefs if changes are made via the GoGoMounts options
--Pram: spellID - spellID to set the table value for
---------
local function GoGo_PassengerMount_update(spellID)
---------
	if ExtraPassengerMounts[spellID] or GoGo_SearchTable(GoGo_Prefs.UnknownMounts, spellID) then
		ExtraPassengerMounts[spellID]  = null
	else
		ExtraPassengerMounts[spellID]  = true
	end
end


---------
local function GoGo_ZoneExcludeMount_update(spellID,ZoneID)
---------
	local zone = ZoneID or GoGo_Variables.Player.MapID
	ZoneMountList[zone] = ZoneMountList[zone] or {["Preferred"] = {}, ["Excluded"] = {},}

	if ZoneMountList[zone]["Excluded"][spellID] or GoGo_SearchTable(GoGo_Prefs.UnknownMounts, spellID) then
		ZoneMountList[zone]["Excluded"][spellID]  = null
	else
		ZoneMountList[zone]["Excluded"][spellID]  = true
	end
end


---------
local function GoGo_ZonePrefMount_update(spellID,ZoneID)
---------
	local zone = ZoneID or GoGo_Variables.Player.MapID
	ZoneMountList[zone] = ZoneMountList[zone] or {["Preferred"] = {}, ["Excluded"] = {},}
	if ZoneMountList[zone]["Preferred"][spellID] or GoGo_SearchTable(GoGo_Prefs.UnknownMounts, spellID) then
		ZoneMountList[zone]["Preferred"][spellID]  = null
	else
		ZoneMountList[zone]["Preferred"][spellID]  = true
	end
end


---------
local function ZonePrefMount(spellID,ZoneID)
---------
	if spellID == nil or ZoneID == nil then
		return
	else
		spellID = tonumber(spellID)
	end

	if GoGo_Variables.Debug >= 10 then
		GoGo_DebugAddLine("GoGo_ZonePrefMount: Preference ID " .. spellID)
	end

	GoGo_Prefs.MapIDs[ZoneID] = GoGo_Prefs.MapIDs[ZoneID] or {["Preferred"] = {},["Excluded"] = {}}

	for GoGo_CounterA = 1, #GoGo_Prefs.MapIDs[ZoneID]["Preferred"] do
		if GoGo_Prefs.MapIDs[ZoneID]["Preferred"][GoGo_CounterA] == spellID then
			table.remove(GoGo_Prefs.MapIDs[ZoneID]["Preferred"], GoGo_CounterA)
			GoGo_ZonePrefMount_update(spellID,ZoneID)
			return -- mount found, removed and now returning
		end
	end

	if not GoGo_SearchTable(GoGo_Prefs.UnknownMounts, spellID) then
		table.insert(GoGo_Prefs.MapIDs[ZoneID]["Preferred"], spellID)
	end

	GoGo_ZonePrefMount_update(spellID,ZoneID)

end

---------
local function ZoneExcludeMount(spellID, ZoneID)
---------
	if spellID == nil or ZoneID==nil then
		return
	else
		spellID = tonumber(spellID)
	end

	if GoGo_Variables.Debug >= 10 then
		GoGo_DebugAddLine("GoGo_ZoneExcludedMount: Excluded ID " .. spellID)
	end

	GoGo_Prefs.MapIDs[ZoneID] = GoGo_Prefs.MapIDs[ZoneID] or {["Preferred"] = {},["Excluded"] = {}}

	for GoGo_CounterA = 1, #GoGo_Prefs.MapIDs[ZoneID]["Excluded"] do
		if GoGo_Prefs.MapIDs[ZoneID]["Excluded"][GoGo_CounterA] == spellID then
			table.remove(GoGo_Prefs.MapIDs[ZoneID]["Excluded"], GoGo_CounterA)
			GoGo_ZoneExcludeMount_update(spellID)
			return
		end
	end

	table.insert(GoGo_Prefs.MapIDs[ZoneID]["Excluded"], spellID)
	GoGo_ZoneExcludeMount_update(spellID,ZoneID)
end


---Initilizes the buttons and creates the appropriate on click behaviour
--Pram: frame - frame that the checkbox should be added to
--Pram: index - index used to refrence the checkbox that is created created
--Return:  checkbox - the created checkbox frame
---------
local function init_button(frame, index)
---------
	local checkbox = CreateFrame("CheckButton", "GGMM"..index, frame, "ChatConfigCheckButtonTemplate")
	checkbox:SetPoint("BOTTOMRIGHT")
	checkbox.spellID = 0
	checkbox:RegisterForClicks("AnyUp")
	checkbox:SetScript("OnClick",
	function(self, button)
		if (checkbox:GetChecked()) and button == "LeftButton" and EnableZoneEdit then
		-- Sets as Perfered Mount
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			ZonePrefMount(checkbox.spellID, selectedZone )
			checkbox:SetCheckedTexture("Interface/Buttons/UI-CheckBox-Check")
			checkbox.tooltip = L.ZONE_ENABLE
		elseif (checkbox:GetChecked()) and button == "LeftButton" and not EnableZoneEdit and not EnablePassengerEdit then  -- Sets as Perfered Mount
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			GoGo_GlobalPrefMount(checkbox.spellID)
			checkbox:SetCheckedTexture("Interface/Buttons/UI-CheckBox-Check")
			checkbox.tooltip = L.GLOBAL_ENABLE

		elseif (checkbox:GetChecked()) and button == "RightButton" and EnableZoneEdit then  -- Sets as Excluded Mount
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			ZoneExcludeMount(checkbox.spellID, selectedZone)
			checkbox:SetCheckedTexture("Interface/Buttons/UI-GROUPLOOT-PASS-DOWN")
			checkbox.tooltip = L.ZONE_EXCLUDE

		elseif (checkbox:GetChecked()) and button == "RightButton" and not EnableZoneEdit and not EnablePassengerEdit then  -- Sets as Excluded Mount
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			GoGo_GlobalExcludeMount(checkbox.spellID)
			checkbox:SetCheckedTexture("Interface/Buttons/UI-GROUPLOOT-PASS-DOWN")
			checkbox.tooltip = L.GLOBAL_EXCLUDE

		elseif not (checkbox:GetChecked()) and EnableZoneEdit  then  -- Removes Settings from GoGoMount
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			if ZoneMountList[selectedZone]["Preferred"][checkbox.spellID] then
				ZonePrefMount(checkbox.spellID, selectedZone )
			end

			if ZoneMountList[selectedZone]["Excluded"][checkbox.spellID] then
				ZoneExcludeMount(checkbox.spellID, selectedZone)
			end
			checkbox.tooltip = L.GLOBAL_CLEAR
		elseif (checkbox:GetChecked()) and button == "LeftButton" and EnablePassengerEdit then --passenger mount
		-- Sets as Perfered Mount
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			GoGo_ExtraPassengerMounts(checkbox.spellID)
			checkbox:SetCheckedTexture("Interface/Buttons/UI-CheckBox-Check")
			checkbox.tooltip = "Pass"
		elseif not (checkbox:GetChecked()) and EnablePassengerEdit then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			GoGo_ExtraPassengerMounts(checkbox.spellID)
			checkbox.tooltip = L.GLOBAL_CLEAR

		elseif not (checkbox:GetChecked()) and not EnableZoneEdit then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			if GlobalPrefs[checkbox.spellID] then
				GoGo_GlobalPrefMount(checkbox.spellID)
			end

			if GlobalExclude[checkbox.spellID] then
				GoGo_GlobalExcludeMount(checkbox.spellID)
			end
			checkbox.tooltip = L.GLOBAL_CLEAR
		end
	  end
	)

	local text = checkbox:CreateFontString(checkbox:GetName() .. "_Text")
	checkbox.text = text
	checkbox.text:SetFont("Fonts\\FRIZQT__.TTF", 15)
	--checkbox.text:SetTextColor(0.85, 0.85, 0.85, 1)
	checkbox.text:ClearAllPoints()
	checkbox.text:SetPoint("RIGHT", checkbox, "LEFT")
	checkbox.text:SetText("Z:")

	return checkbox
end


---Refreshes our global lists to get any changes made from the GoGoMount options
---------
local function RefreshFromGoGoPrefs()
---------
	wipe(GlobalPrefs)
	wipe(GlobalExclude)
	wipe(ZoneMountList)
	wipe(ExtraPassengerMounts)

	if GoGo_Prefs.GlobalPrefMounts then
		for counter = 1, #GoGo_Prefs.GlobalPrefMounts do
			GlobalPrefs[GoGo_Prefs.GlobalPrefMounts[counter]] = true
		end
	end

	if GoGo_Prefs.GlobalExclude then
		for counter = 1, #GoGo_Prefs.GlobalExclude do
			GlobalExclude[GoGo_Prefs.GlobalExclude[counter]] = true
		
		end
	end

	if GoGo_Prefs.ExtraPassengerMounts then
		for counter = 1, #GoGo_Prefs.ExtraPassengerMounts do
			ExtraPassengerMounts[GoGo_Prefs.ExtraPassengerMounts[counter]] = true
		
		end
	end

	if GoGo_Prefs.MapIDs then
		for zone, data in pairs(GoGo_Prefs.MapIDs) do
			ZoneMountList[zone] = {["Preferred"] = {}, ["Excluded"] = {},}

			for counter = 1,#GoGo_Prefs.MapIDs[zone]["Preferred"] do
				ZoneMountList[zone]["Preferred"][GoGo_Prefs.MapIDs[zone]["Preferred"][counter]] = true
			end

			for counter = 1,#GoGo_Prefs.MapIDs[zone]["Excluded"] do
				ZoneMountList[zone]["Excluded"][GoGo_Prefs.MapIDs[zone]["Excluded"][counter]] = true
			end
		end
	end

end


---Updates the checkboxes on Collection Mount List to match GoGoMount set mounts
---------
local function UpdateMountList_Checkboxes()
---------
	local scrollFrame = MountJournal.ListScrollFrame
	local offset = HybridScrollFrame_GetOffset(scrollFrame)
	local buttons = scrollFrame.buttons
	local numMounts = C_MountJournal.GetNumMounts()
	local showMounts = true
	if  ( numMounts < 1 ) then return end  --If there are no mounts then nothing needs to be done.

	local numDisplayedMounts = C_MountJournal.GetNumDisplayedMounts()
	for i=1, #buttons do
		local button = buttons[i]
		local displayIndex = i + offset
		if ( displayIndex <= numDisplayedMounts and showMounts ) then
			local index = displayIndex
			local _, spellID, _, _, isUsable,_, _, _, _, _, isCollected  = C_MountJournal.GetDisplayedMountInfo(index)
			if  button.GGMM then

			else
				button.GGMM = init_button(button, i)
			end

			--Dont let mounts that are not able to be used be selected.
			if isCollected then
				button.GGMM.spellID = spellID
				button.GGMM:SetChecked(false)
				button.GGMM.tooltip = L.GLOBAL_CLEAR
				if EnableZoneEdit then
					button.GGMM.tooltip = L.ZONE_CLEAR
					button.GGMM.text:SetText("Z:")
					button.GGMM.text:Show()
					ZoneMountList[selectedZone] = ZoneMountList[selectedZone] or {["Preferred"]={},["Excluded"]={}}
					if ZoneMountList[selectedZone]["Preferred"][spellID]then
						button.GGMM:SetCheckedTexture("Interface/Buttons/UI-CheckBox-Check")
						button.GGMM:SetChecked(true)
						button.GGMM.tooltip = L.ZONE_ENABLE
					end

					if ZoneMountList[selectedZone]["Excluded"][spellID] then
						button.GGMM:SetCheckedTexture("Interface/Buttons/UI-GROUPLOOT-PASS-DOWN")
						button.GGMM:SetChecked(true)
						button.GGMM.tooltip = L.ZONE_EXCLUDE
					end
				elseif EnablePassengerEdit then 
					button.GGMM.text:SetText("P:")
					button.GGMM.text:Show()

					if ExtraPassengerMounts[spellID] then
						button.GGMM:SetCheckedTexture("Interface/Buttons/UI-CheckBox-Check")
						button.GGMM:SetChecked(true)
						button.GGMM.tooltip = "Passeng"
					end
				else
					button.GGMM.text:Hide()

					if GlobalPrefs[spellID] then
						button.GGMM:SetCheckedTexture("Interface/Buttons/UI-CheckBox-Check")
						button.GGMM:SetChecked(true)
						button.GGMM.tooltip = L.GLOBAL_ENABLE
					end

					if GlobalExclude[spellID] then
						button.GGMM:SetCheckedTexture("Interface/Buttons/UI-GROUPLOOT-PASS-DOWN")
						button.GGMM:SetChecked(true)
						button.GGMM.tooltip = L.GLOBAL_EXCLUDE
					end
				end
				button.GGMM:Show()
			else
				button.GGMM:Hide()
			end

		else
			if button.GGMM then
				button.GGMM:Hide()
			end
		end
	end

	local currentMapID = C_Map.GetBestMapForUnit("player")

	--Sets status message
	if EnableZoneEdit then
		GGMM_ZONE_ALERT:SetText("Zone Based Settings")

	elseif GoGo_Prefs.MapIDs[currentMapID] and (#GoGo_Prefs.MapIDs[currentMapID]["Preferred"] > 0 or #GoGo_Prefs.MapIDs[currentMapID]["Excluded"] > 0) then
		GGMM_ZONE_ALERT:SetText("Zone has Favorite Overides")

	else
		GGMM_ZONE_ALERT:SetText("")
	end
end


---------
function GoGoMount_Manager:UpdateCB()
---------
	UpdateMountList_Checkboxes()
end


---------
function GoGoMount_Manager:SelectedZone()
---------
	return selectedZone
end


--- Gets current Manager profile data and updates the GoGoMount saved variables to match
---------
local function UpdateGoGoMountPrefs()
---------
	GoGo_Prefs.GlobalPrefMounts = {}
	for id in pairs(GlobalPrefs) do
		tinsert(GoGo_Prefs.GlobalPrefMounts,id)
	end

	GoGo_Prefs.GlobalExclude  = {}
	for id in pairs(GlobalExclude) do
		tinsert(GoGo_Prefs.GlobalExclude,id)
	end

	GoGo_Prefs.ExtraPassengerMounts  = {}
	for id in pairs(ExtraPassengerMounts) do
		tinsert(GoGo_Prefs.ExtraPassengerMounts,id)
	end

	GoGo_Prefs.MapIDs  = {}
	for zone, data in pairs(ZoneMountList) do
		GoGo_Prefs.MapIDs[zone] = {["Preferred"] = {}, ["Excluded"] = {},}

		for id in pairs(data["Preferred"]) do
			tinsert(GoGo_Prefs.MapIDs[zone]["Preferred"],id)
		end

		for id in pairs(data["Excluded"]) do
			tinsert(GoGo_Prefs.MapIDs[zone]["Excluded"],id)
		end
	end

end


---------
function GoGoMount_Manager:UpdateGoGoMountPrefs()
---------
	UpdateGoGoMountPrefs()
end


---Ace based addon initilization
---------
function GoGoMount_Manager:OnInitialize()
---------
	self.db = LibStub("AceDB-3.0"):New("GoGoMount_ManagerDB", defaults)
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("GoGoMount_Manager", options)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("GoGoMount_Manager_Zone", zone_options)

	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("GoGoMount_Manager", "GoGoMount_Manager")

	self.db.RegisterCallback(self, "OnProfileChanged", "ChangeProfile")
	self.db.RegisterCallback(self, "OnProfileCopied", "ChangeProfile")
	self.db.RegisterCallback(self, "OnProfileReset", "ResetProfile")
	self.db.RegisterCallback(self, "OnNewProfile", "ResetProfile")


	local LibDualSpec = LibStub('LibDualSpec-1.0')
	LibDualSpec:EnhanceDatabase(self.db, "GoGoMount_Manager")
	LibDualSpec:EnhanceOptions(options.args.profiles, self.db)

	--Hooking GoGoMount funtions
	self:SecureHook("GoGo_GlobalExcludeMount", GoGo_GlobalExcludeMount_update)
	self:SecureHook("GoGo_ExtraPassengerMounts", GoGo_PassengerMount_update)

	self:SecureHook("GoGo_GlobalPrefMount", GoGo_GlobalPrefMount_update)
	self:SecureHook("GoGo_ZoneExcludeMount", GoGo_ZoneExcludeMount_update)
	self:SecureHook("GoGo_ZonePrefMount", GoGo_ZonePrefMount_update)
end


---------
function GoGoMount_Manager:OnEnable()
---------
  	--Link local lists to profile data
	GlobalPrefs = self.db.profile.GlobalPrefs or {}
	GlobalExclude = self.db.profile.GlobalExclude or {}
	ZoneMountList = self.db.profile.ZoneMountList or {}
	ExtraPassengerMounts = self.db.profile.ExtraPassengerMounts or {}

	GoGoMount_Manager:ToggleFixes(self.db.profile.UseFix)
	GoGoMount_Manager:ToggleRandomizer(self.db.profile.ForceRandom)
	self:SecureHook("GoGo_GetMountDB", "AddMissingMounts")
	GoGo_GetMountDB()

	GoGoMount_Manager:SyncPrefs()

	--Hooking MountJournal functions
	LoadAddOn("Blizzard_Collections")
	self:SecureHook("MountJournal_UpdateMountList", UpdateMountList_Checkboxes)
	self:SecureHook(MountJournal.ListScrollFrame,"update", UpdateMountList_Checkboxes)

	GoGoMount_Manager:Build()
	GoGoMount_Manager.JournalFilter:OnLogin()
	GoGoMount_Manager.JournalFilter:LoadUI()
	GoGoMount_Manager.JournalFilter:InitDropdown()
end


---Resets current profile
---------
function GoGoMount_Manager:ResetProfile()
---------
	wipe(GoGoMount_Manager.db.profile)
	GlobalPrefs = {}
	GlobalExclude = {}
	ZoneMountList = {}
	ExtraPassengerMounts = {}
	GoGoMount_Manager:SyncPrefs()
	GoGoMount_Manager:UpdateCB()
end


--Updates mount list to be selected profile
---------
function GoGoMount_Manager:ChangeProfile()
---------
	GlobalPrefs = self.db.profile.GlobalPrefs or {}
	GlobalExclude = self.db.profile.GlobalExclude or {}
	ZoneMountList = self.db.profile.ZoneMountList or {}
	ExtraPassengerMounts = self.db.profile.ExtraPassengerMounts or {}
	GoGoMount_Manager:SyncPrefs()
	GoGoMount_Manager:UpdateCB()
end


---Syncs mount prefrence lists between GoGoMount & GoGoMount_Manager
---------
function GoGoMount_Manager:SyncPrefs()
---------
	--if initial run rebuilds tables based on current GoGoMount selections
	if GoGoMount_Manager.db.profile.init then
		RefreshFromGoGoPrefs()
		GoGoMount_Manager.db.profile.init = false

	--sets GoGoMount selections to be what is stored in the profile.
	else
		UpdateGoGoMountPrefs()
	end
end


--clears all global favorites
---------
function GoGoMount_Manager:ClearGlobalFav()
---------
	GoGo_Prefs.GlobalPrefMounts = {}
	RefreshFromGoGoPrefs()
	UpdateMountList_Checkboxes()
end


--clears global exclusions
---------
function GoGoMount_Manager:ClearGlobalExclude()
---------
	GoGo_Prefs.GlobalExclude = {}
	RefreshFromGoGoPrefs()
	UpdateMountList_Checkboxes()
end


--clears current zone favorites
---------
function GoGoMount_Manager:ClearZoneFavorites()
---------
	GoGo_Prefs.MapIDs[selectedZone] = {["Preferred"] = {},["Excluded"] = {},}
	RefreshFromGoGoPrefs()
	UpdateMountList_Checkboxes()
end


--clears all zone favorites
---------
function GoGoMount_Manager:ClearAllZoneFavorites()
---------
	wipe(GoGo_Prefs.MapIDs)
	RefreshFromGoGoPrefs()
	UpdateMountList_Checkboxes()
end


--Builds the menu frame for the Mount Journal
---------
function GoGoMount_Manager:Build()
---------
	local f = CreateFrame('Frame', "GoGoMountManager_ZoneMenu", MountJournal)
	f:SetClampedToScreen(true)
	f:SetSize(250, 160)
	f:SetPoint("TOPLEFT",MountJournal,"TOPRIGHT")
	f:SetPoint("BOTTOMLEFT",MountJournal,"BOTTOMRIGHT")
	f:Hide()
	f:EnableMouse(true)
	f:SetFrameStrata('HIGH')
	f:SetMovable(false)
	f:SetToplevel(true)

	f.border = f:CreateTexture()
	f.border:SetAllPoints()
	f.border:SetColorTexture(0,0,0,1)
	f.border:SetTexture([[Interface\Tooltips\UI-Tooltip-Background]])
	f.border:SetDrawLayer('BORDER')

	f.background = f:CreateTexture()
	f.background:SetPoint('TOPLEFT', f, 'TOPLEFT', 1, -1)
	f.background:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', 65, 1)
	--f.background:SetColorTexture(0.1,0.1,0.1,1)
	f.background:SetTexture("Interface\\PetBattles\\MountJournal-BG")
	f.background:SetDrawLayer('ARTWORK')

	local close_ = CreateFrame("Button", nil, f)
	close_:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
	close_:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
	close_:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	close_:SetSize(32, 32)
	close_:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	close_:SetScript("OnClick", function(self)
		self:GetParent():Hide()
		self:GetParent().free = true
	end)

	f.close = close_

	local content = CreateFrame("Frame",nil, f)
	content:SetPoint("TOPLEFT",15,-15)
	content:SetPoint("BOTTOMRIGHT",-15,15)
	--This creats a cusomt AceGUI container which lets us imbed a AceGUI menu into our frame.
	local widget = {
		frame     = f,
		content   = content,
		type      = "GGMMContainer"
	}
	widget["OnRelease"] = function(self)
		self.status = nil
		wipe(self.localstatus)
	end

	f:SetScript("OnShow", function(self)
		selectedZone = C_Map.GetBestMapForUnit("player")
		ZoneList = {[C_Map.GetBestMapForUnit("player")]=C_Map.GetMapInfo(C_Map.GetBestMapForUnit("player")).name}
		selectedCont = nil
		EnableZoneEdit = false
		LibStub("AceConfigDialog-3.0"):Open("GoGoMount_Manager_Zone", widget, "zoneoptions")
		f:Show()
		end)

	f:SetScript("OnHide", function(self)
		selectedZone =C_Map.GetBestMapForUnit("player")
		ZoneList = {[C_Map.GetBestMapForUnit("player")]=C_Map.GetMapInfo(C_Map.GetBestMapForUnit("player")).name}
		selectedCont = nil
		EnableZoneEdit = false
		GoGoMount_Manager:UpdateCB()
		f:Hide()
		end)

	LibStub("AceGUI-3.0"):RegisterAsContainer(widget)

	local mountButton = CreateFrame("Button", nil , MountJournal)
	mountButton:SetNormalTexture("Interface\\Buttons\\UI-MicroButton-Mounts-Up")
	mountButton:SetPushedTexture("Interface\\Buttons\\UI-MicroButton-Mounts-Down")
	mountButton:SetPoint("BOTTOMRIGHT", MountJournal, "BOTTOMRIGHT", 0, 0)
	mountButton:SetWidth(30)
	mountButton:SetHeight(45)
	mountButton:SetScript("OnClick", function(self, button, down)
		local Shift = IsShiftKeyDown()
		if Shift then
			selectedZone = C_Map.GetBestMapForUnit("player")
			EnableZoneEdit = not EnableZoneEdit
			GoGoMount_Manager:UpdateCB()
		else
			if f:IsShown() then
				f:Hide()
			else
				f:Show()
			end
		end

	end)
	mountButton:SetScript("OnEnter",
		function(self)
			GameTooltip:SetOwner (self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L.GOGOMOUNT_BUTTON_TOOLTIP, 1, 1, 1)
			GameTooltip:Show()
		end
	)
	mountButton:SetScript("OnLeave",
		function()
			GameTooltip:Hide()
		end
	)

	local text = mountButton:CreateFontString("GGMM_ZONE_ALERT")
	mountButton.text = text
	mountButton.text:SetFont("Fonts\\FRIZQT__.TTF", 15)
	mountButton.text:SetTextColor(1, 0, 0, 1)
	mountButton.text:ClearAllPoints()
	mountButton.text:SetPoint("LEFT", MountJournalMountButton, "RIGHT",10,-3)
	mountButton.text:SetText("Zone has Favorite Overides")

end


--GOGOMount Fixes:  Small code tweaks to fix some issues with GoGoMount until they are officialy fixed

--Currently the if favorite mounts are selected instant casts are not found due to not being in the filtered list.
--This builds a list of "special" mounts (IE forms, spells, items) that are not included when global/zone favorites are set and adds them
-- to the passed list
local GoGo_MountList = {}

---------
function GoGoMount_Manager:BuildSpecialMountList(FilteredMountList)
---------
	if not GoGoMount_Manager.db.profile.UseFix or #FilteredMountList == 0  then return end

	GoGo_MountList = {}

	if GoGo_Variables.Player.Class == "DRUID" then
		if GoGo_InBook(GoGo_Variables.Localize.AquaForm) then
			table.insert(GoGo_MountList, GoGo_Variables.Localize.AquaForm)
		end
		if GoGo_InBook(GoGo_Variables.Localize.CatForm) then
			table.insert(GoGo_MountList, GoGo_Variables.Localize.CatForm)
		end
		if GoGo_InBook(GoGo_Variables.Localize.FlightForm) then  -- may not be used any more since Warcraft 6.0
			table.insert(GoGo_MountList, GoGo_Variables.Localize.FlightForm)
		end
		if GoGo_InBook(GoGo_Variables.Localize.FastFlightForm) then  -- may not be used any more since Warcraft 6.0
			table.insert(GoGo_MountList, GoGo_Variables.Localize.FastFlightForm)
		end
		if GoGo_InBook(165962) then  -- Flight Form that appears with "Glyph of the Stag" in Warcraft 6.0
			table.insert(GoGo_MountList, 165962)
		end
		if GoGo_InBook(GoGo_Variables.Localize.TravelForm) then
			table.insert(GoGo_MountList, GoGo_Variables.Localize.TravelForm)
		end
	elseif GoGo_Variables.Player.Class == "SHAMAN" then
		if GoGo_InBook(GoGo_Variables.Localize.GhostWolf) then
			table.insert(GoGo_MountList, GoGo_Variables.Localize.GhostWolf)
		end

	elseif GoGo_Variables.Player.Class == "MONK" then
		if GoGo_InBook(GoGo_Variables.Localize.ZenFlight) then
			table.insert(GoGo_MountList, GoGo_Variables.Localize.ZenFlight)
			GoGo_TableAddUnique(GoGo_Variables.AirSpeed, 160)
		end
	end

	if GoGo_Variables.Player.Race == "Worgen" then
		if (GoGo_InBook(GoGo_Variables.Localize.RunningWild)) then
			if GoGo_Variables.Debug >= 10 then
				GoGo_DebugAddLine("GoGo_BuildMountList: We are a Worgen and have Running Wild - added to known mount list.")
			end
			table.insert(GoGo_MountList, GoGo_Variables.Localize.RunningWild)
		end
	end

	for MountItemID, MountItemData in pairs(GoGo_Variables.MountItemIDs) do
		local GoGo_SpellId = GoGo_Variables.MountItemIDs[MountItemID][50000]
		if GoGo_Variables.MountItemIDs[MountItemID][51000] then  -- in bag items
			if GoGo_InBags(MountItemID) then
				if GoGo_Variables.Debug >= 10 then
					GoGo_DebugAddLine("GoGo_BuildMountList: Found mount item ID " .. MountItemID .. " in a bag and added to known mount list.")
				end
				table.insert(GoGo_MountList, GoGo_SpellId)
			end
		elseif GoGo_Variables.MountItemIDs[MountItemID][51001] then  -- equipable items
			if IsEquippedItem(MountItemID) or GoGo_InBags(MountItemID) then
				table.insert(GoGo_MountList, GoGo_SpellId)
			end
		end
	end

	-- WoD Nagrand's Garrison mounts
	GoGo_Variables.Player.MapID = C_Map.GetBestMapForUnit("player")
	if GoGo_Variables.Player.MapID == 550 then
		-- or 551, 552, 553 TODO
		local name = GetSpellInfo(161691)
		spellID = select(7, GetSpellInfo(name))
		if spellID == 165803 or spellID == 164222 then
			table.insert(GoGo_MountList, spellID)
		end
	end


	--Adds any special mounts to the passed Mount List
	for index, mountID in pairs(GoGo_MountList) do
		if not GoGo_SearchTable(FilteredMountList, mountID) then
			table.insert(FilteredMountList,mountID)
		end
	end

end


--Fixes GoGoMount trying to look up profession skills based on old level.  We really dont care about profession levels any more
--as the default api will tell us if a character has the profession/skill via the C_MountJournal.GetMountInfoByID is usable flag
--Just returning a large number to have GoGoMount skip any profession based filtering
---------
local function GoGo_GetProfSkillLevel_Fix()
---------
	return 900
end


local listSize = 0
--GoGo_RemoveUnusableMounts did not properly remove mounts due to IsUsableSpell not being reliable bacuse the spell to cast an unuaable mount will always return true.
--Needs to verify that the mount is actually useable via the mount list
---------
local function GoGo_RemoveUnusableMounts_Fix(MountList)  -- Remove mounts Blizzard says we can't use due to location, timers, etc.
---------
	if not MountList or #MountList == 0 then
		return {}
	end

	local GoGo_NewTable = {}
	for a=1,#MountList do
		local GoGo_SpellID = MountList[a]
		if not GoGo_SearchTable(GoGo_Prefs.UnknownMounts, GoGo_SpellID) then		-- if mount spell is unknown then don't search the database - it's not in it
			if GoGo_Variables.MountDB[GoGo_SpellID][50000] then
				-- item mount, check item status
				local GoGo_ItemID = GoGo_Variables.MountDB[GoGo_SpellID][50000]  -- get item id
				if GoGo_Variables.MountItemIDs[GoGo_ItemID][51000] then  -- if item should be in bags
					if GoGo_InBags(GoGo_ItemID) then  -- if item is in bag
						if GetItemCooldown(GoGo_ItemID) == 0 then  -- if item doens't have a cooldown timer
							if IsUsableItem(GoGo_ItemID) then  -- if item can be used
								table.insert(GoGo_NewTable, GoGo_SpellID)
							end
						end
					end
				elseif GoGo_Variables.MountItemIDs[GoGo_ItemID][51001] then  -- if item should be equiped
					if IsEquippedItem(GoGo_ItemID) then  -- if item is equipped
						if GetItemCooldown(GoGo_ItemID) == 0 then  -- if item doens't have a cooldown timer
							if IsUsableItem(GoGo_ItemID) then  -- if item can be used
								table.insert(GoGo_NewTable, GoGo_SpellID)
							end
						end
					end
				end
			else  -- it's a mount spell or class shape form
				--Lookup the mount ID and verify if it is actuallu usable
				if spell_to_id[GoGo_SpellID] then
					isUsable = select(5, C_MountJournal.GetMountInfoByID(spell_to_id[GoGo_SpellID]))
					if isUsable then
						table.insert(GoGo_NewTable, GoGo_SpellID)
					end

				elseif IsUsableSpell(GoGo_SpellID) then  -- don't use IsSpellKnown() - mounts in collection are not known... morons....
					table.insert(GoGo_NewTable, GoGo_SpellID)

				end

			end
		end
	end
	listSize = #GoGo_NewTable
	return GoGo_NewTable
end


--Fix for the change to the returned data of GetShapeshiftFormInfo()
---------
local function GoGo_IsShifted_Fix()
---------
	if GoGo_Variables.Debug >= 10 then
		GoGo_DebugAddLine("GoGo_IsShifted:  GoGo_IsShifted starting")
	end

	for i = 1, GetNumShapeshiftForms() do
		local icon, active, castable, spellID = GetShapeshiftFormInfo(i)
		if active then
			if GoGo_Variables.Debug >= 10 then
				GoGo_DebugAddLine("GoGo_IsShifted: Found " .. name)
			end

			return spellID
		end
	end
end


--Toggle using fixes or not
---------
function GoGoMount_Manager:ToggleFixes(toggle)
---------
	if toggle then
		self:RawHook("GoGo_IsShifted",GoGo_IsShifted_Fix, true)
		self:RawHook("GoGo_GetProfSkillLevel",GoGo_GetProfSkillLevel_Fix, true)
		self:RawHook("GoGo_RemoveUnusableMounts",GoGo_RemoveUnusableMounts_Fix, true)
		self:Hook("GoGo_CheckForUnknownMounts","BuildSpecialMountList", true)
		
	else
		self:Unhook("GoGo_IsShifted")
		self:Unhook("GoGo_GetProfSkillLevel")
		self:Unhook("GoGo_RemoveUnusableMounts")
		self:Unhook("GoGo_CheckForUnknownMounts")
	end
end


--Looks in the mount journal and adds missing mounts to the GoGoMountDB
---------
function GoGoMount_Manager:AddMissingMounts()
---------
	if not GoGoMount_Manager.db.profile.AddMissingMounts then return end
	GoGo_Prefs.UnknownMounts = {}
	local spellID, mountType, mountName
	for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
		mountName, spellID = C_MountJournal.GetMountInfoByID(mountID)
		mountType = select(5, C_MountJournal.GetMountInfoExtraByID(mountID))
		if GoGo_Variables.MountDB[spellID] == nil and mountType ~= 242 then
			if  MountDefaults[mountType] == nil then
				--GoGo_Msg(UnknownMount)
			else
				GoGo_Variables.MountDB[spellID] = MountDefaults[mountType]
				--print(MountDefaults[mountType]["type"].." Mount: "..mountName.."(".. spellID..")" .." added.")
			end

		end
	end
	GoGoMount_Manager:UpdateGoGoMountPrefs()
end


---------
local function SearchTable(Table, Value)
---------
	if type(Table) == "table" and #Table > 0 then
		for a=1, #Table do
			if Table[a] == Value then
				return true
			end
		end
	end
	return false
end


---------
function GoGoMount_Manager:ToggleRandomizer(toggle)
---------
	if toggle then
		self:RawHook("GoGo_ChooseMount","RandomizeMount", true)
		--GoGo_ChooseMount = GoGoMount_Manager.RandomizeMount

	else
		--GoGo_ChooseMount = GoGo_ChooseMount_hook
		self:Unhook("GoGo_ChooseMount")
	end
end


local lastmount = ""
--Function to try to prevent the same mount from being chosen multiple times in a row
---------
function GoGoMount_Manager:RandomizeMount()
---------
	local selectedMount = self.hooks.GoGo_ChooseMount()
	local keepSize = min(GoGoMount_Manager.db.profile.HistorySize, listSize)
	local breakpoint = 3
	local duplicatePick = SearchTable(recentMounts, selectedMount)
	local counter = 0

	while duplicatePick do
		selectedMount = self.hooks.GoGo_ChooseMount()

		if selectedMount == lastmount then 
			selectedMount = self.hooks.GoGo_ChooseMount()
		end

		counter = counter + 1
		duplicatePick = SearchTable(recentMounts, selectedMount)
		
		if counter > keepSize + 1 then 
			break
		end
	end

	table.insert(recentMounts, selectedMount)

	if #recentMounts > keepSize then
		table.remove(recentMounts, 1)
	end

	for i, name in pairs(recentMounts) do
	--print(name)
	end
	--print("---")
	lastmount = selectedMount

	return selectedMount
end
