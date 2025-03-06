AddCSLuaFile("cl_init.lua")
AddCSLuaFile("cl_input.lua")
AddCSLuaFile("cl_nav.lua")
AddCSLuaFile("shared.lua")

AddCSLuaFile("imgui.lua")

include("shared.lua")

function ENT:Initialize()
    self:SetScreenModel("models/hunter/plates/plate1x2.mdl")
    self:SetURL("https://ui.shadcn.com/")
    self:SetMaxDistance(500)
    self:SetHTMLSize(1024)
    self:SetAngle(0)
    
    self:SetModel("models/hunter/plates/plate1x2.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    self:NetworkVarNotify("ScreenModel", function(ent, key, old, new)
        ent:SetModel(new)
        ent:PhysicsInit(SOLID_VPHYSICS)
    end)
end

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