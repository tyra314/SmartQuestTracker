--[[
	Copyright 2016 tyra <https://twitter.com/tyra_314>. All rights reserved.

	This work is licensed under the Creative Commons Attribution-NonCommercial-
	ShareAlike 4.0 International License. To view a copy of this license, visit
	http://creativecommons.org/licenses/by-nc-sa/4.0/ or send a letter to
	Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
]]


local function ChatPrint(...)
	local frame = DEFAULT_CHAT_FRAME
	for _, frameName in ipairs(CHAT_FRAMES or {}) do
		local candidate = _G[frameName]
		if candidate and GetChatWindowInfo(candidate:GetID()) == "SQT" then
			frame = candidate
			break
		end
	end

	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	frame:AddMessage(table.concat(parts, " "))
end

local function DebugLog(...)
--@debug@
	ChatPrint("|cffFF6A00Smart Quest Tracker|r:", ...)
--@end-debug@
end

MyPlugin = LibStub("AceAddon-3.0"):NewAddon("SmartQuestTracker", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

local autoTracked = {}
local superTrackedQuestID
local autoSuperTrackedQuestID
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
	local isWorldQuest = C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID) or false

	return isCompleted, isWorldQuest
end

local function getQuestInfo(index)
	local info = C_QuestLog.GetInfo(index)

	if not info or info.isHeader or not info.questID or info.questID == 0 then
		return nil
	end

	local questID = info.questID

	-- Some clients do not expose the retail-only quest classifications.
	local isLegendaryQuest = C_QuestLog.IsLegendaryQuest and C_QuestLog.IsLegendaryQuest(questID) or false
	local nextWaypoint
	if C_QuestLog.GetNextWaypoint then
		nextWaypoint = C_QuestLog.GetNextWaypoint(questID)
	end

	--@debug@
	ChatPrint("%%%%%%%%%" .. tostring(info.title) .. "%%%%%%%")
	--@end-debug@

	local questMapId
	if C_TaskQuest and C_TaskQuest.GetQuestZoneID then
		questMapId = C_TaskQuest.GetQuestZoneID(questID)
	end
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

	local isCampaignQuest = C_CampaignInfo and C_CampaignInfo.IsCampaignQuest and C_CampaignInfo.IsCampaignQuest(questID) or false

	local isInstance = false
	local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
	if tagInfo then
		local tagId = tagInfo.tagID
	    isInstance = tagId == QUEST_TAG_DUNGEON or tagId == QUEST_TAG_HEROIC or tagId == QUEST_TAG_RAID or tagId == QUEST_TAG_RAID10 or tagId == QUEST_TAG_RAID25
	end

	return questID, questMapId, info["isOnMap"] or info["hasLocalPOI"], isCompleted, isDaily, isWeekly, isInstance, info["isTask"], isLegendaryQuest or info.isStory or isCampaignQuest, distance
end

local function getSuperTrackedQuestID()
	if not C_SuperTrack or not C_SuperTrack.GetSuperTrackedQuestID then
		return nil
	end
	local questID = C_SuperTrack.GetSuperTrackedQuestID()
	if questID and questID > 0 then
		return questID
	end
end

local function trackQuest(questID, markAutoTracked)
	if questID == getSuperTrackedQuestID() and questID ~= autoSuperTrackedQuestID then
		autoTracked[questID] = nil
		return
	end

	if autoTracked[questID] ~= true and markAutoTracked then
		autoTracked[questID] = true
		C_QuestLog.AddQuestWatch(questID, 1)
	end

    if autoSort then
		C_QuestLog.SortQuestWatches()
	end
end

local function untrackQuest(questID)
	if questID == getSuperTrackedQuestID() and questID ~= autoSuperTrackedQuestID then
		autoTracked[questID] = nil
		return
	end

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
		if info and not info.isHeader and info.questID ~= getSuperTrackedQuestID() then
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
	ChatPrint("#########################")
	ChatPrint("Current MapID: " .. tostring(areaid))
	ChatPrint("ZenMode: " .. tostring(zenMode) .. " Completed setting: " .. tostring(handlingComplete))
	ChatPrint("SuperTrack: " .. tostring(getSuperTrackedQuestID()) .. " AutoSuperTrack: " .. tostring(autoSuperTrackedQuestID))

	local inInstance, instanceType = IsInInstance()

	ChatPrint("In instance: " .. tostring(inInstance))
	ChatPrint("Instance type: " .. instanceType)

	local numEntries, numQuests = C_QuestLog.GetNumQuestLogEntries()
	ChatPrint(numQuests .. " Quests in " .. numEntries .. " Entries.")
	local numWatches = C_QuestLog.GetNumQuestWatches()
	ChatPrint(numWatches .. " Quests tracked.")
	ChatPrint("#########################")

	for questIndex = 1, numEntries do
		local questID, questMapId, isOnMap, isCompleted, isDaily, isWeekly, isInstance, isWorldQuest, isLegendaryQuest, distance = getQuestInfo(questIndex)
		if questID ~= nil then
			if (not onlyWatched) or (onlyWatched and autoTracked[questID] == true) then
				local info = C_QuestLog.GetInfo(questIndex)
				local rawDistance, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
				ChatPrint("#" .. questID .. " - |cffFF6A00" .. info["title"] .. "|r")
				ChatPrint("Raw distance squared: " .. tostring(rawDistance) .. " OnContinent: " .. tostring(onContinent))
                ChatPrint("MapID: " .. tostring(questMapId) .. " IsOnMap: " .. tostring(isOnMap) .. " isInstance: " .. tostring(isInstance) .. " distance: " .. tostring(distance))
				ChatPrint("AutoTracked: " .. tostring(autoTracked[questID] == true) .. " isLocal: " .. tostring(((questMapId == 0 and isOnMap) or (questMapId == areaid)) and not (isInstance and not inInstance and not isCompleted)))
				ChatPrint("Completed: ".. tostring(isCompleted) .. " Daily: " .. tostring(isDaily) .. " Weekly: " .. tostring(isWeekly) .. " WorldQuest: " .. tostring(isWorldQuest) .. " LegendaryQuest: " .. tostring(isLegendaryQuest))
			end
		end
	end

	ChatPrint("C_QuestLog.GetQuestsOnMap(areaid): ")

	local quests = areaid and C_QuestLog.GetQuestsOnMap(areaid) or {}
	quests = quests or {}
	for qid = 1, #quests do
		local quest = quests[qid]
		ChatPrint("questID: " .. quest.questID)
	end
