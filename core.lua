--[[
Copyright (c) 2008 Chris Bannister,
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
   derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]
local print = function(...)
	local str = ""
	for i = 1, select("#", ...) do
		str = str .. tostring(select(i, ...)) .. " "
	end
	ChatFrame1:AddMessage(str)
end

local teknicolor = teknicolor
local addon = CreateFrame("Frame")
addon:SetScript("OnEvent", function(self, event, ...)
	return self[event](self, event, ...)
end)
addon:RegisterEvent("CHAT_MSG_WHISPER")
addon:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
addon:RegisterEvent("ADDON_LOADED")

addon.frames = {}

local currentwin = 1
local windowcount = 0

local playername = UnitName("player")

-- name = UID
local UIDmap = {}

-- Cache, UID = Frame
local cache = {}

function addon:ADDON_LOADED(event, addon)
	if addon == "IRchat" then
		local defaults = {
			profile = {
				pos = "0:0",
				size = "205:400",
				colors = {
					urgent = { 1, 0, 0, 0.9 },
					active = { 1, 1, 1, 1 },
					nonactive = { 1, 1, 1, 0.5 },
					playerchat = { 1, 1, 1, 1 },
					chat = { 0.7, 0.7, 0.7, 1 },
				},
			}
		}
		self.db = LibStub("AceDB-3.0"):New("IRchatDB", defaults)
		self:UnregisterEvent(event)
		teknicolor = teknicolor or getfenv(0).teknicolor
	end
end

-- To stop C Stack overflows
local registry = {}

local nameid = setmetatable({}, {
	__index = function(self, name)
		name = name:gsub("(.)", string.upper, 1)
		local id
		if UIDmap[name] and cache[UIDmap[name]] then
			-- cache return an old frame
			windowcount = windowcount + 1
			id = windowcount
			addon.frames[id] = cache[UIDmap[name]]
			cache[UIDmap[name]] = nil

			local win = addon.frames[id]
			win.title:Show()

			if id == currentwin then
				win:Show()
			end

			addon:UpdateBar()
		else
			id = addon:NewWindow(name)
		end

		if not addon.window:IsShown() then
			addon.window:Show()
		end

		rawset(self, name, id)
		return id
	end,
	__call = function(self, name)
		return self[name]
	end,
})

local GetUID
do
	local c = 0
	GetUID = function()
		c = c + 1
		return c
	end
end

function addon:SpawnBase()
	if self.window then return end

	local x, y = string.match(self.db.profile.pos, "(%d+):(%d+)")
	local h, w = string.match(self.db.profile.size, "(%d+):(%d+)")

	local bg = CreateFrame("Frame", nil, UIParent)
	bg:SetHeight(h)
	bg:SetWidth(w)
	bg:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
	bg:SetMovable(true)
	bg:SetResizable(true)
	bg:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
	bg:SetBackdropColor(0, 0, 0, 0.7)
	bg:SetClampedToScreen(true)
	bg:SetMinResize(100, 50)


	local bar = CreateFrame("Frame", nil, bg)
	bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
	bar:SetPoint("BOTTOMLEFT", bg, "TOPLEFT")
	bar:SetPoint("BOTTOMRIGHT", bg, "TOPRIGHT")
	bar:SetHeight(20)
	bar:SetBackdropColor(0, 0, 0, 0.9)
	bar:EnableMouse(true)

	bar:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and IsAltKeyDown() then
			bg:ClearAllPoints()
			bg:StartMoving()
		end
	end)

	bar:SetScript("OnMouseUp", function(self, button)
		bg:StopMovingOrSizing()
		local x, y = math.floor(bg:GetLeft()), math.floor(bg:GetTop())
		addon.db.profile.pos = x .. ":" .. y
	end)

	local scale = CreateFrame("Button", nil, bg)
	scale:SetNormalTexture([[Interface\AddOns\IRchat\texture\rescale.tga]])
	scale:SetPoint("BOTTOMRIGHT", -1, -1)
	scale:SetHeight(16)
	scale:SetWidth(16)
	scale:EnableMouse()
	scale:SetAlpha(0.4)

	-- @TODO Add saving of scale and position
	scale:SetScript("OnMouseUp", function(self)
		bg:StopMovingOrSizing()
		local h, w = math.floor(bg:GetHeight()), math.floor(bg:GetWidth())
		addon.db.profile.size = h .. ":" .. w
	end)

	scale:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and IsAltKeyDown() then
			bg:StartSizing()
		end
	end)

	local edit = CreateFrame("EditBox", nil, bg)
	edit:SetFont(STANDARD_TEXT_FONT, 12)
	edit:SetShadowColor(0, 0, 0, 1)
	edit:SetShadowOffset(1, -1)
	edit:SetPoint("TOPLEFT", bg, "BOTTOMLEFT")
	edit:SetPoint("TOPRIGHT", bg, "TOPRIGHT")
	edit:SetHeight(16)
	edit:EnableMouse(true)
	edit:SetAutoFocus(false)
	edit:EnableKeyboard(true)
	edit:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
	edit:SetBackdropColor(0, 0, 0, 0.7)
	edit:SetAltArrowKeyMode(false)

	edit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	edit:SetScript("OnEnterPressed", function(self)
		local win = addon.frames[currentwin]
		if win and win.name then
			local msg = self:GetText()
			-- is it a command?
			if string.match(msg, "^:") then
				local cmd, rest = string.match(msg, ":(%S+)%s?(.*)")
				rest = rest or ""
				local args = {}

				for str in string.gmatch(rest, "(%S+)") do
					table.insert(args, str)
				end

				if cmd == "q" then
					-- close window
					addon:CloseWindow(win.id)
				else
					addon:HandleCommand(cmd, unpack(args))
				end
			else
				-- send the whisper
				SendChatMessage(msg, "WHISPER", nil, win.name)
			end
		end

		self:SetText("")
	end)

	local header = edit:CreateFontString(nil, "OVERLAY")
	header:SetFont(STANDARD_TEXT_FONT, 12)
	header:SetShadowColor(0, 0, 0, 1)
	header:SetShadowOffset(1, -1)
	header:SetPoint("TOPLEFT", 1, 0)
	header:SetPoint("BOTTOMLEFT", 1, 0)
	header:SetText("")

	local hijack = CreateFrame("Frame", nil, UIParent)
	hijack:EnableKeyboard(true)
	hijack:SetScript("OnKeyDown", function(self, key)
	end)
	hijack:Hide()

	bg.bar = bar
	bg.scale = scale
	bg.edit = edit
	bg.header = header

	self.window = bg
