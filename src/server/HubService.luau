--!nonstrict
-- HubService: builds Neon Plaza — our version of the W101 Commons.
-- Data fountain centerpiece, 7 Protocol pylons (Ravenwood energy), shop kiosks,
-- holo billboards, and Chief Codewright (quest giver NPC, model TBD).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SchoolColors = require(ReplicatedStorage.Shared.SchoolColors)
local MeshVisuals = require(script.Parent.MeshVisuals)

local HubService = {}

local PLAZA_RADIUS = 38

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

local function billboard(parent: BasePart, text: string, color: Color3?, width: number?, offsetY: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(width or 16, 4)
	gui.StudsOffset = Vector3.new(0, offsetY or 9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 160
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.fromRGB(120, 255, 220)
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
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
	local pos = Vector3.new(math.cos(rad) * radius, 1.25, math.sin(rad) * radius)
	return CFrame.lookAt(pos, Vector3.new(0, 1.25, 0))
end

local function buildFountain(folder: Folder)
	-- Adopt a Studio-imported fountain model if one exists in Workspace
	local imported = Workspace:FindFirstChild("commons_fountain")
	if imported and imported:IsA("Model") then
		local ok = pcall(function()
			local size = imported:GetExtentsSize()
			imported:ScaleTo(18 / math.max(size.X, size.Z, 0.001))
			local scaled = imported:GetExtentsSize()
			imported:PivotTo(CFrame.new(0, 1.25 + scaled.Y / 2, 0))
		end)
		if ok then
			local anchor = imported:FindFirstChildWhichIsA("BasePart", true)
			if anchor then
				local light = Instance.new("PointLight")
				light.Range = 40
				light.Brightness = 2
				light.Color = Color3.fromRGB(60, 255, 210)
				light.Parent = anchor
				billboard(anchor, "NEON PLAZA", Color3.fromRGB(60, 255, 210), 20, 14)
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
		local mesh = MeshVisuals.place("commons_fountain", CFrame.new(0, 1.25, 0), Vector3.new(18, 20, 18), folder)
		if mesh then
			mesh.CanCollide = true
			local light = Instance.new("PointLight")
			light.Range = 40
			light.Brightness = 2
			light.Color = Color3.fromRGB(60, 255, 210)
			light.Parent = mesh
			billboard(mesh, "NEON PLAZA", Color3.fromRGB(60, 255, 210), 20, 12)
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
	billboard(beam, "NEON PLAZA", Color3.fromRGB(60, 255, 210), 20, 10)
end

local function buildSchoolPylons(folder: Folder)
	local schools = { "Burnout", "Coolant", "Surge", "Patch", "Leech", "Ghost", "Kernel" }
	local taglines = {
		Burnout = "Watch them cook",
		Coolant = "Outlast everything",
		Surge = "All or nothing",
		Patch = "Outheal the pain",
		Leech = "Their loss, your gain",
		Ghost = "Twice the trouble",
		Kernel = "Master of all",
	}
	-- ring of 7, angled to dodge the four street mouths on the axes
	for i, school in schools do
		local angle = math.rad(20 + (i - 1) * 45.7)
		local x, z = math.cos(angle) * 30, math.sin(angle) * 30
		local color = SchoolColors[school]

		local base = part({
			Name = school .. "Base",
			Size = Vector3.new(6, 1, 6),
			Position = Vector3.new(x, 0.9, z),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(30, 30, 45),
		})
		base.Parent = folder

		local column = part({
			Name = school .. "Pylon",
			Size = Vector3.new(2, 14, 2),
			Position = Vector3.new(x, 8.4, z),
			Material = Enum.Material.Neon,
			Color = color,
		})
		billboard(column, school:upper() .. "\n" .. taglines[school], color, 14, 9)
		column.Parent = folder
	end
end

local function buildShops(folder: Folder)
	local shops = {
		{ name = "CARD SHOP", angle = 45, color = Color3.fromRGB(200, 80, 255) },
		{ name = "GEAR VAULT", angle = 135, color = Color3.fromRGB(80, 180, 255) },
		{ name = "CROWN EXCHANGE", angle = 315, color = Color3.fromRGB(255, 220, 80) },
	}
	for _, shop in shops do
		local angle = math.rad(shop.angle)
		local x, z = math.cos(angle) * 33, math.sin(angle) * 33
		local pos = Vector3.new(x, 0, z)
		local facing = CFrame.lookAt(pos + Vector3.new(0, 5, 0), Vector3.new(0, 5, 0))

		local building = part({
			Name = shop.name,
			Size = Vector3.new(14, 10, 8),
			CFrame = facing,
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(24, 24, 36),
		})
		building.Parent = folder

		local trim = part({
			Name = shop.name .. "_trim",
			Size = Vector3.new(14.4, 0.8, 8.4),
			CFrame = facing * CFrame.new(0, 5.4, 0),
			Material = Enum.Material.Neon,
			Color = shop.color,
		})
		billboard(trim, shop.name, shop.color, 16, 4)
		trim.Parent = folder

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
	local stallCFrame = CFrame.lookAt(Vector3.new(-20, 1.25, 24), Vector3.new(0, 1.25, 0))
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
	local npcCFrame = CFrame.lookAt(Vector3.new(9, 1.25, 4), Vector3.new(0, 1.25, 10))
	if adoptImported("chief_codewright", Vector3.new(3, 6.5, 3), { npcCFrame }, folder) then
		local adopted = folder:FindFirstChild("chief_codewright")
		local anchor = adopted and adopted:FindFirstChildWhichIsA("BasePart", true)
		if anchor then
			billboard(anchor, "CHIEF CODEWRIGHT\nQuests up top, choom", Color3.fromRGB(255, 220, 80), 16, 6)
		end
		return
	end
	if MeshVisuals.available("chief_codewright") then
		local mesh = MeshVisuals.place("chief_codewright", npcCFrame, Vector3.new(3, 6.5, 3), folder)
		if mesh then
			billboard(mesh, "CHIEF CODEWRIGHT\nQuests up top, choom", Color3.fromRGB(255, 220, 80), 16, 5)
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
	billboard(body, "CHIEF CODEWRIGHT\nQuests up top, choom", Color3.fromRGB(255, 220, 80), 16, 5)
	body.Parent = folder
end

function HubService.build()
	local folder = Instance.new("Folder")
	folder.Name = "NeonPlaza"

	-- plaza disc with a neon rim
	cylinder(PLAZA_RADIUS * 2, 1.2, 0.65, {
		Name = "PlazaFloor",
		Material = Enum.Material.Slate,
		Color = Color3.fromRGB(24, 24, 34),
	}).Parent =
		folder
	for i = 1, 24 do
		local angle = math.rad(i * 15)
		local stud = part({
			Name = "RimLight",
			Size = Vector3.new(1.6, 0.6, 1.6),
			Position = Vector3.new(math.cos(angle) * (PLAZA_RADIUS - 1), 1.3, math.sin(angle) * (PLAZA_RADIUS - 1)),
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
