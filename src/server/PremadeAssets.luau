--!nonstrict
-- PremadeAssets: free Creator Store models used as world props (buildings, lamps,
-- vehicles, street clutter, kiosks, chests, NPCs) and as a fallback tier for enemies.
-- Models come from ServerStorage.StoreModels (pre-fetched through Studio, see
-- tools/fetch_store_models.luau) or, once the place is published, InsertService.
-- Every caller keeps its procedural placeholder when a model is unavailable.
-- SECURITY: every script inside a store model is destroyed before it touches the world.

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local AdoptModel = require(script.Parent.AdoptModel)

local PremadeAssets = {}

-- number = Creator Store asset id; string = Tripo model name in ServerStorage.TripoModels
export type AssetKey = number | string

-- Single-purpose slots.
PremadeAssets.ids = {
	grid_stalker = 77342670464136, -- "Horror Wolf Wendigo Monster R15 - NPC no Scripted"
	pylon = 157006174, -- "Awesome Crystal Cluster Mesh", tinted per school
	gate_arch = "gate_arch_struct", -- Tripo archway over each premium-district entrance
}

-- Variety pools: callers pick a variant by seed so neighbouring lots differ.
-- Each id was checked via the toolbox API (free, no scripts/tools) and by thumbnail.
PremadeAssets.pools = {
	-- Tripo community set (2026-09-19): ready-made cyberpunk models exported from the
	-- Tripo gallery (see assets/TRIPO_PICKS.md), baked through tools/tripo_bake.py.
	-- Names are ServerStorage.TripoModels children; stampVariant skips any name that
	-- is not imported yet, so a pool can list models ahead of their import.
	-- Front-row street buildings (60-110 studs tall, scaled by height).
	tower = {
		"bld_photoreal_a",
		"bld_multilevel_neon",
		"bld_cyber_signage",
		"bld_store_neon",
		"bld_midrise_jp",
		"bld_twostory_neon",
		"bld_block_house",
		"bld_repair_shop",
		"bld_neon_multicolor",
		"bld_signage_b",
		"bld_multistory_neon",
		"bld_blue_sign_tower",
		"bld_commercial_8f",
		"bld_multistory_b",
		"bld_ornate_lit",
		"bld_photoreal_b",
	},
	-- Back-row skyline (120-200 studs): skyscrapers and towers.
	skyline = {
		"sky_neon_signage",
		"sky_lowpoly_blue",
		"sky_neon_signs",
		"sky_stacked",
		"sky_futuristic",
		"sky_tall_neon",
		"sky_neon_lit",
		"sky_glass_neon",
		"sky_neon_blue",
		"sky_blue_glass",
		"sky_tokyo",
		"sky_dark_tower",
		"sky_pink_tower",
		"sky_gold_trim",
		"twr_neon_signage",
		"twr_elevated",
		"twr_spiral",
		"twr_platforms",
	},
	lamp = {
		"lamp_black_orange",
		"lamp_energy_orange",
		"lamp_neon_curved",
		"lamp_modern_tapered",
		"lamp_curved_metal",
	},
	vehicle = {
		"veh_hover_neon_blue",
		"bike_red_glow",
		"veh_cyber_sports",
		"moto_racing",
		"veh_hover_indie",
		"bike_green_armored",
		"veh_cyber_hover",
		"moto_hover_pink",
		"veh_hover_nitro",
		"bike_anime_red",
		"veh_cyber_armored",
		"moto_hover_b",
		"veh_hover_blue",
		"bike_green_angular",
		"veh_cyber_angular",
		"moto_2077",
		"veh_hover_red",
		"bike_orange_teal",
		"veh_cyber_black",
		"moto_neon_cyan",
		"veh_flying_neon",
		"veh_aura_float",
	},
	prop = {
		"vend_cyber_neon",
		"dump_green_rusty",
		"bar_concrete_hazard",
		"gen_futuristic",
		"term_gambling",
		"arcade_ready",
		"vend_cyber_glass",
		"dump_green_lid",
		"bar_orange_chevron",
		"gen_blue_scifi",
		"term_orange_glass",
		"arcade_jukebox",
		"vend_graffiti",
		"dump_graffiti",
		"bar_steel_yellow",
		"gen_gray_futuristic",
		"term_touchscreen",
		"arcade_retro",
		"vend_neon_b",
		"term_pillar",
		"arcade_hopper",
		"vend_scifi_lit",
		"term_dual_blue",
		"vend_neon_lit",
		"term_console_red",
		"vend_neon_c",
		"term_nifps",
		"vend_neon_wide",
		"vend_blue_d",
	},
	sign = { "sign_triangle", "sign_letter_circle", "sign_mountain", "sign_whale", "sign_circular_red" },
	kiosk = { "kiosk_neon_shop", "kiosk_illumi", "kiosk_storefront" },
	fixer = {
		"npc_warrior_coat",
		"npc_hacker_glow",
		"npc_long_coat",
		"npc_hacker_female",
		"npc_neon_purple",
		"npc_hacker_realistic",
		"npc_blue_jacket",
		"npc_hacker_purple",
		"npc_long_coat_glow",
	},
	chest = {
		"chest_blue_cyan",
		"chest_neon_blue",
		"chest_purple",
		"chest_glow_blue",
		"chest_black_gold",
		"chest_scifi_purple",
		"chest_orange_glow",
		"chest_scifi_rust",
		"chest_open_blue",
		"chest_bevel",
	},
}

