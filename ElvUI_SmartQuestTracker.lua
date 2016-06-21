--[[
	Copyright 2016 tyra <https://twitter.com/tyra_314>. All rights reserved.

	This work is licensed under the Creative Commons Attribution-NonCommercial-
	ShareAlike 4.0 International License. To view a copy of this license, visit
	http://creativecommons.org/licenses/by-nc-sa/4.0/ or send a letter to
	Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
]]

MyAddon = LibStub("AceAddon-3.0"):NewAddon("SmartQuestTracker", "AceConsole-3.0", "AceEvent-3.0")

local autoTracked = {}
local autoRemove
local autoSort
local removeComplete

local function getQuestId(index)
 	local _, _, _, _, _, _, _, id, _, _, _, _, _, _ = GetQuestLogTitle(index)

	return id
end

local function trackQuest(index, markAutoTracked)
	local questID = getQuestId(index)
	local isWatched = IsQuestWatched(index)

	if (not isWatched) or markAutoTracked then
		autoTracked[questID] = true
		AddQuestWatch(index)
	end
end

local function untrackQuest(index)
	local questID = getQuestId(index)

	if autoTracked[questID] and autoRemove then
		autoTracked[questID] = nil
		RemoveQuestWatch(index)
	end
end

local function untrackAllQuests()
	local numEntries, _ = GetNumQuestLogEntries()

	for index = 1, numEntries do
		local _, _, _, isHeader, _, _, _, _, _, _, _, _, _, _ = GetQuestLogTitle(index)
		if ( not isHeader) then
			RemoveQuestWatch(index)
		end
	end

	autoTracked = {}
end

local function debugPrintQuestsHelper(onlyWatched)
	local areaid = GetCurrentMapAreaID();
	print("#########################")
	print("Current MapID: " .. areaid)
	local numEntries, numQuests = GetNumQuestLogEntries()
	print(numQuests .. " Quests in " .. numEntries .. " Entries.")
	local numWatches = GetNumQuestWatches()
	print(numWatches .. " Quests tracked.")
	print("#########################")

	for questIndex = 1, numEntries do
		local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory = GetQuestLogTitle(questIndex)
		if ( not isHeader) then
			local questMapId, questFloorId = GetQuestWorldMapAreaID(questID)
			local distance, reachable = GetDistanceSqToQuest(questIndex)
			if (not onlyWatched) or (onlyWatched and IsQuestWatched(questIndex)) then
				print("#" .. questID .. " - |cffFF6A00" .. title .. "|r")
				print("Completed: ".. tostring(isComplete))
				print("MapID: " .. questMapId .. " - IsOnMap: " .. tostring(isOnMap) .. " - hasLocalPOI: " .. tostring(hasLocalPOI))
				print("Distance: " .. distance)
				if autoTracked[questID] then
					print("AutoTracked: yes")
				else
					print("AutoTracked: no")
				end
			end
		end
	end
end

local function run_update()
	local areaid = GetCurrentMapAreaID();
	local numEntries, _ = GetNumQuestLogEntries()
	for questIndex = 1, numEntries do
		local title, _, _, isHeader, _, isComplete, _, questID, _, _, isOnMap, hasLocalPOI, _, _ = GetQuestLogTitle(questIndex)
		if ( not isHeader) then
			local questMapId, _ = GetQuestWorldMapAreaID(questID)
			if (isComplete and removeComplete) then
				untrackQuest(questIndex)
			elseif questMapId == areaid or (questMapId == 0 and isOnMap) or hasLocalPOI then
				trackQuest(questIndex)
			else
				untrackQuest(questIndex)
			end
		end
	end
	if autoSort then
		SortQuestWatches()
	end
end

function MyAddon:Update()
	autoRemove = self.db.profile.AutoRemove
	autoSort =  self.db.profile.AutoSort
	removeComplete = self.db.profile.RemoveComplete

	run_update()
end

function MyAddon:QUEST_WATCH_UPDATE(event, questIndex)
	local _, _, _, _, _, isComplete, _, _, _, _, _, _, _, _ = GetQuestLogTitle(questIndex)
	if (removeComplete and isComplete) then
		untrackQuest(questIndex)
	else
		trackQuest(questIndex, true)
	end
end

function MyAddon:QUEST_ACCEPTED(event, questIndex)
	trackQuest(questIndex, true)
end

function MyAddon:ZONE_CHANGED()
	run_update()
end

function MyAddon:ZONE_CHANGED_NEW_AREA()
	run_update()
end

function MyAddon:BuildOptions()
	local options = {
		order = 100,
		type = "group",
		name = "|cffFF6A00Smart Quest Tracker|r",
		handler = MyAddon,
		args = {
			clear = {
				order = 1,
				type = "group",
				name = 'Untrack quests when changing area',
				guiInline = true,
				args = {
					removecomplete = {
						order = 1,
						type = "toggle",
						name = "Completed quests",
						get = function(info)
							return self.db.profile.RemoveComplete
						end,
						set = function(info, value)
							self.db.profile.RemoveComplete = value
							MyAddon:Update()
						end,
					},
					autoremove = {
						order = 2,
						type = "toggle",
						name = "Quests from other areas",
						get = function(info)
							return self.db.profile.AutoRemove
						end,
						set = function(info, value)
							self.db.profile.AutoRemove = value
							MyAddon:Update()
						end,
					},
				},
			},
			sort = {
				order = 2,
				type = "group",
				name = 'Sort of quests in tracker',
				guiInline = true,
				args = {
					autosort = {
						order = 1,
						type = "toggle",
						name = "Automatically sort quests",
						get = function(info)
							return self.db.profile.AutoSort
						end,
						set = function(info, value)
							self.db.profile.AutoSort = value
							MyAddon:Update()
						end,
					},
				},
			},
			debug = {
				order = 3,
				type = "group",
				name = "Debug",
				guiInline = true,
				args = {
					printAll = {
						type = 'execute',
						order = 1,
						name = 'Print all quests to chat',
						func = function() debugPrintQuestsHelper(false) end,
					},
					printTracked = {
						type = 'execute',
						order = 1,
						name = 'Print tracked quests to chat',
						func = function() debugPrintQuestsHelper(true) end,
					},
					untrack = {
						type = 'execute',
						order = 1,
						name = 'Untrack all quests',
						func = function() untrackAllQuests() end,
					},
					update = {
						type = 'execute',
						order = 1,
						name = 'Force update of tracked quests',
						func = function() run_update() end,
					},
				},
			},
		},
	}

	options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	return options
end

function MyAddon:OnInitialize()
	local defaults = {
	  profile = {
		AutoSort = true,
		AutoRemove = true,
		RemoveComplete = false
	  }
	}

	self.db = LibStub("AceDB-3.0"):New("SmartQuestTrackerDB", defaults)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("SmartQuestTracker", MyAddon:BuildOptions(), {"sqt", "SmartQuestTracker"})

	self.profilesFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SmartQuestTracker");

	--Register event triggers
	MyAddon:RegisterEvent("ZONE_CHANGED")
	MyAddon:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	MyAddon:RegisterEvent("QUEST_WATCH_UPDATE")
	MyAddon:RegisterEvent("QUEST_ACCEPTED")

	untrackAllQuests()
	MyAddon:Update()
end
