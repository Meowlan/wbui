function ENT:SimulateMouseInput(type)
    if not IsValid(self.Panel) or not self.UiInputs.MouseX or not self.UiInputs.MouseY then return end

    local clickScript = string.format([[
        if (window.gmod && typeof window.gmod.simulateMouseInput === "function")
            gmod.simulateMouseInput("%s", %d, %d);
    ]], type, self.UiInputs.MouseX, self.UiInputs.MouseY)
     
    self.Panel:RunJavascript(clickScript)
end

function ENT:SimulateScroll(delta)
    if not IsValid(self.Panel) then return end

    local scrollScript = string.format([[
        window.scrollBy(0, %d);
    ]], delta * -self.ScrollSpeed)
    
    self.Panel:RunJavascript(scrollScript)
end

-- TODO: prevent default behavior correctly, and support all inputs

function ENT:OnMouseDown()
    self:SimulateMouseInput("mousedown")

    self.UiInputs.MouseDown = true
    self.UiInputs.LastMouseDown = SysTime()
    self.UiInputs.LastMouseDownPos = {x = self.UiInputs.MouseX, y = self.UiInputs.MouseY}
    self.UiInputs.LastMouseDownPosVGUI = {x = self.UiInputs.VguiMouseX, y = self.UiInputs.VguiMouseY}
end

function ENT:OnMouseUp()
    self:SimulateMouseInput("mouseup")
    self.UiInputs.MouseDown = false

    sound.Play("ambient/water/drip1.wav", self:GetPos(), 75, 100)
    self.UiInputs.LastMouseUp = SysTime()
    self.UiInputs.LastMouseUpPos = {x = self.UiInputs.MouseX, y = self.UiInputs.MouseY}
    self.UiInputs.LastMouseUpPosVGUI = {x = self.UiInputs.VguiMouseX, y = self.UiInputs.VguiMouseY}
end

function ENT:HandleInputsCreateMove(cmd)
    if self:GetLocked() then return end

    local state = cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2)
    if state and not self.Panel.ForceInputLock then
        self.Panel:SetKeyBoardInputEnabled(false)
    end

    if not IsValid(self) or not self.Hovering then return end
    local wheelDelta = cmd:GetMouseWheel()
    if wheelDelta ~= 0 then
        self:SimulateScroll(wheelDelta)
        cmd:ClearMovement()
        cmd:ClearButtons()
    end

    if not state and self._clickState then
        self._clickState = nil
        self:OnMouseUp()
    elseif state then
        if not self._clickState then
            self:OnMouseDown()
        end

        self._clickState = true
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)
    end
end
