-- ─────────────────────────────────────────────────────────
--  WbuiControl  –  fancy navigation panel
-- ─────────────────────────────────────────────────────────

-- Color palette
local C = {
    panelBg     = Color(18,  18,  26,  248),
    panelBorder = Color(60,  70,  110, 200),
    accent      = Color(88,  150, 255, 255),
    accentDim   = Color(55,  100, 200, 100),

    navCluster  = Color(0,   0,   0,   0),    -- transparent, no black box
    navBtn      = Color(48,  54,  80,  255),
    navBtnHov   = Color(75,  130, 230, 220),
    navBtnPress = Color(120, 180, 255, 200),

    urlBg       = Color(12,  12,  20,  255),
    urlBorder   = Color(48,  52,  78,  255),
    urlBorderH  = Color(88,  150, 255, 200),
    urlText     = Color(190, 205, 230, 255),
    urlPlaceh   = Color(90,  100, 130, 255),

    divider     = Color(45,  50,  75,  255),
    rowBg       = Color(14,  14,  22,  255),

    volTrack    = Color(35,  38,  58,  255),
    volFill     = Color(70,  130, 220, 255),
    volKnob     = Color(140, 185, 255, 255),

    lockOff     = Color(32,  34,  52,  255),
    lockOffHov  = Color(65,  120, 220, 220),
    lockOn      = Color(50,  180, 100, 255),
    lockOnHov   = Color(80,  220, 130, 220),

    white       = Color(255, 255, 255, 255),
    labelDim    = Color(120, 135, 165, 255),
}

-- ── helpers ───────────────────────────────────────────────

-- Smooth lerp stored per-panel by key, frametime-based
local function SmoothLerp(panel, key, target, speed)
    panel[key] = Lerp(FrameTime() * speed, panel[key] or target, target)
    return panel[key]
end

-- Rounded icon button with animated hover/press
local function MakeFancyBtn(parent, icon, tip, onClick)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn:SetTooltip(tip)

    local img = vgui.Create("DImage", btn)
    img:SetSize(16, 16)
    img:SetImage(icon)
    img:SetMouseInputEnabled(false)
    btn._img = img

    btn.PerformLayout = function(self, w, h)
        self._img:SetPos(math.Round(w / 2 - 8), math.Round(h / 2 - 8))
    end

    btn.Paint = function(self, w, h)
        local hov   = SmoothLerp(self, "_hov",   self:IsHovered() and 1 or 0, 12)
        local press = SmoothLerp(self, "_press",  self:IsDown()    and 1 or 0, 22)

        -- base
        draw.RoundedBox(6, 0, 0, w, h, C.navBtn)

        -- hover tint
        if hov > 0.01 then
            local col = C.navBtnHov
            draw.RoundedBox(6, 0, 0, w, h, Color(col.r, col.g, col.b, math.floor(hov * col.a)))
        end

        -- press flash
        if press > 0.01 then
            local col = C.navBtnPress
            draw.RoundedBox(6, 0, 0, w, h, Color(col.r, col.g, col.b, math.floor(press * col.a)))
        end

        -- top highlight sliver
        surface.SetDrawColor(255, 255, 255, math.floor(25 + hov * 50))
        surface.DrawRect(2, 0, w - 4, 1)
    end

    btn.DoClick = onClick
    return btn
end

-- Toggle icon button (active state changes palette)
local function MakeToggleBtn(parent, iconOff, iconOn, tipOff, tipOn, onToggle)
    local btn = MakeFancyBtn(parent, iconOff, tipOff, function() end)
    btn._active = false
    btn._iconOff, btn._iconOn = iconOff, iconOn
    btn._tipOff,  btn._tipOn  = tipOff,  tipOn

    local basePaint = btn.Paint
    btn.Paint = function(self, w, h)
        local hov   = SmoothLerp(self, "_hov",   self:IsHovered() and 1 or 0, 12)
        local press = SmoothLerp(self, "_press",  self:IsDown()    and 1 or 0, 22)

        local base = self._active and C.lockOn or C.navBtn
        draw.RoundedBox(6, 0, 0, w, h, base)

        local hovCol = self._active and C.lockOnHov or C.navBtnHov
        if hov > 0.01 then
            draw.RoundedBox(6, 0, 0, w, h, Color(hovCol.r, hovCol.g, hovCol.b, math.floor(hov * hovCol.a)))
        end
        if press > 0.01 then
            local col = C.navBtnPress
            draw.RoundedBox(6, 0, 0, w, h, Color(col.r, col.g, col.b, math.floor(press * col.a)))
        end

        surface.SetDrawColor(255, 255, 255, math.floor(25 + hov * 50))
        surface.DrawRect(2, 0, w - 4, 1)
    end

    btn.SetActive = function(self, state)
        self._active = state
        self._img:SetImage(state and self._iconOn or self._iconOff)
        self:SetTooltip(state and self._tipOn or self._tipOff)
    end

    btn.DoClick = function(self)
        onToggle(self, not self._active)
    end

    return btn
