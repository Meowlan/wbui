local PANEL = {}

function PANEL:Init()
    self.Entity = nil
    self:SetTall(60) -- Set a reasonable height for the control panel
    
    -- Create main container
    self.Container = vgui.Create("DPanel", self)
    self.Container:Dock(FILL)
    self.Container:SetPaintBackground(false)
    
    -- Top row - Navigation controls
    self.TopRow = vgui.Create("DPanel", self.Container)
    self.TopRow:Dock(TOP)
    self.TopRow:SetPaintBackground(false)
    self.TopRow:DockMargin(2, 2, 2, 2)
    
    -- Back button
    self.BackBtn = vgui.Create("DImageButton", self.TopRow)
    self.BackBtn:Dock(LEFT)
    self.BackBtn:SetWide(25)
    self.BackBtn:SetImage("icon16/resultset_previous.png")
    self.BackBtn:SetTooltip("Back")
    self.BackBtn.DoClick = function()
        if IsValid(self.Entity) then
            self.Entity:NavigateBack()
        end
    end
    
    -- Forward button
    self.ForwardBtn = vgui.Create("DImageButton", self.TopRow)
    self.ForwardBtn:Dock(LEFT)
    self.ForwardBtn:SetWide(25)
    self.ForwardBtn:SetImage("icon16/resultset_next.png")
    self.ForwardBtn:SetTooltip("Forward")
    self.ForwardBtn.DoClick = function()
        if IsValid(self.Entity) then
            self.Entity:NavigateForward()
        end
    end
    
    -- Home button
    self.HomeBtn = vgui.Create("DImageButton", self.TopRow)
    self.HomeBtn:Dock(LEFT)
    self.HomeBtn:SetWide(25)
    self.HomeBtn:SetImage("icon16/house.png")
    self.HomeBtn:SetTooltip("Home")
    self.HomeBtn.DoClick = function()
        if IsValid(self.Entity) then
            self.Entity:Home()
        end
    end
    
    -- Refresh button
    self.RefreshBtn = vgui.Create("DImageButton", self.TopRow)
    self.RefreshBtn:Dock(LEFT)
    self.RefreshBtn:SetWide(25)
    self.RefreshBtn:SetImage("icon16/arrow_refresh.png")
    self.RefreshBtn:SetTooltip("Refresh")
    self.RefreshBtn.DoClick = function()
        if IsValid(self.Entity) then
            self.Entity:Refresh()
        end
    end
    
    -- URL Bar
    self.UrlBar = vgui.Create("DTextEntry", self.TopRow)
    self.UrlBar:Dock(FILL)
    self.UrlBar:DockMargin(5, 0, 5, 0)
    self.UrlBar:SetPlaceholderText("Enter URL...")
    self.UrlBar.OnGetFocus = function(panel)
        -- lock keyboard input when focused
        panel:SetKeyboardInputEnabled(true) 
        
    end

    self.UrlBar.OnEnter = function(panel)
        if IsValid(self.Entity) then
            self.Entity:NavigateTo(panel:GetValue())
        end
    end

    local paint = self.UrlBar.Paint
    self.UrlBar.Paint = function(panel, w, h)
        panel:SetText(self.Entity:GetURL())
        paint(panel, w, h)
    end
    
    -- Go button
    self.GoBtn = vgui.Create("DImageButton", self.TopRow)
    self.GoBtn:Dock(RIGHT)
    self.GoBtn:SetWide(25)
    self.GoBtn:SetImage("icon16/arrow_right.png")
    self.GoBtn:SetTooltip("Navigate")
    self.GoBtn.DoClick = function()
        if IsValid(self.Entity) then
            self.Entity:NavigateTo(self.UrlBar:GetValue())
        end
    end
    
    -- Second row - Volume and input controls
    self.BottomRow = vgui.Create("DPanel", self.Container)
    self.BottomRow:Dock(TOP)
    self.BottomRow:SetTall(30)
    self.BottomRow:SetPaintBackground(false)
    self.BottomRow:DockMargin(2, 2, 2, 2)
    
    -- Volume icon
    self.VolumeIcon = vgui.Create("DImage", self.BottomRow)
    self.VolumeIcon:Dock(LEFT)
    self.VolumeIcon:SetWide(20)
    self.VolumeIcon:SetImage("icon16/sound.png")
    
    -- Volume slider
    self.VolumeSlider = vgui.Create("DNumSlider", self.BottomRow)
    self.VolumeSlider:Dock(FILL)
    self.VolumeSlider:DockMargin(5, 0, 5, 0)
    self.VolumeSlider:SetText("")
    self.VolumeSlider:SetMin(0)
    self.VolumeSlider:SetMax(1)
    self.VolumeSlider:SetDecimals(2)
    self.VolumeSlider:SetValue(1)
    self.VolumeSlider.OnValueChanged = function(panel, value)
        if IsValid(self.Entity) then
            self.Entity:SetVolume(value)
        end
    end
    
    -- Lock mouse button
    self.LockMouseBtn = vgui.Create("DImageButton", self.BottomRow)
    self.LockMouseBtn:Dock(RIGHT)
    self.LockMouseBtn:SetWide(25)
    self.LockMouseBtn:SetImage("icon16/mouse.png")
    self.LockMouseBtn:SetTooltip("Lock Mouse Input")
    self.LockMouseBtn.DoClick = function()
        if not IsValidWbuiPanel(self.Entity) then return end

        if not self.Entity.Panel:IsMouseInputEnabled() then
            self.LockMouseBtn:SetImage("icon16/mouse_delete.png")
            self.LockMouseBtn:SetTooltip("Unlock Mouse Input")
            self.Entity:LockMouse()
        else
            self.LockMouseBtn:SetImage("icon16/mouse.png")
            self.LockMouseBtn:SetTooltip("Lock Mouse Input")
            self.Entity:UnlockMouse()
        end
    end
    
    -- Lock keyboard button
    self.LockKeyboardBtn = vgui.Create("DImageButton", self.BottomRow)
    self.LockKeyboardBtn:Dock(RIGHT)
    self.LockKeyboardBtn:SetWide(25)
    self.LockKeyboardBtn:SetImage("icon16/keyboard.png")
    self.LockKeyboardBtn:SetTooltip("Lock Keyboard Input")
    self.LockKeyboardBtn.DoClick = function()
        if not IsValidWbuiPanel(self.Entity) then return end

        if not self.Entity.Panel:IsKeyboardInputEnabled() then
            self.LockKeyboardBtn:SetImage("icon16/keyboard_delete.png")
            self.LockKeyboardBtn:SetTooltip("Unlock Keyboard Input")
            self.Entity:LockKeyboard()
        else
            self.LockKeyboardBtn:SetImage("icon16/keyboard.png")
            self.LockKeyboardBtn:SetTooltip("Lock Keyboard Input")
            self.Entity:UnlockKeyboard()
        end
    end
end

function PANEL:SetEntity(ent)
    assert(IsValid(ent))
    assert(ent:GetClass() == "wbui_panel")
    self.Entity = ent
    
    self:InvalidateLayout()
end

function PANEL:Paint(w, h)
    -- Draw a subtle background
    draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
    draw.RoundedBox(4, 1, 1, w-2, h-2, Color(70, 70, 70, 100))
end

vgui.Register("WbuiControl", PANEL, "Panel")