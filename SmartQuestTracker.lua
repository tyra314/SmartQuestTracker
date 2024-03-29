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
DEFAULT_CHAT_FRAME:AddMessage(printResult)
--@end-debug@
end

MyPlugin = LibStub("AceAddon-3.0"):NewAddon("SmartQuestTracker", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local autoTracked = {}
local autoRemove
local autoSort
local removeComplete
local keepComplete
local removeLegendary
local showDailies
local removeWaypoints
local zenMode
local zenModeRunning
local zenModeDistance
local zenModeInterval

-- control variables to pass arguments from on event handler to another
local skippedUpdate = false
local newQuestIndex = nil
local doUpdate = false

local function getQuestInfoById(questID)
	local isCompleted = C_QuestLog.IsComplete(questID)
	local isWorldQuest = C_QuestLog.IsWorldQuest(questID)

	return isCompleted, isWorldQuest
end

local function getQuestInfo(index)
	local info = C_QuestLog.GetInfo(index)

	if not info then
		return nil
	end

	local questID = info.questID

	local isLegendaryQuest = C_QuestLog.IsLegendaryQuest(questID)
	local nextWaypoint = C_QuestLog.GetNextWaypoint(questID)

	if info.isHeader then
		return nil
	end

	--@debug@
	print("%%%%%%%%%" .. tostring(info.title) .. "%%%%%%%")
	--@end-debug@

	local questMapId = C_TaskQuest.GetQuestZoneID(questID)
	if questMapId == nil then
		questMapId = 0
	end
	if nextWaypoint ~= nil and nextWaypoint ~= questMapId and removeWaypoints then
		questMapId = 0
	end
	local distance, reachable = C_QuestLog.GetDistanceSqToQuest(questID)
	if not distance then
		distance = 9999999999
	end
	local areaid = C_Map.GetBestMapForUnit("player")

	local frequency = info.frequency

    local isDaily = frequency == LE_QUEST_FREQUENCY_DAILY
	local isWeekly =  frequency == LE_QUEST_FREQUENCY_WEEKLY

	local isCompleted = C_QuestLog.IsComplete(questID)

	local isCampaignQuest = C_CampaignInfo.IsCampaignQuest(questID)

	local isInstance = false
	local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
	if tagInfo then
		local tagId = tagInfo.tagID
	    isInstance = tagId == QUEST_TAG_DUNGEON or tagId == QUEST_TAG_HEROIC or tagId == QUEST_TAG_RAID or tagId == QUEST_TAG_RAID10 or tagId == QUEST_TAG_RAID25
	end

	return questID, questMapId, info["isOnMap"] or info["hasLocalPOI"], isCompleted, isDaily, isWeekly, isInstance, info["isTask"], isLegendaryQuest or info.isStory or isCampaignQuest, distance
end

local function trackQuest(questID, markAutoTracked)
	if autoTracked[questID] ~= true and markAutoTracked then
		autoTracked[questID] = true
		C_QuestLog.AddQuestWatch(questID, 1)
	end

    if autoSort then
		C_QuestLog.SortQuestWatches()
	end
end

local function untrackQuest(questID)
	if autoTracked[questID] == true then
		C_QuestLog.RemoveQuestWatch(questID)
		autoTracked[questID] = nil
	end

    if autoSort then
		C_QuestLog.SortQuestWatches()
	end
end

local function untrackAllQuests()
	local numEntries, _ = C_QuestLog.GetNumQuestLogEntries()

	for index = 1, numEntries do
		local info = C_QuestLog.GetInfo(index)
		if ( not info["isHeader"]) then
			C_QuestLog.RemoveQuestWatch(info["questID"])
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
	local areaid = C_Map.GetBestMapForUnit("player");
	print("#########################")
	print("Current MapID: " .. areaid)

	local inInstance, instanceType = IsInInstance()

	print("In instance: " .. tostring(inInstance))
	print("Instance type: " .. instanceType)

	local numEntries, numQuests = C_QuestLog.GetNumQuestLogEntries()
	print(numQuests .. " Quests in " .. numEntries .. " Entries.")
	local numWatches = C_QuestLog.GetNumQuestWatches()
	print(numWatches .. " Quests tracked.")
	print("#########################")

	for questIndex = 1, numEntries do
		local questID, questMapId, isOnMap, isCompleted, isDaily, isWeekly, isInstance, isWorldQuest, isLegendaryQuest, distance = getQuestInfo(questIndex)
		if questID ~= nil then
			if (not onlyWatched) or (onlyWatched and autoTracked[questID] == true) then
				local info = C_QuestLog.GetInfo(questIndex)
				print("#" .. questID .. " - |cffFF6A00" .. info["title"] .. "|r")
                print("MapID: " .. tostring(questMapId) .. " IsOnMap: " .. tostring(isOnMap) .. " isInstance: " .. tostring(isInstance) .. " distance: " .. tostring(distance))
				print("AutoTracked: " .. tostring(autoTracked[questID] == true) .. " isLocal: " .. tostring(((questMapId == 0 and isOnMap) or (questMapId == areaid)) and not (isInstance and not inInstance and not isCompleted)))
				print("Completed: ".. tostring(isCompleted) .. " Daily: " .. tostring(isDaily) .. " Weekly: " .. tostring(isWeekly) .. " WorldQuest: " .. tostring(isWorldQuest) .. " LegendaryQuest: " .. tostring(isLegendaryQuest))
			end
		end
	end

	print("C_QuestLog.GetQuestsOnMap(areaid): ")

	local quests = C_QuestLog.GetQuestsOnMap(areaid)
	for qid = 1, #quests do
		local quest = quests[qid]
		print("questID: " .. quest.questID)
	end
end

function hasFocusQuest(mapID)
	if not zenMode or mapID == nil then
		return false
	end
	local quests = C_QuestLog.GetQuestsOnMap(mapID)

	if quests == nil then
		return false
	end

	for qid = 1, #quests do
		local quest = quests[qid]
		local distanceSq, _ = C_QuestLog.GetDistanceSqToQuest(quest.questID)

		if distanceSq == nil then
			return false
		end

		if distanceSq <= zenModeDistance * 1000 then
			return true
		end
	end

	return false
end

--Function we can call when a setting changes.
function MyPlugin:Update()
	autoRemove = self.db.profile.AutoRemove
	autoSort =  self.db.profile.AutoSort
	removeLegendary = self.db.profile.RemoveLegendary
	removeWaypoints = self.db.profile.RemoveWaypoints
	showDailies = self.db.profile.ShowDailies
	handlingComplete = self.db.profile.HandlingComplete
	zenMode = self.db.profile.ZenMode
	if self.db.profile.ZenModeDistance > 10000 then
		-- change zenModDistance to new scaled value
		self.db.profile.ZenModeInterval = self.db.profile.ZenModeInterval / 1000
	end
	zenModeDistance = self.db.profile.ZenModeDistance
	zenModeInterval = self.db.profile.ZenModeInterval

	if handlingComplete == "keep" then
		keepComplete = true
		removeComplete = false
	elseif handlingComplete == "keep_local" then
		keepComplete = false
		removeComplete = false
	elseif handlingComplete == "remove" then
		keepComplete = false
		removeComplete = true
	end

	untrackAllQuests()

	run_update()

	if not zenModeRunning then
		self:ScheduleTimer("ZenMode", zenModeInterval)
	end
end

function MyPlugin:RunUpdate()
	if self.update_running ~= true then
		self.update_running = true

		-- Update play information cache, so we don't run it for every quest
		self.areaID = C_Map.GetBestMapForUnit("player")
		self.inInstance = select(1, IsInInstance())
		self.hasFocus = hasFocusQuest(self.areaID)

		--@debug@
		DebugLog("MyPlugin:RunUpdate")
		--@end-debug@
		self:ScheduleTimer("PartialUpdate", 0.01, 1)
	else
		self.update_required = true
	end
end

function MyPlugin:ZenMode()
	if zenMode then
		zenModeRunning = true
		if not WorldMapFrame:IsVisible() then
			--@debug@
			DebugLog("Running zen mode update")
			--@end-debug@

			run_update()
		end
		self:ScheduleTimer("ZenMode", zenModeInterval)
	else
		zenModeRunning = false
	end
end

function MyPlugin:PartialUpdate(index)
	local numEntries, _ = C_QuestLog.GetNumQuestLogEntries()

	if index >= numEntries then
		--@debug@
		DebugLog("Finished partial updates")
		--@end-debug@

		if self.update_required == true then
			self.update_required = nil
			self.areaID = C_Map.GetBestMapForUnit("player")
			self.inInstance = select(1, IsInInstance())
			self.hasFocus = hasFocusQuest(self.areaID)

			--@debug@
			DebugLog("Reschedule partial update")
			--@end-debug@
			self:ScheduleTimer("PartialUpdate", 0.01, 1)
		else
			if autoSort then
				C_QuestLog.SortQuestWatches()
			end
			self.update_running = nil
		end

		return
	end

	local questID, questMapId, isOnMap, isCompleted, isDaily, isWeekly, isInstance, isWorldQuest, isLegendaryQuest, distance = getQuestInfo(index)
	if questID ~= nil then
		if isCompleted and removeComplete then
			untrackQuest(questID)
		elseif isCompleted and keepComplete then
			trackQuest(questID, not isWorldQuest)
		elseif self.hasFocus and distance > zenModeDistance * 1000 and (not isLegendaryQuest or removeLegendary)then
			untrackQuest(questID)
		elseif isLegendaryQuest and removeLegendary and not isOnMap then
			untrackQuest(questID)
		elseif isOnMap and not (isInstance and not self.inInstance and not isCompleted) then
			trackQuest(questID, not isWorldQuest)
		elseif showDailies and isDaily and not inInstance then
			trackQuest(questID, not isWorldQuest)
		elseif showDailies and isWeekly then
			trackQuest(questID, not isWorldQuest)
		else
			untrackQuest(questID)
		end
	end

	self:ScheduleTimer("PartialUpdate", 0.01, index + 1)
end

-- event handlers

function MyPlugin:QUEST_WATCH_UPDATE(event, questID)
	DebugLog("Update for quest: ", questID)

	if questID ~= nil then
		local isCompleted, isWorldQuest = getQuestInfoById(questID)

		if removeComplete and isCompleted then
			untrackQuest(questID)
		elseif not isWorldQuest then
			trackQuest(questID, not isWorldQuest)
		end
	end
end

function MyPlugin:QUEST_ACCEPTED(event, questID)
	DebugLog("Accepted new quest: ", questID)

	if questID ~= nil then
		local isCompleted, isWorldQuest = getQuestInfoById(questID)

		if removeComplete and isCompleted then
			untrackQuest(questID)
		elseif not isWorldQuest then
			trackQuest(questID, not isWorldQuest)
		end
	end
end

function MyPlugin:QUEST_REMOVED(event, questID)
	DebugLog("Removed quest: ", questID)
	autoTracked[questID] = nil
	-- run_update()
end

function MyPlugin:ZONE_CHANGED()
	DebugLog("ZONE_CHANGED")
	run_update()
end

function MyPlugin:ZONE_CHANGED_NEW_AREA()
	DebugLog("ZONE_CHANGED_NEW_AREA")
	run_update()
end

function MyPlugin:BuildOptions()
	local options = {
		order = 100,
		type = "group",
		name = "|cffFF6A00Smart Quest Tracker|r",
		handler = MyPlugin,
		args = {
			zenMode = {
				order = 2,
				type = "group",
				name = "Zen mode",
				guiInline = true,
				args = {
					zenModeDesc = {
						order = 1,
						type = "description",
						name = "Zen mode will only track those Quest, which are within the given distance, if at least one quest is within the given distance. The distance will be measured in the same unit as the quest tracker on the HUD. Using Zen mode will be MUCH more demanding on the CPU, as a constant scanning is required. You can configure the rescan interval."
					},
					zenModeEnabled = {
						order = 10,
						type = "toggle",
						name = "Enabled",
						get = function(info)
							return self.db.profile.ZenMode
						end,
						set = function(info, value)
							self.db.profile.ZenMode = value
							MyPlugin:Update() --We changed a setting, call our Update function
						end,
					},
					zenModeDistance = {
						order = 11,
						type = "range",
						name = "Distance to quest",
						min = 1,
						max = 10000,
						softMin = 10,
						softMax = 1000,
						step = 1,
						bigStep = 10,
						get = function(info)
							return self.db.profile.ZenModeDistance
						end,
						set = function(info, value)
							self.db.profile.ZenModeDistance = value
							MyPlugin:Update() --We changed a setting, call our Update function
						end,
					},
					zenModeInterval = {
						order = 11,
						type = "range",
						name = "Rescan interval (seconds)",
						min = 1,
						max = 10,
						step = 1,
						get = function(info)
							return self.db.profile.ZenModeInterval
						end,
						set = function(info, value)
							self.db.profile.ZenModeInterval = value
							MyPlugin:Update() --We changed a setting, call our Update function
						end,
					},
				}
			},
			clear = {
				order = 1,
				type = "group",
				name = "Untrack quests when changing area",
				guiInline = true,
				args = {
					removelegendary = {
						order = 3,
						type = "toggle",
						name = "Keep story quests",
						get = function(info)
							return not self.db.profile.RemoveLegendary
						end,
						set = function(info, value)
							self.db.profile.RemoveLegendary = not value
							MyPlugin:Update() --We changed a setting, call our Update function
						end,
					},
					removewaypoints = {
						order = 2,
						type = "toggle",
						name = "Quest waypoints",
						get = function(info)
							return self.db.profile.RemoveWaypoints
						end,
						set = function(info, value)
							self.db.profile.RemoveWaypoints = value
							MyPlugin:Update() --We changed a setting, call our Update function
						end,
					},
					autoremove = {
						order = 1,
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
						order = 5,
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
					removecomplete = {
						order = 10,
						type = "select",
						style = "radio",
						name = "Completed quests",
						values = {
							keep = "Keep all",
							keep_local = "Keep only local",
							remove = "Remove all",
						},
						get = function(info)
							return self.db.profile.HandlingComplete
						end,
						set = function(info, value)
							self.db.profile.HandlingComplete = value
							MyPlugin:Update() --We changed a setting, call our Update function
						end,
					}
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

	return options
end

function MyPlugin:OnInitialize()
	local defaults = {
		profile = {
			HandlingComplete = "keep_local",
			RemoveLegendary = true,
			RemoveWaypoints = false,
			AutoSort = true,
			AutoRemove = true,
			ShowDailies = false,
			ZenMode = false,
			ZenModeDistance = 100,
			ZenModeInterval = 1,
		}
	}

	self.db = LibStub("AceDB-3.0"):New("SmartQuestTrackerDB", defaults)
	LibStub("AceConfig-3.0"):RegisterOptionsTable("SmartQuestTracker", MyPlugin:BuildOptions(), {"sqt", "SmartQuestTracker"})

	self.profilesFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SmartQuestTracker");

	--Register event triggers
	MyPlugin:RegisterEvent("ZONE_CHANGED")
	MyPlugin:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	MyPlugin:RegisterEvent("QUEST_WATCH_UPDATE")
	MyPlugin:RegisterEvent("QUEST_ACCEPTED")
	MyPlugin:RegisterEvent("QUEST_REMOVED")

	MyPlugin:Update()
end
