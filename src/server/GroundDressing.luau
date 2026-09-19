--!nonstrict
-- GroundDressing: gives the floor a street language. Everything here is a flush overlay
-- (thin part centred on the floor plane) so it never becomes a step. Player = 5 studs.
--   Road:      asphalt, neon centre dashes, direction chevrons pointing down the road
--   Sidewalks: concrete band between the curb light and the building fronts
--   Entrances: crosswalk stripes at every district start (reads as a threshold)
--   Details:   manhole covers, wet puddles with reflections
--   Plaza:     concrete disc, inner neon ring, radial seams, paved path to the road mouth

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneData = require(ReplicatedStorage.Shared.ZoneData)

local GroundDressing = {}

local OVERLAY = 0.2
-- overlays that sit ON the road/plaza overlay are lifted a hair to avoid z-fighting
local MARK_LIFT = 0.06

local SIDEWALK_WIDTH = 8 -- curb light to building fronts (ZoneService FRONT_SETBACK)
local DASH_LENGTH, DASH_GAP = 6, 6
local CHEVRON_SPACING = 35

local ASPHALT = Color3.fromRGB(26, 26, 34)
local CONCRETE = Color3.fromRGB(74, 74, 88)
local CONCRETE_LIGHT = Color3.fromRGB(98, 98, 112)
local LANE_NEON = Color3.fromRGB(60, 255, 210)
local CHEVRON_NEON = Color3.fromRGB(255, 60, 120)
local STRIPE = Color3.fromRGB(200, 200, 210)
local METAL = Color3.fromRGB(60, 62, 70)
local PUDDLE = Color3.fromRGB(18, 26, 36)

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false -- markings are paint, the floor below carries the player
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	for k, v in props do
		p[k] = v
	end
	return p
end

-- Flat overlay: `along` is the road axis length, `across` the width, centred at pos.
local function slab(
	parent: Instance,
	name: string,
	pos: Vector3,
	along: number,
	across: number,
	dir: Vector3,
	lift: number,
	props
)
	local size = Vector3.new(along, OVERLAY, across)
	local cf = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0) -- X axis along `dir`
	local p = part(props)
	p.Name = name
	p.Size = size
	p.CFrame = cf + Vector3.new(0, lift, 0)
	p.Parent = parent
	return p
end

function GroundDressing.dressSegment(folder: Instance, dir: Vector3, start: number)
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local length, width = ZoneData.ROAD_LENGTH, ZoneData.ROAD_WIDTH
	local curb = width / 2
	local mid = dir * (start + length / 2)

	-- sidewalks: concrete bands from the curb light to the building fronts
	for side = -1, 1, 2 do
		slab(
			folder,
			"Sidewalk",
			mid + right * ((curb + 1 + SIDEWALK_WIDTH / 2) * side),
			length,
			SIDEWALK_WIDTH,
			dir,
			0,
			{
				Material = Enum.Material.Concrete,
				Color = CONCRETE,
			}
		)
		-- seam every 12 studs so the sidewalk reads as paving, not one slab
		for along = start, start + length, 12 do
			slab(
				folder,
				"SidewalkSeam",
				dir * along + right * ((curb + 1 + SIDEWALK_WIDTH / 2) * side),
				0.3,
				SIDEWALK_WIDTH,
				dir,
				MARK_LIFT,
				{
					Material = Enum.Material.SmoothPlastic,
					Color = ASPHALT,
				}
			)
		end
	end

	-- centre line: neon dashes down the middle of the road
	local along = start + DASH_GAP
	while along + DASH_LENGTH < start + length do
		slab(folder, "LaneDash", dir * (along + DASH_LENGTH / 2), DASH_LENGTH, 0.5, dir, MARK_LIFT, {
			Material = Enum.Material.Neon,
			Color = LANE_NEON,
			Transparency = 0.15,
		})
		along += DASH_LENGTH + DASH_GAP
	end

	-- direction chevrons: two bars that meet at a tip and sweep back and outward, so the
	-- shape reads as ">" pointing down the road
	local sweep = math.rad(40)
	for at = start + CHEVRON_SPACING / 2, start + length - 10, CHEVRON_SPACING do
		local tip = dir * at + Vector3.new(0, MARK_LIFT, 0)
		for side = -1, 1, 2 do
			local axis = -dir * math.cos(sweep) + right * (side * math.sin(sweep))
			local centre = tip + axis * 3.5
			local p = part({
				Name = "Chevron",
				Size = Vector3.new(7, OVERLAY, 1.2),
				Material = Enum.Material.Neon,
				Color = CHEVRON_NEON,
				Transparency = 0.25,
			})
			p.CFrame = CFrame.lookAt(centre, centre + axis) * CFrame.Angles(0, math.rad(90), 0)
			p.Parent = folder
		end
	end

	-- crosswalk at the district entrance: stripes across the road
	for i = 0, 5 do
		local offset = -width / 2 + 2 + i * (width - 4) / 5
		slab(folder, "Crosswalk", dir * (start + 2) + right * offset, 4, 1.4, dir, MARK_LIFT, {
			Material = Enum.Material.SmoothPlastic,
			Color = STRIPE,
		})
	end

	-- manhole covers on the road, two per segment
	for i = 1, 2 do
		local pos = dir * (start + length * (0.3 * i + 0.1) + math.random(-8, 8)) + right * math.random(-6, 6)
		local cover = part({
			Name = "Manhole",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(OVERLAY, 3.5, 3.5),
			Material = Enum.Material.DiamondPlate,
			Color = METAL,
		})
		cover.CFrame = CFrame.new(pos + Vector3.new(0, MARK_LIFT, 0)) * CFrame.Angles(0, 0, math.rad(90))
		cover.Parent = folder
	end

	-- wet puddles: reflective dark patches, road and sidewalk
	for i = 1, 5 do
		local lateral = math.random(-curb - SIDEWALK_WIDTH, curb + SIDEWALK_WIDTH)
		local pos = dir * (start + math.random(10, length - 10)) + right * lateral
		local w, d = math.random(5, 11), math.random(3, 7)
		local puddle = part({
			Name = "Puddle",
			Size = Vector3.new(w, OVERLAY, d),
			Material = Enum.Material.Glass,
			Color = PUDDLE,
			Transparency = 0.35,
			Reflectance = 0.45,
		})
		puddle.CFrame = CFrame.new(pos + Vector3.new(0, MARK_LIFT + 0.01 * i, 0))
			* CFrame.Angles(0, math.rad(math.random(0, 179)), 0)
		puddle.Parent = folder
	end
