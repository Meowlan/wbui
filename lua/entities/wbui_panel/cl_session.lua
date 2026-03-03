-- ─────────────────────────────────────────────────────────
--  cl_session.lua  –  Shared browsing session logic
--
--  Handles both sending (Conductor) and receiving (Viewer)
--  of sync messages. Designed to be sync-mode agnostic so
--  future modes (relay streaming, etc.) can slot in.
-- ─────────────────────────────────────────────────────────

local syncHooksJs = file.Read("data_static/wbui_sync_hooks.txt", "GAME")
assert(syncHooksJs, "Failed to load sync hooks JS")

-- ── Conductor: Send helpers ──────────────────────────────

--- Whether the local player is the Conductor for this panel.
function ENT:IsLocalConductor()
	return self:IsShared() and self:IsConductor(LocalPlayer())
end

--- Whether the local player is a Viewer (shared mode, not conductor, AND opted in).
function ENT:IsLocalViewer()
	return self:IsShared() and not self:IsConductor(LocalPlayer()) and self._syncOptedIn == true
end

--- Whether this panel has an active share the local player could join.
function ENT:CanJoinShare()
	return self:IsShared() and not self:IsConductor(LocalPlayer()) and not self._syncOptedIn
end

--- Send a URL navigation event to the server for relay.
function ENT:SyncSendNav(url)
	if not self:IsLocalConductor() then return end
	if not url or #url == 0 then return end

	net.Start("wbui_sync_nav")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteString(url)
	net.SendToServer()
end

--- Send a media event (play/pause/seek) to the server.
--- @param eventType number 0=play, 1=pause, 2=seek
function ENT:SyncSendMediaEvent(eventType, currentTime, playbackRate)
	if not self:IsLocalConductor() then return end

	net.Start("wbui_sync_media")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteUInt(eventType, 3)
		net.WriteFloat(currentTime or 0)
		net.WriteFloat(playbackRate or 1)
	net.SendToServer()
end

--- Send periodic media tick for drift correction.
function ENT:SyncSendMediaTick(currentTime, paused, playbackRate)
	if not self:IsLocalConductor() then return end

	net.Start("wbui_sync_media_tick")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteFloat(currentTime or 0)
		net.WriteBool(paused or false)
		net.WriteFloat(playbackRate or 1)
	net.SendToServer()
end

--- Send scroll position (as ratio 0-1).
function ENT:SyncSendScroll(ratioX, ratioY)
	if not self:IsLocalConductor() then return end

	net.Start("wbui_sync_scroll")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteFloat(ratioX or 0)
		net.WriteFloat(ratioY or 0)
	net.SendToServer()
end

--- Send cursor position (normalized 0-1 relative to HTML resolution).
function ENT:SyncSendCursor(cx, cy)
	if not self:IsLocalConductor() then return end

	net.Start("wbui_sync_cursor")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteFloat(cx or 0)
		net.WriteFloat(cy or 0)
	net.SendToServer()
end

--- Send input text change for a specific element.
function ENT:SyncSendInput(selector, value)
	if not self:IsLocalConductor() then return end
	if not selector or #selector == 0 then return end

	net.Start("wbui_sync_input")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteString(selector)
		net.WriteString(value or "")
	net.SendToServer()
end

--- Send fullscreen state change to the server.
function ENT:SyncSendFullscreen(active, selector)
	if not self:IsLocalConductor() then return end

	net.Start("wbui_sync_fullscreen")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteBool(active or false)
		net.WriteString(selector or "")
	net.SendToServer()
end

-- ── Conductor: JS callback registration ──────────────────

--- Inject sync hooks JS and bind gmod.sync* callbacks.
--- Called from OpenPage after the panel is created.
function ENT:SyncSetupConductorHooks()
	if not IsValid(self.Panel) then return end

	-- Inject the sync hooks JS on every document load
	self.Panel:AddFunction("gmod", "syncUrlChanged", function(url)
		self.Panel.URL = url
		self:SyncSendNav(url)
	end)

	self.Panel:AddFunction("gmod", "syncMediaEvent", function(json)
		local data = util.JSONToTable(json)
		if not data then return end

		local typeMap = { play = 0, pause = 1, seek = 2 }
		local eventType = typeMap[data.type]
		if not eventType then return end

		self:SyncSendMediaEvent(eventType, data.currentTime, data.playbackRate)
	end)

	self.Panel:AddFunction("gmod", "syncMediaTick", function(json)
		local data = util.JSONToTable(json)
		if not data then return end

		self:SyncSendMediaTick(data.currentTime, data.paused, data.playbackRate)
	end)

	self.Panel:AddFunction("gmod", "syncScroll", function(json)
		local data = util.JSONToTable(json)
		if not data then return end

		self:SyncSendScroll(data.x, data.y)
	end)

	self.Panel:AddFunction("gmod", "syncInput", function(json)
		local data = util.JSONToTable(json)
		if not data then return end

		self:SyncSendInput(data.selector, data.value)
	end)

	self.Panel:AddFunction("gmod", "syncFullscreen", function(json)
		local data = util.JSONToTable(json)
		if not data then return end

		self:SyncSendFullscreen(data.active, data.selector)
	end)
