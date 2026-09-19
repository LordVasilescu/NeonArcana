--!nonstrict
-- ZoneService: procedurally builds the streets off Neon Plaza — roads, neon curbs,
-- name signs, and crown-gates on premium zones. Gate touch: unlocked -> teleport
-- past it; locked -> send purchase offer to the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local ZoneData = require(ReplicatedStorage.Shared.ZoneData)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PremadeAssets = require(script.Parent.PremadeAssets)
local AdoptModel = require(script.Parent.AdoptModel)
local GroundDressing = require(script.Parent.GroundDressing)

local ZoneService = {}

-- One floor level (see HubService): ground top is y=0, overlays are OVERLAY thick centred
-- on y=0, so everything walkable tops out at SURFACE_Y.
local OVERLAY = 0.2
local SURFACE_Y = OVERLAY / 2

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

local ACCENTS = {
	Color3.fromRGB(40, 255, 200),
	Color3.fromRGB(255, 60, 120),
	Color3.fromRGB(200, 80, 255),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(80, 180, 255),
}

-- Scale table (player = 5 studs). Front-row buildings tower 12-22x over the player;
-- the back row is taller still so the skyline reads as a city, not a film set.
local FRONT_HEIGHT = { 60, 110 }
local BACK_HEIGHT = { 120, 200 }
local FRONT_SETBACK = 8 -- studs behind the curb
local BACK_SETBACK = 70
local MAX_FOOTPRINT = 90
local FRONT_GAP = 3

