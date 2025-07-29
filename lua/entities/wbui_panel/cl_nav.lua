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

function ENT:NavigateTo(url)
    if type(url) ~= "string" then
        WbuiError("Provide a valid url.")
        return
    end
    
    self.Panel:OpenURL(url)
end

function ENT:UrlPrompt()
    Derma_StringRequest("Enter URL", "Please enter a URL to navigate to:", self.Panel.URL or "", function(input)
        self:NavigateTo(input)
    end)
end

function ENT:UrlCopy()
    SetClipboardText(self.Panel.URL)
    notification.AddLegacy( "URL Copied", NOTIFY_GENERIC, 2 )
end