include("shared.lua")
include("cl_input.lua")
include("cl_nav.lua")

local imgui = include("imgui.lua")
local inputHandlerJs = [[function setupInputElement(element) {
   if (!element.hasAttribute("data-gmod-initialized")) {
      element.setAttribute("data-gmod-initialized", "true");

      element.addEventListener("click", function () {
         if (!this.id) {
            this.id = "gmod_input_" + Math.random().toString(36).substr(2, 9);
         }

         this.focus();
         this.select();
         gmod.inputLock();
      });

      element.addEventListener("submit", function () {
         gmod.freeInputLock();
      });

      element.addEventListener("blur", function () {
         gmod.freeInputLock();
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
         gmod.inputLock();
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
         if (!mutation.addedNodes || !mutation.addedNodes.length) return;

         mutation.addedNodes.forEach((node) => {
            if (node.nodeType !== Node.ELEMENT_NODE) return;

            if (node.matches("input, textarea")) {
               setupInputElement(node);
            }

            if (node.getAttribute("contentEditable") !== "true") return;

            setupEditableElement(node);

            if (!node.querySelectorAll) return;

            node.querySelectorAll("input, textarea").forEach(setupInputElement);
            node
               .querySelectorAll("[contentEditable=true]")
               .forEach(setupEditableElement);
         });
      });
   });

   observer.observe(document.body, {
      childList: true,
      subtree: true,
   });

   return observer;
}

if (!window.gmod) {
   window.gmod = {};
}

gmod.simulateMouseInput = function (type, x, y, button = 0) {
   const eventOptions = {
      view: window,
      bubbles: true,
      cancelable: true,
      clientX: x,
      clientY: y,
      button: button,
      buttons: button === 0 ? 1 : button === 1 ? 4 : 2,
      screenX: x,
      screenY: y,
   };

   const mouseEvent = new MouseEvent(type, eventOptions);
   const targetElement = document.elementFromPoint(x, y);

   if (!gmod.lastHoverElement) gmod.lastHoverElement = null;

   if (targetElement) {
      targetElement.dispatchEvent(mouseEvent);

      if (type === "mousedown") {
         gmod.lastDownElement = targetElement;
         gmod.isDragging = true;
      } else if (type === "mouseup") {
         gmod.isDragging = false;

         if (gmod.lastDownElement === targetElement) {
            const clickEvent = new MouseEvent("click", eventOptions);
            targetElement.dispatchEvent(clickEvent);
         }

         gmod.lastDownElement = null;
         gmod.lastClickElement = targetElement;
      } else if (type === "mousemove") {
         if (targetElement !== gmod.lastHoverElement) {
            if (gmod.lastHoverElement) {
               const leaveEvent = new MouseEvent("mouseleave", {
                  ...eventOptions,
                  relatedTarget: targetElement,
               });
               gmod.lastHoverElement.dispatchEvent(leaveEvent);
            }

            const enterEvent = new MouseEvent("mouseenter", {
               ...eventOptions,
               relatedTarget: gmod.lastHoverElement,
            });
            targetElement.dispatchEvent(enterEvent);

            gmod.lastHoverElement = targetElement;
         }

         const hoverEvent = new MouseEvent("mouseover", eventOptions);
         targetElement.dispatchEvent(hoverEvent);

         if (gmod.isDragging && gmod.lastDownElement) {
            const dragEvent = new MouseEvent("drag", eventOptions);
            gmod.lastDownElement.dispatchEvent(dragEvent);

            const dragOverEvent = new MouseEvent("dragover", eventOptions);
            targetElement.dispatchEvent(dragOverEvent);
         }

         const computedStyle = window.getComputedStyle(targetElement);
         document.body.style.cursor = computedStyle.cursor;
      }

      return true;
   } else {
      if (type === "mousemove" && gmod.lastHoverElement) {
         const leaveEvent = new MouseEvent("mouseleave", {
            ...eventOptions,
            relatedTarget: null,
         });
         gmod.lastHoverElement.dispatchEvent(leaveEvent);
         gmod.lastHoverElement = null;

         document.body.style.cursor = "default";
      }

      return false;
   }
};

if (!gmod.lastDownElement) gmod.lastDownElement = null;
if (!gmod.lastClickElement) gmod.lastClickElement = null;
if (!gmod.lastHoverElement) gmod.lastHoverElement = null;
if (!gmod.isDragging) gmod.isDragging = false;

function createKeyboardToggle() {
   // Create container div for the toggle button
   const toggleContainer = document.createElement("div");
   toggleContainer.id = "keyboard-toggle-container";
   toggleContainer.style.position = "fixed";
   toggleContainer.style.bottom = "20px";
   toggleContainer.style.right = "20px";
   toggleContainer.style.zIndex = "9999";
   toggleContainer.style.width = "50px";
   toggleContainer.style.height = "50px";
   toggleContainer.style.borderRadius = "50%";
   toggleContainer.style.backgroundColor = "#4354593F";
   toggleContainer.style.boxShadow = "0 4px 8px rgba(0, 0, 0, 0.2)";
   toggleContainer.style.cursor = "pointer";
   toggleContainer.style.display = "flex";
   toggleContainer.style.justifyContent = "center";
   toggleContainer.style.alignItems = "center";
   toggleContainer.style.transition = "background-color 0.3s ease";

   // Add keyboard icon
   toggleContainer.innerHTML = `
    <svg stroke="currentColor" fill="white" stroke-width="0" viewBox="0 0 576 512" height="30px" width="30px" xmlns="http://www.w3.org/2000/svg">
        <path d="M528 448H48c-26.51 0-48-21.49-48-48V112c0-26.51 21.49-48 48-48h480c26.51 0 48 21.49 48 48v288c0 26.51-21.49 48-48 48zM128 180v-40c0-6.627-5.373-12-12-12H76c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h40c6.627 0 12-5.373 12-12zm96 0v-40c0-6.627-5.373-12-12-12h-40c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h40c6.627 0 12-5.373 12-12zm96 0v-40c0-6.627-5.373-12-12-12h-40c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h40c6.627 0 12-5.373 12-12zm96 0v-40c0-6.627-5.373-12-12-12h-40c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h40c6.627 0 12-5.373 12-12zm96 0v-40c0-6.627-5.373-12-12-12h-40c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h40c6.627 0 12-5.373 12-12zm-336 96v-40c0-6.627-5.373-12-12-12h-40c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h40c6.627 0 12-5.373 12-12zm96 0v-40c0-6.627-5.373-12-12-12h-40c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h40c6.627 0 12-5.373 12-12zm96 0v-40c0-6.627-5.373-12-12-12h-40c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h40c6.627 0 12-5.373 12-12zm96 0v-40c0-6.627-5.373-12-12-12h-40c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h40c6.627 0 12-5.373 12-12zm-336 96v-40c0-6.627-5.373-12-12-12H76c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h40c6.627 0 12-5.373 12-12zm288 0v-40c0-6.627-5.373-12-12-12H172c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h232c6.627 0 12-5.373 12-12zm96 0v-40c0-6.627-5.373-12-12-12h-40c-6.627 0-12 5.373-12 12v40c0 6.627 5.373 12 12 12h40c6.627 0 12-5.373 12-12z"></path>
    </svg>
    `;

   // Create tooltip to show current state
   const tooltip = document.createElement("div");
   tooltip.id = "keyboard-toggle-tooltip";
   tooltip.innerText = "Keyboard: Unlocked";
   tooltip.style.position = "absolute";
   tooltip.style.top = "-40px";
   tooltip.style.right = "0";
   tooltip.style.backgroundColor = "rgba(0, 0, 0, 0.7)";
   tooltip.style.color = "white";
   tooltip.style.padding = "5px 10px";
   tooltip.style.borderRadius = "5px";
   tooltip.style.fontSize = "14px";
   tooltip.style.whiteSpace = "nowrap";
   tooltip.style.opacity = "0";
   tooltip.style.transition = "opacity 0.3s ease";

   toggleContainer.appendChild(tooltip);

   toggleContainer.addEventListener("mouseenter", () => {
      tooltip.style.opacity = "1";
   });

   toggleContainer.addEventListener("mouseleave", () => {
      tooltip.style.opacity = "0";
   });

   let isInputLocked = false;
   let forceInputLocked = false;

   toggleContainer.addEventListener("click", () => {
      if (isInputLocked) {
         isInputLocked = false;
         forceInputLocked = false;

			gmod.freeInputLock();
			
         toggleContainer.style.backgroundColor = "#4354593F";
         tooltip.innerText = "Keyboard: Unlocked";
      } else {
			gmod.inputLock(true);

         isInputLocked = true;
         forceInputLocked = true;
         toggleContainer.style.backgroundColor = "#F44336FF";
         tooltip.innerText = "Keyboard: Locked";
      }
   });

   // a bit sketchy
   if (window.gmod) {
      const originalInputLock = window.gmod.inputLock;
      window.gmod.inputLock = function (...args) {
         if (forceInputLocked) return;

         isInputLocked = true;
         toggleContainer.style.backgroundColor = "#F44336";
         tooltip.innerText = "Keyboard: Locked";
         return originalInputLock.apply(this, args);
      };

      const originalFreeInputLock = window.gmod.freeInputLock;
      window.gmod.freeInputLock = function (...args) {
         if (forceInputLocked) return;

         isInputLocked = false;
         toggleContainer.style.backgroundColor = "#4354593F";
         tooltip.innerText = "Keyboard: Unlocked";
         return originalFreeInputLock.apply(this, args);
      };
   }

   document.body.appendChild(toggleContainer);
   console.log("[WBUI] Keyboard toggle added");
}

initializeExistingElements();
setupMutationObserver();

window.onbeforeunload = function (event) {
   window.gmod.freeInputLock();
};

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

		-- TODO: better DrawCircle function!!!
		if mx and my and not self:GetLocked() then
			local cursorSize = 5
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
