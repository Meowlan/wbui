include("shared.lua")
include("cl_input.lua")
include("cl_nav.lua")
include("cl_session.lua")

local imgui = include("imgui-wbui.lua")
local inputHandlerJs = file.Read("data_static/wbui_input_handler.txt", "GAME")
local fullscreenPolyfillJs = file.Read("data_static/wbui_fullscreen_polyfill.txt", "GAME")
local syncHooksJs = file.Read("data_static/wbui_sync_hooks.txt", "GAME")

assert(inputHandlerJs, "Failed to load input handler JS")
assert(fullscreenPolyfillJs, "Failed to load fullscreen polyfill JS")
assert(syncHooksJs, "Failed to load sync hooks JS")

ENT.SizeRatio = 100 -- This is just for other surface renders
ENT.ScrollSpeed = 50

ENT.LastUpdate = 0
ENT.NeedUpdate = false

local devCvar = GetConVar("developer")

function ENT:QueueUpdate()
	self.LastUpdate = CurTime() + 1
	self.NeedUpdate = true
end

function ENT:Initialize()
	self.UiInputs = {}

	self:NetworkVarNotify("Angle", self.QueueUpdate)
	self:NetworkVarNotify("HTMLSize", self.QueueUpdate)
	self:NetworkVarNotify("TargetURL", self.QueueUpdate)

	self:NetworkVarNotify("ScreenModel", function(ent, key, old, new)
        ent:SetModel(new)
        ent:PhysicsInit(SOLID_VPHYSICS)

		self:QueueUpdate()
    end)

	-- Auto-leave share when sharing is disabled
	self:NetworkVarNotify("SyncMode", function(ent, key, old, new)
		if new == WBUI_SYNC_LOCAL then
			ent._syncOptedIn = false
		end
	end)

	-- When conductor changes, auto-opt-in the old conductor as a viewer
	self:NetworkVarNotify("Conductor", function(ent, key, old, new)
		if not ent:IsShared() then return end
		if IsValid(old) and old == LocalPlayer() and new ~= LocalPlayer() then
			ent._syncOptedIn = true
		end
	end)

	self:Setup()

	hook.Add("CreateMove", self, self.HandleInputsCreateMove)
	hook.Add("Think", self, function()
			if not IsValidWbuiPanel(self) then return end

			if input.IsKeyDown(KEY_F8) or input.IsKeyDown(KEY_ESCAPE) then
				if self:IsPanelFullscreen() then
					self:ExitPanelFullscreen()
				else
					self.Panel:SetKeyboardInputEnabled(false)
					self.Panel:SetMouseInputEnabled(false)
					self.Panel:SetAlpha(0)
				end
			end

			-- when cursor is visible, IN_ATTACK is never set in usercmd so
			-- we must detect clicks via raw input.IsMouseDown here instead
			if vgui.CursorVisible() then
				self:HandleCursorVisibleInput()
			end
	end)
end

function ENT:Setup()
	self.UiOffset = self:OBBMins()
	self.UiOffset.z = self:OBBMaxs().z
	self.UiSize = self:OBBMaxs() * 2 * self.SizeRatio
	self.UiSize = Vector(self.UiSize.y, self.UiSize.x, self.UiSize.z)

	local aspectRatio = self.UiSize.x / self.UiSize.y

	local ang = self:GetAngle() % 360
	if ang == 90 or ang == 270 then
		self.HTMLResolution = {self:GetHTMLSize(), self:GetHTMLSize() * aspectRatio}
	else
		self.HTMLResolution = {self:GetHTMLSize() * aspectRatio, self:GetHTMLSize()}
	end

	self.Mat = nil
	self:OpenPage()
end

ALREADY_WARNED = ALREADY_WARNED or false