end

-- Thin horizontal divider
local function MakeDivider(parent)
    local d = vgui.Create("DPanel", parent)
    d:Dock(TOP)
    d:SetTall(1)
    d:DockMargin(8, 3, 8, 3)
    d.Paint = function(self, w, h)
        surface.SetDrawColor(C.divider.r, C.divider.g, C.divider.b, C.divider.a)
        surface.DrawRect(0, 0, w, h)
        -- accent glint in the centre
        surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 55)
        surface.DrawRect(math.floor(w * 0.35), 0, math.floor(w * 0.3), h)
    end
    return d
end

-- ── panel definition ──────────────────────────────────────

local PANEL = { Entity = nil }

function PANEL:Init()
    self:SetTall(88)

    self.Container = vgui.Create("DPanel", self)
    self.Container:Dock(FILL)
    self.Container:SetPaintBackground(false)
    self.Container:DockPadding(6, 5, 6, 5)

    -- ── Row 1: nav cluster + url bar ─────────────────────
    self.TopRow = vgui.Create("DPanel", self.Container)
    self.TopRow:Dock(TOP)
    self.TopRow:SetTall(30)
    self.TopRow:DockMargin(0, 0, 0, 0)
    self.TopRow.Paint = function(self, w, h) end  -- painted by children

    -- Nav button cluster background
    self.NavCluster = vgui.Create("DPanel", self.TopRow)
    self.NavCluster:Dock(LEFT)
    self.NavCluster:SetWide(118)  -- 4 × 28 + 3 × 2 gaps + 4 padding
    self.NavCluster.Paint = function(self, w, h) end  -- no background

    local btnW, btnH = 26, 26
    local navDefs = {
        { "icon16/resultset_previous.png", "Back",    function() if IsValid(self.Entity) then self.Entity:NavigateBack()    end end },
        { "icon16/resultset_next.png",     "Forward", function() if IsValid(self.Entity) then self.Entity:NavigateForward() end end },
        { "icon16/house.png",              "Home",    function() if IsValid(self.Entity) then self.Entity:Home()            end end },
        { "icon16/arrow_refresh.png",      "Refresh", function() if IsValid(self.Entity) then self.Entity:Refresh()         end end },
    }
    for i, def in ipairs(navDefs) do
        local btn = MakeFancyBtn(self.NavCluster, def[1], def[2], def[3])
        btn:SetSize(btnW, btnH)
        btn:SetPos(3 + (i - 1) * (btnW + 2), 2)
    end

    -- Separator between cluster and URL bar
    local sep = vgui.Create("DPanel", self.TopRow)
    sep:Dock(LEFT)
    sep:SetWide(6)
    sep:SetPaintBackground(false)

    -- URL bar
    self.UrlBar = vgui.Create("DTextEntry", self.TopRow)
    self.UrlBar:Dock(FILL)
    self.UrlBar:DockMargin(0, 1, 4, 1)
    self.UrlBar:SetFont("DermaDefault")
    self.UrlBar:SetTextColor(C.urlText)
    self.UrlBar:SetPlaceholderText("Enter URL…")
    self.UrlBar:SetPlaceholderColor(C.urlPlaceh)
    self.UrlBar:SetCursorColor(C.accent)

    self.UrlBar.Paint = function(panel, w, h)
        local hov = SmoothLerp(panel, "_hov", panel:IsHovered() and 1 or 0, 10)
        -- background
        draw.RoundedBox(6, 0, 0, w, h, C.urlBg)
        -- border
        local bClr = C.urlBorder
        local r = math.floor(bClr.r + (C.urlBorderH.r - bClr.r) * hov)
        local g = math.floor(bClr.g + (C.urlBorderH.g - bClr.g) * hov)
        local b = math.floor(bClr.b + (C.urlBorderH.b - bClr.b) * hov)
        local a = math.floor(bClr.a + (C.urlBorderH.a - bClr.a) * hov)
        surface.SetDrawColor(r, g, b, a)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        -- top glint
        surface.SetDrawColor(255, 255, 255, 12)
        surface.DrawRect(2, 0, w - 4, 1)
        -- update displayed text each frame
        panel:SetText(IsValid(self.Entity) and self.Entity:GetURL() or "")
        panel:DrawTextEntryText(C.urlText, Color(60, 120, 220, 200), C.urlText)
    end

    self.UrlBar.OnGetFocus = function(panel)
        local ent = self.Entity
        Derma_StringRequest("Navigate to URL", "Enter the URL to navigate to:", panel:GetValue(), function(text)
            if IsValid(ent) then ent:NavigateTo(text) end
        end)
    end

    self.UrlBar.OnEnter = function(panel)
        if IsValid(self.Entity) then self.Entity:NavigateTo(panel:GetValue()) end
    end

    -- Go button
    self.GoBtn = MakeFancyBtn(self.TopRow, "icon16/arrow_right.png", "Navigate", function()
        if IsValid(self.Entity) then self.Entity:NavigateTo(self.UrlBar:GetValue()) end
    end)
    self.GoBtn:Dock(RIGHT)
    self.GoBtn:SetWide(28)

    -- ── divider ───────────────────────────────────────────
    MakeDivider(self.Container)

    -- ── Row 2: volume + input lock buttons ───────────────
    self.BottomRow = vgui.Create("DPanel", self.Container)
    self.BottomRow:Dock(TOP)
    self.BottomRow:SetTall(26)
    self.BottomRow:SetPaintBackground(false)

    -- Volume icon
    self.VolumeIcon = vgui.Create("DImage", self.BottomRow)
    self.VolumeIcon:Dock(LEFT)
    self.VolumeIcon:SetWide(18)
    self.VolumeIcon:DockMargin(2, 3, 4, 3)
    self.VolumeIcon:SetImage("icon16/sound.png")

    -- Custom volume slider
    self.VolumeSlider = vgui.Create("DPanel", self.BottomRow)
    self.VolumeSlider:Dock(FILL)
    self.VolumeSlider:DockMargin(0, 6, 8, 6)
    self.VolumeSlider._vol = 1
    self.VolumeSlider._dragging = false

    self.VolumeSlider.Paint = function(sld, w, h)
        local frac = sld._vol
        -- track
        draw.RoundedBox(3, 0, 0, w, h, C.volTrack)
        -- fill
        if frac > 0 then
            draw.RoundedBox(3, 0, 0, math.floor(frac * w), h, C.volFill)
        end
        -- knob
        local kx = math.floor(frac * w)
        local ky = math.floor(h / 2)
        draw.RoundedBox(4, kx - 5, ky - 5, 10, 10, C.volKnob)
        surface.SetDrawColor(255, 255, 255, 40)
        surface.DrawRect(kx - 3, ky - 3, 6, 1)
    end

    local function SliderSetFromMouse(sld)
        local mx = sld:ScreenToLocal(gui.MouseX(), 0)
        local frac = math.Clamp(mx / sld:GetWide(), 0, 1)
        sld._vol = frac
        if IsValid(self.Entity) then self.Entity:SetVolume(frac) end
    end

    self.VolumeSlider.OnMousePressed = function(sld, mc)
        if mc == MOUSE_LEFT then
            sld._dragging = true
            sld:MouseCapture(true)
            SliderSetFromMouse(sld)
        end
    end
    self.VolumeSlider.OnMouseReleased = function(sld, mc)
        if mc == MOUSE_LEFT then
            sld._dragging = false
            sld:MouseCapture(false)
        end
    end
    self.VolumeSlider.OnCursorMoved = function(sld)
        if sld._dragging then SliderSetFromMouse(sld) end
    end

    -- Combined input lock button (right side)
    self.LockInputBtn = MakeToggleBtn(
        self.BottomRow,
        "icon16/lock_open.png", "icon16/lock.png",
        "Lock Mouse & Keyboard", "Unlock Mouse & Keyboard",
        function(btn, newState)
            if not IsValidWbuiPanel(self.Entity) then return end
            if newState then
                self.Entity:LockMouse()
                self.Entity:LockKeyboard()
            else
                self.Entity:UnlockMouse()
                self.Entity:UnlockKeyboard()
            end
            btn:SetActive(newState)
        end
    )
    self.LockInputBtn:Dock(RIGHT)
    self.LockInputBtn:SetWide(26)
    self.LockInputBtn:DockMargin(2, 0, 0, 0)

    -- "Vol" label
    local volLabel = vgui.Create("DLabel", self.BottomRow)
    volLabel:Dock(LEFT)
    volLabel:SetWide(24)
    volLabel:SetText("Vol")
    volLabel:SetFont("DermaDefault")
    volLabel:SetTextColor(C.labelDim)
    volLabel:DockMargin(2, 0, 0, 0)
end

function PANEL:SetEntity(ent)
    assert(IsValid(ent))
    assert(ent:GetClass() == "wbui_panel")
    self.Entity = ent
    self:InvalidateLayout()
end

function PANEL:Paint(w, h)
    -- outer background
    draw.RoundedBox(6, 0, 0, w, h, C.panelBg)

    -- accent top border
    surface.SetDrawColor(C.accent.r, C.accent.g, C.accent.b, 180)
    surface.DrawRect(8, 0, w - 16, 2)

    -- subtle inner bevel
    surface.SetDrawColor(C.panelBorder.r, C.panelBorder.g, C.panelBorder.b, C.panelBorder.a)
    surface.DrawOutlinedRect(0, 0, w, h, 1)

    -- bottom shadow line
    surface.SetDrawColor(0, 0, 0, 80)
    surface.DrawRect(4, h - 1, w - 8, 1)
end

vgui.Register("WbuiControl", PANEL, "Panel")