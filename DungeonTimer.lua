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

local instanceInfo = {
	["Ahn'kahet: The Old Kingdom"] 	= { type="bosskill", id=29311, },
	["Azjol-Nerub"] 								= { type="bosskill", id=29120, },
	["Drak'Tharon Keep"] 						= { type="bosskill", id=26632, },
	["Gundrak"] 										= { type="bosskill", id=29306, },
	["Halls of Lightning"] 					= { type="bosskill", id=28923 },
	["Halls of Reflection"] 				= { type="emote", text="Nowhere to run... You're mine now!" },
	["Halls of Stone"] 							= { type="bosskill", id=27978 },
	["Pit of Saron"] 								= { type="bosskill", id=36658 },
	["The Culling of Stratholme"] 	= { type="emote", text="Your journey has just begun" },
	["The Forge of Souls"] 					= { type="bosskill", id=36502 },
	["The Nexus"] 									= { type="bosskill", id=26723 },
	["The Oculus"] 									= { type="bosskill", id=27656 },
	["The Violet Hold"] 						= { type="bosskill", id=31134 },
	["Trial of the Champion"] 			= { type="emote", text="No! I must not fail... again..." },
	["Utgarde Keep"] 								= { type="emote", text="No! I can do... better! I can..." },
	["Utgarde Pinnacle"] 						= { type="bosskill", id=26861 },
}

-- Debug stuff
local function Print(...) print("|cFF33FF99DungeonTimer|r:", ...) end
local debugf = tekDebug and tekDebug:GetFrame("DungeonTimer")
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end

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

local function FormatTimeSpanLong(totalSeconds)
	local secs = totalSeconds % 60
	local mins = math.floor(totalSeconds / 60)
	local hours = math.floor(totalSeconds / 3600)
	if hours > 0 then 
		return string.format("%d hours, %d mins, %d secs", hours, mins, secs)
	else
		return string.format("%d mins, %d secs", mins, secs)
	end
end

local function FormatTimeSpanShort(totalSeconds)
	local secs = totalSeconds % 60
	local mins = math.floor(totalSeconds / 60)
	local hours = math.floor(totalSeconds / 3600)
	if hours > 0 then 
		return string.format("%d:%02d:%02d", hours, mins, secs)
	else
		return string.format("%d:%02d", mins, secs)
	end
end


function f:ADDON_LOADED(event, addon)
	if addon:lower() ~= "dungeontimer" then return end

	DungeonTimerDB = setmetatable(DungeonTimerDB or {}, {__index = defaults})
	db = DungeonTimerDB

	-- Do anything you need to do after addon has loaded

	LibStub("tekKonfig-AboutPanel").new(nil, "DungeonTimer") -- Make first arg nil if no parent config panel
	self:UnregisterEvent("ADDON_LOADED")
	self.ADDON_LOADED = nil
	if IsLoggedIn() then self:PLAYER_LOGIN() else self:RegisterEvent("PLAYER_LOGIN") end
end


function f:PLAYER_LOGIN()
	self:RegisterEvent("PLAYER_LOGOUT")

	f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:ZONE_CHANGED_NEW_AREA()

	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil
end

function f:ZONE_CHANGED_NEW_AREA()
	-- If we're already timing, bail
	if timerStarted then return end

	local zone = GetRealZoneText()
	if zone==nil or zone=="" then return  end -- TODO: try again in 5 sec

	local _, type, difficulty, difficultyName = GetInstanceInfo()
	if type == "party" then
		timerZone = zone
		if instanceInfo[timerZone] then
			Print("You have entered " .. difficultyName .. " " .. zone .. ".")
			Print("Timer will start as soon as you enter combat.")
			dataobj.text = "0:00"
			self:RegisterEvent("PLAYER_REGEN_DISABLED")
		else
			Print("Unknown instance! Timer disabled")
		end
	end
end

local total = 0
function f:OnUpdate(elapsed)
	total = total + elapsed
	if total >= 1 then
		dataobj.text = FormatTimeSpanShort(time() - startTime) -- TODO: better format than this
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
	Print("Timer started!")

	-- Enable the LDB text update
	self:SetScript("OnUpdate", self.OnUpdate)

	if instanceInfo[timerZone].type == "bosskill" then
		-- Watch the combat log for the death of the boss
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	elseif instanceInfo[timerZone].type == "emote" then
		-- This one is for emotes
		self:RegisterEvent("CHAT_MSG_MONSTER_YELL")
	else
		Print("Unknown instance conclusion type. Please contact the addon developer.")
	end
end

function f:StopTimer()
	local elapsedTime = time() - startTime

	self:SetScript("OnUpdate", nil)

	local name, type, difficulty, difficultyName = GetInstanceInfo()
	local key = name.." - "..difficultyName
	if not db[key] or elapsedTime < db[key] then
		db[key] = elapsedTime
	end
	Print("Elapsed time: " .. FormatTimeSpanLong(elapsedTime))

	timerStarted = nil
	timerZone = nil
end

-- Boss trap to see when we're done with the current instance
function f:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
	local timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = select(1, ...)
	if type=="UNIT_DIED" then
		local id = tonumber((destGUID):sub(-12, -7), 16)
		if instanceInfo[timerZone].id == id then
			Print("Final boss dead! " ..tostring(destName))
			self:StopTimer()
			self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
	end
end

-- Monster yell trap to see when we're done with the current instance
function f:CHAT_MSG_MONSTER_YELL(event, msg, ...)
	if string.find(instanceInfo[timerZone].text,msg) then
		Print("Final boss defeated!")
		self:StopTimer()
		self:UnregisterEvent("CHAT_MSG_MONSTER_YELL")
	end
end

SLASH_DUNGEONTIMER1 = "/dtimer"
SlashCmdList.DUNGEONTIMER = function(msg)
	if timerStarted then
		local elapsedTime = time() - startTime
		Print(timerZone.." elapsed time: " .. FormatTimeSpanLong(elapsedTime))
	else
		Print("Timer not started!")
	end
end

-- LDB Tooltip
dataobj.OnTooltipShow = function(self)
	self:AddLine("DungeonTimer")
	for k,v in pairs(db) do
		self:AddDoubleLine(k, FormatTimeSpanLong(v), 1,1,1, 1,1,1)
	end
end


