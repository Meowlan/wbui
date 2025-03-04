function ENT:SimulateMouseClick()
    if not self.Panel or not self.UiInputs.MouseX or not self.UiInputs.MouseY then return end

    local clickScript = string.format([[
        var x = %d;
        var y = %d;
        var element = document.elementFromPoint(x, y);
        
        if (element) {
            var events = ['mouseover', 'mousedown', 'click', 'mouseup'];
            events.forEach(function(eventType) {
                var event = new MouseEvent(eventType, {
                    'view': window,
                    'bubbles': true,
                    'cancelable': true,
                    'clientX': x,
                    'clientY': y
                });
                element.dispatchEvent(event);
            });
        }
    ]], self.UiInputs.MouseX, self.UiInputs.MouseY)
     
    self.Panel:RunJavascript(clickScript)
end

function ENT:SimulateMouseHover()
    if not self.Panel or not self.UiInputs.MouseX or not self.UiInputs.MouseY then return end
    
    local enterScript = string.format([[
        var x = %d;
        var y = %d;
        var element = document.elementFromPoint(x, y);
        
        if (element) {
            var events = ['mouseover', 'mousemove'];
            events.forEach(function(eventType) {
                var event = new MouseEvent(eventType, {
                    'view': window,
                    'bubbles': true,
                    'cancelable': true,
                    'clientX': x,
                    'clientY': y
                });
                element.dispatchEvent(event);
            });
        }
    ]], self.UiInputs.MouseX, self.UiInputs.MouseY)
     
    self.Panel:RunJavascript(enterScript)
end

function ENT:SimulateScroll(delta)
    if not self.Panel then return end

    local scrollScript = string.format([[
        window.scrollBy(0, %d);
    ]], delta * -self.ScrollSpeed)
    
    self.Panel:RunJavascript(scrollScript)
end

-- TODO: prevent default behavior correctly, and support all inputs

function ENT:HandleInputsCreateMove(cmd)
    -- Only process if entity is valid and hovering
    if not IsValid(self) or not self.Hovering then return end
    
    -- Handle mouse wheel scroll
    local wheelDelta = cmd:GetMouseWheel()
    if wheelDelta ~= 0 then
        self:SimulateScroll(wheelDelta)
        cmd:ClearMovement()
        cmd:ClearButtons()
    end

    local state = cmd:KeyDown(IN_ATTACK) or cmd:KeyDown(IN_ATTACK2)
    if not state and self._clickState then
        self._clickState = nil
        self:SimulateMouseClick()
    elseif state then
        self._clickState = true
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)
    end
end