local LOAD_TIMEOUT = 20

-- Every asset id we know about (for preload and the Studio fetch script).
function PremadeAssets.allIds(): { AssetKey }
	local ids = {}
	for _, id in PremadeAssets.ids do
		table.insert(ids, id)
	end
	for _, pool in PremadeAssets.pools do
		for _, id in pool do
			table.insert(ids, id)
		end
	end
	return ids
end

local function stripScripts(model: Instance)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		end
	end
end

function PremadeAssets.load(assetId: number): Model?
	local ok, container = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not container then
		warn("[PremadeAssets] failed to load asset " .. tostring(assetId) .. ": " .. tostring(container))
		return nil
	end
	local model = container:FindFirstChildWhichIsA("Model") or container:FindFirstChildWhichIsA("BasePart")
	if not model then
		container:Destroy()
		return nil
	end
	if model:IsA("BasePart") then
		local wrapper = Instance.new("Model")
		model.Parent = wrapper
		model = wrapper
	end
	stripScripts(model)
	model.Parent = nil
	container:Destroy()
	return model
end

-- Models pre-fetched through Studio's command bar and carried in ServerStorage.StoreModels
-- by tools/build_demo. InsertService refuses free models until the place is published.
function PremadeAssets.fromStorage(assetId: AssetKey): Model?
	-- Tripo models (string keys) live in ServerStorage.TripoModels by slot name; store
	-- models (number keys) in ServerStorage.StoreModels as asset_<id>.
	local folder = ServerStorage:FindFirstChild(if typeof(assetId) == "string" then "TripoModels" else "StoreModels")
	local holderName = if typeof(assetId) == "string" then assetId else "asset_" .. assetId
	local holder = folder and folder:FindFirstChild(holderName)
	if not holder or not holder:IsA("Model") then
		return nil
	end
	local model = holder:Clone()
	stripScripts(model)
	return model
end

-- assetId -> Model (loaded) | false (failed) ; nil = not requested yet
local templates: { [AssetKey]: Model | boolean } = {}
local loading: { [AssetKey]: boolean } = {}

local function cachedModel(assetId: AssetKey): Model?
	local cached = templates[assetId]
	if typeof(cached) == "Instance" then
		return (cached :: any) :: Model
	end
	return nil
end

-- Loads an asset's template once and caches it. Yields on the first call per asset.
function PremadeAssets.template(assetId: AssetKey): Model?
	if templates[assetId] ~= nil then
		return cachedModel(assetId)
	end
	if loading[assetId] then
		local deadline = os.clock() + LOAD_TIMEOUT
		while templates[assetId] == nil and os.clock() < deadline do
			task.wait(0.1)
		end
		return cachedModel(assetId)
	end
	loading[assetId] = true
	local model = PremadeAssets.fromStorage(assetId)
	if not model and typeof(assetId) == "number" then
		model = PremadeAssets.load(assetId)
	end
	templates[assetId] = model or false
	loading[assetId] = nil
	return model