end

function addon:NewWindow(name)
	if registry[name:lower()] then return end
	local uid = GetUID()

	windowcount = windowcount + 1
	local id = windowcount

	local frame = CreateFrame("ScrollingMessageFrame", nil, self.window)
	frame:SetFont(STANDARD_TEXT_FONT, 12)
	frame:SetShadowColor(0, 0, 0, 1)
	frame:SetShadowOffset(1, -1)
	frame:SetFading(false)
	frame:SetAllPoints(addon.window)
	frame:SetJustifyH("LEFT")
	frame:EnableMouseWheel(true)
	frame:SetMaxLines(250)

	-- Copied from oChat by Haste
	local scroll = function(self, dir)
		if(dir > 0) then
			if(IsShiftKeyDown()) then
				self:ScrollToTop()
			else
				self:ScrollUp()
			end
		elseif(dir < 0) then
			if(IsShiftKeyDown()) then
				self:ScrollToBottom()
			else
				self:ScrollDown()
			end
		end
	end

	frame:SetScript("OnMouseWheel", scroll)

	local title = CreateFrame("Frame", nil, self.window.bar)
	title:SetHeight(20)
	title:EnableMouse()

	title:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			addon:SetActiveWindow(frame.id)
		end
	end)

	local f = title:CreateFontString(nil, "OVERLAY")
	f:SetFont(STANDARD_TEXT_FONT, 12)
	f:SetShadowColor(0, 0, 0, 1)
	f:SetShadowOffset(1, -1)
	f:SetFormattedText("[%s: %s]", id, name)

	local w = f:GetStringWidth()
	title:SetWidth(w)

	f:SetAllPoints(title)

	frame.name = name
	frame.id = name
	frame.uid = uid

	frame.title = title
	frame.text = f

	self.frames[id] = frame

	registry[name:lower()] = true

	UIDmap[name] = uid

	self:UpdateBar()

	frame:Hide()

	if currentwin == id then
		self.window.header:SetText(name .. "> ")
		self.window.edit:SetTextInsets(self.window.header:GetStringWidth(), 0, 0, 0)
		self:SetActiveWindow(id, true)
	else
		f:SetTextColor(unpack(self.db.profile.colors.nonactive))
	end

	return id
end

function addon:CloseWindow(id)
	-- Hide the frame and drop it in the cache
	windowcount = windowcount - 1
	local win = self.frames[id]
	win:Hide()
	win.title:Hide()

	local uid = win.uid

	cache[uid] = table.remove(self.frames, id)

	registry[win.name:lower()] = nil

	nameid[win.name] = nil

	if not self.frames[id] then
		id = id - 1
		while id > 0 do
			if self.frames[id] then
				break
			end

			id = id - 1
		end
	end

	if id == 0 then
		self.window:Hide()
		return
	end -- Hide the whole frame

	nameid[id] = self.frames[id].name

	-- Set the new active window
	self:SetActiveWindow(id, true)

	self:UpdateBar()
end

function addon:SetActiveWindow(id, force)
	if id == currentwin and not force then return end

	if not self.frames[id] then return end

	local old = self.frames[currentwin]
	local new = self.frames[id]

	if old then
		old:Hide()
		old.text:SetTextColor(unpack(self.db.profile.colors.nonactive))
	end

	new:Show()

	self.window.header:SetText(new.name .. "> ")
	self.window.edit:SetTextInsets(self.window.header:GetStringWidth(), 0, 0, 0)

	new.urgent = false
	new.text:SetTextColor(unpack(self.db.profile.colors.active))

	currentwin = id
end

