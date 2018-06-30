--[[
	Copyright 2016 tyra <https://twitter.com/tyra_314>. All rights reserved.

	This work is licensed under the Creative Commons Attribution-NonCommercial-
	ShareAlike 4.0 International License. To view a copy of this license, visit
	http://creativecommons.org/licenses/by-nc-sa/4.0/ or send a letter to
	Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
]]


local function DebugLog(...)
--@debug@
printResult = "|cffFF6A00Smart Quest Tracker|r: "
for i,v in ipairs({...}) do
	printResult = printResult .. tostring(v) .. " "
end
print(printResult)
DEFAULT_CHAT_FRAME:AddMessage(printResult)
--@end-debug@
end

MyPlugin = LibStub("AceAddon-3.0"):NewAddon("SmartQuestTracker", "AceConsole-3.0", "AceEvent-3.0")

local autoTracked = {}
local autoRemove
local autoSort
local removeComplete
local showDailies

-- control variables to pass arguments from on event handler to another
local skippedUpdate = false
local updateQuestIndex = nil
local newQuestIndex = nil
local doUpdate = false

local function getQuestInfo(index)
	local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, startEvent, displayQuestID, isOnMap, hasLocalPOI, isTask, isStory = GetQuestLogTitle(index)

	if isHeader then
		return nil
	end

	local questMapId = GetQuestUiMapID(questID)
	local distance, reachable = GetDistanceSqToQuest(index)
	local areaid = C_Map.GetBestMapForUnit("player");
	local isTracked = IsQuestWatched(index)

    local isDaily = frequency == LE_QUEST_FREQUENCY_DAILY
	local isWeekly =  frequency == LE_QUEST_FREQUENCY_WEEKLY
	local isRepeatable = isDaily or isWeekly
	local isLocal = questMapId == areaid or (questMapId == 0 and isOnMap) --or hasLocalPOI
	local isCompleted = isComplete ~= nil
	local isAutoTracked = autoTracked[questID] == true
	local tagId = GetQuestTagInfo(questID)
	local isInstance = false
	if tagId then
	    isInstance = tagId == QUEST_TAG_DUNGEON or tagId == QUEST_TAG_HEROIC or tagId == QUEST_TAG_RAID or tagId == QUEST_TAG_RAID10 or tagId == QUEST_TAG_RAID25
	end
	local playerInInstance, _ = IsInInstance()
	if isInstance and not playerInInstance and not isCompleted then
		isLocal = false
	end

	local quest = {};

    quest["id"] = questID
    quest["mapID"] = tostring(questMapId)
    quest["areaLocal"] = questMapId == areaid
    quest["isOnMap"] = questMapId == 0 and isOnMap
    quest["hasLocalPOI"] = hasLocalPOI
    quest["isInstance"] = isInstance
    quest["title"] = title
    quest["isLocal"] = isLocal
    quest["distance"] = distance
    quest["isRepeatable"] = isRepeatable
    quest["isDaily"] = isDaily
    quest["isWeekly"] = isWeekly
    quest["isCompleted"] = isCompleted
    quest["isTracked"] = isTracked
    quest["isAutoTracked"] = isAutoTracked
	quest["isWorldQuest"] = isTask

	return quest
end

local function trackQuest(index, quest, markAutoTracked)
	if (not quest["isTracked"]) or markAutoTracked then
		if not quest["isWorldQuest"] then
			autoTracked[quest["id"]] = true
		end
		AddQuestWatch(index)
	end

    if autoSort then
		SortQuestWatches()
	end
end

local function untrackQuest(index, quest)
	if quest["isAutoTracked"] and autoRemove then
        autoTracked[quest["id"]] = nil
		RemoveQuestWatch(index)
	end

    if autoSort then
		SortQuestWatches()
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

local function run_update()
	DebugLog("Running full update")

	local inInstance, instanceType = IsInInstance()
	local numEntries, _ = GetNumQuestLogEntries()
	for questIndex = 1, numEntries do
		local quest = getQuestInfo(questIndex)
		if not (quest == nil) then
			if quest["isCompleted"] and removeComplete then
				untrackQuest(questIndex, quest)
			elseif quest["isLocal"] then
				trackQuest(questIndex, quest)
			elseif showDailies and quest["isDaily"] and not inInstance then
				trackQuest(questIndex, quest)
			elseif showDailies and quest["isWeekly"] then
				trackQuest(questIndex, quest)
			else
				untrackQuest(questIndex, quest)
			end
		end
	end
	if autoSort then
		SortQuestWatches()
	end
end

