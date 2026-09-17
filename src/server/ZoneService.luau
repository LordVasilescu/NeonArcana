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

		if zone.crownCost > 0 then
			buildGate(zone, folder, entrance, dir)
		end
	end

	folder.Parent = Workspace
end

return ZoneService
