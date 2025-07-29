local cmds = {
    {"wbui_forward", "Forward", function(panel) panel:NavigateForward() end, "icon16/arrow_right.png"},
    {"wbui_back", "Back", function(panel) panel:NavigateBack() end, "icon16/arrow_left.png"},
    {"wbui_home", "Home", function(panel) panel:Home() end, "icon16/application_home.png"},
    {"wbui_refresh", "Refresh", function(panel) panel:Refresh() end, "icon16/arrow_refresh.png"},
    {"wbui_url", "Set URL", function(panel, url) if url then panel:NavigateTo(url) else panel:UrlPrompt() end end, "icon16/world.png"},
    {"wbui_copy_url", "Copy URL", function(panel) panel:UrlCopy() end, "icon16/page_copy.png"},
}

local i = 0
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

    properties.Add(cmd, {
        PrependSpacer = i == 0,
        MenuLabel = desc,
        MenuIcon = icon,
        Order = 100000+i, -- why is the edit properties order 90001???
        Filter = function(self, ent, ply)
            if not IsValid(ent) then return false end
            if ent:GetClass() ~= "wbui_panel" then return false end
            
            return true
        end,
        Action = function(self,ent)
            action(ent)
        end,
        MenuOpen = function(self, option, ent)
            if not IsValid(ent) then return end
            if ent:GetClass() ~= "wbui_panel" then return end
            if self.InternalName ~= "wbui_url" then return end

            local paint = option.Paint
            option.Paint = function(self, w, h)
                local url = ent.Panel and ent.Panel.URL or ent.DefaultURL
                self:SetText("URL - " .. string.sub(url, 1, 50) .. (string.len(url) > 50 and "..." or ""))
                self:SetTooltip(url)

                paint(self, w, h)
            end
        end
    })

    i=i+1
end

function WbuiPrint(...)
	MsgC(Color(136, 223, 218), "[WBUI] ", Color(187, 187, 187), ..., "\n")
end

function WbuiError(...)
	MsgC(Color(136, 223, 218), "[WBUI] ", Color(255, 0, 0), ..., "\n")
end

WbuiPrint(string.format("Loaded %s commands.", #cmds))