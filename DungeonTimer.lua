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
	-- Lich King 5-mans
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
local function PartySay(msg) SendChatMessage("DungeonTimer: " .. msg, "PARTY")

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

-- Iterator function that returns them sorted by key
local function pairsByKeys (t, f)
      local a = {}
      for n in pairs(t) do table.insert(a, n) end
      table.sort(a, f)
      local i = 0      -- iterator variable
      local iter = function ()   -- iterator function
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
      end
      return iter
    end

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

	self:ZONE_CHANGED_NEW_AREA()

	self.PLAYER_LOGIN = nil
end

function f:ZONE_CHANGED_NEW_AREA()
	local zone = GetRealZoneText()
	local _, type, difficulty, difficultyName = GetInstanceInfo()
	if zone==nil or zone=="" then return  end -- TODO: try again in 5 sec

	-- If we're already timing, bail
	if timerStarted then 
		if type == "party" and zone ~= timerZone then
			-- we're in a new instance zone, cancel the old time without saving
			self:StopTimer(true)
		else
			return -- Bail out... we're still in the same place... prob just died and ran back
		end
	end


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

function f:StopTimer(abandoned)
	self:SetScript("OnUpdate", nil)
	local elapsedTime = time() - startTime

	if abandoned then
		Print("Instance abandoned. Time spent: " .. FormatTimeSpanLong(elapsedTime))
	else
		local name, type, difficulty, difficultyName = GetInstanceInfo()
		local key = name.." - "..difficultyName
		if not db[key] or elapsedTime < db[key] then
			db[key] = elapsedTime
			PartySay("New record established for "..timerZone)
		end
		PartySay("Elapsed time: " .. FormatTimeSpanLong(elapsedTime))
	end

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
		PartySay(timerZone.." elapsed time - " .. FormatTimeSpanLong(elapsedTime))
	else
		Print("Timer not started!")
	end
end
dataobj.OnClick = SlashCmdList.DUNGEONTIMER

-- LDB Tooltip
dataobj.OnTooltipShow = function(self)
	local r,g,b = 1,1,1
	self:AddLine("DungeonTimer")
	for k,v in pairsByKeys(db) do
		if k = timerZone then b = 0 end
		self:AddDoubleLine(k, FormatTimeSpanLong(v), r,g,b, r,g,b)
	end
	self:AddLine("Hint: While the timer is running, click to report current elapsed time to party chat.", 0,1,0, true)
end

