-- wbui_panel.lua
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_input.lua")
AddCSLuaFile("cl_nav.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

-- Server-side initialization
function ENT:Initialize()
    if SERVER then
        self:SetModel("models/hunter/plates/plate2x2.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
    end
end

-- Spawn function
function ENT:SpawnFunction(ply, tr, ClassName)
    if not tr.Hit then return end

    local ent = ents.Create(ClassName)
    ent:SetPos(tr.HitPos)
    ent:SetAngles(tr.HitNormal:Angle() + Angle(90, 0, 0))
    ent:Spawn()
    ent:Activate()

    local phys = ent:GetPhysicsObject()
    if phys:IsValid() then
        phys:EnableMotion(false)
    end

    return ent
end

print("[WBUI] Web Browser Panel loaded")
