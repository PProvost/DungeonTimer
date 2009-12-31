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

local BossIDs = {
	-- Lich King 5-mans
	[26861] = "King Ymiron", -- Utgarde Pinnacle
	[23954] = "Ingvar the Plunderer", -- Utgarde Keep
	[29306] = "Gal'darah", -- Gundrak
	[26632] = "The Prophet Tharon'ja", -- Drak'Tharon Keep
	[29120] = "Anub'arak", -- Azjol-Nerub
	[29311] = "Herald Volazj",-- Ahn'kahet: The Old Kingdom
	[26723] = "Keristrasza", -- The Nexus
	[27656] = "Ley-Guardian Eregos", -- The Oculus
	[31134] = "Cyanigosa", -- Violet Hold
	[27978] = "Sjonnir The Ironshaper", -- Halls of Stone
	[28586] = "Loken", -- Halls of Lightning
	[26533] = "Mal'Ganis", -- The Culling of Stratholme
	[35451] = "The Black Knight", -- Trial of Champions
	[36502] = "Devourer of Souls", -- Forge of Souls
	[36658] = "Scourgelord Tyrannus", -- Pit of Saron  (note this might be 36661 instead of 36658)
	[37226] = "The Lich King" -- Halls of Reflection (no idea if this shows up as a UNIT_DEATH or not)
}

-- Debug stuff
local function Print(...) print("|cFF33FF99DungeonTimer|r:", ...) end
local debugf = tekDebug and tekDebug:GetFrame("DungeonTimer")
local function Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end

-- Locals
local timerStarted = nil
local L = setmetatable({}, {__index=function(t,i) return i end})
local defaults, db = {}

-- Since we're using Stopwatch right now, this function will ensure
-- it is loaded.
local function EnsureTimeManagerLoaded()
	if not IsAddOnLoaded("Blizzard_TimeManager") then
		LoadAddOn("Blizzard_TimeManager")
	end
end

-- Addon frame and Initialization
local f = CreateFrame("frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
f:RegisterEvent("ADDON_LOADED")

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
	--TODO: If we're already started, we shoud not do this
	if timerStarted then return end

	local zone = GetRealZoneText()
	if zone==nil or zone=="" then
		-- TODO: try again in 5 sec
		return
	end

	local _,type,difficulty,difficultyName = GetInstanceInfo()
	if type == "party" then
		Print("You have entered " .. difficultyName .. " " .. zone .. ".")
		Print("Timer will start as soon as you enter combat.")
		EnsureTimeManagerLoaded()
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end

-- This will fire when we enter combat for the first time
-- effectively signalling the start of an instance.
function f:PLAYER_REGEN_DISABLED()
	timerStarted = true
	Print("Timer started!")

	if not StopwatchFrame:IsVisible() then
		Stopwatch_Toggle()
	end
	Stopwatch_Clear()
	Stopwatch_Play()

	self:UnregisterEvent("PLAYER_REGEN_DISABLED")
end

-- Boss trap to see when we're done with the current instance
function f:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
	local timestamp, type, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = select(1, ...)
	if type=="UNIT_DIED" then
		local id = tonumber((destGUID):sub(-12, -7), 16)
		if BossIDs[id] then
			Print("Final boss dead! " ..tostring(destName))
			Stopwatch_Pause()
			timerStarted = nil
		end
	end
end

function f:PLAYER_LOGOUT()
	for i,v in pairs(defaults) do if db[i] == v then db[i] = nil end end
	-- Do anything you need to do as the player logs out
end

--[[
SLASH_DUNGEONTIMER1 = "/dt"
SlashCmdList.DUNGEONTIMER = function(msg)
	-- Do crap here
end

local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:GetDataObjectByName("DungeonTimer") or ldb:NewDataObject("DungeonTimer", {type = "launcher", icon = "Interface\\Icons\\Spell_Nature_GroundingTotem"})
dataobj.OnClick = SlashCmdList.DUNGEONTIMER
]]