-- Procedural fallback tower when no store model is available.
local function proceduralTower(
	folder: Folder,
	base: Vector3,
	width: number,
	height: number,
	isXAxis: boolean,
	right: Vector3,
	side: number
)
	local tower = part({
		Name = "Tower",
		Size = Vector3.new(width, height, width),
		Position = base + Vector3.new(0, height / 2, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(18 + math.random(0, 10), 18 + math.random(0, 10), 30 + math.random(0, 12)),
	})
	tower.Parent = folder

	local accent = ACCENTS[math.random(#ACCENTS)]
	local crown = part({
		Name = "TowerCrown",
		Size = Vector3.new(width + 0.5, 1.2, width + 0.5),
		Position = base + Vector3.new(0, height + 0.6, 0),
		Material = Enum.Material.Neon,
		Color = accent,
	})
	crown.Parent = folder

	local strip = part({
		Name = "WindowStrip",
		Size = Vector3.new(isXAxis and width + 0.4 or 0.4, height * 0.7, isXAxis and 0.4 or width + 0.4),
		Position = base + Vector3.new(0, height * 0.45, 0) - right * (side * (width / 2 + 0.3)),
		Material = Enum.Material.Neon,
		Color = accent,
		Transparency = 0.35,
	})
	strip.Parent = folder
end

-- Pack one row of buildings shoulder to shoulder along the segment. Each building is
-- scaled by HEIGHT (not squeezed into a box), then slid so its near face sits `setback`
-- studs behind the curb and its left edge starts where the previous one ended.
local function packRow(
	folder: Folder,
	dir: Vector3,
	right: Vector3,
	isXAxis: boolean,
	start: number,
	side: number,
	seedBase: number,
	heightRange: { number },
	setback: number,
	gap: number,
	pool: string
)
	local curb = ZoneData.ROAD_WIDTH / 2
	local cursor = start
	local lot = 0
	while cursor < start + ZoneData.ROAD_LENGTH do
		lot += 1
		local seed = seedBase + lot * 3 + (side + 1)
		local height = math.random(heightRange[1], heightRange[2])
		local probe = dir * cursor + right * ((curb + setback) * side)
		local facing = CFrame.lookAt(probe, probe - right * side)
		local model = PremadeAssets.stampVariantHeight(pool, seed, facing, height, MAX_FOOTPRINT, folder)
		if not model then
			local width = 18
			proceduralTower(
				folder,
				dir * (cursor + width / 2) + right * ((curb + setback + width / 2) * side),
				width,
				height,
				isXAxis,
				right,
				side
			)
			cursor += width + gap
			continue
		end
		local size = model:GetExtentsSize()
		local along = isXAxis and size.X or size.Z
		local depth = isXAxis and size.Z or size.X
		local centre = dir * (cursor + along / 2)
			+ right * ((curb + setback + depth / 2) * side)
			+ Vector3.new(0, size.Y / 2, 0)
		model:PivotTo(CFrame.lookAt(centre, centre - right * side))
		AdoptModel.settle(model, 0) -- sidewalk ground top; exact lowest visible corner on it
		cursor += along + gap
	end
end

-- Skyline: a front row of big buildings forming the street walls, and a taller back
-- row behind them for depth.
local function buildSkyline(folder: Folder, dir: Vector3, isXAxis: boolean, start: number, zoneIndex: number)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	for side = -1, 1, 2 do
		packRow(
			folder,
			dir,
			right,
			isXAxis,
			start,
			side,
			zoneIndex * 5,
			FRONT_HEIGHT,
			FRONT_SETBACK,
			FRONT_GAP,
			"tower"
		)
		packRow(
			folder,
			dir,
			right,
			isXAxis,
			start + math.random(0, 25),
			side,
			zoneIndex * 7 + 40,
			BACK_HEIGHT,
			BACK_SETBACK,
			math.random(8, 24),
			"skyline"
		)
	end
end

local function buildLamps(folder: Folder, dir: Vector3, start: number, zoneIndex: number)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	for i = 1, 4 do
		for side = -1, 1, 2 do
			local along = start + (i - 0.5) * (ZoneData.ROAD_LENGTH / 4)
			local base = dir * along + right * ((ZoneData.ROAD_WIDTH / 2 + 3) * side)
			-- one lamp style per street (so each district reads differently), facing the
			-- road; the pole+bulb placeholder is the fallback
			local lamp = PremadeAssets.stampVariant(
				"lamp",
				zoneIndex,
				CFrame.lookAt(base, base - right * side),
				Vector3.new(5, 12, 5),
				folder
			)
			if not lamp then
				local pole = part({
					Name = "LampPole",
					Size = Vector3.new(0.6, 12, 0.6),
					Position = base + Vector3.new(0, 6, 0),
					Material = Enum.Material.Metal,
					Color = Color3.fromRGB(40, 40, 55),
				})
				pole.Parent = folder
			end
			local bulb = part({
				Name = "LampBulb",
				Size = Vector3.new(1.6, 1.6, 1.6),
				Position = base + Vector3.new(0, 11.5, 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(180, 240, 255),
				Transparency = lamp and 1 or 0,
				CanCollide = lamp == nil,
			})
			local light = Instance.new("PointLight")
			light.Range = 24
			light.Brightness = 1.5
			light.Color = Color3.fromRGB(160, 220, 255)
			light.Parent = bulb
			bulb.Parent = folder
		end
	end
end

-- Street life: parked vehicles at the curb, clutter (vending machines, dumpsters,
-- neon wall sets) on the sidewalks, and neon signs hung on the building fronts.
local function buildStreetLife(folder: Folder, dir: Vector3, start: number, zoneIndex: number)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local curb = ZoneData.ROAD_WIDTH / 2
	-- vehicles: 3 per street, alternating sides, nosed along the road
	for i = 1, 3 do
		local side = (i % 2 == 0) and 1 or -1
		local along = start + ZoneData.ROAD_LENGTH * (0.12 + 0.3 * (i - 1)) + math.random(-6, 6)
		local base = dir * along + right * ((curb - 5) * side) + Vector3.new(0, SURFACE_Y, 0) -- on the road overlay
		local heading = (i + zoneIndex) % 2 == 0 and dir or -dir
		PremadeAssets.stampVariant(
			"vehicle",
			i + zoneIndex * 3,
			CFrame.lookAt(base, base + heading),
			Vector3.new(7, 4, 14),
			folder
		)
	end
	-- sidewalk clutter: 6 per street, just outside the curb, facing the road
	for i = 1, 6 do
		local side = (i % 2 == 0) and 1 or -1
		local along = start + ZoneData.ROAD_LENGTH * (0.08 + 0.15 * (i - 1)) + math.random(-4, 4)
		local base = dir * along + right * ((curb + 6) * side)
		PremadeAssets.stampVariant(
			"prop",
			i + zoneIndex * 2,
			CFrame.lookAt(base, base - right * side),
			Vector3.new(4.5, 5.5, 4.5),
			folder
		)
	end
	-- neon signs: 3 per street on the building line, up high, facing the road
	for i = 1, 3 do
		local side = (i % 2 == 0) and -1 or 1
		local along = start + ZoneData.ROAD_LENGTH * (0.2 + 0.3 * (i - 1))
		local base = dir * along + right * ((curb + 7.5) * side) + Vector3.new(0, 8, 0)
		PremadeAssets.stampVariant(
			"sign",
			i + zoneIndex,
			CFrame.lookAt(base, base - right * side),
			Vector3.new(6, 6, 1.5),
			folder
		)
	end
end

-- Fixer NPC at each street mouth: touch to pick up side jobs for that street.
local function buildFixer(zone, folder: Folder, entrance: Vector3, dir: Vector3, zoneIndex: number)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local spot = entrance + dir * 6 + right * (ZoneData.ROAD_WIDTH / 2 - 3)
	-- store NPC model (a different look per street) facing the street mouth; the neon
	-- block becomes an invisible trigger
	local npc = PremadeAssets.stampVariant(
		"fixer",
		zoneIndex,
		CFrame.lookAt(spot + Vector3.new(0, SURFACE_Y, 0), spot - dir * 10 + Vector3.new(0, SURFACE_Y, 0)),
		Vector3.new(3.5, 5.5, 3.5),
		folder
	)
	local fixer = part({
		Name = zone.id .. "_fixer",
		Size = npc and Vector3.new(4, 5.5, 4) or Vector3.new(2.2, 4.8, 2.2),
		Position = spot + Vector3.new(0, 3, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(120, 255, 220),
		Transparency = npc and 1 or 0,
		CanCollide = npc == nil,
	})
	fixer.Parent = folder

	local debounce = {}
	fixer.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or debounce[player] then
			return
		end
		debounce[player] = true
		task.delay(2, function()
			debounce[player] = nil
		end)
		PlayerDataService.acceptSideQuest(player, zone.id)
	end)
end

local function buildGate(zone, folder: Folder, entrance: Vector3, dir: Vector3)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local gate = part({
		Name = zone.id .. "_gate",
		Size = Vector3.new(2, 14, ZoneData.ROAD_WIDTH),
		CFrame = CFrame.lookAlong(entrance + Vector3.new(0, 7, 0), right),
		Material = Enum.Material.ForceField,
		Color = Color3.fromRGB(255, 60, 120),
		Transparency = 0.2,
	})
	gate.Parent = folder

	-- Tripo archway framing the force field, spanning the road; nothing if not imported yet
	local archBase = entrance + Vector3.new(0, SURFACE_Y, 0)
	PremadeAssets.stamp(
		"gate_arch",
		CFrame.lookAt(archBase, archBase + dir),
		Vector3.new(ZoneData.ROAD_WIDTH + 10, 20, 10),
		folder
	)

	local debounce = {}
	gate.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or debounce[player] then
			return
		end
		debounce[player] = true
		task.delay(2, function()
			debounce[player] = nil
		end)

		if PlayerDataService.isZoneUnlocked(player, zone.id) then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then
				root.CFrame = CFrame.new(entrance + dir * 10 + Vector3.new(0, 4, 0))
			end
		else
			PlayerDataService.notify(
				player,
				("%s is a premium district."):format(zone.name),
				{ zoneId = zone.id, name = zone.name, cost = zone.crownCost }
			)
		end
	end)
end

function ZoneService.build()
	local folder = Instance.new("Folder")
	folder.Name = "Zones"

	for zoneIndex, zone in ZoneData.list do
		local dir = zone.dir
		local entrance = dir * (zone.startOverride or ZoneData.ROAD_START)
		local mid = dir * ((zone.startOverride or ZoneData.ROAD_START) + ZoneData.ROAD_LENGTH / 2)
		local isXAxis = math.abs(dir.X) > 0.5

		-- ground under the whole segment: the baseplate ends long before the road does
		local ground = part({
			Name = zone.id .. "_ground",
			Size = isXAxis and Vector3.new(ZoneData.ROAD_LENGTH + 2, 1, 320)
				or Vector3.new(320, 1, ZoneData.ROAD_LENGTH + 2),
			Position = mid + Vector3.new(0, -0.5, 0),
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(16, 16, 22),
		})
		ground.Parent = folder

		-- road
		local road = part({
			Name = zone.id,
			Size = isXAxis and Vector3.new(ZoneData.ROAD_LENGTH, OVERLAY, ZoneData.ROAD_WIDTH)
				or Vector3.new(ZoneData.ROAD_WIDTH, OVERLAY, ZoneData.ROAD_LENGTH),
			Position = mid,
			Material = Enum.Material.Asphalt,
			Color = Color3.fromRGB(26, 26, 34),
		})
		road.Parent = folder
		GroundDressing.dressSegment(folder, dir, zone.startOverride or ZoneData.ROAD_START)

		-- neon curbs
		for side = -1, 1, 2 do
			local offset = isXAxis and Vector3.new(0, 0, side * (ZoneData.ROAD_WIDTH / 2 + 1))
				or Vector3.new(side * (ZoneData.ROAD_WIDTH / 2 + 1), 0, 0)
			local curb = part({
				Name = zone.id .. "_curb",
				Size = isXAxis and Vector3.new(ZoneData.ROAD_LENGTH, OVERLAY, 2)
					or Vector3.new(2, OVERLAY, ZoneData.ROAD_LENGTH),
				Position = mid + offset,
				Material = Enum.Material.Neon,
				Color = zone.crownCost > 0 and Color3.fromRGB(255, 60, 120) or Color3.fromRGB(40, 255, 200),
			})
			curb.Parent = folder
		end

		local start = zone.startOverride or ZoneData.ROAD_START
		buildSkyline(folder, dir, isXAxis, start, zoneIndex)
		buildLamps(folder, dir, start, zoneIndex)
		buildStreetLife(folder, dir, start, zoneIndex)
		buildFixer(zone, folder, entrance, dir, zoneIndex)

		if zone.crownCost > 0 then
			buildGate(zone, folder, entrance, dir)
		end
	end

	folder.Parent = Workspace
end

return ZoneService
