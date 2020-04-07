--[[
Title: Haqi Combat Mod
Author(s): LiXizhi
Date: 2020/3/26
Desc: combat server mod
use the lib:
-------------------------------------------------------
NPL.load("npl_packages/HaqiMod/");
local HaqiMod = NPL.load("HaqiMod");
HaqiMod.PrepareConfigFiles();
HaqiMod.Join()
-------------------------------------------------------
]]
local ItemManager = commonlib.gettable("System.Item.ItemManager");
local MsgHandler = commonlib.gettable("MyCompany.Aries.Combat.MsgHandler");
local HaqiMod = commonlib.inherit(nil, NPL.export())
local Files = commonlib.gettable("MyCompany.Aries.Game.Common.Files");

HaqiMod.gsl_config_filename = "npl_mod/HaqiMod/config/GSL.config.xml"
HaqiMod.clientconfig_file = "npl_mod/HaqiMod/config/HaqiGameClient.config.xml";

-- debugging only
--HaqiMod.dump_client_msg = true
--HaqiMod.dump_server_msg = true

local client;

-- join the current world
function HaqiMod.Join()
    if(HaqiMod.IsHaqi()) then
        NPL.load("(gl)script/apps/Aries/Desktop/GameMemoryProtector.lua");
        local GameMemoryProtector = commonlib.gettable("MyCompany.Aries.Desktop.GameMemoryProtector");
        GameMemoryProtector.StopMonitor();
    else
        System.options.clientconfig_file = HaqiMod.clientconfig_file;
    end
    
    System.User.nid = "localuser"; --  or System.User.keepworkUsername;
    
    -- start server
    HaqiMod.StartServer()

    client = client or System.GSL.client:new({});

    MsgHandler.gslClient = client;

    HaqiMod.CheckLoadModels()
    
    local function DoLogin_()
        if(HaqiMod.IsServerReady() and HaqiMod.resourceLoaded) then
            HaqiMod.InstallFakeHaqiAPI();
            NPL.load("(gl)script/apps/Aries/Combat/main.lua");
            if(ItemManager.SyncGlobalStore()) then
                MyCompany.Aries.Combat.Init_OnGlobalStoreLoaded()
            end
            MyCompany.Aries.Combat.Init();
            local BasicArena = commonlib.gettable("MyCompany.Aries.Quest.NPCs.BasicArena");
            BasicArena.allowWithoutPetCombat = true;

            local WorldManager = commonlib.gettable("MyCompany.Aries.WorldManager");
            local worldinfo = WorldManager:GetCurrentWorld();
            -- @Note： this will fake the client to use "Test.Arena_Mobs.xml" regardless of real world path
            worldinfo.name = "Test";
            worldinfo.worldpath = "temp/localuser/Test/"
            worldinfo.can_reverse_time = false;
            worldinfo.enter_combat_range = 5;
            worldinfo.is_standalone = true;
            -- worldinfo.immortal_after_combat = true;
            worldinfo.enter_combat_range_sq = worldinfo.enter_combat_range ^ 2;
            worldinfo.alert_combat_range_sq = (worldinfo.enter_combat_range + 3)^ 2;

            client:LoginServer("localuser", "", worldinfo.worldpath, {
                is_local_instance = true,
                create_join = true,
            })
            return true;
        end
    end

    local tryCount = 0;
    local mytimer = commonlib.Timer:new({callbackFunc = function(timer)
        if(not DoLogin_() and tryCount < 10) then
            tryCount = tryCount + 1;
            timer:Change(tryCount*1000)
        end
    end})
    mytimer:Change(1000)
end

-- disconnect from server and delete world entities
function HaqiMod.Logout()
    if(HaqiMod.isServerStarted) then
        client:LogoutServer(true)
        -- MyCompany.Aries.Combat.Init();
    end
end

-- start server in main thread, the server may take several seconds to start. 
-- use HaqiMod.IsServerReady()
function HaqiMod.StartServer()
    if(HaqiMod.isServerStarted) then
        return
    end
    NPL.load("(gl)script/apps/GameServer/GSL.lua");
    
    HaqiMod.isServerStarted = true;

    GameLogic:Connect("WorldUnloaded", HaqiMod, HaqiMod.OnWorldUnload, "UniqueConnection")

    local gateway = commonlib.gettable("System.GSL.gateway");
    gateway.ignoreWebGSLStat = true;

    local gsl_system_file = "script/apps/GameServer/GSL_system.lua";
    local gsl_gateway_file = "script/apps/GameServer/GSL_gateway.lua";
    System.GSL.dump_client_msg = HaqiMod.dump_client_msg
    System.options.localGSL = true; -- this will make sure all power item manager uses local data instead of fetching DB server. 
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
    MsgHandler.ResetUI()
    MsgHandler.gslClient = nil;

    NPL.load("(gl)script/apps/Aries/Quest/NPC.lua");
	MyCompany.Aries.Quest.NPC.OnWorldClosing();
end


function HaqiMod.CheckLoadModels()
    if(not HaqiMod.resourceLoaded) then
        NPL.load("(gl)script/apps/Aries/Combat/ObjectManager.lua");
        local ObjectManager = commonlib.gettable("MyCompany.Aries.Combat.ObjectManager");
        ObjectManager.SyncEssentialCombatResourceMini(function()
            HaqiMod.resourceLoaded = true;
        end);
    end
end

-- in case paracraft does not have some haqi API, we will create fake placeholders here. 
function HaqiMod.InstallFakeHaqiAPI()
    if(HaqiMod.fakeAPIInited) then
        return;
    end
    HaqiMod.fakeAPIInited = true;

    if(not HaqiMod.IsHaqi()) then
        local VIP = commonlib.gettable("MyCompany.Aries.VIP");
        VIP.IsVIP = VIP.IsVIP or function() return false end


        NPL.load("(gl)script/apps/Aries/Scene/EffectManager.lua");
        MyCompany.Aries.EffectManager.Init();
        
        NPL.load("(gl)script/apps/Aries/Combat/SpellPlayer.lua");
        MyCompany.Aries.Combat.SpellPlayer.Init();
    end

    HaqiMod.PrepareFakeUserItems();
end

function HaqiMod.PrepareFakeUserItems()
    -- make sure we have bag 0
    ItemManager.bags[0] = ItemManager.bags[0] or {};

    -- shall we insert some preset cards to combat bags?
    local MyCardsManager = commonlib.gettable("MyCompany.Aries.Inventory.Cards.MyCardsManager");
    MyCardsManager.combat_bags = {{gsid=22142,},{gsid=22153,},{gsid=22153,},{gsid=22146,},{gsid=43143,},{gsid=43143,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},}

    -- default commbat level, should be bigger than 10 or 30 to prevent user hint tips
    local localuser = commonlib.gettable("MyCompany.Aries.Combat.localuser");
    localuser.combatlel = 50;
end

-- prepare all configuration files in current world directory
function HaqiMod.PrepareConfigFiles()
    local filename = Files.WorldPathToFullPath("mod/Haqi/Haqi.Arenas_Mobs.xml")
    ParaIO.CreateDirectory(filename);
    local relativeFilename = Files.ResolveFilePath(filename)
end