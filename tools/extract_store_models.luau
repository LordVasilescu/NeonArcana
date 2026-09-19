--!nonstrict
-- After running tools/fetch_store_models.luau in Studio and saving the place, copy
-- ServerStorage.StoreModels out of that place into assets/store_models.rbxm.
--   lune run tools/extract_store_models [path/to/place.rbxl]   (default: the demo place)
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")

local place = process.args[1] or "build/NeonArcana.demo.rbxl"
local game = roblox.deserializePlace(fs.readFile(place))
local folder = game:GetService("ServerStorage"):FindFirstChild("StoreModels")
if not folder then
	error("no ServerStorage.StoreModels in " .. place .. "; run tools/fetch_store_models.luau in Studio first")
end
for _, holder in folder:GetChildren() do
	local parts, scripts = 0, 0
	for _, d in holder:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		elseif d:IsA("LuaSourceContainer") then
			scripts += 1
		end
	end
	print(("%s: parts=%d scripts=%d"):format(holder.Name, parts, scripts))
end
fs.writeFile("assets/store_models.rbxm", roblox.serializeModel({ folder }))
print("wrote assets/store_models.rbxm (" .. #folder:GetChildren() .. " models)")