end

--- Inject the sync hooks JS into the current page.
--- Called from OnDocumentReady.
function ENT:SyncInjectHooks()
	if not IsValid(self.Panel) then return end
	if not self:IsLocalConductor() then return end

	self.Panel:RunJavascript(syncHooksJs)
end

-- ── Viewer: Apply incoming sync state ────────────────────

--- Apply a navigation command from the Conductor.
function ENT:SyncApplyNav(url)
	if not IsValid(self.Panel) then return end

	self.Panel.URL = url
	self.Panel:OpenURL(url)
end

--- Apply a media event from the Conductor.
--- @param eventType number 0=play, 1=pause, 2=seek
function ENT:SyncApplyMediaEvent(eventType, currentTime, playbackRate)
	if not IsValid(self.Panel) then return end

	local typeNames = { [0] = "play", [1] = "pause", [2] = "seek" }
	local typeName = typeNames[eventType] or "play"

	self.Panel:RunJavascript(string.format(
		"if(window.__wbuiApplyMediaState) window.__wbuiApplyMediaState(%q, %f, %f);",
		typeName, currentTime, playbackRate
	))
end

--- Apply a media tick (drift correction) from the Conductor.
function ENT:SyncApplyMediaTick(currentTime, paused, playbackRate, duration)
	if not IsValid(self.Panel) then return end

	self.Panel:RunJavascript(string.format(
		"if(window.__wbuiApplyMediaTick) window.__wbuiApplyMediaTick(%f, %s, %f, %f);",
		currentTime, paused and "true" or "false", playbackRate, duration or 0
	))
end

--- Apply scroll position from the Conductor.
function ENT:SyncApplyScroll(ratioX, ratioY)
	if not IsValid(self.Panel) then return end

	self.Panel:RunJavascript(string.format(
		"if(window.__wbuiApplyScroll) window.__wbuiApplyScroll(%f, %f);",
		ratioX, ratioY
	))
end

--- Apply input text from the Conductor.
function ENT:SyncApplyInput(selector, value)
	if not IsValid(self.Panel) then return end

	-- Escape for safe JS string embedding
	local safeSelector = string.JavascriptSafe(selector)
	local safeValue = string.JavascriptSafe(value)

	self.Panel:RunJavascript(string.format(
		'if(window.__wbuiApplyInput) window.__wbuiApplyInput("%s", "%s");',
		safeSelector, safeValue
	))
end

--- Apply fullscreen state from the Conductor.
function ENT:SyncApplyFullscreen(active, selector)
	if not IsValid(self.Panel) then return end

	local safeSelector = string.JavascriptSafe(selector or "")

	self.Panel:RunJavascript(string.format(
		'if(window.__wbuiApplyFullscreen) window.__wbuiApplyFullscreen(%s, "%s");',
		active and "true" or "false", safeSelector
	))
end

-- ── Viewer: Net message receivers ────────────────────────
-- These are global net.Receive handlers; they look up the entity and delegate.

local function GetSyncEntity()
	local entIdx = net.ReadUInt(16)
	local ent = Entity(entIdx)
	if not IsValid(ent) or ent:GetClass() ~= "wbui_panel" then return nil end
	if not ent:IsLocalViewer() then return nil end
	return ent
end

net.Receive("wbui_sync_nav", function()
	local ent = GetSyncEntity()
	if not ent then return end

	local url = net.ReadString()
	ent:SyncApplyNav(url)
end)

net.Receive("wbui_sync_media", function()
	local ent = GetSyncEntity()
	if not ent then return end

	local eventType = net.ReadUInt(3)
	local currentTime = net.ReadFloat()
	local playbackRate = net.ReadFloat()

	ent:SyncApplyMediaEvent(eventType, currentTime, playbackRate)
end)

net.Receive("wbui_sync_media_tick", function()
	local ent = GetSyncEntity()
	if not ent then return end

	local currentTime = net.ReadFloat()
	local paused = net.ReadBool()
	local playbackRate = net.ReadFloat()

	ent:SyncApplyMediaTick(currentTime, paused, playbackRate)
end)

net.Receive("wbui_sync_scroll", function()
	local ent = GetSyncEntity()
	if not ent then return end

	local ratioX = net.ReadFloat()
	local ratioY = net.ReadFloat()

	ent:SyncApplyScroll(ratioX, ratioY)
end)

net.Receive("wbui_sync_input", function()
	local ent = GetSyncEntity()
	if not ent then return end

	local selector = net.ReadString()
	local value = net.ReadString()

	ent:SyncApplyInput(selector, value)
end)

net.Receive("wbui_sync_fullscreen", function()
	local ent = GetSyncEntity()
	if not ent then return end

	local active = net.ReadBool()
	local selector = net.ReadString()

	ent:SyncApplyFullscreen(active, selector)
end)

