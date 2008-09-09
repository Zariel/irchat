local print = function(...)
	local str = ""
	for i = 1, select("#", ...) do
		str = str .. tostring(select(i, ...)) .. " "
	end
	ChatFrame1:AddMessage(str)
end

local addon = CreateFrame("Frame")
addon:SetScript("OnEvent", function(self, event, ...)
	return self[event](self, event, ...)
end)
addon:RegisterEvent("CHAT_MSG_WHISPER")
addon:RegisterEvent("CHAT_MSG_WHISPER_INFORM")

addon.frames = {}

local currentwin = 1
local windowcount = 0

local playername = UnitName("player")

-- name = UID
local UIDmap = {}

-- Cache, UID = Frame
local cache = {}

local colors = {
	urgent = { 1, 0, 0, 0.9 },
	active = { 1, 1, 1, 1 },
	nonactive = { 1, 1, 1, 0.5 },
	playerchat = { 1, 1, 1, 1 },
	chat = { 1, 1, 1, 0.7 }
}

-- To stop C Stack overflows
local registry = {}

local nameid = setmetatable({}, {
	__index = function(self, name)
		local id
		if UIDmap[name] and cache[UIDmap[name]] then
			-- cache return an old frame
			windowcount = windowcount + 1
			id = windowcount
			addon.frames[id] = table.remove(cache, UIDmap[name])

			local win = addon.frames[id]
			win.title:Show()

			if id == currentwin then
				win:Show()
			end
		else
			id = addon:NewWindow(name)
		end

		if not addon.window:IsShown() then
			addon.window:Show()
		end

		rawset(self, name, id)
		return id
	end
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

	local bg = CreateFrame("Frame", nil, UIParent)
	bg:SetHeight(225)
	bg:SetWidth(400)
	bg:SetPoint("CENTER")
	bg:SetMovable(true)
	bg:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
	bg:SetBackdropColor(0, 0, 0, 0.7)

	local bar = CreateFrame("Frame", nil, bg)
	bar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(20)
	bar:SetBackdropColor(0, 0, 0, 0.4)

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
	end)

	scale:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			bg:StartSizing()
		end
	end)

	local edit = CreateFrame("EditBox", nil, bg)
	edit:SetFont(STANDARD_TEXT_FONT, 12)
	edit:SetShadowColor(0, 0, 0, 1)
	edit:SetShadowOffset(1, -1)
	edit:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", 0, -1)
	edit:SetPoint("TOPRIGHT", bg, "TOPRIGHT", 0, -1)
	edit:SetHeight(16)
	edit:EnableMouse(true)
	edit:SetAutoFocus(false)
	edit:EnableKeyboard(true)
	edit:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
	edit:SetBackdropColor(0, 0, 0, 0.7)

	edit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	edit:SetScript("OnEnterPressed", function(self)
		local win = addon.frames[currentwin]
		if win and win.name then
			local msg = self:GetText()
			-- is it a command?
			-- @TODO Add commands, use VIM commands or slash
			-- commands? /wc vs :q :o 2 D;
			if string.match(msg, "^:") then
				local cmd, rest = string.match(msg, "^:(%S+)%s*(%S*)$")
				if cmd == "q" then
					-- close window
					addon:CloseWindow(win.id)
				else
					addon:HandleCommand(cmd, rest)
				end
			else
				-- send the whisper
				SendChatMessage(msg, "WHISPER", nil, win.name)
			end
		end
		self:ClearFocus()
		self:SetText("")
	end)

	local header = edit:CreateFontString(nil, "OVERLAY")
	header:SetFont(STANDARD_TEXT_FONT, 12)
	header:SetShadowColor(0, 0, 0, 1)
	header:SetShadowOffset(1, -1)
	header:SetPoint("TOPLEFT", 1, 0)
	header:SetPoint("BOTTOMLEFT", 1, 0)
	header:SetText("")

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
		f:SetTextColor(unpack(colors.nonactive))
	end

	return id
end

local commands = {
	["w"] = function(p)
		nameid[p] = addon:NewWindow(p)
	end,
}

function addon:HandleCommand(cmd, rest)
	if commands[cmd] then commands[cmd](rest) end
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
		old.text:SetTextColor(unpack(colors.nonactive))
	end

	new:Show()

	self.window.header:SetText(new.name .. "> ")
	self.window.edit:SetTextInsets(self.window.header:GetStringWidth(), 0, 0, 0)

	new.urgent = false
	new.text:SetTextColor(unpack(colors.active))

	currentwin = id

end

function addon:UpdateBar()
	for id = 1, (# self.frames) do
		local frame = self.frames[id]
		if id ~= frame.id then
			-- some frame before got closed
			frame.id = id
			frame.text:SetFormattedText("[%s: %s]", id, frame.name)
			local w = frame.text:GetStringWidth()
			frame.title:SetWidth(w)
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

function addon:HandleWhisper(event, msg, from)
	if not self.window then
		self:SpawnBase()
	end

	local id = nameid[from]
	local f = self.frames[id]

	local r, g, b, a = unpack(colors.playerchat)
	if event == "CHAT_MSG_WHISPER" then
		-- Urgent handling
		if id ~= currentwin then
			f.text:SetTextColor(unpack(colors.urgent))
			f.urgent = true
		end
		r, g, b, a = unpack(colors.chat)
	else
		from = playername
	end

	local m = string.format("%s <%s> %s", date("%X"), from, msg)

	m = string.format("|c%02x%02x%02x%02x%s|r", a * 255, r * 255, g * 255, b * 255, m)

	f:AddMessage(m)
end

addon.CHAT_MSG_WHISPER = addon.HandleWhisper
addon.CHAT_MSG_WHISPER_INFORM = addon.HandleWhisper
