--[[
Title: Haqi Combat Mod
Author(s): LiXizhi
Date: 2020/3/26
Desc: combat server mod
use the lib:
-------------------------------------------------------
NPL.load("npl_packages/HaqiMod/");
local HaqiMod = NPL.load("HaqiMod");
HaqiMod.Join()
-------------------------------------------------------
]]
local HaqiMod = commonlib.inherit(nil, NPL.export())

HaqiMod.gsl_config_filename = "npl_mod/HaqiMod/config/GSL.config.xml"
HaqiMod.clientconfig_file = "npl_mod/HaqiMod/config/HaqiGameClient.config.xml";

local client;

function HaqiMod.IsHaqi()
    return not System.options.mc;
end

-- join the current world
function HaqiMod.Join()
    if(not HaqiMod.IsHaqi()) then
        System.options.clientconfig_file = HaqiMod.clientconfig_file;
    end
    NPL.load("(gl)script/apps/GameServer/GSL.lua");
    NPL.load("(gl)script/apps/Aries/Combat/ServerObject/combat_client.lua");
    
    System.User.nid = System.User.nid or System.User.keepworkUsername or "default";

    -- start server
    HaqiMod.StartServer()

	client = client or System.GSL.client:new({});
    client:LoginServer("", "", GameLogic.GetWorldDirectory(), {
        is_local_instance = true,
        create_join = true,
    })
end

function HaqiMod.StartServer()
    if(HaqiMod.isServerStarted) then
        return
    end
    HaqiMod.isServerStarted = true;

    local gsl_system_file = "script/apps/GameServer/GSL_system.lua";
    local gsl_gateway_file = "script/apps/GameServer/GSL_gateway.lua";
        
    -- start the worker as GSL server mode
    NPL.activate(gsl_system_file, {type="restart", 
        config = {
            nid = "", 
            ws_id = "", 
            gsl_config_filename = HaqiMod.gsl_config_filename,
            addr = "",
            debug = false, -- true to dump log for every message 
            log_level = LOG.level,
            gm_uac = "everyone",
            locale = "zhCN",
        }
    });
end
