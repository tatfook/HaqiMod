--[[
Title: Haqi Combat Mod
Author(s): LiXizhi
Date: 2020/3/26
Desc: combat server mod
use the lib:
-------------------------------------------------------
NPL.load("npl_packages/HaqiMod/");
local HaqiMod = NPL.load("HaqiMod");
HaqiMod.Logout();
HaqiMod.Join();
-------------------------------------------------------
]]
NPL.load("(gl)script/apps/Aries/Combat/MsgHandler.lua");
local ItemManager = commonlib.gettable("System.Item.ItemManager");
local MsgHandler = commonlib.gettable("MyCompany.Aries.Combat.MsgHandler");
local Combat = commonlib.gettable("MyCompany.Aries.Combat");
local Arena = NPL.load("./Arena.lua");
local HaqiMod = commonlib.inherit(nil, NPL.export())
local Files = commonlib.gettable("MyCompany.Aries.Game.Common.Files");

HaqiMod.gsl_config_filename = "npl_mod/HaqiMod/config/GSL.config.xml"
HaqiMod.clientconfig_file = "npl_mod/HaqiMod/config/HaqiGameClient.config.xml";

-- debugging only
-- HaqiMod.dump_client_msg = true
-- HaqiMod.dump_server_msg = true

local configDirty = {}
local client;
-- all editable arenas on client side
HaqiMod.Arenas = {};

-- join the current world
function HaqiMod.Join()
    if(HaqiMod.IsHaqi()) then
        NPL.load("(gl)script/apps/Aries/Desktop/GameMemoryProtector.lua");
        local GameMemoryProtector = commonlib.gettable("MyCompany.Aries.Desktop.GameMemoryProtector");
        GameMemoryProtector.StopMonitor();
    else
        System.options.clientconfig_file = HaqiMod.clientconfig_file;
    end
    
    if(not HaqiMod.oldNid) then
        HaqiMod.oldNid = System.User.nid
    end
    System.User.nid = "localuser"; --  or System.User.keepworkUsername;
    
    -- HaqiMod.Logout();

    -- start server
    HaqiMod.StartServer()

    client = client or System.GSL.client:new({});

    MsgHandler.gslClient = client;

    HaqiMod.CheckLoadModels()
    
    local function DoLogin_()
        if(HaqiMod.IsServerReady() and HaqiMod.resourceLoaded) then
            HaqiMod.PrepareConfigFiles();
            HaqiMod.InstallFakeHaqiAPI();
            NPL.load("(gl)script/apps/Aries/Combat/main.lua");
            if(ItemManager.SyncGlobalStore()) then
                MyCompany.Aries.Combat.Init_OnGlobalStoreLoaded()
            end
            MyCompany.Aries.Combat.Init();

            -- join with full HP
            MsgHandler.SetCurrentHP(MsgHandler.GetMaxHP())

            local BasicArena = commonlib.gettable("MyCompany.Aries.Quest.NPCs.BasicArena");
            BasicArena.allowWithoutPetCombat = true;

            local WorldManager = commonlib.gettable("MyCompany.Aries.WorldManager");
            local worldinfo = WorldManager:GetCurrentWorld();
            -- @Note： this will fake the client to use "Haqi.Arena_Mobs.xml" regardless of real world path
            worldinfo.name = "Haqi";
            worldinfo.worldpath = "temp/localuser/Haqi/"
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
        client:EnableReceive(false);

        NPL.load("(gl)script/apps/Aries/NPCs/Combat/39000_BasicArena.lua");
        MyCompany.Aries.Quest.NPCs.BasicArena.EnableGlobalTimer(false);

        local ObjectManager = commonlib.gettable("MyCompany.Aries.Combat.ObjectManager");
        ObjectManager.DestroyAllArenaAndMobs();
        
        -- reset combat msg handler. 
        MsgHandler.ResetUI()
        MsgHandler.gslClient = nil;
        MsgHandler.Init();
        
        NPL.load("(gl)script/apps/Aries/Combat/ServerObject/arena_server.lua");
        local Arena = commonlib.gettable("MyCompany.Aries.Combat_Server.Arena");
        Arena.UnloadAllConfigFiles();

        NPL.load("(gl)script/apps/Aries/Combat/ServerObject/mob_server.lua");
        local Mob = commonlib.gettable("MyCompany.Aries.Combat_Server.Mob");
        Mob.ClearTemplates()

        -- System.GSL_grid:Reset() is called inside following function
        System.GSL.system:OnAllServicesLoaded();
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
    configDirty = {}
    HaqiMod.Arenas = {};
    HaqiMod.curArena = nil;

    HaqiMod.Logout()

    NPL.load("(gl)script/apps/Aries/Quest/NPC.lua");
    MyCompany.Aries.Quest.NPC.OnWorldClosing();
    
    MyCompany.Aries.Combat.localuser = nil;

    if(HaqiMod.oldNid) then
        System.User.nid = HaqiMod.oldNid
        HaqiMod.oldNid = nil;
    end
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