function addon:UpdateBar()
	for id = 1, (# self.frames) do
		local frame = self.frames[id]
		if id ~= frame.id then
			-- some frame before got closed
			frame.id = id
			nameid[frame.name] = id
			frame.text:SetFormattedText("[%s: %s]", id, frame.name)
			local w = frame.text:GetStringWidth()
			frame.title:SetWidth(w)
		end

		if id ~= currentwin and not frame.urgent then
			frame.text:SetTextColor(unpack(colors.nonactive))
		end

		frame.title:ClearAllPoints()
		frame.title:SetPoint("TOP")

		if id == 1 then
			frame.title:SetPoint("LEFT", 2, 0)
		else
			frame.title:SetPoint("LEFT", self.frames[id - 1].title, "RIGHT", 2, 0)
		end
	end
end

local commands = setmetatable({
	["w"] = function(name, message)
		if not name then
			return
		end

		nameid(name)
		if message then
			SendChatMessage(name, "WHISPER", nil, name)
		end
	end,
	["o"] = function(id)
		-- id comes as a string, expected number
		id = tonumber(id)
		if addon.frames[id] then
			addon:SetActiveWindow(id)
		else
			local win = addon.frames[currentwin]
			if win then
				win:AddMessage("Window does not exist " .. id)
			end
		end
	end,
	-- mother config command D;
	["set"] = function(cmd, ...)
		local db = addon.db.profile
		if cmd == "color" then
			local what, r, g, b, a = ...
			if db.colors[what] then
				db.colors[what] = { r or 1, g or 1, b or 1, a or 1 }

				-- Update all colors
				local urgent = db.colors.urgent
				local active = db.colors.active
				local nonactive = db.colors.nonactive
				local chat = db.colors.chat
				local pchat = db.colors.playerchat

				-- fun fun
				for id, frame in pairs(addon.frames) do
					if frame.urget then
						frame.text:SetTextColor(unpack(urgent))
					elseif id == currentwin then
						frame.text:SetTextColor(unpack(active))
					else
						frame.text:SetTextColor(unpack(nonactive))
					end
				end
			end
		end
	end,
	["help"] = function(cmd, ...)
		local win = addon.frames[currentwin]
		if not win then return end
		if cmd == "color" then
			local str = date("%X") .. " <system> "
			win:AddMessage(str .. "color usage:")
			win:AddMessage(str .. "        :set color <what> <r> <g> <b> <a>")
			win:AddMessage(str .. "what can be:")
			win:AddMessage(str .. "        active")
			win:AddMessage(str .. "        nonactive")
			win:AddMessage(str .. "        urgent")
			win:AddMessage(str .. "        chat")
			win:AddMessage(str .. "        playerchat")
		end
	end,
}, {
	__index = function(self, key)
		return function()
			local win = addon.frames[currentwin]
			if win then
				win:AddMessage("Unknown command :" .. tostring(key))
			end
		end
	end,
})

function addon:HandleCommand(cmd, ...)
	commands[cmd](...)
end

function addon:HandleWhisper(event, msg, from)
	if not self.window then
		self:SpawnBase()
	end

	local id = nameid[from]
	local f = self.frames[id]

	local r, g, b, a = unpack(self.db.profile.colors.playerchat)
	if event == "CHAT_MSG_WHISPER" then
		-- Urgent handling
		if id ~= currentwin then
			f.text:SetTextColor(unpack(self.db.profile.colors.urgent))
			f.urgent = true
		end
		r, g, b, a = unpack(self.db.profile.colors.chat)
	else
		from = playername
	end

	local m
	if teknicolor and teknicolor.nametable[from] then
		local str = teknicolor.nametable[from]:gsub("%[", ""):gsub("%]", "")
		m = string.format("%s <%s> %s", date("%X"), str, msg)
	else
		m = string.format("%s <%s> %s", date("%X"), from, msg)
	end

	m = string.format("|c%02x%02x%02x%02x%s|r", a * 255, r * 255, g * 255, b * 255, m)

	f:AddMessage(m)
end

addon.CHAT_MSG_WHISPER = addon.HandleWhisper
addon.CHAT_MSG_WHISPER_INFORM = addon.HandleWhisper

local ChatFilter = function(message)
	local name, str
	if string.match(message, "%w+ has gone offline.") then
		name = message:match("(%S+) has gone offline")
		str = string.format("%s <System> %s has gone offline", date("%X"), name)
	elseif string.match(message, "%w+ has come online.") then
		name = message:match("(%S+) has come online")
		str = string.format("%s <System> %s has come online", date("%X"), name)
	elseif string.match(message, "No player named '%w+' is currently playing") then
		name = message:match("No player named '(%S+)' is currently playing")
		str = string.format("%s <System> %s does not exist", date("%X"), name)
	elseif message == "Away from Keyboard" then
		-- Global args D;
		name = arg2
		str = string.format("%s <System> %s is AFK", date("%X"), name)
	end

	if str then
		if registry[name:lower()] then  -- we have a window with this person
			local f = addon.frames[nameid[name]]
			if f then
				f:AddMessage(str)
				return true
			end
		end
	end

	return false
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", ChatFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_AFK", ChatFilter)