end

function MyPlugin:UpdateZenSuperTracking()
	if not C_SuperTrack or not C_SuperTrack.SetSuperTrackedQuestID then
		return
	end

	local currentQuestID = getSuperTrackedQuestID()
	-- A target selected outside this addon belongs to the player.
	if currentQuestID and currentQuestID ~= autoSuperTrackedQuestID then
		return
	end
	if not currentQuestID and C_SuperTrack.IsSuperTrackingAnything and C_SuperTrack.IsSuperTrackingAnything() then
		return
	end

	local nearestQuestID, nearestDistance
	if zenMode then
		local numEntries = C_QuestLog.GetNumQuestLogEntries()
		for index = 1, numEntries do
			local info = C_QuestLog.GetInfo(index)
			if info and not info.isHeader and autoTracked[info.questID] then
				local distance, onContinent = C_QuestLog.GetDistanceSqToQuest(info.questID)
				if distance and onContinent ~= false and (not nearestDistance or distance < nearestDistance
					or (distance == nearestDistance and info.questID == currentQuestID)) then
					nearestQuestID, nearestDistance = info.questID, distance
				end
			end
		end
	end

	if nearestQuestID ~= currentQuestID then
		-- Set ownership before the API call, which can fire the change event.
		autoSuperTrackedQuestID = nearestQuestID
		C_SuperTrack.SetSuperTrackedQuestID(nearestQuestID or 0)
		self:SUPER_TRACKING_CHANGED()
	end
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
		self.db.profile.ZenModeDistance = self.db.profile.ZenModeDistance / 1000
	end
	zenModeDistance = self.db.profile.ZenModeDistance
	zenModeInterval = self.db.profile.ZenModeInterval
	if not zenMode then
		self:UpdateZenSuperTracking()
	end

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

	if index > numEntries then
		--@debug@
		DebugLog("Finished partial updates")
		--@end-debug@

		self:UpdateZenSuperTracking()
		if self.update_required == true then
			self.update_required = nil
			self.areaID = C_Map.GetBestMapForUnit("player")
			self.inInstance = select(1, IsInInstance())

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
		if zenMode and distance > zenModeDistance * 1000 then
			untrackQuest(questID)
		elseif isCompleted and removeComplete then
			untrackQuest(questID)
		elseif isCompleted and keepComplete then
			trackQuest(questID, not isWorldQuest)
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

function MyPlugin:SUPER_TRACKING_CHANGED()
	local questID = getSuperTrackedQuestID()
	local previousQuestID = superTrackedQuestID
	superTrackedQuestID = questID
	if questID ~= autoSuperTrackedQuestID then
		autoSuperTrackedQuestID = nil
	end

	if questID and questID ~= autoSuperTrackedQuestID then
		autoTracked[questID] = nil
	end
	if previousQuestID and previousQuestID ~= questID then
		-- The previous target is managed by the normal tracking rules again.
		autoTracked[previousQuestID] = true
		run_update()
	end
end

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
						name = "Zen mode only automatically tracks quests within the configured distance, including story quests and completed quests. Automatically tracked quests without a known distance are hidden. If no quests are nearby, no automatically tracked quests remain. Manually tracked quests are preserved. The distance will be measured in the same unit as the quest tracker on the HUD. Using Zen mode will be MUCH more demanding on the CPU, as a constant scanning is required. You can configure the rescan interval."
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
						desc = "Sort tracked quests by distance, including while Zen mode is active.",
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

	options.childGroups = "tab"
	options.args = {
		general = {
			order = 1,
			type = "group",
			name = "General",
			args = options.args,
		},
		profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
	}
	options.args.profiles.order = 100

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
	self.db.RegisterCallback(self, "OnProfileChanged", "Update")
	self.db.RegisterCallback(self, "OnProfileCopied", "Update")
	self.db.RegisterCallback(self, "OnProfileReset", "Update")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("SmartQuestTracker", MyPlugin:BuildOptions(), {"sqt", "SmartQuestTracker"})

	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("SmartQuestTracker");

	--Register event triggers
	MyPlugin:RegisterEvent("ZONE_CHANGED")
	MyPlugin:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	MyPlugin:RegisterEvent("QUEST_WATCH_UPDATE")
	MyPlugin:RegisterEvent("QUEST_ACCEPTED")
	MyPlugin:RegisterEvent("QUEST_REMOVED")
	if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
		MyPlugin:RegisterEvent("SUPER_TRACKING_CHANGED")
		MyPlugin:RegisterEvent("PLAYER_ENTERING_WORLD", "SUPER_TRACKING_CHANGED")
		superTrackedQuestID = getSuperTrackedQuestID()
	end

	MyPlugin:Update()
end
