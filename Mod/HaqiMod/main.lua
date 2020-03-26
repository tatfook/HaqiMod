--[[
Title: 
Author(s):  
Date: 
Desc: 
use the lib:
------------------------------------------------------------
NPL.load("(gl)Mod/HaqiMod/main.lua");
local HaqiMod = commonlib.gettable("Mod.HaqiMod");
------------------------------------------------------------
]]
local HaqiMod = commonlib.inherit(commonlib.gettable("Mod.ModBase"),commonlib.gettable("Mod.HaqiMod"));

function HaqiMod:ctor()
end

-- virtual function get mod name

function HaqiMod:GetName()
	return "HaqiMod"
end

-- virtual function get mod description 

function HaqiMod:GetDesc()
	return "HaqiMod is a plugin in paracraft"
end

function HaqiMod:init()
	LOG.std(nil, "info", "HaqiMod", "plugin initialized");
end

function HaqiMod:OnLogin()
end
-- called when a new world is loaded. 

function HaqiMod:OnWorldLoad()
end
-- called when a world is unloaded. 

function HaqiMod:OnLeaveWorld()
end

function HaqiMod:OnDestroy()
end
