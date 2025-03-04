include("shared.lua")
include("cl_input.lua")
include("cl_nav.lua")

-- Configuration
ENT.MaterialResolution = {2048, 2048}
ENT.SizeRatio = 10

function ENT:OpenPage(url)
    url = url or "https://example.com/"

    if self.LastUrl then
        url = self.LastUrl
        self.LastUrl = nil
    end

    -- Remove existing panel if it exists
    if self.Panel then
        self.Panel:Remove()
        self.Panel = nil
    end

    -- Create web panel
    self.Panel = vgui.Create("DHTML")
    self.Panel:SetSize(unpack(self.MaterialResolution))
    self.Panel:OpenURL(url)
    
    -- Hide panel rendering
    self.Panel:SetAlpha(0)
    self.Panel:SetMouseInputEnabled(false)

    self.Panel.OnBeginLoadingDocument = function(self, url)
        self.Panel.URL = url
    end

    self.Panel.OnDocumentReady = function(self)
        self:RunJavascript([[
            var style = document.createElement('style');
            style.innerHTML = "body { background-color: transparent; }";
            document.head.appendChild(style);
        ]])
    end

    print("[WBUI] Panel opened: " .. url)
end

function ENT:CreateWebMaterial()
    if not self.Panel then return nil end
    
    local html_mat = self.Panel:GetHTMLMaterial()
    if not html_mat then return nil end

    local scale_x, scale_y = unpack(self.MaterialResolution)
    local matdata = {
        ["$basetexture"] = html_mat:GetName(),
        ["$basetexturetransform"] = string.format("center 0 0 scale %d %d rotate 0 translate 0 0", scale_x, scale_y),
        ["$texturealpha"] = 1
    }

    local uid = string.Replace(html_mat:GetName(), "__vgui_texture_", "")
    return CreateMaterial("WebMaterial_" .. uid, "gmodscreenspace", matdata)
end

function ENT:Draw()
    self:DrawModel()

    local imgui = include("imgui.lua")
    if IsValid(self.Panel) and imgui.Entity3D2D(self, self.UiOffset, Angle(0, 90, 0), 1 / self.SizeRatio) then
        local mx, my = imgui.CursorPos()
        
        -- Update mouse input coordinates
        if mx and my then
            self.UiInputs.MouseX = (mx / self.UiSize.x) * self.MaterialResolution[1]
            self.UiInputs.MouseY = (my / self.UiSize.y) * self.MaterialResolution[2]
        end
        
        -- Check hovering state
        self.Hovering = imgui.IsHovering(0, 0, self.UiSize.x, self.UiSize.y)
        if self.Hovering then
            self:SimulateMouseHover()
        end

        -- Render material
        if self.Mat then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(self.Mat)
            surface.DrawTexturedRect(0, 0, self.UiSize.x, self.UiSize.y)
        elseif self.Panel:GetHTMLMaterial() then
            self.Mat = self:CreateWebMaterial()
            if self.Mat then
                print("[WBUI] Created Material!")
            end
        end

        imgui.End3D2D()
    end

    if self.Hovering then
        hook.Add("HUDShouldDraw", "HideWeaponSelector", function(name)
            if name == "CHudWeaponSelection" then
                return false
            end
        end)
    else
        hook.Remove("HUDShouldDraw", "HideWeaponSelector")
    end
end

function ENT:Initialize()
    self.UiOffset = self:OBBMins()
    self.UiOffset.z = self:OBBMaxs().z
    self.UiSize = self:OBBMaxs() * 2 * self.SizeRatio

    self.ScrollSpeed = 50
    self.UiInputs = {}

    -- self:OpenPage()

    -- Hook setup
    hook.Add("CreateMove", self, self.HandleInputsCreateMove)
end

local maxDist2 = 500^2

function ENT:Think()
    local inRange = self:GetPos():DistToSqr(LocalPlayer():GetPos()) < maxDist2
    if inRange and not self.Panel then
        self:OpenPage()
    elseif not inRange and self.Panel then
        self.LastUrl = self.Panel.URL
        self.Panel:Remove()
        self.Panel = nil
        self.Mat = nil
    end
end

function ENT:OnRemove()
    if self.Panel then 
        self.Panel:Remove()
        self.Mat = nil
    end

    hook.Remove("CreateMove", self)
end
