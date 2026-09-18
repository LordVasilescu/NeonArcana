--!nonstrict
-- ChestService: data caches scattered through the districts. Touch to crack one
-- open — credits, occasionally gear. Per-player 5-minute cooldown per cache.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local ZoneData = require(ReplicatedStorage.Shared.ZoneData)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CHEST_COOLDOWN = 300 -- seconds, per player per chest
local GEAR_CHANCE = 0.12

local ChestService = {}

-- gear pool per zone tier: chests can roll the same tier the streets drop
local ZONE_GEAR = {
	circuit_row = { "scrap_visor", "punk_jacket", "wire_boots" },
	static_alley = { "chrome_visor", "ganger_plate", "wraith_striders" },
	chrome_strip = { "sentinel_helm" },
	mainframe_blvd = { "knight_plate", "stalker_treads" },
}
local ZONE_CREDITS = { circuit_row = 25, static_alley = 60, chrome_strip = 110, mainframe_blvd = 200 }

local function makeChest(chestId: string, zoneId: string, position: Vector3, parent: Instance)
	local chest = Instance.new("Part")
	chest.Name = chestId
	chest.Anchored = true
	chest.Size = Vector3.new(3, 2.2, 2.2)
	chest.Position = position + Vector3.new(0, 1.6, 0)
	chest.Material = Enum.Material.Neon
	chest.Color = Color3.fromRGB(255, 220, 80)
	chest.TopSurface = Enum.SurfaceType.Smooth
	chest.BottomSurface = Enum.SurfaceType.Smooth

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(8, 2)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = "DATA CACHE"
	label.Parent = gui
	gui.Parent = chest

	chest.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local profile = PlayerDataService.get(player)
		if not profile then
			return
		end
		profile.chests = profile.chests or {}
		local last = profile.chests[chestId] or 0
		if os.time() - last < CHEST_COOLDOWN then
			return
		end
		profile.chests[chestId] = os.time()

		local credits = ZONE_CREDITS[zoneId] or 25
		PlayerDataService.addCredits(player, credits)
		local pool = ZONE_GEAR[zoneId]
		if pool and #pool > 0 and math.random() < GEAR_CHANCE then
			PlayerDataService.awardGear(player, pool[math.random(#pool)])
		end
		PlayerDataService.notify(player, ("DATA CACHE CRACKED: +%d credits"):format(credits))
		PlayerDataService.pushHUD(player)
	end)

	chest.Parent = parent
end

function ChestService.init()
	local folder = Instance.new("Folder")
	folder.Name = "DataCaches"
	folder.Parent = Workspace

	for _, zone in ZoneData.list do
		local right = Vector3.new(-zone.dir.Z, 0, zone.dir.X)
		for i, at in { 0.35, 0.85 } do
			local side = if i == 1 then 1 else -1
			local position = zone.dir * ((zone.startOverride or ZoneData.ROAD_START) + ZoneData.ROAD_LENGTH * at)
				+ right * (side * (ZoneData.ROAD_WIDTH / 2 - 4))
			makeChest(zone.id .. "_cache_" .. i, zone.id, position, folder)
		end
	end

	-- two in the plaza for new players to stumble into
	makeChest("plaza_cache_1", "circuit_row", Vector3.new(24, 0.65, -18), folder)
	makeChest("plaza_cache_2", "circuit_row", Vector3.new(-26, 0.65, 14), folder)
end

return ChestService