end

function GroundDressing.dressPlaza(folder: Instance, radius: number, roadDir: Vector3)
	-- inner neon ring around the fountain court
	local ringRadius = 20
	local segments = 36
	for i = 1, segments do
		local a0 = (i - 1) / segments * math.pi * 2
		local a1 = i / segments * math.pi * 2
		local p0 = Vector3.new(math.cos(a0) * ringRadius, 0, math.sin(a0) * ringRadius)
		local p1 = Vector3.new(math.cos(a1) * ringRadius, 0, math.sin(a1) * ringRadius)
		local seg = part({
			Name = "PlazaRing",
			Size = Vector3.new((p1 - p0).Magnitude + 0.2, OVERLAY, 0.6),
			Material = Enum.Material.Neon,
			Color = LANE_NEON,
			Transparency = 0.2,
		})
		local centre = (p0 + p1) / 2 + Vector3.new(0, MARK_LIFT, 0)
		seg.CFrame = CFrame.lookAt(centre, centre + (p1 - p0)) * CFrame.Angles(0, math.rad(90), 0)
		seg.Parent = folder
	end

	-- radial paving seams
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2
		local dirV = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local inner, outer = ringRadius + 1, radius - 2
		local centre = dirV * ((inner + outer) / 2) + Vector3.new(0, MARK_LIFT, 0)
		local seam = part({
			Name = "PlazaSeam",
			Size = Vector3.new(outer - inner, OVERLAY, 0.3),
			Material = Enum.Material.SmoothPlastic,
			Color = ASPHALT,
		})
		seam.CFrame = CFrame.lookAt(centre, centre + dirV) * CFrame.Angles(0, math.rad(90), 0)
		seam.Parent = folder
	end

	-- paved path from the fountain court to the road mouth: the way forward
	local pathStart, pathEnd = ringRadius, ZoneData.ROAD_START
	local centre = roadDir * ((pathStart + pathEnd) / 2)
	slab(folder, "PlazaPath", centre, pathEnd - pathStart, 14, roadDir, MARK_LIFT, {
		Material = Enum.Material.Concrete,
		Color = CONCRETE_LIGHT,
	})
	for side = -1, 1, 2 do
		local right = Vector3.new(-roadDir.Z, 0, roadDir.X)
		slab(folder, "PlazaPathEdge", centre + right * (7.2 * side), pathEnd - pathStart, 0.5, roadDir, MARK_LIFT * 2, {
			Material = Enum.Material.Neon,
			Color = LANE_NEON,
			Transparency = 0.15,
		})
	end
end

return GroundDressing
