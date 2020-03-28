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

-- debugging only
--HaqiMod.dump_client_msg = true
--HaqiMod.dump_server_msg = true

local client;

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

    local function DoLogin_()
        if(HaqiMod.IsServerReady()) then
            HaqiMod.InstallFakeHaqiAPI();
            NPL.load("(gl)script/apps/Aries/Combat/main.lua");
            MyCompany.Aries.Combat.Init();
            local BasicArena = commonlib.gettable("MyCompany.Aries.Quest.NPCs.BasicArena");
            BasicArena.allowWithoutPetCombat = true;

            local WorldManager = commonlib.gettable("MyCompany.Aries.WorldManager");
            local worldinfo = WorldManager:GetCurrentWorld();
            -- @Note： this will fake the client to use "Test.Arena_Mobs.xml" regardless of real world path
            worldinfo.name = "Test";
            worldinfo.worldpath = "temp/localuser/Test/"

            client:LoginServer("localuser", "", worldinfo.worldpath, {
                is_local_instance = true,
                create_join = true,
            })
            return true;
        end
    end

    local tryCount = 0;
    local mytimer = commonlib.Timer:new({callbackFunc = function(timer)
        if(not DoLogin_() and tryCount < 5) then
            tryCount = tryCount + 1;
            timer:Change(tryCount*1000)
        end
    end})
    mytimer:Change(1000)
end

-- start server in main thread, the server may take several seconds to start. 
-- use HaqiMod.IsServerReady()
function HaqiMod.StartServer()
    if(HaqiMod.isServerStarted) then
        return
    end
    HaqiMod.isServerStarted = true;

    GameLogic:Connect("WorldUnloaded", HaqiMod, HaqiMod.OnWorldUnload, "UniqueConnection")

    local gateway = commonlib.gettable("System.GSL.gateway");
    gateway.ignoreWebGSLStat = true;

    local gsl_system_file = "script/apps/GameServer/GSL_system.lua";
    local gsl_gateway_file = "script/apps/GameServer/GSL_gateway.lua";
    System.GSL.dump_client_msg = HaqiMod.dump_client_msg

    -- start the worker as GSL server mode
    NPL.activate(gsl_system_file, {type="restart", 
        config = {
            nid = "", 
            ws_id = "", 
            gsl_config_filename = HaqiMod.gsl_config_filename,
            addr = "",
            debug = HaqiMod.dump_server_msg, -- true to dump log for every message 
            log_level = LOG.level,
            gm_uac = "everyone",
            locale = "zhCN",
        }
    });
end

function HaqiMod.IsHaqi()
    return not System.options.mc;
end

function HaqiMod.IsServerReady()
    return GameServer and GameServer.isReady;
end

function HaqiMod:OnWorldUnload()
    -- we shall log out silently. 
    System.GSL_client:EnableReceive(false);

    NPL.load("(gl)script/apps/Aries/NPCs/Combat/39000_BasicArena.lua");
    MyCompany.Aries.Quest.NPCs.BasicArena.EnableGlobalTimer(false);

    -- reset combat msg handler. 
    NPL.load("(gl)script/apps/Aries/Combat/MsgHandler.lua");
    local MsgHandler = commonlib.gettable("MyCompany.Aries.Combat.MsgHandler");
    MsgHandler.ResetUI()
end


-- in case paracraft does not have some haqi API, we will create fake placeholders here. 
function HaqiMod.InstallFakeHaqiAPI()
    if(HaqiMod.fakeAPIInited) then
        return;
    end
    HaqiMod.fakeAPIInited = true;
    if(HaqiMod.IsHaqi()) then
        return
    end

    local VIP = commonlib.gettable("MyCompany.Aries.VIP");
    VIP.IsVIP = VIP.IsVIP or function() return false end

    HaqiMod.PrepareFakeUserItems();
end

function HaqiMod.PrepareFakeUserItems()
    NPL.load("(gl)script/kids/3DMapSystemItem/ItemManager.lua");
    local ItemManager = commonlib.gettable("System.Item.ItemManager");
    -- make sure we have bag 0
    ItemManager.bags[0] = ItemManager.bags[0] or {};

    -- shall we insert some preset cards to combat bags?
    NPL.load("(gl)script/apps/Aries/Inventory/Cards/MyCardsManager.lua");
    local MyCardsManager = commonlib.gettable("MyCompany.Aries.Inventory.Cards.MyCardsManager");
    -- self.combat_bags
end