local function debugPrintQuestsHelper(onlyWatched)
	local areaid = C_Map.GetBestMapForUnit("player");
	print("#########################")
	print("Current MapID: " .. areaid)

	local inInstance, instanceType = IsInInstance()

	print("In instance: " .. tostring(inInstance))
	print("Instance type: " .. instanceType)

	local numEntries, numQuests = GetNumQuestLogEntries()
	print(numQuests .. " Quests in " .. numEntries .. " Entries.")
	local numWatches = GetNumQuestWatches()
	print(numWatches .. " Quests tracked.")
	print("#########################")

	for questIndex = 1, numEntries do
		local quest = getQuestInfo(questIndex)
		if not (quest == nil) then
			if (not onlyWatched) or (onlyWatched and quest["isTracked"]) then
				print("--------------" .. questIndex .. "--------------")
				print("#" .. quest["id"] .. " - |cffFF6A00" .. quest["title"] .. "|r")
				print("Completed: ".. tostring(quest["isCompleted"]))
				print("IsLocal: " .. tostring(quest["isLocal"]))
                print("MapID: " .. tostring(quest["mapID"]))
                print("IsAreaLocal: " .. tostring(quest["areaLocal"]))
                print("IsOnMap: " .. tostring(quest["isOnMap"]))
                print("hasLocalPOI: " .. tostring(quest["hasLocalPOI"]))
                print("isInstance: " .. tostring(quest["isInstance"]))
				print("Distance: " .. quest["distance"])
				print("AutoTracked: " .. tostring(quest["isAutoTracked"]))
				print("Is repeatable: " .. tostring(quest["isRepeatable"]))
				print("Is Daily: " .. tostring(quest["isDaily"]))
				print("Is Weekly: " .. tostring(quest["isWeekly"]))
			end
		end
	end
end

function MyPlugin:Update()
	autoRemove = self.db.profile.AutoRemove
	autoSort =  self.db.profile.AutoSort
	removeComplete = self.db.profile.RemoveComplete
	showDailies = self.db.profile.ShowDailies

    untrackAllQuests()
	-- doUpdate = true
	run_update()
end

-- event handlers

function MyPlugin:QUEST_WATCH_UPDATE(event, questIndex)
	DebugLog("Update for quest:", questIndex)
	run_update()
end

function MyPlugin:QUEST_LOG_UPDATE(event)
 	DebugLog("Running update for quests")
	run_update()
end

function MyPlugin:QUEST_ACCEPTED(event, questIndex)
	DebugLog("Accepted new quest:", questIndex)
	run_update()
end

function MyPlugin:QUEST_REMOVED(event, questIndex)
	DebugLog("REMOVED:", questIndex)
	autoTracked[questIndex] = nil
	run_update()
end

function MyPlugin:ZONE_CHANGED()
	run_update()
end

function MyPlugin:ZONE_CHANGED_NEW_AREA()
	run_update()
end

function MyPlugin:BuildOptions()
	local options = {
		order = 100,
		type = "group",
		name = "|cffFF6A00Smart Quest Tracker|r",
		handler = MyPlugin,
		args = {
			clear = {
				order = 1,
				type = "group",
				name = "Untrack quests when changing area",
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
							MyPlugin:Update() --We changed a setting, call our Update function
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
							MyPlugin:Update() --We changed a setting, call our Update function
						end,
					},
					showDailies = {
						order = 3,
						type = "toggle",
						name = "Keep daily and weekly quest tracked",
						get = function(info)
							return self.db.profile.ShowDailies
						end,
						set = function(info, value)
							self.db.profile.ShowDailies = value
							MyPlugin:Update()
						end,
					},
				},
			},
			sort = {
				order = 2,
				type = "group",
				name = "Sorting of quests in tracker",
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
							MyPlugin:Update()
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
					print = {
						type = 'execute',
						order = 2,
						name = 'Print all quests to chat',
						func = function() debugPrintQuestsHelper(false) end,
					},
					printWatched = {
						type = 'execute',
						order = 3,
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
						order = 4,
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

function MyPlugin:OnInitialize()
	local defaults = {
	  profile = {
		AutoSort = true,
		AutoRemove = true,
		RemoveComplete = false,
		ShowDailies = false
	  }
	}

	self.db = LibStub("AceDB-3.0"):New("SmartQuestTrackerDB", defaults)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("SmartQuestTracker", MyPlugin:BuildOptions(), {"sqt", "SmartQuestTracker"})

	self.profilesFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SmartQuestTracker");

	--Register event triggers
    MyPlugin:RegisterEvent("ZONE_CHANGED")
    MyPlugin:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    MyPlugin:RegisterEvent("QUEST_WATCH_UPDATE")
    MyPlugin:RegisterEvent("QUEST_LOG_UPDATE")
    MyPlugin:RegisterEvent("QUEST_ACCEPTED")
	MyPlugin:RegisterEvent("QUEST_REMOVED")

	MyPlugin:Update()
end
