--[[
	I want a chatbox which only holds whispers, which is tabbed like irssi and has its
	own editbox which automatically replies to the chat your reading, ala irssi.

	- Use 1 editbox and cache what gets typed so we can add it in again when we change
	who we message

	- a bar somewhere which is clickable like
	[ 1: Person ][ 2: Horse ][ 3:SadPanda ]
	and have some sort of notification support for it.
]]
local print = function(...)
	local str = ""
	for i = 1, select("#", ...) do
		str = str .. tostring(select(i, ...)) .. " "
	end
	ChatFrame1:AddMessage(str)
end

local PLAYER = UnitName("player")
local COUNT = 0

local addon = CreateFrame("Frame", nil, UIParent)

addon:SetScript("OnEvent", function(self, event, ...) return self[event](self, ...) end)
addon:RegisterEvent("CHAT_MSG_WHISPER")
addon:RegisterEvent("CHAT_MSG_WHISPER_INFORM")

-- For memory sake use 1 frame to display the messages and just change the
-- text displayed

-- @TODO: Take these out of scope
local chatbox = CreateFrame("ScrollingMessageFrame", nil, UIParent)
chatbox:SetFont(STANDARD_TEXT_FONT, 12)
chatbox:SetShadowColor(0, 0, 0, 1)
chatbox:SetShadowOffset(1, -1)
chatbox:SetWidth(350)
chatbox:SetHeight(250)
chatbox:SetPoint("CENTER")
chatbox:SetJustifyH("LEFT")
chatbox:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
chatbox:SetBackdropColor(0, 0, 0, 0.45)
chatbox:SetFading(false)
chatbox.currentwin = 1
chatbox.prevwin = nil
chatbox.cache = {}

local nameBar = CreateFrame("Frame", nil, chatbox)
nameBar:SetPoint("TOPLEFT")
nameBar:SetPoint("TOPRIGHT")
nameBar:SetHeight(16)
nameBar:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16})
nameBar:SetBackdropColor(0, 0, 0, 0.4)
chatbox.bar = nameBar

local edit = CreateFrame("EditBox", nil, chatbox)
edit:SetFont(STANDARD_TEXT_FONT, 12)
edit:SetShadowColor(0, 0, 0, 1)
edit:SetShadowOffset(1, -1)
edit:SetPoint("TOPLEFT", chatbox, "BOTTOMLEFT", 0, -1)
edit:SetPoint("TOPRIGHT", chatbox, "TOPRIGHT", 0, -1)
edit:SetHeight(20)
edit:EnableMouse(true)
edit:SetAutoFocus(false)
edit:EnableKeyboard(true)

edit:SetScript("OnEditFocusGained", function(self)
	local win = chatbox.windows[chatbox.currentwin]
	if win and win.name then
		edit.text:SetText(win.name .. "> ")
		edit:SetTextInsets(edit.text:GetStringWidth(), 0, 0, 0)
	end
end)

edit:SetScript("OnEditFocusLost", function(self)
	self:SetText("")
	edit.text:SetText("")
end)

edit:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)

edit:SetScript("OnEnterPressed", function(self)
	if chatbox.windows[chatbox.currentwin] then
		local win = chatbox.windows[chatbox.currentwin]
		win:SendMessage(self:GetText())

		self:ClearFocus()
	end
end)

edit:SetAttribute("chatType", "WHISPER")

local text = edit:CreateFontString(nil, "OVERLAY")
text:SetFont(STANDARD_TEXT_FONT, 12)
text:SetShadowColor(0, 0, 0, 1)
text:SetShadowOffset(1, -1)
text:SetPoint("TOPLEFT", edit, "TOPLEFT")
text:SetPoint("BOTTOMLEFT", edit, "BOTTOMLEFT")
text:SetTextColor(0.8, 0.8, 0.8)
edit.text = text

chatbox.edit = edit

-- name <-> index
local NameToIndex = {}
local uuids = {}
chatbox.windows = {}

-- prototype for each new 'window'
local proto = {}

function proto:SendMessage(msg)
	if strtrim(msg) == "/wc" then
		-- close meh
		self:Cache()
		return
	end

	if self.name then
		SendChatMessage(msg, "WHISPER", nil, self.name)
	end
end

function proto:SetActiveWindow()
	if chatbox.currentwin == self.id then return end

	chatbox.prevwin = chatbox.currentwin

	chatbox:Clear()

	for time, msg in pairs(self.cache) do
		chatbox:AddMessage(msg)
	end

	if self.urgent then
		self.urgent = false
	end

	self.title.text:SetTextColor(1, 1, 1, 1)

	if chatbox.prevwin and chatbox.edit:GetText() ~= "" then
		chatbox.windows[chatbox.prevwin].editcache = chatbox.edit:GetText()
	end

	if self.editcache then
		edit:SetText(self.editcache)
		self.editcache = nil
	end

	edit.text:SetText(self.name .. "> ")
	edit:SetTextInsets(edit.text:GetStringWidth(), 0, 0, 0)

	chatbox.currentwin = self.id
