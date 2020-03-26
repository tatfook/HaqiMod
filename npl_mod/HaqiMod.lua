--[[
Title: Haqi Combat Mod
Author(s): LiXizhi
Date: 2020/3/26
Desc: combat server mod
use the lib:
-------------------------------------------------------
local HaqiMod = NPL.load("HaqiMod");
local ActorNPC = commonlib.gettable("MyCompany.Aries.Game.Movie.ActorNPC");
-------------------------------------------------------
]]
local HaqiMod = commonlib.inherit(nil, NPL.export())

function HaqiMod.IsHaqi()
    return not System.options.mc;
end

function HaqiMod.Join()
    if(not HaqiMod.IsHaqi()) then
        System.options.clientconfig_file = "npl_mod/HaqiMod/config/HaqiGameClient.config.xml"
    end
    NPL.load("(gl)script/apps/GameServer/GSL.lua");
    NPL.load("(gl)script/apps/Aries/Combat/ServerObject/combat_client.lua");
    -- System.GSL_client:LogoutServer(true);
    -- System.GSL_client:LoginServer(params.gs_nid, params.ws_id, worldpath, 
	-- 		{nid=params.nid, gridrule_id=params.gridnoderule_id, mode=params.mode, create_join=params.create_join, combat_is_started=params.combat_is_started, is_local_instance=params.is_local_instance, room_key=params.room_key, match_info = params.match_info});
end

