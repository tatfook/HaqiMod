--[[
Title: Arena Config
Author(s): LiXizhi
Date: 2020/4/10
Desc: 
use the lib:
-------------------------------------------------------
local Arena = NPL.load("./Arena.lua");
-------------------------------------------------------
]]
local HaqiMod = NPL.load("./HaqiMod.lua");
local Mob = NPL.load("./Mob.lua");
local Arena = commonlib.inherit(nil, NPL.export())


function Arena:ctor()
end
local nextId = 10001;

function Arena:Init(name, x, y, z)
    self.name = name;
    self.x = x;
    self.y = y;
    self.z = z;
    self.id = nextId;
    nextId = nextId + 1;
    self.mobs = {};
    return self;
end

function Arena:AddMob(index, name, assetFile)
    self.mobs[index] = Mob:new():Init(name, assetFile)
end

function Arena:GetConfigXMLText()
    local lines = {};
    lines[#lines+1] = string.format('<arena players_max="1" ai_module="" id="%s" position="%s, %s, %s" respawn_interval_easy="99999000" respawn_interval="99999000" respawn_interval_hard="99999000" facing="0" label="">\n', 
        self.id, self.x, self.y, self.z);
    for i=1, 4 do
        local mob = self.mobs[i]
        if(mob and mob.name) then
            lines[#lines+1] = format('    <mob mob_template="%s" />\n', mob:GetConfigFileName())
        else
            lines[#lines+1] = '    <mob mob_template="" />\n'
        end
    end
    lines[#lines+1] = "</arena>\n\n"
    local text = table.concat(lines, "")
    return text;
end

-- @param bOverwrite: true to overwrite existing files. 
function Arena:GenerateMobTemplateFiles(bOverwrite)
    for i=1, 4 do
        local mob = self.mobs[i]
        if(mob and mob.name) then
            mob:GenerateTemplateFile(bOverwrite)
        end
    end
end