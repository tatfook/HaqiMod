--[[
Title: Mob Config
Author(s): LiXizhi
Date: 2020/4/10
Desc: 
use the lib:
-------------------------------------------------------
local Mob = NPL.load("./Mob.lua");
-------------------------------------------------------
]]
local HaqiMod = NPL.load("./HaqiMod.lua");
local Files = commonlib.gettable("MyCompany.Aries.Game.Common.Files");
local Mob = commonlib.inherit(nil, NPL.export())

function Mob:ctor()
end

function Mob:Init(name, assetFile)
    self.name = name;
    self.assetFile = assetFile;
    self.configFilenameFullpath = Files.WorldPathToFullPath(format("mod/Haqi/%sMobTemplate.xml", self.name))
    self.configFilename = Files.ResolveFilePath(self.configFilenameFullpath).relativeToRootPath
    return self;
end

function Mob:GetConfigFileName()
    return self.configFilename;
end

function Mob:GetConfigFileNameFullpath()
    return self.configFilenameFullpath;
end

-- @param bOverwrite: true to overwrite existing files. 
function Mob:GenerateTemplateFile(bOverwrite)
    local filename = self:GetConfigFileNameFullpath();
    if( bOverwrite or not ParaIO.DoesFileExist(filename) ) then
        local file = ParaIO.open(filename, "w")
        if(file) then
            local text = HaqiMod.GetFileContent("npl_mod/HaqiMod/config/HaqiMobTemplate_Lv1.xml")
            if(text) then
                text = text:gsub("character/v5/10mobs/HaqiTown/OrangeBaby/OrangeBaby%.x", self.assetFile)
                file:WriteString(text);
            end
            file:close();
        end
    end
end