function ENT:OpenPage()
	if IsValid(self.Panel) then
		self.Panel:Remove()
		self.Panel = nil
	end

	if not ALREADY_WARNED and not CEFCodecFixAvailable then
		ALREADY_WARNED = true

		-- it is highly recommend to use WBUI with cefcodecfix, https://solsticegamestudios.com/fixmedia/
		chat.AddText(Color(136, 223, 218), "[WBUI]", Color(255, 100, 100), " It seems like you are not using CEFCodecFix! It is highly recommended to use WBUI with it for maximum compatibility, https://solsticegamestudios.com/fixmedia/")
	end

	local ent = self -- capture entity ref for callbacks where 'self' is shadowed

	self.Panel = vgui.Create("DHTML")
	self.Panel._isWbui = true
	self.Panel:SetSize(unpack(self.HTMLResolution))
	self.Panel:OpenURL(self:GetTargetURL())
	
	self.Panel:SetAlpha(0)
	self.Panel:SetMouseInputEnabled(false)

	self.Panel.OnBeginLoadingDocument = function(self, url)
		self.URL = url
		-- Relay full-page navigations (link clicks, redirects) to Viewers
		ent:SyncSendNav(url)
	end

	self.Panel.OnDocumentReady = function(self, url)
		-- Emulate Fullscreen API (GMod CEF does not support native fullscreen)
		self:RunJavascript(fullscreenPolyfillJs)
		-- Inject javascript to detect forms or anything that requires keyboard input
		self:RunJavascript(inputHandlerJs)
		-- Inject sync hooks JS for both Conductor (event capture) and Viewer (apply helpers)
		self:RunJavascript(syncHooksJs)
	end

	-- wtf is going on here with self 😭
	self.Panel.OnFinishLoadingDocument = function(self, url)
		self.Panel:AddFunction( "gmod", "inputLock", function(force)
			-- Snapshot mouse-lock state before MakePopup() potentially changes it,
			-- so that a textbox click doesn't silently disable the user's mouse lock.
			local mouseLocked = self.Panel:IsMouseInputEnabled()
			self.Panel:MakePopup()
			self.Panel:SetMouseInputEnabled(mouseLocked)

			-- Stay force-locked if the user had mouse locked, so freeInputLock
			-- (triggered on blur) doesn't release keyboard input either.
			self.Panel.ForceInputLock = force or mouseLocked
		end)

		self.Panel:AddFunction( "gmod", "freeInputLock", function()
			if self.Panel.ForceInputLock then return end
			if ent:IsPanelFullscreen() then return end

			self.Panel:SetMouseInputEnabled(false)
			self.Panel:SetKeyboardInputEnabled(false)
		end)

		self.Panel:AddFunction( "gmod", "urlChanged", function(url)
			self.URL = url
		end)

		-- Register sync callbacks for Conductor relay
		ent:SyncSetupConductorHooks()
	end

	self.Panel.OnChildViewCreated = function(self, sourceURL, targetURL)
	   self.Panel:OpenURL(targetURL) -- Otherwise hrefs to new pages dont open
	end

	self.Panel.ConsoleMessage = function(self, message) 
		if devCvar:GetInt() > 0 then
			MsgC(message, "\n")
		end
	end

	self.Panel.Paint = function(pnl, w, h)
		-- While in fullscreen, draw a solid black background so page
		-- navigations don't flash transparent between unload and load.
		if ent:IsPanelFullscreen() then
			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawRect(0, 0, w, h)
		end
	end
end

-- ── Panel Fullscreen (local overlay) ─────────────────────
-- Pops the DHTML panel to fill the player's actual screen.
-- The panel IS resized to ScrW()×ScrH() for a proper fullscreen
-- experience. On exit, we resize back and recreate the 3D2D material
-- with a generation counter (so CreateMaterial returns a fresh one).

