AddCSLuaFile("autorun/client/cl_wbui.lua")
AddCSLuaFile("autorun/client/cl_wbui_vgui.lua")
AddCSLuaFile("wbui/cef_detection.lua")

resource.AddSingleFile("data_static/wbui_input_handler.txt")
resource.AddSingleFile("data_static/wbui_fullscreen_polyfill.txt")
resource.AddSingleFile("data_static/wbui_sync_hooks.txt")

-- ── Net message registration ──────────────────────────────
util.AddNetworkString("wbui_sync_nav")       -- URL navigation relay
util.AddNetworkString("wbui_sync_media")     -- Media play/pause/seek events
util.AddNetworkString("wbui_sync_media_tick")-- Periodic media time syncx
util.AddNetworkString("wbui_sync_scroll")    -- Scroll position relay
util.AddNetworkString("wbui_sync_cursor")    -- Conductor cursor position
util.AddNetworkString("wbui_sync_set_mode")  -- Toggle shared mode on/off
util.AddNetworkString("wbui_sync_take")      -- Request/take conductor role (also used server→conductor prompt)
util.AddNetworkString("wbui_sync_take_respond") -- Conductor approves/denies takeover
util.AddNetworkString("wbui_sync_input")     -- Text input relay
util.AddNetworkString("wbui_sync_fullscreen")-- Fullscreen state relay

function WbuiPrint(...)
	MsgC(Color(136, 223, 218), "[WBUI] ", Color(187, 187, 187), ..., "\n")
end

function WbuiError(...)
	MsgC(Color(136, 223, 218), "[WBUI] ", Color(255, 0, 0), ..., "\n")
end

-- ── Helpers ───────────────────────────────────────────────

--- Broadcast a net message to all players EXCEPT the sender, scoped to an entity's PVS.
--- @param msgName string  The net message name (already started by caller).
--- @param ent Entity      The wbui_panel entity.
--- @param sender Player   The player to exclude from the broadcast.
local function BroadcastToViewers(msgName, ent, sender)
	local recipients = RecipientFilter()
	recipients:AddPVS(ent:GetPos())
	recipients:RemovePlayer(sender)
	net.Send(recipients)
end

-- ── Relay handlers ────────────────────────────────────────
-- Each handler validates that the sender is the Conductor, then relays to viewers.

local function ValidateConductor(ply)
	local entIdx = net.ReadUInt(16)
	local ent = Entity(entIdx)
	if not IsValid(ent) or ent:GetClass() ~= "wbui_panel" then return nil, nil end
	if ent:GetSyncMode() == WBUI_SYNC_LOCAL then return nil, nil end
	if not ent:IsConductor(ply) then return nil, nil end
	return ent, entIdx
end

-- Navigation relay: Conductor navigated, tell all Viewers to follow
net.Receive("wbui_sync_nav", function(len, ply)
	local ent, entIdx = ValidateConductor(ply)
	if not ent then return end

	local url = net.ReadString()
	if not url or #url == 0 then return end

	WbuiPrint(string.format("Sync nav [%s]: %s -> %s", ply:Nick(), tostring(entIdx), url))

	net.Start("wbui_sync_nav")
		net.WriteUInt(entIdx, 16)
		net.WriteString(url)
	BroadcastToViewers("wbui_sync_nav", ent, ply)
end)

-- Media event relay: play/pause/seek
net.Receive("wbui_sync_media", function(len, ply)
	local ent, entIdx = ValidateConductor(ply)
	if not ent then return end

	local eventType = net.ReadUInt(3)  -- 0=play, 1=pause, 2=seek
	local currentTime = net.ReadFloat()
	local playbackRate = net.ReadFloat()

	net.Start("wbui_sync_media")
		net.WriteUInt(entIdx, 16)
		net.WriteUInt(eventType, 3)
		net.WriteFloat(currentTime)
		net.WriteFloat(playbackRate)
	BroadcastToViewers("wbui_sync_media", ent, ply)
end)

-- Media tick relay: periodic time sync for drift correction
net.Receive("wbui_sync_media_tick", function(len, ply)
	local ent, entIdx = ValidateConductor(ply)
	if not ent then return end

	local currentTime = net.ReadFloat()
	local paused = net.ReadBool()
	local playbackRate = net.ReadFloat()

	net.Start("wbui_sync_media_tick")
		net.WriteUInt(entIdx, 16)
		net.WriteFloat(currentTime)
		net.WriteBool(paused)
		net.WriteFloat(playbackRate)
	BroadcastToViewers("wbui_sync_media_tick", ent, ply)
end)

