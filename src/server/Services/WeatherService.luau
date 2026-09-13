--!strict

local Lighting = game:GetService("Lighting")

local WeatherService = {}

local function ensureEffect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing then return existing end
	local effect = Instance.new(className)
	effect.Name = name
	effect.Parent = Lighting
	return effect
end

function WeatherService.Start()
	Lighting.ClockTime = 13.2
	Lighting.Brightness = 2.3
	Lighting.Ambient = Color3.fromRGB(118, 168, 176)
	Lighting.OutdoorAmbient = Color3.fromRGB(148, 188, 184)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 221, 175)
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.65

	local atmosphere = ensureEffect("Atmosphere", "GrowAnIslandAtmosphere") :: Atmosphere
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(185, 231, 255)
	atmosphere.Decay = Color3.fromRGB(255, 216, 166)
	atmosphere.Glare = 0.12
	atmosphere.Haze = 1.1

	local bloom = ensureEffect("BloomEffect", "GrowAnIslandBloom") :: BloomEffect
	bloom.Intensity = 0.28
	bloom.Size = 30
	bloom.Threshold = 1.1

	local grade = ensureEffect("ColorCorrectionEffect", "GrowAnIslandColor") :: ColorCorrectionEffect
	grade.Brightness = 0.02
	grade.Contrast = 0.06
	grade.Saturation = 0.16
	grade.TintColor = Color3.fromRGB(255, 247, 229)

	local rays = ensureEffect("SunRaysEffect", "GrowAnIslandSunRays") :: SunRaysEffect
	rays.Intensity = 0.055
	rays.Spread = 0.72

	local sky = ensureEffect("Sky", "GrowAnIslandSky") :: Sky
	sky.CelestialBodiesShown = true
	sky.StarCount = 0
end

return WeatherService
