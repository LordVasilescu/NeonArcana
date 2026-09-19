--!nonstrict
-- WorldLighting: the atmosphere pass. Night city, but lit enough that the ground,
-- sidewalks and building bases read; fog to give the road depth; bloom so neon glows
-- instead of just being bright; a mild cool grade. Applied at boot so it works whether
-- the place file's Lighting was saved that way or not.

local Lighting = game:GetService("Lighting")

local WorldLighting = {}

local function ensure(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

function WorldLighting.apply()
	Lighting.ClockTime = 0.5 -- deep night, sun below the horizon
	Lighting.Brightness = 1.2
	Lighting.Ambient = Color3.fromRGB(70, 72, 96)
	Lighting.OutdoorAmbient = Color3.fromRGB(78, 80, 110)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.FogColor = Color3.fromRGB(22, 18, 40)
	Lighting.FogStart = 220
	Lighting.FogEnd = 1100

	local atmosphere = ensure("Atmosphere", "CityAtmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(110, 96, 150)
	atmosphere.Decay = Color3.fromRGB(60, 40, 110)
	atmosphere.Glare = 0.25
	atmosphere.Haze = 1.8

	local bloom = ensure("BloomEffect", "NeonBloom")
	bloom.Intensity = 0.45
	bloom.Size = 28
	bloom.Threshold = 0.92

	local grade = ensure("ColorCorrectionEffect", "CityGrade")
	grade.Brightness = 0.02
	grade.Contrast = 0.12
	grade.Saturation = 0.12
	grade.TintColor = Color3.fromRGB(236, 240, 255)

	local sky = ensure("Sky", "NightSky")
	sky.StarCount = 4000
	sky.CelestialBodiesShown = false
	sky.SunAngularSize = 0
	sky.MoonAngularSize = 0
end

return WorldLighting