function ENT:EnterPanelFullscreen()
	if not IsValid(self.Panel) then return end
	if self._panelFullscreen then return end

	self._panelFullscreen = true
	self._savedPanelState = {
		alpha = self.Panel:GetAlpha(),
		mouse = self.Panel:IsMouseInputEnabled(),
		keyboard = self.Panel:IsKeyboardInputEnabled(),
		forceInputLock = self.Panel.ForceInputLock,
	}

	self.Panel:SetPos(0, 0)
	self.Panel:SetSize(ScrW(), ScrH())
	self.Panel:SetAlpha(255)
	self.Panel:MakePopup()
	self.Panel:SetMouseInputEnabled(true)
	self.Panel:SetKeyboardInputEnabled(true)
	self.Panel.ForceInputLock = true
	self.Panel:SetZPos(32767)

	-- Overlay exit button — parented to the panel so it draws on top
	if IsValid(self._fsExitBtn) then self._fsExitBtn:Remove() end
	self._fsExitBtn = vgui.Create("DButton", self.Panel)
	self._fsExitBtn:SetSize(100, 30)
	self._fsExitBtn:SetPos(ScrW() - 110, 10)
	self._fsExitBtn:SetText("Exit (ESC)")
	self._fsExitBtn:SetFont("DermaDefault")
	self._fsExitBtn:SetTextColor(Color(255, 255, 255))
	self._fsExitBtn.Paint = function(_, w, h)
		draw.RoundedBox(6, 0, 0, w, h, Color(30, 30, 40, 220))
		surface.SetDrawColor(88, 150, 255, 180)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
	end
	local ent = self
	self._fsExitBtn.DoClick = function()
		ent:ExitPanelFullscreen()
	end
end

function ENT:ExitPanelFullscreen()
	if not self._panelFullscreen then return end
	self._panelFullscreen = false

	if IsValid(self._fsExitBtn) then
		self._fsExitBtn:Remove()
		self._fsExitBtn = nil
	end

	if not IsValid(self.Panel) then return end

	local s = self._savedPanelState or {}
	self.Panel:SetSize(self.HTMLResolution[1], self.HTMLResolution[2])
	self.Panel:SetAlpha(s.alpha or 0)
	self.Panel:SetMouseInputEnabled(s.mouse or false)
	self.Panel:SetKeyboardInputEnabled(s.keyboard or false)
	self.Panel.ForceInputLock = s.forceInputLock or false
	self.Panel:SetZPos(0)
	self._savedPanelState = nil

	-- The material is stale (points to fullscreen-sized texture).
	-- Bump generation so CreateWebMaterial makes a fresh one, and
	-- set a cooldown so we don't recreate until the texture settles.
	self._matGeneration = (self._matGeneration or 0) + 1
	self.Mat = nil
	self._matCooldown = RealTime() + 0.5
end

function ENT:IsPanelFullscreen()
	return self._panelFullscreen == true
end

function ENT:CreateWebMaterial()
	if not IsValid(self.Panel) then return end
	
	local html_mat = self.Panel:GetHTMLMaterial()
	if not html_mat then return end

	local scale_x, scale_y = 2048, 2048
	local matdata = {
		["$basetexture"] = html_mat:GetName(),
		["$basetexturetransform"] = string.format("center 0 0 scale %d %d rotate 0 translate 0 0", scale_x, scale_y),
		["$texturealpha"] = 1
	}

	local uid = string.Replace(html_mat:GetName(), "__vgui_texture_", "")
	local gen = self._matGeneration or 0
	return CreateMaterial("WebMaterial_" .. uid .. "_g" .. gen, "gmodscreenspace", matdata)
end

