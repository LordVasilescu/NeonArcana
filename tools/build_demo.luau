--!nonstrict
-- Builds a playable demo place: the canonical Studio-saved world (imported models and
-- all) with every script replaced by the current contents of src/. The canonical file
-- is only read, never written.
--   lune run tools/build_demo            -> build/NeonArcana.demo.rbxl

local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")

local CANONICAL = "build/NeonArcana.rbxl"
local OUT = "build/NeonArcana.demo.rbxl"

-- src folder -> where Rojo mounts it (mirrors default.project.json)
local MOUNTS = {
	{ dir = "src/server", service = "ServerScriptService", folder = "Server" },
	{ dir = "src/shared", service = "ReplicatedStorage", folder = "Shared" },
	{ dir = "src/client", service = "StarterPlayer", path = { "StarterPlayerScripts" }, folder = "Client" },
}

local function classAndName(fileName: string): (string?, string?)
	local base = fileName:match("^(.*)%.luau$") or fileName:match("^(.*)%.lua$")
	if not base then
		return nil, nil
	end
	if base:sub(-7) == ".server" then
		return "Script", base:sub(1, -8)
	elseif base:sub(-7) == ".client" then
		return "LocalScript", base:sub(1, -8)
	end
	return "ModuleScript", base
end

local game = roblox.deserializePlace(fs.readFile(CANONICAL))
local replaced, created = 0, 0

for _, mount in MOUNTS do
	local parent = game:GetService(mount.service)
	for _, seg in mount.path or {} do
		parent = parent:FindFirstChild(seg) or error("missing " .. seg .. " under " .. mount.service)
	end
	local folder = parent:FindFirstChild(mount.folder)
	if not folder then
		folder = roblox.Instance.new("Folder")
		folder.Name = mount.folder
		folder.Parent = parent
	end
	for _, fileName in fs.readDir(mount.dir) do
		local className, name = classAndName(fileName)
		if className and name then
			local source = fs.readFile(mount.dir .. "/" .. fileName)
			local inst = folder:FindFirstChild(name)
			if inst and inst.ClassName ~= className then
				inst:Destroy()
				inst = nil
			end
			if inst then
				inst.Source = source
				replaced += 1
			else
				inst = roblox.Instance.new(className)
				inst.Name = name
				inst.Source = source
				inst.Parent = folder
				created += 1
			end
		end
	end
end

-- Store models fetched through Studio (tools/fetch_store_models) ride along in
-- ServerStorage.StoreModels so PremadeAssets can use them without InsertService.
local STORE_MODELS = "assets/store_models.rbxm"
local storeCount = 0
if fs.isFile(STORE_MODELS) then
	local serverStorage = game:GetService("ServerStorage")
	local existing = serverStorage:FindFirstChild("StoreModels")
	if existing then
		existing:Destroy()
	end
	for _, inst in roblox.deserializeModel(fs.readFile(STORE_MODELS)) do
		inst.Parent = serverStorage
		storeCount += #inst:GetChildren()
	end
end

-- Tripo models imported through Studio (tools/import_tripo.ps1 + extract_tripo_models)
-- ride along as ServerStorage.TripoModels.
local TRIPO_MODELS = "assets/tripo_models.rbxm"
local tripoCount = 0
if fs.isFile(TRIPO_MODELS) then
	local serverStorage = game:GetService("ServerStorage")
	local existing = serverStorage:FindFirstChild("TripoModels")
	if existing then
		existing:Destroy()
	end
	for _, inst in roblox.deserializeModel(fs.readFile(TRIPO_MODELS)) do
		inst.Parent = serverStorage
		tripoCount += #inst:GetChildren()
	end
end
print(("[demo] %d tripo models"):format(tripoCount))

fs.writeFile(OUT, roblox.serializePlace(game))
print(("[demo] %s: %d scripts updated, %d created, %d store models"):format(OUT, replaced, created, storeCount))
process.exit(0)