end

-- Caches the current window to open it again later
function proto:Cache()
	chatbox.cache[uuids[self.name]] = table.remove(chatbox.windows, self.id)
	NameToIndex[self.name] = nil

	self.title:ClearAllPoints()
	self.title:Hide()

	COUNT = COUNT - 1

	if chatbox.currentwin == self.id then
		local i = self.id - 1
		while i >= 0 do
			if chatbox.windows[i] then
				break
			end
			i = i - 1
		end
		if i > 0 then
			chatbox.windows[i]:SetActiveWindow()
		else
			-- no windows
			chatbox:Clear()
		end
	end

	self.id = nil
end

function proto:ActivateCache()
	COUNT = COUNT + 1

	local index = COUNT

	chatbox.windows[index] = chatbox.cache[self.uid]
	chatbox.cache[self.uid] = nil

	NameToIndex[self.name] = index
	self.id = index

	local col = self.title

	col:SetPoint("TOP")
	if chatbox.windows[index - 1] then
		col:SetPoint("LEFT", chatbox.windows[index - 1].title, "RIGHT", 1, 0)
	else
		col:SetPoint("LEFT", 2, 0)
	end

	col:Show()

	self.id = index
	col.text:SetFormattedText("[%d: %s]", index, self.name)

	if not chatbox.currentwin or chatbox.currentwin == self.id then
		for id, msg in pairs(self.cache) do
			chatbox:AddMessage(msg)
		end
	end

	return index
end

function chatbox:NewWindow(name)
	if self[NameToIndex[name]] then
		-- Already got it
		return
	end

	local UUID = time()

	uuids[name] = UUID

	COUNT = COUNT + 1
	local index = COUNT

	local info = setmetatable({}, {__index = proto})
	-- Name should be the person to reply to.
	info.name = name
	-- To cache messages in
	info.cache = {}
	info.id = index
	info.uid = UUID

	local col = CreateFrame("Frame", nil, nameBar)

	if self.windows[index - 1] then
		col:SetPoint("LEFT", self.windows[index - 1].title, "RIGHT", 1, 0)
	else
		col:SetPoint("LEFT", 2, 0)
	end

	col:SetPoint("TOP")
	col:EnableMouse(true)
	col:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" then
			info:SetActiveWindow()
		end
	end)

	local t = col:CreateFontString(nil, "OVERLAY")
	t:SetFont(STANDARD_TEXT_FONT, 12)
	t:SetShadowColor(0, 0, 0, 1)
	t:SetShadowOffset(1, -1)
	t:SetPoint("TOP", nameBar, "TOP")
	local str = string.format("[%d: %s]", index, name)
	t:SetText(str)
	t:SetTextColor(0.8, 0.8, 0.8)

	t:SetPoint("TOPLEFT", col, "TOPLEFT")

	local len = t:GetStringWidth()
	col:SetWidth(len)
	col:SetHeight(16)

	col.text = t

	info.title = col

	NameToIndex[name] = index

	self.windows[index] = info

	return index
end

function addon:CHAT_MSG_WHISPER(message, sender)
	local id = NameToIndex[sender]

	if uuids[sender] and chatbox.cache[uuids[sender]] then
		id = chatbox.cache[uuids[sender]]:ActivateCache()
		print(id)
	elseif not id or not chatbox.windows[id] then
		id = chatbox:NewWindow(sender)
	end

	local time, unix = date("%X"), time()

	-- unix time is for saving it to a sv.
	local msg = string.format("%s| <%s> %s", time, sender == PLAYER and "|cff00ff00" .. sender .. "|r" or sender, message)      -- oChat style

	table.insert(chatbox.windows[id].cache, msg)

	-- is the window currently open?
	if chatbox.currentwin == id then
		chatbox:AddMessage(msg)
	else
		if not chatbox.windows[id].urgent then
			chatbox.windows[id].title.text:SetTextColor(1, 0, 0)
			chatbox.windows[id].urgent = true
		end
	end
end

function addon:CHAT_MSG_WHISPER_INFORM(message, sender)
	local id = NameToIndex[sender]

	if uuids[sender] and chatbox.cache[uuids[sender]] then
		id = chatbox.cache[uuids[sender]]:ActivateCache()
	elseif not id or not chatbox.windows[id] then
		id = chatbox:NewWindow(sender)
	end

	local time, unix = date("%X"), time()

	-- unix time is for saving it to a sv.
	local msg = string.format("%s| <%s> %s", time, "|cff00ff00" .. PLAYER .. "|r", message)      -- oChat style

	table.insert(chatbox.windows[id].cache, msg)

	-- is the window currently open?
	if chatbox.currentwin == id then
		chatbox:AddMessage(msg)
	end
end