end

-- Kick off every known asset's load in parallel and wait (bounded), so the world
-- builders that follow stamp instantly instead of each yielding on first use.
function PremadeAssets.preload()
	local ids = PremadeAssets.allIds()
	local pending = 0
	for _, id in ids do
		if templates[id] == nil and not loading[id] then
			pending += 1
			task.spawn(function()
				PremadeAssets.template(id)
				pending -= 1
			end)
		end
	end
	local deadline = os.clock() + LOAD_TIMEOUT
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	local loaded = 0
	for _, id in ids do
		if templates[id] then
			loaded += 1
		end
	end
	print(("[PremadeAssets] %d/%d store models ready"):format(loaded, #ids))
end

local function tintModel(model: Model, tint: Color3)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = tint
			descendant.Material = Enum.Material.Neon
			if descendant:IsA("MeshPart") then
				descendant.TextureID = "" -- textures override Color; drop them so the tint shows
			end
		elseif descendant:IsA("SpecialMesh") then
			descendant.TextureId = ""
			descendant.VertexColor = Vector3.new(tint.R, tint.G, tint.B)
		end
	end
end

-- Clone an asset scaled to fit `fitSize`, base resting at `cframe`. Nil when unavailable.
function PremadeAssets.stampId(
	assetId: AssetKey,
	cframe: CFrame,
	fitSize: Vector3,
	parent: Instance,
	tint: Color3?
): Model?
	local template = PremadeAssets.template(assetId)
	if not template then
		return nil
	end
	local clone = template:Clone()
	clone.Name = if typeof(assetId) == "string" then assetId else "asset_" .. assetId
	if not AdoptModel.scaleToFit(clone, fitSize) then
		clone:Destroy()
		return nil
	end
	AdoptModel.stamp(clone, cframe, parent, true)
	if tint then
		tintModel(clone, tint)
	end
	return clone
end

-- Single-purpose slot from PremadeAssets.ids.
function PremadeAssets.stamp(slot: string, cframe: CFrame, fitSize: Vector3, parent: Instance, tint: Color3?): Model?
	local id = PremadeAssets.ids[slot]
	if not id then
		return nil
	end
	local model = PremadeAssets.stampId(id, cframe, fitSize, parent, tint)
	if model then
		model.Name = slot
	end
	return model
end

-- Variant `seed` from a pool scaled to a target HEIGHT (footprint free, capped by
-- maxFootprint). Base rests at `cframe`. Used for buildings, where height against the
-- player is what matters and the width is read back by the caller for packing.
function PremadeAssets.stampVariantHeight(
	pool: string,
	seed: number,
	cframe: CFrame,
	height: number,
	maxFootprint: number,
	parent: Instance
): Model?
	local ids = PremadeAssets.pools[pool]
	if not ids or #ids == 0 then
		return nil
	end
	for attempt = 0, #ids - 1 do
		local id = ids[((seed + attempt) % #ids) + 1]
		local template = PremadeAssets.template(id)
		if template then
			local clone = template:Clone()
			clone.Name = pool
			if AdoptModel.scaleToHeight(clone, height, maxFootprint) then
				AdoptModel.stamp(clone, cframe, parent, true)
				return clone
			end
			clone:Destroy()
		end
	end
	return nil
end

-- Variant `seed` from a pool (cycles through the pool, so consecutive seeds differ).
-- Falls back to the next variants if the chosen one is unavailable.
function PremadeAssets.stampVariant(
	pool: string,
	seed: number,
	cframe: CFrame,
	fitSize: Vector3,
	parent: Instance,
	tint: Color3?
): Model?
	local ids = PremadeAssets.pools[pool]
	if not ids or #ids == 0 then
		return nil
	end
	for attempt = 0, #ids - 1 do
		local id = ids[((seed + attempt) % #ids) + 1]
		local model = PremadeAssets.stampId(id, cframe, fitSize, parent, tint)
		if model then
			model.Name = pool
			return model
		end
	end
	return nil
end

return PremadeAssets
