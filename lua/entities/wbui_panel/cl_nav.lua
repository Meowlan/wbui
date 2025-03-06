function ENT:NavigateBack()
    if not self.Panel then return end
    
    self.Panel:RunJavascript("window.history.back();")
end

function ENT:NavigateForward()
    if not self.Panel then return end
    
    self.Panel:RunJavascript("window.history.forward();")
end

function ENT:Refresh()
    if not self.Panel then return end
    
    self.Panel:Refresh()
end

function ENT:NavigateTo(url)
    if not self.Panel then return end
    
    self.Panel:OpenURL(url)
end