net.Receive("wbui_sync_cursor", function()
	local entIdx = net.ReadUInt(16)
	local ent = Entity(entIdx)
	if not IsValid(ent) or ent:GetClass() ~= "wbui_panel" then return end
	if not ent:IsLocalViewer() then return end

	local cx = net.ReadFloat()
	local cy = net.ReadFloat()

	-- Store conductor cursor for rendering in Draw()
	ent.SyncConductorCursor = { x = cx, y = cy, time = SysTime() }
end)

-- ── Block list for takeover spam ──────────────────────────
local function GetBlockList(ent)
	if not ent._syncBlockedPlayers then
		ent._syncBlockedPlayers = {}
	end
	return ent._syncBlockedPlayers
end

-- ── Takeover request prompt ──────────────────────────────
local activeTakeFrame = nil

local function ShowTakeoverPrompt(ent, requesterIdx, requesterName)
	if IsValid(activeTakeFrame) then activeTakeFrame:Remove() end

	local frame = vgui.Create("DFrame")
	frame:SetSize(300, 100)
	frame:Center()
	frame:SetTitle(requesterName .. " wants control")
	frame:MakePopup()
	frame:SetKeyboardInputEnabled(false)
	activeTakeFrame = frame

	local allow = vgui.Create("DButton", frame)
	allow:SetPos(10, 35)
	allow:SetSize(85, 30)
	allow:SetText("Allow")
	allow.DoClick = function()
		if IsValid(ent) then ent:SyncRespondTakeRequest(requesterIdx, true) end
		frame:Remove()
	end

	local deny = vgui.Create("DButton", frame)
	deny:SetPos(105, 35)
	deny:SetSize(85, 30)
	deny:SetText("Deny")
	deny.DoClick = function()
		if IsValid(ent) then ent:SyncRespondTakeRequest(requesterIdx, false) end
		frame:Remove()
	end

	local block = vgui.Create("DButton", frame)
	block:SetPos(200, 35)
	block:SetSize(85, 30)
	block:SetText("Block")
	block.DoClick = function()
		if IsValid(ent) then
			ent:SyncRespondTakeRequest(requesterIdx, false)
			GetBlockList(ent)[requesterIdx] = true
			chat.AddText(Color(255, 120, 80), "[WBUI] ", Color(220, 220, 220),
				"Blocked " .. requesterName .. " from requesting control.")
		end
		frame:Remove()
	end

	-- Auto-dismiss after 15s
	timer.Simple(15, function()
		if IsValid(frame) then
			if IsValid(ent) then ent:SyncRespondTakeRequest(requesterIdx, false) end
			frame:Remove()
		end
	end)
end

-- Takeover request from another player
net.Receive("wbui_sync_take", function()
	local entIdx = net.ReadUInt(16)
	local requesterIdx = net.ReadUInt(16)
	local requesterName = net.ReadString()

	local ent = Entity(entIdx)
	if not IsValid(ent) or ent:GetClass() ~= "wbui_panel" then return end
	if not ent:IsLocalConductor() then return end

	if GetBlockList(ent)[requesterIdx] then return end

	ShowTakeoverPrompt(ent, requesterIdx, requesterName)
end)

-- ── Sync mode toggle (client-side request) ───────────────

function ENT:SyncRequestSetMode(mode)
	net.Start("wbui_sync_set_mode")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteUInt(mode, 3)
	net.SendToServer()
end

function ENT:SyncRequestTakeConductor()
	net.Start("wbui_sync_take")
		net.WriteUInt(self:EntIndex(), 16)
	net.SendToServer()
end

--- Opt in to viewing a shared session (with privacy warning).
function ENT:SyncJoinShare()
	if self._syncOptedIn then return end
	if not self:IsShared() then return end

	local ent = self
	Derma_Query(
		"Joining shared browsing exposes your IP address to the websites " ..
		"being visited.\n\nOnly join sessions hosted by people you trust.\n\n" ..
		"Do you want to continue?",
		"Privacy Warning",
		"Join", function()
			if not IsValid(ent) then return end
			ent._syncOptedIn = true
			-- Navigate to the conductor's current page
			if IsValid(ent.Panel) and IsValid(ent:GetConductor()) then
				-- The next nav sync from the conductor will bring us in sync
			end
		end,
		"Cancel", function() end
	)
end

--- Leave a shared session.
function ENT:SyncLeaveShare()
	self._syncOptedIn = false
end

--- Respond to a takeover request (conductor only).
function ENT:SyncRespondTakeRequest(requesterIdx, accepted)
	net.Start("wbui_sync_take_respond")
		net.WriteUInt(self:EntIndex(), 16)
		net.WriteUInt(requesterIdx, 16)
		net.WriteBool(accepted)
	net.SendToServer()
end

-- ── Cursor relay throttle ────────────────────────────────
ENT._lastCursorSync = 0

function ENT:SyncThrottledCursor(cx, cy)
	if SysTime() - self._lastCursorSync < (1 / 15) then return end -- 15 updates/sec
	self._lastCursorSync = SysTime()
	self:SyncSendCursor(cx, cy)
end
