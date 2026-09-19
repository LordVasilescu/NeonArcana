--!nonstrict
-- HubService: builds Neon Plaza — our version of the W101 Commons.
-- Data fountain centerpiece, 7 Protocol pylons (Ravenwood energy), shop kiosks,
-- holo billboards, and Chief Codewright (quest giver NPC, model TBD).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SchoolColors = require(ReplicatedStorage.Shared.SchoolColors)
local MeshVisuals = require(script.Parent.MeshVisuals)
local PremadeAssets = require(script.Parent.PremadeAssets)
local AdoptModel = require(script.Parent.AdoptModel)
local GroundDressing = require(script.Parent.GroundDressing)

local HubService = {}

local PLAZA_RADIUS = 38
-- ONE floor level. The baseplate/ground top is y=0; every walkable overlay (plaza disc,
-- roads, pads) is OVERLAY thick and centred on y=0, so its top is SURFACE_Y. Anything
-- that stands on the ground stands at SURFACE_Y. No steps anywhere.
local OVERLAY = 0.2
local SURFACE_Y = OVERLAY / 2

-- The place file ships a SpawnLocation and DuelPad built as 1-stud slabs floating at
-- y=1.4; flatten them onto the floor too.
local function flattenPlacePart(name: string)
	local instance = Workspace:FindFirstChild(name)
	if instance and instance:IsA("BasePart") then
		instance.Size = Vector3.new(instance.Size.X, OVERLAY, instance.Size.Z)
		instance.Position = Vector3.new(instance.Position.X, 0, instance.Position.Z)
	end
end

local function part(props): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

local function cylinder(diameter: number, height: number, y: number, props)
	local p = part(props)
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90))
	return p
end

-- Adopt a Studio-imported model by name: scale to fit, stamp at one or more
-- cframes (cloning for multiples), anchor everything. Returns true if adopted.
local function adoptImported(name: string, fitSize: Vector3, cframes: { CFrame }, folder: Folder): boolean
	local template = Workspace:FindFirstChild(name)
	if not (template and template:IsA("Model")) then
		return false
	end
	local ok = pcall(function()
		local size = template:GetExtentsSize()
		local factor = math.min(
			fitSize.X / math.max(size.X, 0.001),
			fitSize.Y / math.max(size.Y, 0.001),
			fitSize.Z / math.max(size.Z, 0.001)
		)
		template:ScaleTo(factor)
	end)
	if not ok then
		return false
	end
	local height = template:GetExtentsSize().Y
	for index, cframe in cframes do
		local instance = index == 1 and template or template:Clone()
		instance:PivotTo(cframe * CFrame.new(0, height / 2, 0))
		AdoptModel.settle(instance, cframe.Position.Y)
		for _, descendant in instance:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		instance.Parent = folder
	end
	return true
end

local function ringCFrame(angleDeg: number, radius: number): CFrame
	local rad = math.rad(angleDeg)
	local pos = Vector3.new(math.cos(rad) * radius, SURFACE_Y, math.sin(rad) * radius)
	return CFrame.lookAt(pos, Vector3.new(0, SURFACE_Y, 0))
end

local function buildFountain(folder: Folder)
	-- Adopt a Studio-imported fountain model if one exists in Workspace
	local imported = Workspace:FindFirstChild("commons_fountain")
	if imported and imported:IsA("Model") then
		local ok = pcall(function()
			local size = imported:GetExtentsSize()
			imported:ScaleTo(18 / math.max(size.X, size.Z, 0.001))
			local scaled = imported:GetExtentsSize()
			imported:PivotTo(CFrame.new(0, SURFACE_Y + scaled.Y / 2, 0))
			AdoptModel.settle(imported, SURFACE_Y)
		end)
		if ok then
			local anchor = imported:FindFirstChildWhichIsA("BasePart", true)
			if anchor then
				local light = Instance.new("PointLight")
				light.Range = 40
				light.Brightness = 2
				light.Color = Color3.fromRGB(60, 255, 210)
				light.Parent = anchor
			end
			for _, descendant in imported:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
				end
			end
			return
		end
	end
	-- Tripo fountain replaces the procedural one once uploaded
	if MeshVisuals.available("commons_fountain") then
		local mesh = MeshVisuals.place("commons_fountain", CFrame.new(0, SURFACE_Y, 0), Vector3.new(18, 20, 18), folder)
		if mesh then
			mesh.CanCollide = true
			local light = Instance.new("PointLight")
			light.Range = 40
			light.Brightness = 2
			light.Color = Color3.fromRGB(60, 255, 210)
			light.Parent = mesh
			return
		end
	end
	cylinder(
		18,
		1.6,
		0.8,
		{ Name = "FountainBase", Material = Enum.Material.Metal, Color = Color3.fromRGB(35, 35, 50) }
	).Parent =
		folder
	cylinder(12, 1.2, 2.0, { Name = "FountainMid", Material = Enum.Material.Metal, Color = Color3.fromRGB(45, 45, 65) }).Parent =
		folder
	cylinder(6, 1.0, 3.0, { Name = "FountainTop", Material = Enum.Material.Metal, Color = Color3.fromRGB(55, 55, 80) }).Parent =
		folder

	-- the data stream: a column of light instead of water
	local beam = cylinder(2, 16, 11, {
		Name = "DataBeam",
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(60, 255, 210),
		Transparency = 0.25,
		CanCollide = false,
	})
	beam.CFrame = CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.rad(90))
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 2
	light.Color = Color3.fromRGB(60, 255, 210)
	light.Parent = beam
	beam.Parent = folder
