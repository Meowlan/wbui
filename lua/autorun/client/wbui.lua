local cmds = {
    {"wbui_forward", "Forward", function(panel) panel:NavigateForward() end, "icon16/arrow_right.png"},
    {"wbui_back", "Back", function(panel) panel:NavigateBack() end, "icon16/arrow_left.png"},
    {"wbui_home", "Home", function(panel) panel:Home() end, "icon16/application_home.png"},
    {"wbui_refresh", "Refresh", function(panel) panel:Refresh() end, "icon16/arrow_refresh.png"},
    {"wbui_url", "Set URL", function(panel, url) if url then panel:NavigateTo(url) else panel:UrlPrompt() end end, "icon16/world.png"},
    {"wbui_copy_url", "Copy URL", function(panel) panel:UrlCopy() end, "icon16/page_copy.png"},
    {"wbui_fullscreen", "Fullscreen", function(panel) panel:Fullscreen() end, "icon16/application_view_tile.png"},
}

for _, cmd in ipairs(cmds) do
    local cmd, desc, action, icon = unpack(cmd)

    concommand.Add(cmd, function(ply, cmd, args)
        local ent = ply:GetEyeTrace().Entity
        if not IsValid(ent) or ent:GetClass() ~= "wbui_panel" or not IsValid(ent.Panel) then
            WbuiError("Not looking at a valid wbui panel")
            return
        end

        action(ent, unpack(args))
    end, nil, desc)
end

-- Freaky ahhh way to add our own ui to the context menu
properties.Add("test", {
    PrependSpacer = true,
    MenuLabel = "test",
    Order = 1000010,
    Filter = function(self, ent, ply)
        return IsValid(ent) and ent:GetClass() == "wbui_panel"
    end,
    Action = function(self,ent) end,
    MenuOpen = function(self, option, ent)
        if not IsValid(ent) or ent:GetClass() ~= "wbui_panel" then return end
        if self.InternalName ~= "test" then return end

        local Control = vgui.Create( "WbuiControl", option:GetParent() )
        -- Control:SetSize( 300, 200 )
        Control:SetEntity(ent)
        Control:SetWidth( 300 )

        option:Remove()
    end
})

function IsValidWbuiPanel(ent)
    return IsValid(ent) and ent.GetClass and ent:GetClass() == "wbui_panel" and IsValid(ent.Panel)
end

-- Show an unobtrusive "F8 to unlock" hint whenever a wbui_panel has keyboard focus
hook.Add("HUDPaint", "wbui_f8_hint", function()
    local focused = vgui.GetKeyboardFocus()
    if not IsValid(focused) or not focused._isWbui then return end

    local msg = "F8 to unlock"
    surface.SetFont("DermaDefault")
    local tw, th = surface.GetTextSize(msg)
    local pw, ph = tw + 16, th + 8
    local px = math.floor((ScrW() - pw) / 2)
    local py = ScrH() - ph - 24
    draw.RoundedBox(5, px, py, pw, ph, Color(20, 20, 30, 170))
    surface.SetDrawColor(50, 180, 100, 120)
    surface.DrawOutlinedRect(px, py, pw, ph, 1)
    surface.SetTextColor(190, 240, 190, 210)
    surface.SetTextPos(px + 8, py + 4)
    surface.DrawText(msg)
end)

function WbuiPrint(...)
	MsgC(Color(136, 223, 218), "[WBUI] ", Color(187, 187, 187), ..., "\n")
end

function WbuiError(...)
	MsgC(Color(136, 223, 218), "[WBUI] ", Color(255, 0, 0), ..., "\n")
end

WbuiPrint(string.format("Loaded %s commands.", #cmds))