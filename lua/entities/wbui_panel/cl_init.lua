include("shared.lua")
include("cl_input.lua")
include("cl_nav.lua")

local imgui = include("imgui.lua")
local inputHandlerJs = file.Read("addons/wbui/data/wbuiInputHandler.js", "GAME")

ENT.SizeRatio = 100 -- This is just for other surface renders
ENT.ScrollSpeed = 50

ENT.LastUpdate = 0
ENT.NeedUpdate = false

function ENT:QueueUpdate()
	self.LastUpdate = CurTime() + 1
	self.NeedUpdate = true
end

function ENT:Initialize()
	self.UiInputs = {}

	self:NetworkVarNotify("Angle", self.QueueUpdate)
	self:NetworkVarNotify("HTMLSize", self.QueueUpdate)
	self:NetworkVarNotify("URL", self.QueueUpdate)

	self:NetworkVarNotify("ScreenModel", function(ent, key, old, new)
        ent:SetModel(new)
        ent:PhysicsInit(SOLID_VPHYSICS)

		self:QueueUpdate()
    end)

	self:Setup()

	hook.Add("CreateMove", self, self.HandleInputsCreateMove)
end

function ENT:Setup()
	self.UiOffset = self:OBBMins()
	self.UiOffset.z = self:OBBMaxs().z
	self.UiSize = self:OBBMaxs() * 2 * self.SizeRatio
	self.UiSize = Vector(self.UiSize.y, self.UiSize.x, self.UiSize.z)

	local aspectRatio = self.UiSize.x / self.UiSize.y
	self.HTMLResolution = {self:GetHTMLSize() * aspectRatio, self:GetHTMLSize()}

	if self:GetAngle() == 90 or self:GetAngle() == 270 then
		self.HTMLResolution = {self:GetHTMLSize(), self:GetHTMLSize() * aspectRatio}
	end

	self.Mat = nil
	self:OpenPage()
end

-- TODO: Dont forget to remove this
if vgui.GetKeyboardFocus() then
	vgui.GetKeyboardFocus():Remove()
end

function ENT:OpenPage()
	if self.Panel then
		self.Panel:Remove()
		self.Panel = nil
	end

	self.Panel = vgui.Create("DHTML")
	self.Panel:SetSize(unpack(self.HTMLResolution))
	self.Panel:OpenURL(self:GetURL())
	
	self.Panel:SetAlpha(0)
	self.Panel:SetMouseInputEnabled(false)

	self.Panel.OnBeginLoadingDocument = function(self, url)
		self.Panel.URL = url
	end

	self.Panel.OnDocumentReady = function(self, url)
		-- Inject javascript to detect forms or anything that requires keyboard input
		self:RunJavascript(inputHandlerJs)
	end

	self.Panel.OnFinishLoadingDocument = function(self, url)
		self.Panel:AddFunction( "gmod", "inputLock", function(force)
			self.Panel:MakePopup()
			self.Panel:SetMouseInputEnabled(false)

			self.ForceInputLock = force
		end)

		self.Panel:AddFunction( "gmod", "freeInputLock", function()
			self.Panel:SetMouseInputEnabled(false)
			self.Panel:SetKeyboardInputEnabled(false)

			self.ForceInputLock = false
		end)

		self.Panel:RunJavascript("window.createKeyboardToggle();")
	end

	self.Panel.OnChildViewCreated = function(self, sourceURL, targetURL)
	   self.Panel:OpenURL(targetURL) -- Otherwise hrefs to new pages dont open
	end

	-- self.Panel.ConsoleMessage = function(self, message) end
end

function ENT:CreateWebMaterial()
	if not self.Panel then return nil end
	
	local html_mat = self.Panel:GetHTMLMaterial()
	if not html_mat then return nil end

	local scale_x, scale_y = 2048, 2048
	local matdata = {
		["$basetexture"] = html_mat:GetName(),
		["$basetexturetransform"] = string.format("center 0 0 scale %d %d rotate 0 translate 0 0", scale_x, scale_y),
		["$texturealpha"] = 1
	}

	local uid = string.Replace(html_mat:GetName(), "__vgui_texture_", "")
	return CreateMaterial("WebMaterial_" .. uid, "gmodscreenspace", matdata)
end

function ENT:Draw()
	self:DrawModel()

	if IsValid(self.Panel) and imgui.Entity3D2D(self, self.UiOffset, Angle(0, 90, 0), 1 / self.SizeRatio) then
		local mx, my = imgui.CursorPos()
		self.UiInputs.VguiMouseX, self.UiInputs.VguiMouseY = mx, my
		
		-- update mouse input coordinates, could probably simplify this a lot
		if mx and my then
			local rotatedX, rotatedY

			local swapDimensions = (math.abs(self:GetAngle()) == 90 or math.abs(self:GetAngle()) == 270)
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

		self.Hovering = imgui.IsHovering(0, 0, self.UiSize.x, self.UiSize.y)
		if self.Hovering and not self:GetLocked() then
    	self:SimulateMouseInput("mousemove")
		end

		if self.Mat then
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(self.Mat)

			local sizeX, sizeY = self.UiSize.x, self.UiSize.y
			if math.abs(self:GetAngle()) == 90 or math.abs(self:GetAngle()) == 270 then
				sizeX, sizeY = sizeY, sizeX
			end

			surface.DrawTexturedRectRotated(self.UiSize.x / 2, self.UiSize.y / 2, sizeX, sizeY, self:GetAngle())
		elseif self.Panel:GetHTMLMaterial() then
			self.Mat = self:CreateWebMaterial()
		end

		if not mx or not my or self:GetLocked() then imgui.End3D2D() return end
		if mx < 0 or my < 0 or mx > self.UiSize.x or my > self.UiSize.y then imgui.End3D2D() return end

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
end

function ENT:Think()
   local pos = self:WorldSpaceCenter()
   local plyPos = LocalPlayer():EyePos()
   local dist = pos:Distance(plyPos)
	local inRange = dist < self:GetMaxDistance()

	if inRange and not self.Panel then
		self:OpenPage()
	elseif not inRange and self.Panel then
		self.LastUrl = self.Panel.URL
		self.Panel:Remove()
		self.Panel = nil
		self.Mat = nil
	end

	if self.NeedUpdate and self.LastUpdate < CurTime()  then
		self.NeedUpdate = false
		self:Setup()

		LocalPlayer():EmitSound("ambient/water/drip" .. math.random(1, 3) .. ".wav", 75, 100)
	end

   -- TODO: Whole bunch of magic numbers, needs some settings
   if self.Panel then
      local plyDir = LocalPlayer():GetAimVector()
      local dir = (pos - plyPos):GetNormalized()
      local dot = plyDir:Dot(dir)

      local angleFactor = math.Clamp((dot + 1) / 2, 0.1, 1)

      local dist = pos:Distance(plyPos)
      local maxDist = 500

		if dist <= 0 or dist >= maxDist then return end
      local distanceFactor = math.Clamp((1 - (dist / maxDist))^2, 0, 1)
      local finalVolume = math.Clamp(angleFactor * distanceFactor * self:GetVolume() * 0.2, 0, 0.2)

      self.Panel:RunJavascript(string.format([[
         document.querySelectorAll('audio, video').forEach(el => {
            el.volume = %f;
         });
      ]], finalVolume))
   end
end

function ENT:OnRemove()
	if self.Panel then 
		self.Panel:Remove()
		self.Mat = nil
	end

	hook.Remove("CreateMove", self)
	hook.Remove("HUDShouldDraw", "HideWeaponSelector")
end