function ENT:Draw()
	self:DrawModel()

	if IsValid(self.Panel) and imgui.Entity3D2D(self, self.UiOffset, Angle(0, 90, 0), 1 / self.SizeRatio) then
		if self.Hovering == nil then self.Hovering = false end
		local mx, my = imgui.CursorPos()
		self.UiInputs.VguiMouseX, self.UiInputs.VguiMouseY = mx, my
		
		-- update mouse input coordinates, could probably simplify this a lot
		if mx and my then
			local rotatedX, rotatedY

			local ang = self:GetAngle() % 360
			local swapDimensions = ang == 90 or ang == 270
			local uiWidth = swapDimensions and self.UiSize.y or self.UiSize.x
			local uiHeight = swapDimensions and self.UiSize.x or self.UiSize.y

			local normalizedX = mx / self.UiSize.x
			local normalizedY = my / self.UiSize.y

			local centerX, centerY = self.UiSize.x / 2, self.UiSize.y / 2
			local angleRad = math.rad(self:GetAngle())

			local translatedX = mx - centerX
			local translatedY = my - centerY

			local tempX = translatedX * math.cos(angleRad) - translatedY * math.sin(angleRad)
			local tempY = translatedX * math.sin(angleRad) + translatedY * math.cos(angleRad)

			rotatedX = tempX + uiWidth / 2
			rotatedY = tempY + uiHeight / 2

			self.UiInputs.MouseX = rotatedX / uiWidth * self.HTMLResolution[1]
			self.UiInputs.MouseY = rotatedY / uiHeight * self.HTMLResolution[2]
		end

		-- When SetMouseInputEnabled is true the browser receives native VGUI mouse
		-- events at (screen_x - panel_x, screen_y - panel_y).  Shift the panel so
		-- that value equals the 3D-projected MouseX/Y we are already injecting via
		-- JS, keeping both coordinate systems in sync and eliminating cursor offset.
		-- Skip this while in panel fullscreen — the panel is already at (0,0) filling the screen.
		if not self:IsPanelFullscreen() and self.Panel:IsMouseInputEnabled() and self.UiInputs.MouseX and self.UiInputs.MouseY then
			self.Panel:SetPos(
				gui.MouseX() - self.UiInputs.MouseX,
				gui.MouseY() - self.UiInputs.MouseY
			)
		end

		self.Hovering = imgui.IsHovering(0, 0, self.UiSize.x, self.UiSize.y)
		if self.Hovering and not self:GetLocked() and not self:IsLocalViewer() then
			-- Build the real held-buttons bitmask so mousemove events accurately
			-- reflect which buttons are down (left=1, right=2, middle=4).
			-- Without this, button=0 default makes JS always set buttons=1 (left
			-- held), confusing games like Eaglercraft that read buttons on mousemove.
			local heldMask = (self._clickState and 1 or 0)
				+ (self._rightClickState and 2 or 0)
				+ (self._middleClickState and 4 or 0)
    		self:SimulateMouseInput("mousemove", 0, heldMask)

			-- Conductor: relay cursor position to Viewers
			if self:IsLocalConductor() and self.UiInputs.MouseX and self.UiInputs.MouseY then
				self:SyncThrottledCursor(
					self.UiInputs.MouseX / self.HTMLResolution[1],
					self.UiInputs.MouseY / self.HTMLResolution[2]
				)
			end
		end

		if self.Hovering and not self:GetLocked() then
			hook.Add("HUDShouldDraw", "HideWeaponSelector", function(name)
				if name == "CHudWeaponSelection" then
					return false
				end
			end)
		else
			hook.Remove("HUDShouldDraw", "HideWeaponSelector")
		end

		if self.Mat then
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(self.Mat)

			local sizeX, sizeY = self.UiSize.x, self.UiSize.y
			if math.abs(self:GetAngle()) == 90 or math.abs(self:GetAngle()) == 270 then
				sizeX, sizeY = sizeY, sizeX
			end

			surface.DrawTexturedRectRotated(self.UiSize.x / 2, self.UiSize.y / 2, sizeX, sizeY, self:GetAngle())
		elseif self.Panel:GetHTMLMaterial() and not self:IsPanelFullscreen() and (not self._matCooldown or RealTime() > self._matCooldown) then
			self.Mat = self:CreateWebMaterial()
		end

		-- Draw Conductor's ghost cursor for Viewers
		if self:IsLocalViewer() and self.SyncConductorCursor then
			local cc = self.SyncConductorCursor
			local age = SysTime() - cc.time
			if age < 1 then -- fade out after 1 second of no updates
				local alpha = math.Clamp(255 * (1 - age), 0, 255)
				local gcx = cc.x * self.UiSize.x
				local gcy = cc.y * self.UiSize.y
				surface.SetDrawColor(100, 180, 255, alpha)
				surface.DrawCircle(gcx, gcy, 40)
				surface.DrawCircle(gcx, gcy, 20)

				-- Draw conductor name label
				local conductor = self:GetConductor()
				if IsValid(conductor) then
					draw.SimpleText(
						conductor:Nick(),
						"DermaDefault",
						gcx + 50, gcy - 10,
						Color(100, 180, 255, alpha),
						TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP
					)
				end
			end
		end

		if not mx or not my or self:GetLocked() then imgui.End3D2D() return end
		if mx < 0 or my < 0 or mx > self.UiSize.x or my > self.UiSize.y then imgui.End3D2D() return end

		-- Viewers don't get their own cursor or click interaction
		if self:IsLocalViewer() then imgui.End3D2D() return end

		-- When mouse input is enabled (input lock / fullscreen), the DHTML
		-- renders its own native cursor, so hide our custom 3D2D one.
		if self.Panel:IsMouseInputEnabled() then imgui.End3D2D() return end

		local cursorSize = 50
		local sinceMouseUp = SysTime() - (self.UiInputs.LastMouseUp or 0)

		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawCircle(mx, my, self.UiInputs.MouseDown and cursorSize * 0.8 or cursorSize)

		if self.UiInputs.LastMouseUpPos and self.UiInputs.LastMouseUp then
			local rippleProgress = math.Clamp(sinceMouseUp / 1.0, 0, 0.5)
			local rippleSize = cursorSize * (1 + (2 * math.ease.OutQuad(rippleProgress)))
			local rippleAlpha = 255 * (1 - math.ease.OutQuad(rippleProgress * 2))

			surface.SetDrawColor(255, 255, 255, rippleAlpha)
			surface.DrawCircle(
					self.UiInputs.LastMouseUpPosVGUI.x, 
					self.UiInputs.LastMouseUpPosVGUI.y, 
					rippleSize
			)
		end

		imgui.End3D2D()
	else
		-- Entity3D2D returned false (not in view / panel invalid): ensure hover cleanup runs
		if self.Hovering then
			self.Hovering = false
			hook.Remove("HUDShouldDraw", "HideWeaponSelector")
		end
	end