-- set cards for current local player
-- @param cards: such as {{gsid=22142,},{gsid=22153,},{gsid=22153,},{gsid=22146,},{gsid=43143,},{gsid=43143,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},}
function HaqiMod.setMyCards(cards)
    HaqiMod.myCards = cards or {};
    -- set my cards
    local MyCardsManager = commonlib.gettable("MyCompany.Aries.Inventory.Cards.MyCardsManager");
    MyCardsManager.combat_bags = HaqiMod.myCards;
end

function HaqiMod.PrepareFakeUserItems()
    -- make sure we have bag 0
    ItemManager.bags[0] = ItemManager.bags[0] or {};

    -- set my cards
    local MyCardsManager = commonlib.gettable("MyCompany.Aries.Inventory.Cards.MyCardsManager");
    MyCardsManager.combat_bags = HaqiMod.myCards or {{gsid=22142,},{gsid=22153,},{gsid=22153,},{gsid=22146,},{gsid=43143,},{gsid=43143,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},{gsid=0,},};

    -- default commbat level, should be bigger than 10 or 30 to prevent user hint tips
    local localuser = commonlib.gettable("MyCompany.Aries.Combat.localuser");
    localuser.combatlel = localuser.combatlel or 50;
end

function HaqiMod.GetFileContent(filename)
    local file = ParaIO.open(filename, "r")
    if(file) then
        local text = file:GetText(0, -1)
        file:close();
        return text;
    end
end

function HaqiMod.removeArena(name)
    if(HaqiMod.Arenas[name]) then
        HaqiMod.Arenas[name] = nil;
        HaqiMod.SetArenaModified()
    end
end

function HaqiMod.removeAllArenas()
    if(next(HaqiMod.Arenas)) then
        HaqiMod.Arenas = {};
        HaqiMod.SetArenaModified()
    end
end



function HaqiMod.createArena(name, x, y, z)
    HaqiMod.curArena = Arena:new():Init(name, x, y, z);
    HaqiMod.Arenas[name] = HaqiMod.curArena;
    HaqiMod.SetArenaModified()
end

function HaqiMod.addArenaMob(index, name, assetFile)
    if(HaqiMod.curArena) then
        HaqiMod.curArena:AddMob(index, name, assetFile);
        HaqiMod.SetArenaModified()
    end
end

-- mark a given config file dirty
function HaqiMod.SetArenaModified(bDirty)
    configDirty["arenas"] = bDirty ~= false;
end
function HaqiMod.IsArenaModified()
    return configDirty["arenas"];
end