end

local function buildSchoolPylons(folder: Folder)
	local schools = { "Burnout", "Coolant", "Surge", "Patch", "Leech", "Ghost", "Kernel" }
	-- ring of 7, angled to dodge the street mouth on +X
	for i, school in schools do
		local angle = math.rad(20 + (i - 1) * 45.7)
		local x, z = math.cos(angle) * 30, math.sin(angle) * 30
		local color = SchoolColors[school]

		local base = part({
			Name = school .. "Base",
			Size = Vector3.new(6, OVERLAY, 6),
			Position = Vector3.new(x, 0, z),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(30, 30, 45),
		})
		base.Parent = folder

		-- store crystal cluster tinted in the school colour; neon column if it isn't available
		local crystal = PremadeAssets.stamp("pylon", CFrame.new(x, SURFACE_Y, z), Vector3.new(5, 10, 5), folder, color)
		local column = part({
			Name = school .. "Pylon",
			Size = Vector3.new(2, 10, 2),
			Position = Vector3.new(x, 6.4, z),
			Material = Enum.Material.Neon,
			Color = color,
			Transparency = crystal and 1 or 0,
			CanCollide = crystal == nil,
		})
		column.Parent = folder
	end
end

local function buildShops(folder: Folder)
	local shops = {
		{ name = "CARD SHOP", angle = 45, color = Color3.fromRGB(200, 80, 255) },
		{ name = "GEAR VAULT", angle = 135, color = Color3.fromRGB(80, 180, 255) },
		{ name = "CROWN EXCHANGE", angle = 315, color = Color3.fromRGB(255, 220, 80) },
	}
	for shopIndex, shop in shops do
		local angle = math.rad(shop.angle)
		local x, z = math.cos(angle) * 33, math.sin(angle) * 33
		local pos = Vector3.new(x, 0, z)
		local facing = CFrame.lookAt(pos + Vector3.new(0, 5, 0), Vector3.new(0, 5, 0))

		-- a different store kiosk per shop, facing the fountain; the metal box is the fallback
		local kiosk = PremadeAssets.stampVariant(
			"kiosk",
			shopIndex - 1,
			CFrame.lookAt(pos + Vector3.new(0, SURFACE_Y, 0), Vector3.new(0, SURFACE_Y, 0)),
			Vector3.new(12, 9, 10),
			folder
		)
		if not kiosk then
			local building = part({
				Name = shop.name,
				Size = Vector3.new(14, 10, 8),
				CFrame = facing,
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(24, 24, 36),
			})
			building.Parent = folder
		end

		local trim = part({
			Name = shop.name .. "_trim",
			Size = Vector3.new(14.4, 0.8, 8.4),
			CFrame = facing * CFrame.new(0, 5.4, 0),
			Material = Enum.Material.Neon,
			Color = shop.color,
			Transparency = kiosk and 1 or 0,
			CanCollide = kiosk == nil,
		})
		trim.Parent = folder

		if kiosk then
			continue
		end

		local door = part({
			Name = shop.name .. "_door",
			Size = Vector3.new(4, 7, 0.4),
			CFrame = facing * CFrame.new(0, -1.5, -4),
			Material = Enum.Material.Neon,
			Color = shop.color,
			Transparency = 0.5,
			CanCollide = false,
		})
		door.Parent = folder
	end
