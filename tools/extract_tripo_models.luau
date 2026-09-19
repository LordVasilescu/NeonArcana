--!nonstrict
-- After importing Tripo FBX files into the open demo place (tools/import_tripo.ps1) and
-- saving it, gather every Workspace model whose name matches a Tripo slot prefix into
-- assets/tripo_models.rbxm. tools/build_demo injects that file as
-- ServerStorage.TripoModels so PremadeAssets can use the models by name.
--   lune run tools/extract_tripo_models [path/to/place.rbxl]   (default: the demo place)
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")

local PREFIXES = { "bld_", "lamp_", "prop_", "veh_", "kiosk_", "chest_", "npc_", "gate_", "sign_" }
local OUT = "assets/tripo_models.rbxm"

local place = process.args[1] or "build/NeonArcana.demo.rbxl"
local game = roblox.deserializePlace(fs.readFile(place))

local folder = roblox.Instance.new("Folder")
folder.Name = "TripoModels"

-- keep models already extracted earlier (they are gone from Workspace after a rebuild)
if fs.isFile(OUT) then
	for _, inst in roblox.deserializeModel(fs.readFile(OUT)) do
		for _, child in inst:GetChildren() do
			child.Parent = folder
		end
	end
end

local function isTripo(name: string): boolean
	for _, prefix in PREFIXES do
		if name:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function collect(container: any)
	for _, inst in container:GetChildren() do
		if inst:IsA("Model") and isTripo(inst.Name) then
			local existing = folder:FindFirstChild(inst.Name)
			if existing then
				existing:Destroy()
			end
			inst.Parent = folder
		end
	end
end
collect(game:GetService("Workspace"))
local stored = game:GetService("ServerStorage"):FindFirstChild("TripoModels")
if stored then
	collect(stored)
end

local names = {}
for _, m in folder:GetChildren() do
	local meshes = 0
	for _, d in m:GetDescendants() do
		if d:IsA("MeshPart") then
			meshes += 1
		end
	end
	table.insert(names, ("%s(%d mesh)"):format(m.Name, meshes))
end
table.sort(names)
fs.writeFile(OUT, roblox.serializeModel({ folder }))
print(("wrote %s: %d models: %s"):format(OUT, #folder:GetChildren(), table.concat(names, ", ")))