-- @return array of filenames relative to world path
function HaqiMod.GetEditableFiles()
    local filenames = {};
    if(HaqiMod.Arenas) then
        local fileMap = {};
        for name, arena in pairs(HaqiMod.Arenas) do
            for _, filename in ipairs(arena:GetEditableFiles() or {}) do
                if(not fileMap[filename]) then
                    fileMap[filename] = true
                    filenames[#filenames+1] = Files.ResolveFilePath(filename).relativeToWorldPath or filename;
                end
            end
        end
    end
    return filenames;
end
-- prepare all configuration files in current world directory
function HaqiMod.PrepareConfigFiles()
    local filename = Files.WorldPathToFullPath("mod/Haqi/")
    ParaIO.CreateDirectory(filename);
    local WorldCombatFilename = Files.WorldPathToFullPath("mod/Haqi/HaqiWorldCombat.NPC.xml")
    local relativeWorldCombatFilename = Files.ResolveFilePath(WorldCombatFilename).relativeToRootPath

    local ArenasMobsFilename = Files.WorldPathToFullPath("mod/Haqi/Haqi.Arenas_Mobs.xml")
    local relativeArenasMobsFilename = Files.ResolveFilePath(ArenasMobsFilename).relativeToRootPath

    local DefaultMobTemplateFilename = Files.WorldPathToFullPath("mod/Haqi/DefaultMobTemplate.xml")
    local relativeDefaultMobTemplateFilename = Files.ResolveFilePath(DefaultMobTemplateFilename).relativeToRootPath

    local GSLConfigFilename = Files.WorldPathToFullPath("mod/Haqi/GSL.config.xml")
    local relativeGSLConfigFilename = Files.ResolveFilePath(GSLConfigFilename).relativeToRootPath
    if( not ParaIO.DoesFileExist(GSLConfigFilename) ) then
        local file = ParaIO.open(GSLConfigFilename, "w")
        if(file) then
            local text = HaqiMod.GetFileContent(HaqiMod.gsl_config_filename)
            if(text) then
                text = text:gsub("npl_mod/HaqiMod/config/HaqiWorldCombat%.NPC%.xml", relativeWorldCombatFilename)
                file:WriteString(text);
            end
            file:close();
        end
    end

    if( not ParaIO.DoesFileExist(WorldCombatFilename) ) then
        local file = ParaIO.open(WorldCombatFilename, "w")
        if(file) then
            local text = HaqiMod.GetFileContent("npl_mod/HaqiMod/config/HaqiWorldCombat.NPC.xml")
            if(text) then
                text = text:gsub("npl_mod/HaqiMod/config/Haqi%.Arenas_Mobs%.xml", relativeArenasMobsFilename)
                file:WriteString(text);
            end
            file:close();
        end
    end

    if( not ParaIO.DoesFileExist(ArenasMobsFilename) or HaqiMod.IsArenaModified()) then
        local file = ParaIO.open(ArenasMobsFilename, "w")
        if(file) then
            local text = HaqiMod.GetFileContent("npl_mod/HaqiMod/config/Haqi.Arenas_Mobs.xml")
            if(text) then
                local arenas_text = "";
                for name, arena in pairs(HaqiMod.Arenas) do
                    arenas_text = arenas_text..arena:GetConfigXMLText()
                    arena:GenerateMobTemplateFiles(false) -- no overwrite
                end
                text = text:gsub("<arena .*</arena>", arenas_text)
                file:WriteString(text);
            end
            file:close();
        end
    end

    -- reload GSL config and restart
    System.GSL.config:load(GSLConfigFilename);
    System.GSL_grid:Restart();
end

function HaqiMod.SetCurrentHP(hpValue)
    MsgHandler.SetCurrentHP(hpValue)
end

function HaqiMod.GetCurrentHP()
    return MsgHandler.GetCurrentHP()
end

-- set equipment addon value for the current player. 
-- @param name: "combatlel", "addonlevel_hp_absolute", "addonlevel_damage_percent", "addonlevel_resilience_percent", 
-- "addonlevel_criticalstrike_percent", "addonlevel_resist_absolute"
function HaqiMod.SetUserValue(name, value)
    local localuser = commonlib.gettable("MyCompany.Aries.Combat.localuser"); 
    localuser[name] = value
end

function HaqiMod.GetUserValue(name)
    local localuser = commonlib.gettable("MyCompany.Aries.Combat.localuser"); 
    return localuser[name]
end