end

-- Tripo set dressing: trees, benches, stalls, billboards. Adopts Studio-imported
-- models first, then Open Cloud meshes; silent no-op until either exists.
local function buildSetDressing(folder: Folder)
	local treeCFrames, benchCFrames, billboardCFrames = {}, {}, {}
	for _, angle in { 68, 158, 248, 338 } do
		table.insert(treeCFrames, ringCFrame(angle, 22))
	end
	for _, angle in { 20, 110, 200, 290 } do
		table.insert(benchCFrames, ringCFrame(angle, 16))
	end
	for _, angle in { 225, 350 } do
		table.insert(billboardCFrames, ringCFrame(angle, 35))
	end
	local stallCFrame = CFrame.lookAt(Vector3.new(-20, SURFACE_Y, 24), Vector3.new(0, SURFACE_Y, 0))
	local statueCFrame = ringCFrame(315, 26)

	if not adoptImported("cyber_tree", Vector3.new(7, 12, 7), treeCFrames, folder) then
		for _, cframe in treeCFrames do
			MeshVisuals.place("cyber_tree", cframe, Vector3.new(7, 12, 7), folder)
		end
	end
	if not adoptImported("plaza_bench", Vector3.new(6, 3, 3), benchCFrames, folder) then
		for _, cframe in benchCFrames do
			MeshVisuals.place("plaza_bench", cframe, Vector3.new(6, 3, 3), folder)
		end
	end
	if not adoptImported("food_stall", Vector3.new(10, 9, 8), { stallCFrame }, folder) then
		MeshVisuals.place("food_stall", stallCFrame, Vector3.new(10, 9, 8), folder)
	end
	if not adoptImported("holo_billboard", Vector3.new(8, 14, 4), billboardCFrames, folder) then
		for _, cframe in billboardCFrames do
			MeshVisuals.place("holo_billboard", cframe, Vector3.new(8, 14, 4), folder)
		end
	end
	if not adoptImported("crown_statue", Vector3.new(5, 8, 5), { statueCFrame }, folder) then
		MeshVisuals.place("crown_statue", statueCFrame, Vector3.new(5, 8, 5), folder)
	end
end

local function buildQuestGiver(folder: Folder)
	-- Chief Codewright: our Ambrose. Tripo model once imported/uploaded, capsule until then.
	-- Player scale: ~5 studs tall; the Chief stands a touch taller.
	local npcCFrame = CFrame.lookAt(Vector3.new(9, SURFACE_Y, 4), Vector3.new(0, SURFACE_Y, 10))
	if adoptImported("chief_codewright", Vector3.new(3, 5.5, 3), { npcCFrame }, folder) then
		return
	end
	if MeshVisuals.available("chief_codewright") then
		if MeshVisuals.place("chief_codewright", npcCFrame, Vector3.new(3, 5.5, 3), folder) then
			return
		end
	end
	local body = part({
		Name = "ChiefCodewright",
		Size = Vector3.new(2.4, 5.2, 2.4),
		Position = Vector3.new(9, 3.2, 4),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 220, 80),
	})
	body.Parent = folder
end

function HubService.build()
	local folder = Instance.new("Folder")
	folder.Name = "NeonPlaza"
	flattenPlacePart("SpawnLocation")
	flattenPlacePart("DuelPad")
	GroundDressing.dressPlaza(folder, PLAZA_RADIUS, Vector3.new(1, 0, 0))

	-- plaza disc with a neon rim
	cylinder(PLAZA_RADIUS * 2, OVERLAY, 0, {
		Name = "PlazaFloor",
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(44, 44, 54),
	}).Parent =
		folder
	for i = 1, 24 do
		local angle = math.rad(i * 15)
		local stud = part({
			Name = "RimLight",
			Size = Vector3.new(1.6, OVERLAY, 1.6),
			Position = Vector3.new(
				math.cos(angle) * (PLAZA_RADIUS - 1),
				SURFACE_Y,
				math.sin(angle) * (PLAZA_RADIUS - 1)
			),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(60, 255, 210),
		})
		stud.Parent = folder
	end

	buildFountain(folder)
	buildSchoolPylons(folder)
	buildShops(folder)
	buildQuestGiver(folder)
	buildSetDressing(folder)

	folder.Parent = Workspace
end

return HubService
