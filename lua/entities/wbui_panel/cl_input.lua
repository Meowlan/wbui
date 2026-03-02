function ENT:SimulateMouseInput(type, button, buttonsMask)
    if not IsValid(self.Panel) or not self.UiInputs.MouseX or not self.UiInputs.MouseY then return end

    -- When mouse input is enabled, the DHTML panel receives native VGUI mouse
    -- events directly (mousedown/mouseup/mousemove), so JS simulation would
    -- double-fire every event and corrupt the browser's button state.
    if self.Panel:IsMouseInputEnabled() then return end

    button = button or 0
    -- -1 tells JS to derive buttons from the single button index (default behaviour)
    buttonsMask = buttonsMask or -1

    local clickScript = string.format([[
        if (window.gmod && typeof window.gmod.simulateMouseInput === "function")
            gmod.simulateMouseInput("%s", %d, %d, %d, %d);
    ]], type, self.UiInputs.MouseX, self.UiInputs.MouseY, button, buttonsMask)
     
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

function ENT:OnMouseDown(button)
    self:SimulateMouseInput("mousedown", button)

    -- only update visual / click-ripple state for primary (left) button
    if not button or button == 0 then
        self.UiInputs.MouseDown = true
        self.UiInputs.LastMouseDown = SysTime()
        self.UiInputs.LastMouseDownPos = {x = self.UiInputs.MouseX, y = self.UiInputs.MouseY}
        self.UiInputs.LastMouseDownPosVGUI = {x = self.UiInputs.VguiMouseX, y = self.UiInputs.VguiMouseY}
    end
end

function ENT:OnMouseUp(button)
    self:SimulateMouseInput("mouseup", button)

    if not button or button == 0 then
        self.UiInputs.MouseDown = false
        sound.Play("ambient/water/drip1.wav", self:GetPos(), 75, 100)
        self.UiInputs.LastMouseUp = SysTime()
        self.UiInputs.LastMouseUpPos = {x = self.UiInputs.MouseX, y = self.UiInputs.MouseY}
        self.UiInputs.LastMouseUpPosVGUI = {x = self.UiInputs.VguiMouseX, y = self.UiInputs.VguiMouseY}
    end
end

function ENT:HandleInputsCreateMove(cmd)
    if self:GetLocked() then return end

    -- when cursor is visible (e.g. holding C), VGUI captures mouse clicks so
    -- IN_ATTACK is never set in the usercmd; click state is handled in Think instead
    if vgui.CursorVisible() then
        -- when cursor is visible, only suppress left-click (IN_ATTACK) so that
        -- right-click (IN_ATTACK2) is free for GMod's own entity-properties menu
        if self.Hovering then
            cmd:RemoveKey(IN_ATTACK)
        end
        return
    end

    local leftState = cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_USE)
    local rightState = cmd:KeyDown(IN_ATTACK2)
    if (leftState or rightState) and not self.Panel.ForceInputLock then
        self.Panel:SetKeyBoardInputEnabled(false)
    end

    if not IsValid(self) or not self.Hovering then return end

    -- always suppress weapon fire while the player is hovering over the screen
    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
    cmd:RemoveKey(IN_USE)

    local wheelDelta = cmd:GetMouseWheel()
    if wheelDelta ~= 0 then
        self:SimulateScroll(wheelDelta)
        cmd:ClearMovement()
        cmd:ClearButtons()
    end

    -- left click (primary / USE)
    if not leftState and self._clickState then
        self._clickState = nil
        self:OnMouseUp(0)
    elseif leftState then
        if not self._clickState then
            self:OnMouseDown(0)
        end
        self._clickState = true
    end

    -- right click
    if not rightState and self._rightClickState then
        self._rightClickState = nil
        self:OnMouseUp(2)
    elseif rightState then
        if not self._rightClickState then
            self:OnMouseDown(2)
        end
        self._rightClickState = true
    end

    -- middle click (not in usercmd, poll directly)
    local middleState = input.IsMouseDown(MOUSE_MIDDLE)
    if not middleState and self._middleClickState then
        self._middleClickState = nil
        self:OnMouseUp(1)
    elseif middleState then
        if not self._middleClickState then
            self:OnMouseDown(1)
        end
        self._middleClickState = true
    end
end

function ENT:HandleCursorVisibleInput()
    -- called from Think when cursor is visible
    -- use raw IsMouseDown since VGUI captures clicks and never sets IN_ATTACK
    local hoveredPanel = vgui.GetHoveredPanel()
    local panelBlocking = IsValid(hoveredPanel) and hoveredPanel ~= vgui.GetWorldPanel() and hoveredPanel:GetName() ~= "ContextMenu"
    if not self.Hovering or self:GetLocked() or panelBlocking then
        if self._clickState then
            self._clickState = nil
            self:OnMouseUp(0)
        end
        if self._rightClickState then
            self._rightClickState = nil
            self:OnMouseUp(2)
        end
        if self._middleClickState then
            self._middleClickState = nil
            self:OnMouseUp(1)
        end
        return
    end

    local state = input.IsMouseDown(MOUSE_LEFT)
    -- right-click is forwarded to the page only when the user has explicitly
    -- locked the mouse; otherwise it is left free for GMod's context menu
    local rightState = self.Panel.ForceInputLock and input.IsMouseDown(MOUSE_RIGHT)

    if (state or rightState) and not self.Panel.ForceInputLock then
        self.Panel:SetKeyBoardInputEnabled(false)
    end

    -- left click
    if not state and self._clickState then
        self._clickState = nil
        self:OnMouseUp(0)
    elseif state then
        if not self._clickState then
            self:OnMouseDown(0)
        end
        self._clickState = true
    end

    -- right click (only when mouse is locked)
    if not rightState and self._rightClickState then
        self._rightClickState = nil
        self:OnMouseUp(2)
    elseif rightState then
        if not self._rightClickState then
            self:OnMouseDown(2)
        end
        self._rightClickState = true
    end

    -- middle click
    local middleState = input.IsMouseDown(MOUSE_MIDDLE)
    if not middleState and self._middleClickState then
        self._middleClickState = nil
        self:OnMouseUp(1)
    elseif middleState then
        if not self._middleClickState then
            self:OnMouseDown(1)
        end
        self._middleClickState = true
    end
end
