include("shared.lua")
include("cl_input.lua")
include("cl_nav.lua")

local imgui = include("imgui.lua")
local inputHandlerJs = [[
	function setupInputElement(element) {
		if (!element.hasAttribute("data-gmod-initialized")) {
			element.setAttribute("data-gmod-initialized", "true");

			element.addEventListener("click", function () {
				if (!this.id) {
					this.id = "gmod_input_" + Math.random().toString(36).substr(2, 9);
				}

				this.focus();
				this.select();
				gmod.inputLock(this.id);
			});
		}
	}

	function setupEditableElement(element) {
		if (!element.hasAttribute("data-gmod-initialized")) {
			element.setAttribute("data-gmod-initialized", "true");

			element.addEventListener("click", function () {
				if (!this.id) {
					this.id =
						"gmod_editable_" + Math.random().toString(36).substr(2, 9);
				}

				this.focus();
				if (window.getSelection && document.createRange) {
					const range = document.createRange();
					range.selectNodeContents(this);
					const selection = window.getSelection();
					selection.removeAllRanges();
					selection.addRange(range);
				}
				gmod.inputLock(this.id);
			});
		}
	}

	function initializeExistingElements() {
		document.querySelectorAll("input, textarea").forEach(setupInputElement);
		document
			.querySelectorAll("[contentEditable=true]")
			.forEach(setupEditableElement);
	}

	function setupMutationObserver() {
		const observer = new MutationObserver((mutations) => {
			mutations.forEach((mutation) => {
				if (mutation.addedNodes && mutation.addedNodes.length > 0) {
					mutation.addedNodes.forEach((node) => {
						if (node.nodeType === Node.ELEMENT_NODE) {
							if (node.matches("input, textarea")) {
								setupInputElement(node);
							}

							if (node.getAttribute("contentEditable") === "true") {
								setupEditableElement(node);
							}

							if (node.querySelectorAll) {
								node
									.querySelectorAll("input, textarea")
									.forEach(setupInputElement);
								node
									.querySelectorAll("[contentEditable=true]")
									.forEach(setupEditableElement);
							}
						}
					});
				}
			});
		});

		observer.observe(document.body, {
			childList: true,
			subtree: true,
		});

		return observer;
	}

	initializeExistingElements();
	setupMutationObserver();

	console.log("[WBUI] Injected.");
]]

ENT.SizeRatio = 10 -- This is just for other surface renders
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
		self.Panel:AddFunction( "gmod", "inputLock", function( str )
			self.Panel:MakePopup()
			self.Panel:SetMouseInputEnabled(false)
		end)
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
		if self.Hovering then
			self:SimulateMouseHover()
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

		if mx and my then
			local cursorSize = 10
			local gradient = Material("gui/gradient")

			render.SetMaterial(gradient)
			surface.DrawCircle(mx, my, 2, 200, 200, 200, 200)
		end

		imgui.End3D2D()
	end

	if self.Hovering then
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
	local inRange = self:GetPos():Distance(LocalPlayer():GetPos()) < self:GetMaxDistance()

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
end

function ENT:OnRemove()
	if self.Panel then 
		self.Panel:Remove()
		self.Mat = nil
	end

	hook.Remove("CreateMove", self)
	hook.Remove("HUDShouldDraw", "HideWeaponSelector")
end
