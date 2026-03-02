local lastHint = 0

function ENT:NavigateBack()
    self.Panel:RunJavascript("window.history.back();")
end

function ENT:NavigateForward()
    self.Panel:RunJavascript("window.history.forward();")
end

function ENT:Refresh()
    self.Panel:Refresh()
end

function ENT:Home()
    self.Panel:OpenURL(self.DefaultURL)
end

function ENT:SetVolume(volume)
    self.Panel:SetVolume(volume)
end

function ENT:NavigateTo(url)
    if type(url) ~= "string" then
        WbuiError("Provide a valid url.")
        return
    end
    
    self.Panel:OpenURL(url)
end

function ENT:GetURL()
    return self.Panel.URL or self.DefaultURL
end

function ENT:UrlPrompt()
    Derma_StringRequest("Enter URL", "Please enter a URL to navigate to:", self:GetUrl(), function(input)
        self:NavigateTo(input)
    end)
end

function ENT:UrlCopy()
    SetClipboardText(self:GetUrl())
    notification.AddLegacy( "URL Copied", NOTIFY_GENERIC, 2 )
end

local function LockHint()
if lastHint + 5 < SysTime() then
        lastHint = SysTime()
        notification.AddLegacy("Press F8 to disable input lock.", NOTIFY_HINT, 5)
    end
end

function ENT:LockMouse()
    local oldKeyboardInput = self.Panel:IsKeyboardInputEnabled()
    if not self.Panel:IsPopup() then self.Panel:MakePopup() end

    self.Panel:SetMouseInputEnabled(true)
    self.Panel:MouseCapture(true)
    self.Panel:SetKeyboardInputEnabled(oldKeyboardInput)
    self.Panel.ForceInputLock = true

    LockHint()
end

function ENT:LockKeyboard()
    local oldMouseInput = self.Panel:IsMouseInputEnabled()
    if not self.Panel:IsPopup() then self.Panel:MakePopup() end

    self.Panel:SetKeyboardInputEnabled(true)
    self.Panel:SetMouseInputEnabled(oldMouseInput)
    self.Panel.ForceInputLock = true

    LockHint()
end

function ENT:UnlockMouse()
    self.Panel:SetMouseInputEnabled(false)

    if not self.Panel:IsKeyboardInputEnabled() then
        self.Panel.ForceInputLock = false
    end
end

function ENT:UnlockKeyboard()
    self.Panel:SetKeyboardInputEnabled(false)

    if not self.Panel:IsMouseInputEnabled() then
        self.Panel.ForceInputLock = false
    end
end

function ENT:Fullscreen()
    self.Panel:MakePopup()
    self.Panel:SetAlpha(255)
    self.Panel:SetKeyboardInputEnabled(true)
    self.Panel:SetMouseInputEnabled(true)
    self.Panel:SetSize(ScrW(), ScrH())

    self.Panel.ForceInputLock = true

    LockHint()
end