AddCSLuaFile("autorun/client/cl_wbui.lua")
AddCSLuaFile("autorun/client/cl_wbui_vgui.lua")
AddCSLuaFile("wbui/cef_detection.lua")

resource.AddSingleFile("data_static/wbui_input_handler.txt")
resource.AddSingleFile("data_static/wbui_fullscreen_polyfill.txt")

function WbuiPrint(...)
	MsgC(Color(136, 223, 218), "[WBUI] ", Color(187, 187, 187), ..., "\n")
end

function WbuiError(...)
	MsgC(Color(136, 223, 218), "[WBUI] ", Color(255, 0, 0), ..., "\n")
end

WbuiPrint("Server loaded")