end

function ENT:Think()
   local pos = self:WorldSpaceCenter()
   local plyPos = LocalPlayer():EyePos()
   local dist = pos:Distance(plyPos)
	local inRange = dist < self:GetMaxDistance()

	if inRange and not IsValid(self.Panel) then
		self:OpenPage()
	elseif not inRange and IsValid(self.Panel) then
		self.LastUrl = self.Panel.URL
		self.Panel:Remove()
		self.Panel = nil
		self.Mat = nil
		self.Hovering = false
		hook.Remove("HUDShouldDraw", "HideWeaponSelector")
	end

	if self.NeedUpdate and self.LastUpdate < CurTime()  then
		self.NeedUpdate = false
		self:Setup()

		LocalPlayer():EmitSound("ambient/water/drip" .. math.random(1, 3) .. ".wav", 75, 100)
	end

   -- TODO: Whole bunch of magic numbers, needs some settings
   if IsValid(self.Panel) then
      local plyDir = LocalPlayer():GetAimVector()
      local dir = (pos - plyPos):GetNormalized()
      local dot = plyDir:Dot(dir)

      local angleFactor = math.Clamp((dot + 1) / 2, 0.1, 1)

      local dist = pos:Distance(plyPos)
      local maxDist = 500

		if dist <= 0 or dist >= maxDist then return end
      local distanceFactor = math.Clamp((1 - (dist / maxDist))^2, 0, 1)
      local finalVolume = math.Clamp(angleFactor * distanceFactor* 0.2, 0, 0.2) * self:GetVolume() 

      self.Panel:RunJavascript(string.format([[
         document.querySelectorAll('audio, video').forEach(el => {
            el.volume = %f;
         });
      ]], finalVolume))
   end
end

function ENT:OnRemove()
	self:ExitPanelFullscreen()

	if self.Panel then 
		self.Panel:Remove()
		self.Mat = nil
	end

	hook.Remove("CreateMove", self)
	hook.Remove("HUDShouldDraw", "HideWeaponSelector")
end
