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

MyPlugin = LibStub("AceAddon-3.0"):NewAddon("SmartQuestTracker", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

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
	local _, _, _, isHeader, _, isComplete, frequency, questID, _, _, isOnMap, _, isTask, _ = GetQuestLogTitle(index)

	if isHeader then
		return nil
	end

	local questMapId, _ = GetQuestWorldMapAreaID(questID)

    local isDaily = frequency == LE_QUEST_FREQUENCY_DAILY
	local isWeekly =  frequency == LE_QUEST_FREQUENCY_WEEKLY

	local isCompleted = isComplete ~= nil

	local tagId = GetQuestTagInfo(questID)
	local isInstance = tagId == QUEST_TAG_DUNGEON or tagId == QUEST_TAG_HEROIC or tagId == QUEST_TAG_RAID or tagId == QUEST_TAG_RAID10 or tagId == QUEST_TAG_RAID25

	return questID, questMapId, isOnMap, isCompleted, isDaily, isWeekly, isInstance, isTask
end

local function trackQuest(index, questID, markAutoTracked)
	if autoTracked[questID] ~= true and markAutoTracked then
		autoTracked[questID] = true
		AddQuestWatch(index)
	end

    if autoSort then
		SortQuestWatches()
	end
end

local function untrackQuest(index, questID)
	if autoTracked[questID] == true then
		RemoveQuestWatch(index)
	end

	autoTracked[questID] = nil

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
	--@debug@
	DebugLog("Running full update")
	--@end-debug@
	MyPlugin:RunUpdate()
end

local function debugPrintQuestsHelper(onlyWatched)
	local areaid = GetCurrentMapAreaID();
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
		local questID, questMapId, isOnMap, isCompleted, isDaily, isWeekly, isInstance, isWorldQuest = getQuestInfo(questIndex)
		if not (questID == nil) then
			if (not onlyWatched) or (onlyWatched and autoTracked[questID] == true) then
				print("#" .. questID .. " - |cffFF6A00" .. select(1, GetQuestLogTitle(questIndex)) .. "|r")
                print("MapID: " .. tostring(questMapId) .. " IsOnMap: " .. tostring(isOnMap) .. " isInstance: " .. tostring(isInstance))
				print("AutoTracked: " .. tostring(autoTracked[questID] == true))
				print("Completed: ".. tostring(isCompleted) .. " Daily: " .. tostring(isDaily) .. " Weekly: " .. tostring(isWeekly) .. " WorldQuest: " .. tostring(isWorldQuest))
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
	doUpdate = true
end

function MyPlugin:RunUpdate()
	if self.update_running ~= true then
		self.update_running = true

		-- Update play information cache, so we don't run it for every quest
		self.areaID = GetCurrentMapAreaID();
		self.inInstance = select(1, IsInInstance())

		--@debug@
		DebugLog("MyPlugin:RunUpdate")
		--@end-debug@
		self:ScheduleTimer("PartialUpdate", 0.01, 1)
	end
end

function MyPlugin:PartialUpdate(index)
	local numEntries, _ = GetNumQuestLogEntries()
	if index >= numEntries then
		--@debug@
		DebugLog("Finished partial updates")
		--@end-debug@

		if autoSort then
			SortQuestWatches()
		end

		self.update_running = nil

		local areaID = GetCurrentMapAreaID();
		if areaID ~= self.areaID then
			self.inInstance = select(1, IsInInstance())
			self.areaID = areaID
			--@debug@
			DebugLog("Reschedule partial update")
			--@end-debug@
			self:ScheduleTimer("PartialUpdate", 0.01, 1)
		end

		return
	end

	local questID, questMapId, isOnMap, isCompleted, isDaily, isWeekly, isInstance, isWorldQuest = getQuestInfo(index)
	if not (questID == nil) then
		if isCompleted and removeComplete then
			untrackQuest(index, questID)
		elseif ((questMapId == 0 and isOnMap) or (questMapId == self.areaID)) and not (isInstance and not self.inInstance and not isCompleted) then
			trackQuest(index, questID, not isWorldQuest)
		elseif showDailies and isDaily and not inInstance then
			trackQuest(index, questID, not isWorldQuest)
		elseif showDailies and isWeekly then
			trackQuest(index, questID, not isWorldQuest)
		else
			untrackQuest(index, questID)
		end
	end

	self:ScheduleTimer("PartialUpdate", 0.01, index + 1)
end

-- event handlers

function MyPlugin:QUEST_WATCH_UPDATE(event, questIndex)
	--@debug@
	DebugLog("Update for quest:", questIndex)
    if updateQuestIndex ~= nil then
		DebugLog("Already had a queued quest update:", updateQuestIndex)
	end
	--@end-debug@

	updateQuestIndex = questIndex
end

function MyPlugin:QUEST_LOG_UPDATE(event)
	if updateQuestIndex ~= nil then
		--@debug@
		DebugLog("Running update for quest:", updateQuestIndex)
		--@end-debug@

		local questIndex = updateQuestIndex
		local questID, _, _, isCompleted, _, _, _, isWorldQuest = getQuestInfo(questIndex)
		if questID ~= nil then
			updateQuestIndex = nil
			if removeComplete and isCompleted then
				untrackQuest(questIndex, questID)
			elseif not isWorldQuest then
				trackQuest(questIndex, questID, true)
			end
		end
	end

	if doUpdate then
		doUpdate = false
		run_update()
	end
end

function MyPlugin:QUEST_ACCEPTED(event, questIndex)
    newQuestIndex = questIndex
	--@debug@
	DebugLog("Accepted new quest:", questIndex)
	--@end-debug@
end

function MyPlugin:QUEST_REMOVED(event, questIndex)
	--@debug@
	DebugLog("REMOVED:", questIndex)
	--@end-debug@
	autoTracked[questIndex] = nil
end

function MyPlugin:ZONE_CHANGED()
    if not WorldMapFrame:IsVisible() then
		doUpdate = true
	else
		skippedUpdate = true
	end
end

function MyPlugin:ZONE_CHANGED_NEW_AREA()
    if not WorldMapFrame:IsVisible() then
		doUpdate = true
	else
		skippedUpdate = true
	end
end

function MyPlugin:WORLD_MAP_UPDATE()
	if skippedUpdate and not WorldMapFrame:IsVisible() then
		skippedUpdate = false
		run_update()
	end
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
    MyPlugin:RegisterEvent("WORLD_MAP_UPDATE")

	MyPlugin:Update()
end
