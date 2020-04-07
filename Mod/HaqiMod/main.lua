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

local block_id = 10518;
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
	-- register a new block item, id < 10512 is internal items, which is not recommended to modify. 
	GameLogic.GetFilters():add_filter("block_types", function(xmlRoot) 
		local blocks = commonlib.XPath.selectNode(xmlRoot, "/blocks/");
		if(blocks) then
			NPL.load("(gl)Mod/HaqiMod/ItemHaqiCodeBlock.lua");
			blocks[#blocks+1] = {name="block", attr={ name="HaqiCodeBlock",
				id = block_id, item_class="ItemNplMicroRobotBlock", text=L"哈奇编辑器",
				icon = "Texture/blocks/codeblock_on.png",
			}}
			LOG.std(nil, "info", "HaqiMod", "HaqiCodeBlock is registered");

		end
		return xmlRoot;
	end)

	-- add block to category list to be displayed in builder window (E key)
	GameLogic.GetFilters():add_filter("block_list", function(xmlRoot) 
		for node in commonlib.XPath.eachNode(xmlRoot, "/blocklist/category") do
			if(node.attr.name == "tool" or node.attr.name == "character") then
				node[#node+1] = {name="block", attr={name="HaqiCodeBlock"} };
			end
		end
		return xmlRoot;
	end)
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
