--!nonstrict
-- ZoneService: procedurally builds the streets off Neon Plaza — roads, neon curbs,
-- name signs, and crown-gates on premium zones. Gate touch: unlocked -> teleport
-- past it; locked -> send purchase offer to the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local ZoneData = require(ReplicatedStorage.Shared.ZoneData)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ZoneService = {}

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

local function addSign(parent: Part, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(24, 5)
	gui.StudsOffset = Vector3.new(0, 10, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(120, 255, 220)
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
end

local ACCENTS = {
	Color3.fromRGB(40, 255, 200),
	Color3.fromRGB(255, 60, 120),
	Color3.fromRGB(200, 80, 255),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(80, 180, 255),
}

-- Skyline: dark towers with a neon crown strip, lining both sides of a street.
local function buildSkyline(folder: Folder, dir: Vector3, isXAxis: boolean)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	for i = 1, 8 do
		for side = -1, 1, 2 do
			local along = ZoneData.ROAD_START + (i - 0.5) * (ZoneData.ROAD_LENGTH / 8)
			local lateral = (ZoneData.ROAD_WIDTH / 2 + 14 + math.random(0, 10)) * side
			local height = math.random(25, 85)
			local width = math.random(10, 18)
			local base = dir * along + right * lateral

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

			-- window strip
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
	end
end

local function buildLamps(folder: Folder, dir: Vector3)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	for i = 1, 4 do
		for side = -1, 1, 2 do
			local along = ZoneData.ROAD_START + (i - 0.5) * (ZoneData.ROAD_LENGTH / 4)
			local base = dir * along + right * ((ZoneData.ROAD_WIDTH / 2 + 3) * side)
			local pole = part({
				Name = "LampPole",
				Size = Vector3.new(0.6, 12, 0.6),
				Position = base + Vector3.new(0, 6, 0),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(40, 40, 55),
			})
			pole.Parent = folder
			local bulb = part({
				Name = "LampBulb",
				Size = Vector3.new(1.6, 1.6, 1.6),
				Position = base + Vector3.new(0, 12.5, 0),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(180, 240, 255),
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
	addSign(gate, ("%s — %d CROWNS"):format(zone.name, zone.crownCost))
	gate.Parent = folder

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

	for _, zone in ZoneData.list do
		local dir = zone.dir
		local entrance = dir * ZoneData.ROAD_START
		local mid = dir * (ZoneData.ROAD_START + ZoneData.ROAD_LENGTH / 2)
		local isXAxis = math.abs(dir.X) > 0.5

		-- road
		local road = part({
			Name = zone.id,
			Size = isXAxis and Vector3.new(ZoneData.ROAD_LENGTH, 1, ZoneData.ROAD_WIDTH)
				or Vector3.new(ZoneData.ROAD_WIDTH, 1, ZoneData.ROAD_LENGTH),
			Position = mid + Vector3.new(0, 0.55, 0),
			Material = Enum.Material.Asphalt,
			Color = Color3.fromRGB(30, 30, 42),
		})
		addSign(road, ("%s  [%s]"):format(zone.name, zone.levelText))
		road.Parent = folder

		-- neon curbs
		for side = -1, 1, 2 do
			local offset = isXAxis and Vector3.new(0, 0, side * (ZoneData.ROAD_WIDTH / 2 + 1))
				or Vector3.new(side * (ZoneData.ROAD_WIDTH / 2 + 1), 0, 0)
			local curb = part({
				Name = zone.id .. "_curb",
				Size = isXAxis and Vector3.new(ZoneData.ROAD_LENGTH, 1.4, 2)
					or Vector3.new(2, 1.4, ZoneData.ROAD_LENGTH),
				Position = mid + offset + Vector3.new(0, 0.7, 0),
				Material = Enum.Material.Neon,
				Color = zone.crownCost > 0 and Color3.fromRGB(255, 60, 120) or Color3.fromRGB(40, 255, 200),
			})
			curb.Parent = folder
		end

		buildSkyline(folder, dir, isXAxis)
		buildLamps(folder, dir)

		if zone.crownCost > 0 then
			buildGate(zone, folder, entrance, dir)
		end
	end

	folder.Parent = Workspace
end

return ZoneService