-- Scroll relay
net.Receive("wbui_sync_scroll", function(len, ply)
	local ent, entIdx = ValidateConductor(ply)
	if not ent then return end

	local ratioX = net.ReadFloat()
	local ratioY = net.ReadFloat()

	net.Start("wbui_sync_scroll")
		net.WriteUInt(entIdx, 16)
		net.WriteFloat(ratioX)
		net.WriteFloat(ratioY)
	BroadcastToViewers("wbui_sync_scroll", ent, ply)
end)

-- Cursor position relay
net.Receive("wbui_sync_cursor", function(len, ply)
	local ent, entIdx = ValidateConductor(ply)
	if not ent then return end

	local cx = net.ReadFloat()
	local cy = net.ReadFloat()

	net.Start("wbui_sync_cursor")
		net.WriteUInt(entIdx, 16)
		net.WriteFloat(cx)
		net.WriteFloat(cy)
	BroadcastToViewers("wbui_sync_cursor", ent, ply)
end)

-- Input text relay
net.Receive("wbui_sync_input", function(len, ply)
	local ent, entIdx = ValidateConductor(ply)
	if not ent then return end

	local selector = net.ReadString()
	local value = net.ReadString()

	net.Start("wbui_sync_input")
		net.WriteUInt(entIdx, 16)
		net.WriteString(selector)
		net.WriteString(value)
	BroadcastToViewers("wbui_sync_input", ent, ply)
end)

-- Fullscreen state relay
net.Receive("wbui_sync_fullscreen", function(len, ply)
	local ent, entIdx = ValidateConductor(ply)
	if not ent then return end

	local active = net.ReadBool()
	local selector = net.ReadString()

	net.Start("wbui_sync_fullscreen")
		net.WriteUInt(entIdx, 16)
		net.WriteBool(active)
		net.WriteString(selector)
	BroadcastToViewers("wbui_sync_fullscreen", ent, ply)
end)

-- Set sync mode: any player can toggle (for now; permissions can be added later)
net.Receive("wbui_sync_set_mode", function(len, ply)
	local entIdx = net.ReadUInt(16)
	local mode = net.ReadUInt(3)
	local ent = Entity(entIdx)

	if not IsValid(ent) or ent:GetClass() ~= "wbui_panel" then return end

	ent:SetSyncMode(mode)

	if mode ~= WBUI_SYNC_LOCAL then
		-- The player who enabled sharing becomes the Conductor
		if not IsValid(ent:GetConductor()) then
			ent:SetConductor(ply)
		end
	else
		ent:SetConductor(NULL)
	end

	WbuiPrint(string.format("Sync mode set to %d on panel %d by %s", mode, entIdx, ply:Nick()))
end)

-- Take conductor role — if there's a current conductor, ask them first
net.Receive("wbui_sync_take", function(len, ply)
	local entIdx = net.ReadUInt(16)
	local ent = Entity(entIdx)

	if not IsValid(ent) or ent:GetClass() ~= "wbui_panel" then return end
	if ent:GetSyncMode() == WBUI_SYNC_LOCAL then return end

	local currentConductor = ent:GetConductor()

	-- If no conductor or requester IS the conductor, just set directly
	if not IsValid(currentConductor) or currentConductor == ply then
		ent:SetConductor(ply)
		WbuiPrint(string.format("%s took conductor on panel %d (no prior conductor)", ply:Nick(), entIdx))
		return
	end

	-- Forward the request to the current conductor for approval
	WbuiPrint(string.format("%s requested conductor on panel %d from %s", ply:Nick(), entIdx, currentConductor:Nick()))
	net.Start("wbui_sync_take")
		net.WriteUInt(entIdx, 16)
		net.WriteUInt(ply:EntIndex(), 16)
		net.WriteString(ply:Nick())
	net.Send(currentConductor)
end)

-- Conductor responds to takeover request
net.Receive("wbui_sync_take_respond", function(len, ply)
	local entIdx = net.ReadUInt(16)
	local requesterIdx = net.ReadUInt(16)
	local accepted = net.ReadBool()

	local ent = Entity(entIdx)
	if not IsValid(ent) or ent:GetClass() ~= "wbui_panel" then return end

	-- Only the current conductor can approve/deny
	if not ent:IsConductor(ply) then return end

	if accepted then
		local requester = Entity(requesterIdx)
		if IsValid(requester) and requester:IsPlayer() then
			ent:SetConductor(requester)
			WbuiPrint(string.format("%s approved takeover by %s on panel %d", ply:Nick(), requester:Nick(), entIdx))
		end
	else
		WbuiPrint(string.format("%s denied takeover request on panel %d", ply:Nick(), entIdx))
	end
end)

WbuiPrint("Server loaded")