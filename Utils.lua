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

local myname, ns = ...

local myFullName = GetAddOnMetadata(myname, "Title")
function ns.Print(...) print("|cFF33FF99"..myFullName.."|r:", ...) end

local debugf = tekDebug and tekDebug:GetFrame(myname)
function ns.Debug(...) if debugf then debugf:AddMessage(string.join(", ", tostringall(...))) end end

function ns.PartySay(msg) SendChatMessage("DungeonTimer: " .. msg, "PARTY") end

-- Iterator function that returns them sorted by key
function ns.PairsByKeys (t, f)
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

function ns.FormatTimeSpanLong(totalSeconds)
	local secs = totalSeconds % 60
	local mins = math.floor(totalSeconds / 60)
	local hours = math.floor(totalSeconds / 3600)
	if hours > 0 then 
		return string.format("%d hours, %d mins, %d secs", hours, mins, secs)
	else
		return string.format("%d mins, %d secs", mins, secs)
	end
end

function ns.FormatTimeSpanShort(totalSeconds)
	local secs = totalSeconds % 60
	local mins = math.floor(totalSeconds / 60)
	local hours = math.floor(totalSeconds / 3600)
	if hours > 0 then 
		return string.format("%d:%02d:%02d", hours, mins, secs)
	else
		return string.format("%d:%02d", mins, secs)
	end
end


