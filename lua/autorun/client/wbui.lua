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

function WbuiPrint(...)
	MsgC(Color(136, 223, 218), "[WBUI] ", Color(187, 187, 187), ..., "\n")
end

function WbuiError(...)
	MsgC(Color(136, 223, 218), "[WBUI] ", Color(255, 0, 0), ..., "\n")
end

WbuiPrint(string.format("Loaded %s commands.", #cmds))