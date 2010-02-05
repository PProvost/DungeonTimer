--[[
Copyright 2009 Peter Provost (Quaiche of Dragonblight)

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
]]

local addonName, ns = ...

-- Locals
local timerStarted = nil
local startTime = 0
local timerZone
local db

-- Addon frame and Initialization
local f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
f:RegisterEvent("ADDON_LOADED")

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:GetDataObjectByName("DungeonTimer") or ldb:NewDataObject("DungeonTimer", {type = "data source", icon = "Interface\\Icons\\INV_Misc_Head_ClockworkGnome_01", text="0:00" })

function f:ADDON_LOADED(event, addon)
	if addon:lower() ~= "dungeontimer" then return end

	local realm, name = GetRealmName(), UnitName('player')
	DungeonTimerDB = setmetatable(DungeonTimerDB or {}, {__index = defaults})
	DungeonTimerDB[realm] = DungeonTimerDB[realm] or {}
	DungeonTimerDB[realm][name] = DungeonTimerDB[realm][name] or {}
	db = DungeonTimerDB[realm][name]

	LibStub("tekKonfig-AboutPanel").new(nil, "DungeonTimer") -- Make first arg nil if no parent config panel
	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil
	if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
end


function f:PLAYER_LOGIN()
	self:RegisterEvent("PLAYER_LOGOUT")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:UnregisterEvent("PLAYER_LOGIN")

	-- Testing out some stuff with the LFG system
	self:RegisterEvent("LFG_UPDATE")
	self:RegisterEvent("LFG_COMPLETION_REWARD")

	self:ZONE_CHANGED_NEW_AREA()

	self.PLAYER_LOGIN = nil
end

function f:LFG_UPDATE(event, ...) ns.Debug("LFG_UPDATE", ...) end
function f:LFG_COMPLETION_REWARD(event, ...) ns.Debug("LFG_UPDATE", ...) end

StaticPopupDialogs["DUNGEON_TIMER_STOPCONFIRM"] = {
	text = "You have left the instance, do you want to abort the timer?",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function()
		f:StopTimer(true)
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = false,
	enterClicksFirstButton = true,
}

function f:ZONE_CHANGED_NEW_AREA()
	if UnitIsDeadOrGhost('player') then 
		ns.Debug("ZONE_CHANGED_NEW_AREA - Player is dead or ghost!")
		return 
	end

	local zone = GetRealZoneText()
	if zone==nil or zone=="" or zone==timerZone then 
		ns.Debug("ZONE_CHANGED_NEW_AREA - zone is nil, \"\" or timerZone")
		return 
	end

	local _, type, difficulty, difficultyName = GetInstanceInfo()
	if type ~= "party" then
		ns.Debug("ZONE_CHANGED_NEW_AREA - not in party")
		return
	end

	if timerStarted then
		StaticPopup_Show("DUNGEON_TIMER_STOPCONFIRM")
	else
		timerZone = zone
		dataobj.text = "0:00"
		if ns.InstanceInfo[timerZone] then
			ns.Print("You have entered " .. difficultyName .. " " .. zone .. ".")
			ns.Print("Timer will start as soon as you enter combat.")
			self:RegisterEvent("PLAYER_REGEN_DISABLED")
		else
			ns.Print("Unknown instance! Timer disabled")
			self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		end
	end
end

local total = 0
function f:OnUpdate(elapsed)
	total = total + elapsed
	if total >= 1 then
		dataobj.text = ns.FormatTimeSpanShort(time() - startTime)
		total = 0
	end
end

-- This will fire when we enter combat for the first time
-- effectively signalling the start of an instance.
function f:PLAYER_REGEN_DISABLED()
	self:UnregisterEvent("PLAYER_REGEN_DISABLED")

	-- Start the timer!
	timerStarted = true
	startTime = time()
	ns.Print("Timer started!")

	-- Enable the LDB text update
	self:SetScript("OnUpdate", self.OnUpdate)

	if ns.InstanceInfo[timerZone].type == "bosskill" then
		-- Watch the combat log for the death of the boss
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	elseif ns.InstanceInfo[timerZone].type == "emote" then
		-- This one is for emotes
		self:RegisterEvent("CHAT_MSG_MONSTER_YELL")
	else
		ns.Print("Unknown instance conclusion type. Please contact the addon developer.")
	end
end

function f:StopTimer(abandoned)
	self:SetScript("OnUpdate", nil)
	local elapsedTime = time() - startTime

	if abandoned then
		ns.Print("Instance abandoned. Time spent: " .. ns.FormatTimeSpanLong(elapsedTime))
	else
		local name, type, difficulty, difficultyName = GetInstanceInfo()
		local key = name.." - "..difficultyName
		if not db[key] or elapsedTime < db[key] then
			db[key] = elapsedTime
			ns.Print("New record established for "..timerZone)
		end
		ns.PartySay("Elapsed time: " .. ns.FormatTimeSpanLong(elapsedTime))
	end

	timerStarted = nil
	timerZone = nil
end

-- Combat log trap to see when we're done with the current instance
function f:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
	local timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = select(1, ...)
	if type=="UNIT_DIED" then
		local id = tonumber((destGUID):sub(-12, -7), 16)
		if ns.InstanceInfo[timerZone].id == id then
			ns.Print("Final boss killed! " ..tostring(destName))
			self:StopTimer()
			self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
	end
end

-- Monster yell trap to see when we're done with the current instance
function f:CHAT_MSG_MONSTER_YELL(event, msg, ...)
	if string.find(ns.InstanceInfo[timerZone].text,msg) then
		ns.Print("Final boss defeated!")
		self:StopTimer()
		self:UnregisterEvent("CHAT_MSG_MONSTER_YELL")
	end
end

SLASH_DUNGEONTIMER1 = "/dtimer"
SlashCmdList.DUNGEONTIMER = function(msg)
	if timerStarted then
		local elapsedTime = time() - startTime
		ns.PartySay(timerZone.." elapsed time - " .. ns.FormatTimeSpanLong(elapsedTime))
	else
		ns.Print("Timer not started!")
	end
end
dataobj.OnClick = SlashCmdList.DUNGEONTIMER

-- LDB Tooltip
dataobj.OnTooltipShow = function(self)
	local r,g,b = 1,1,1
	self:AddLine("DungeonTimer")
	for k,v in ns.PairsByKeys(db) do
		if k == timerZone then b = 0 end
		self:AddDoubleLine(k, ns.FormatTimeSpanLong(v), r,g,b, r,g,b)
	end
	self:AddLine("Hint: While the timer is running, click to report current elapsed time to party chat.", 0,1,0, true)
end

