ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Web Browser Panel"
ENT.Author = "Meowlan"
ENT.Information = "Interactive Web Browser Panel\n Hold C -> Right Click for options."
ENT.Category = "#spawnmenu.category.fun_games"

ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Editable = true

ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT.DefaultURL = "https://www.google.com"

function ENT:SetupDataTables()
	self:NetworkVar( "Int",    0, "HTMLSize", { KeyName = "htmlsize", Edit = { type = "Int", order = 1, min = 1, max = 4096 } } )
	self:NetworkVar( "String", 1, "URL", { KeyName = "url", Edit = { type = "String", order = 2 } } )
	self:NetworkVar( "String", 2, "ScreenModel", { KeyName = "screenmodel", Edit = { type = "String", order = 5 } } )
	self:NetworkVar( "Int",    3, "Angle", { KeyName = "angle", Edit = { type = "Int", order = 3, min = 0, max = 360 } } )
	self:NetworkVar( "Float",  4, "MaxDistance", { KeyName = "maxdistance", Edit = { type = "Float", order = 4, min = 1, max = 10000 } } )
	self:NetworkVar( "Bool",   5, "Locked", { KeyName = "locked", Edit = { type = "Bool", order = 6 } } )
	self:NetworkVar( "Float",  6, "Volume", { KeyName = "volume", Edit = { type = "Float", order = 7, min = 0, max = 1 } })
end