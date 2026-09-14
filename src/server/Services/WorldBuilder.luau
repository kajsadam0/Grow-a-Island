--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Terrain = workspace.Terrain

local Trove = require(ReplicatedStorage.Packages.Trove)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local ProfileTypes = require(ReplicatedStorage.Shared.Types.ProfileTypes)

type PlayerData = ProfileTypes.PlayerData
type PromptCallback = (Player, string, string?) -> ()

local WorldBuilder = {}
WorldBuilder.__index = WorldBuilder
WorldBuilder.WaterSurfaceY = -4
WorldBuilder.OceanRadius = 205
WorldBuilder.TravelStart = Vector3.new(-13, 4.2, 1)
WorldBuilder.TravelEnd = Vector3.new(14, 4.2, 0)
-- Set this Workspace attribute to true once an authored Terrain map supplies its
-- own island and water. The prototype generator will then leave that terrain intact.
WorldBuilder.UseAuthoredTerrainAttribute = "GrowAnIslandUseAuthoredTerrain"

local colors = {
	Sand = Color3.fromRGB(244, 214, 147),
	SandDark = Color3.fromRGB(217, 181, 112),
	Grass = Color3.fromRGB(83, 178, 103),
	GrassDark = Color3.fromRGB(45, 132, 78),
	Leaf = Color3.fromRGB(56, 154, 85),
	LeafLight = Color3.fromRGB(110, 197, 101),
	Trunk = Color3.fromRGB(114, 75, 44),
	Rock = Color3.fromRGB(112, 122, 128),
	Coral = Color3.fromRGB(242, 121, 127),
	CoralPurple = Color3.fromRGB(176, 111, 208),
	Wood = Color3.fromRGB(137, 88, 49),
	Roof = Color3.fromRGB(220, 148, 75),
	Gold = Color3.fromRGB(255, 205, 68),
}

local biomeColors: { [string]: Color3 } = {
	Beach = colors.Sand,
	Jungle = Color3.fromRGB(83, 168, 92),
	Cliff = Color3.fromRGB(133, 137, 119),
	Lagoon = Color3.fromRGB(120, 205, 184),
}

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.CFrame = cframe
	value.Color = color
	value.Material = material or Enum.Material.SmoothPlastic
	value.Anchored = true
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	value.Parent = parent
	return value
end

local function sphere(parent: Instance, name: string, size: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	local value = part(parent, name, Vector3.new(size, size, size), CFrame.new(position), color, material)
	value.Shape = Enum.PartType.Ball
	return value
end

local function cylinder(parent: Instance, name: string, radius: number, height: number, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local value = part(parent, name, Vector3.new(height, radius * 2, radius * 2), cframe * CFrame.Angles(0, 0, math.rad(90)), color, material)
	value.Shape = Enum.PartType.Cylinder
	return value
end

local function addTag(instance: Instance, tag: string)
	CollectionService:AddTag(instance, tag)
end

local function label(parent: Instance, text: string, color: Color3): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WorldLabel"
	billboard.Size = UDim2.fromOffset(190, 48)
	billboard.StudsOffset = Vector3.new(0, 3.8, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0.45
	textLabel.TextScaled = true
	textLabel.Parent = billboard
	return billboard
end

local function decorationSeed(key: string): number
	local sum = 0
	for i = 1, #key do sum += string.byte(key, i) end
	return sum
end

function WorldBuilder.new(onPrompt: PromptCallback)
	local self = setmetatable({}, WorldBuilder)
	self._onPrompt = onPrompt
	self._trove = Trove.new()
	self._structureTrove = Trove.new()
	self.Root = nil :: Folder?
	self._folders = {} :: { [string]: Folder }
	self._tileModels = {} :: { [string]: Model }
	self._tileTroves = {} :: { [string]: any }
	self.SpawnCFrames = {} :: { [number]: CFrame }
	return self
end

function WorldBuilder:_folder(name: string): Folder
	return self._folders[name]
end

function WorldBuilder:_prompt(parent: Instance, action: string, id: string?, actionText: string, objectText: string, maxDistance: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = maxDistance or 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	local promptTrove = if parent:IsDescendantOf(self._folders.Structures) then self._structureTrove else self._trove
	for tileId, tileModel in pairs(self._tileModels) do
		if parent:IsDescendantOf(tileModel) then
			promptTrove = self._tileTroves[tileId]
			break
		end
	end
	promptTrove:Connect(prompt.Triggered, function(player)
		self._onPrompt(player, action, id)
	end)
	return prompt
end

function WorldBuilder:_palm(parent: Instance, base: Vector3, scale: number)
	local trunk = cylinder(parent, "PalmTrunk", 0.7 * scale, 7 * scale, CFrame.new(base + Vector3.new(0, 4 * scale, 0)) * CFrame.Angles(0, 0, math.rad(-9)), colors.Trunk, Enum.Material.Wood)
	trunk.Material = Enum.Material.Wood
	for index = 1, 6 do
		local angle = (index / 6) * math.pi * 2
		local leaf = part(parent, "PalmFrond", Vector3.new(5.8 * scale, 0.28 * scale, 1.25 * scale), CFrame.new(base + Vector3.new(0, 7.4 * scale, 0)) * CFrame.Angles(0, angle, math.rad(11)) * CFrame.new(2.4 * scale, 0, 0), if index % 2 == 0 then colors.Leaf else colors.LeafLight, Enum.Material.Grass)
		leaf.CanCollide = false
	end
	for index = 1, 3 do
		sphere(parent, "DecorativeCoconut", 0.55 * scale, base + Vector3.new((index - 2) * 0.55 * scale, 6.95 * scale, 0.15 * index * scale), Color3.fromRGB(98, 61, 35), Enum.Material.SmoothPlastic)
	end
end

function WorldBuilder:_rock(parent: Instance, position: Vector3, size: number, color: Color3?)
	local rock = sphere(parent, "LowPolyRock", size, position, color or colors.Rock, Enum.Material.Slate)
	rock.Size = Vector3.new(size * 1.25, size * 0.75, size)
	return rock
end

function WorldBuilder:_flower(parent: Instance, position: Vector3, color: Color3)
	cylinder(parent, "FlowerStem", 0.05, 0.7, CFrame.new(position + Vector3.new(0, 0.35, 0)), colors.GrassDark, Enum.Material.Grass)
	for i = 1, 4 do
		local a = i * math.pi / 2
		sphere(parent, "FlowerPetal", 0.22, position + Vector3.new(math.cos(a) * 0.17, 0.78, math.sin(a) * 0.17), color, Enum.Material.Neon)
	end
	return
end

function WorldBuilder:_buildTile(tileId: string, biome: string, position: Vector3, owned: boolean)
	local tilesFolder = self:_folder("Tiles")
	local old = self._tileModels[tileId]
	local oldTrove = self._tileTroves[tileId]
	if oldTrove then oldTrove:Destroy() end
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = `Tile_{tileId}`
	model.Parent = tilesFolder
	self._tileModels[tileId] = model
	self._tileTroves[tileId] = Trove.new()
	local tile = part(model, "IslandTile", Vector3.new(EconomyConfig.Expansion.TileSize, 3.4, EconomyConfig.Expansion.TileSize), CFrame.new(position), if owned then (biomeColors[biome] or colors.Sand) else Color3.fromRGB(99, 170, 176), Enum.Material.Sand)
	tile:SetAttribute("TileId", tileId)
	addTag(tile, if owned then "Plot" else "ExpansionTile")
	if not owned then
		tile.Transparency = 0.42
		tile.CanCollide = false
		local marker = cylinder(model, "ExpansionMarker", 0.65, 6, CFrame.new(position + Vector3.new(0, 4.7, 0)), colors.Wood, Enum.Material.Wood)
		marker:SetAttribute("TileId", tileId)
		addTag(marker, "ExpansionTile")
		self:_prompt(marker, "BuyExpansionTile", tileId, "Claim tile", "Connected island tile", 12)
		return
	end
	local seed = decorationSeed(tileId)
	if biome == "Beach" then
		self:_palm(model, position + Vector3.new(-9, 1.7, 7), 0.72)
		self:_rock(model, position + Vector3.new(9, 2.6, -7), 3.2)
		self:_flower(model, position + Vector3.new(2, 1.8, 4), Color3.fromRGB(255, 144, 172))
	elseif biome == "Jungle" then
		for index = 1, 3 do
			self:_palm(model, position + Vector3.new(-10 + index * 7, 1.7, ((seed + index * 9) % 14) - 7), 0.6)
		end
		self:_flower(model, position + Vector3.new(-6, 1.8, 7), Color3.fromRGB(255, 212, 79))
	elseif biome == "Cliff" then
		for index = 1, 3 do
			self:_rock(model, position + Vector3.new(-8 + index * 7, 4 + index * 1.3, -3 + index * 2), 5 - index * 0.6, Color3.fromRGB(120, 124, 106))
		end
		self:_palm(model, position + Vector3.new(-10, 1.7, 8), 0.5)
	elseif biome == "Lagoon" then
		local lagoon = part(model, "LagoonPool", Vector3.new(16, 0.35, 16), CFrame.new(position + Vector3.new(0, 1.9, 0)), Color3.fromRGB(65, 190, 204), Enum.Material.Glass)
		lagoon.Transparency = 0.35
		for index = 1, 4 do
			self:_rock(model, position + Vector3.new(-7 + index * 4, 2.4, 7 - index * 2), 1.8, colors.Coral)
		end
	end
end

function WorldBuilder:_buildWorldShell()
	if workspace:GetAttribute(WorldBuilder.UseAuthoredTerrainAttribute) ~= true then
		Terrain:FillBlock(CFrame.new(0, -17, 0), Vector3.new(430, 26, 430), Enum.Material.Water)
	end
	local root = Instance.new("Folder")
	root.Name = "GrowAnIslandWorld"
	root.Parent = workspace
	self.Root = root
	self._trove:Add(root)
	for _, name in ipairs({ "Tiles", "Structures", "Pickups", "Chests", "Ocean", "VFX" }) do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = root
		self._folders[name] = folder
	end

	local ocean = self:_folder("Ocean")
	local seaFloor = part(ocean, "SeaFloor", Vector3.new(340, 2, 340), CFrame.new(0, -28, 0), colors.SandDark, Enum.Material.Sand)
	addTag(seaFloor, "DiveZone")
	for index = 1, 20 do
		local angle = index * 1.72
		local radius = 70 + (index % 5) * 18
		local pos = Vector3.new(math.cos(angle) * radius, -25.4, math.sin(angle) * radius)
		self:_rock(ocean, pos, 2 + (index % 3), if index % 2 == 0 then colors.Coral else colors.CoralPurple)
	end
	local vfx = self:_folder("VFX")
	local sun = part(vfx, "SunGlow", Vector3.new(1, 1, 1), CFrame.new(0, 80, 0), Color3.new(1, 1, 1))
	sun.Transparency = 1
	sun.CanCollide = false
	addTag(sun, "VFXAnchor")
end

function WorldBuilder:_buildSellStand(parent: Instance)
	local base = Vector3.new(14, 2.2, 0)
	local stand = Instance.new("Model")
	stand.Name = "CoconutSellStand"
	stand.Parent = parent
	local counter = part(stand, "Counter", Vector3.new(6, 2.3, 2), CFrame.new(base), colors.Wood, Enum.Material.Wood)
	part(stand, "Awning", Vector3.new(7.2, 0.55, 4), CFrame.new(base + Vector3.new(0, 3.4, 0)), Color3.fromRGB(255, 241, 184), Enum.Material.Fabric)
	for _, offset in ipairs({ Vector3.new(-2.5, 1.4, 0), Vector3.new(2.5, 1.4, 0) }) do
		cylinder(stand, "Post", 0.13, 3, CFrame.new(base + offset), colors.Wood, Enum.Material.Wood)
	end
	addTag(counter, "SellZone")
	self:_prompt(counter, "SellCoconuts", "All", "Sell all", "Coconut Stand", 11)
	label(counter, "COCONUT MARKET", Color3.fromRGB(255, 239, 128))
	return counter
end

function WorldBuilder:_buildPalmSite(parent: Instance, purchased: boolean)
	local position = Vector3.new(-13, 1.8, 3)
	if purchased then
		local palm = Instance.new("Model")
		palm.Name = "CoconutPalm"
		palm.Parent = parent
		addTag(palm, "CoconutTree")
		self:_palm(palm, position, 1)
		local slot = part(palm, "PalmPlantSlot", Vector3.new(4, 0.25, 4), CFrame.new(position + Vector3.new(0, -0.15, 0)), colors.Grass, Enum.Material.Grass)
		addTag(slot, "PlantSlot")
		return
	end
	local site = part(parent, "PalmBuildSite", Vector3.new(7, 0.4, 7), CFrame.new(position), Color3.fromRGB(112, 193, 110), Enum.Material.Grass)
	addTag(site, "PlantSlot")
	self:_prompt(site, "BuyCoconutPalm", nil, "Plant palm", "$25", 10)
	label(site, "PLANT A PALM", Color3.fromRGB(255, 248, 190))
end

function WorldBuilder:_buildTravelator(parent: Instance, purchased: boolean)
	if not purchased then
		local site = part(parent, "TravelatorBuildSite", Vector3.new(24, 0.3, 5), CFrame.lookAt(Vector3.new(0, 1.8, 1), Vector3.new(14, 1.8, 0)), Color3.fromRGB(113, 178, 190), Enum.Material.Metal)
		site.Transparency = 0.42
		addTag(site, "TravelatorBuildSite")
		self:_prompt(site, "BuyTravelator", nil, "Build travelator", "$800", 11)
		label(site, "AUTO-SELL TRAVELATOR", Color3.fromRGB(180, 244, 255))
		return
	end
	local route = WorldBuilder.TravelEnd - WorldBuilder.TravelStart
	local length = route.Magnitude
	local center = (WorldBuilder.TravelEnd + WorldBuilder.TravelStart) / 2 - Vector3.new(0, 1.55, 0)
	local belt = part(parent, "TravelatorBelt", Vector3.new(3.8, 0.55, length), CFrame.lookAt(center, center + route), Color3.fromRGB(56, 69, 73), Enum.Material.Metal)
	addTag(belt, "Travelator")
	for distance = 0, length, 3 do
		local at = WorldBuilder.TravelStart:Lerp(WorldBuilder.TravelEnd, distance / length) - Vector3.new(0, 1.1, 0)
		local slat = part(parent, "BeltSlat", Vector3.new(3.95, 0.12, 0.32), CFrame.lookAt(at, at + route), Color3.fromRGB(90, 117, 119), Enum.Material.Metal)
		slat.CanCollide = false
	end
	label(belt, "COCONUT EXPRESS", Color3.fromRGB(171, 242, 239))
end

function WorldBuilder:_buildShelter(parent: Instance, level: number)
	local base = Vector3.new(15, 1.8, 9)
	local site = part(parent, "ShelterPad", Vector3.new(16, 0.35, 14), CFrame.new(base), colors.SandDark, Enum.Material.Sand)
	addTag(site, "ShelterBuildSite")
	if level == 0 then
		self:_prompt(site, "UpgradeShelter", nil, "Build camp", "$900", 12)
		label(site, "BUILD A SHELTER", Color3.fromRGB(255, 237, 161))
		return
	end
	local shelter = Instance.new("Model")
	shelter.Name = `ShelterStage{level}`
	shelter.Parent = parent
	if level == 1 then
		local fire = sphere(shelter, "Campfire", 1.1, base + Vector3.new(-3, 0.9, 0), Color3.fromRGB(255, 163, 61), Enum.Material.Neon)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 221, 122)
		sparkles.Parent = fire
		part(shelter, "Tent", Vector3.new(7, 3.4, 5), CFrame.new(base + Vector3.new(2, 2, 0)) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(241, 181, 83), Enum.Material.Fabric)
	elseif level == 2 then
		part(shelter, "Hut", Vector3.new(10, 6, 8), CFrame.new(base + Vector3.new(0, 3.2, 0)), colors.Wood, Enum.Material.Wood)
		part(shelter, "LeafRoof", Vector3.new(12, 1.2, 10), CFrame.new(base + Vector3.new(0, 6.7, 0)) * CFrame.Angles(0, 0, math.rad(5)), colors.Leaf, Enum.Material.Grass)
	else
		part(shelter, "ShelterWalls", Vector3.new(13, 7, 10), CFrame.new(base + Vector3.new(0, 3.7, 0)), Color3.fromRGB(225, 190, 126), Enum.Material.WoodPlanks)
		part(shelter, "TropicalRoof", Vector3.new(16, 1.4, 13), CFrame.new(base + Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(7)), colors.Leaf, Enum.Material.Grass)
		part(shelter, "Door", Vector3.new(2.6, 4.5, 0.35), CFrame.new(base + Vector3.new(0, 2.5, -5.18)), colors.Wood, Enum.Material.Wood)
	end
	local storage = part(shelter, "CoconutStorage", Vector3.new(2.6, 2.3, 2.1), CFrame.new(base + Vector3.new(-5.4, 1.3, -3.3)), colors.Wood, Enum.Material.Wood)
	addTag(storage, "CoconutStorage")
	self:_prompt(storage, "MoveCoconuts", "Deposit", "Store coconuts", "Shelter storage", 10)
	label(storage, `STORAGE {EconomyConfig.StorageCapacityByShelter[level]}`, Color3.fromRGB(255, 237, 161))
	if level < 3 then
		self:_prompt(site, "UpgradeShelter", nil, "Improve shelter", `$${EconomyConfig.Shelters[level + 1].Cost}`, 12)
	end
end

function WorldBuilder:_buildOxygenSite(parent: Instance, level: number)
	local base = Vector3.new(-14, 2.1, -15)
	local tank = cylinder(parent, "OxygenTank", 1.05, 3.6, CFrame.new(base + Vector3.new(0, 1.9, 0)), Color3.fromRGB(88, 199, 220), Enum.Material.Metal)
	addTag(tank, "OxygenTank")
	local nextUpgrade = EconomyConfig.Oxygen.Upgrades[level + 1]
	if nextUpgrade then
		self:_prompt(tank, "UpgradeOxygen", nil, "Upgrade air tank", `$${nextUpgrade.Cost}`, 10)
		label(tank, `OXYGEN {EconomyConfig.GetOxygenSeconds(level)}s`, Color3.fromRGB(173, 244, 255))
	else
		label(tank, "MAX OXYGEN", Color3.fromRGB(173, 244, 255))
	end
end

function WorldBuilder:_buildRebirthShrine(parent: Instance, ready: boolean)
	local base = Vector3.new(-2, 2, 15)
	local shrine = cylinder(parent, "RebirthShrine", 2.6, 2.2, CFrame.new(base + Vector3.new(0, 1.1, 0)), if ready then colors.Gold else Color3.fromRGB(113, 118, 125), Enum.Material.Slate)
	addTag(shrine, "RebirthShrine")
	self:_prompt(shrine, "RequestRebirth", nil, "Rebirth", if ready then "Ready: permanent income" else "Locked: finish island + shelter", 10)
	label(shrine, if ready then "REBIRTH READY" else "REBIRTH SHRINE", if ready then Color3.fromRGB(255, 223, 97) else Color3.fromRGB(199, 211, 219))
end

function WorldBuilder:RefreshProgress(data: PlayerData)
	self._structureTrove:Destroy()
	self._structureTrove = Trove.new()
	local old = self._folders.Structures
	if old then old:Destroy() end
	local structures = Instance.new("Folder")
	structures.Name = "Structures"
	structures.Parent = self.Root
	self._folders.Structures = structures
	self:_buildPalmSite(structures, data.CoconutPalmPurchased)
	self:_buildTravelator(structures, data.TravelatorPurchased)
	self:_buildSellStand(structures)
	self:_buildShelter(structures, data.ShelterLevel)
	self:_buildOxygenSite(structures, data.OxygenUpgradeLevel)
	local totalOwned = 0
	for _ in pairs(data.PurchasedTiles) do totalOwned += 1 end
	local ready = data.ShelterLevel >= 3 and totalOwned >= self:GetExpansionTileCount()
	self:_buildRebirthShrine(structures, ready)
	self.SpawnCFrames[0] = CFrame.new(-4, 5, 7)
	self.SpawnCFrames[1] = CFrame.new(12, 5, 9)
	self.SpawnCFrames[2] = CFrame.new(14, 5, 9)
	self.SpawnCFrames[3] = CFrame.new(15, 5, 7)
end

function WorldBuilder:GetExpansionTileCount(): number
	local count = 0
	for _ in pairs(EconomyConfig.Expansion.Tiles) do count += 1 end
	return count
end

function WorldBuilder:Build(data: PlayerData)
	self._trove:Destroy()
	self._structureTrove:Destroy()
	for _, tileTrove in pairs(self._tileTroves) do
		tileTrove:Destroy()
	end
	self._trove = Trove.new()
	self._structureTrove = Trove.new()
	self._folders = {}
	self._tileModels = {}
	self._tileTroves = {}
	local old = workspace:FindFirstChild("GrowAnIslandWorld")
	if old then old:Destroy() end
	self:_buildWorldShell()
	self:_buildTile("0_0", "Beach", Vector3.new(0, 0, 0), true)
	for tileId, definition in pairs(EconomyConfig.Expansion.Tiles) do
		local biome = data.PurchasedTiles[tileId]
		local position = Vector3.new(definition.X * EconomyConfig.Expansion.TileSize, 0, definition.Z * EconomyConfig.Expansion.TileSize)
		self:_buildTile(tileId, biome or "Beach", position, biome ~= nil)
	end
	self:RefreshProgress(data)
end

function WorldBuilder:BuildPurchasedTile(tileId: string, biome: string)
	local definition = EconomyConfig.Expansion.Tiles[tileId]
	if not definition then return end
	self:_buildTile(tileId, biome, Vector3.new(definition.X * EconomyConfig.Expansion.TileSize, 0, definition.Z * EconomyConfig.Expansion.TileSize), true)
end

function WorldBuilder:SpawnCoconut(id: string, position: Vector3, conveyor: boolean): Part
	local parent = self:_folder(if conveyor then "VFX" else "Pickups")
	local coconut = sphere(parent, if conveyor then "TravelingCoconut" else "CoconutPickup", 1.05, position, Color3.fromRGB(103, 67, 39), Enum.Material.SmoothPlastic)
	coconut:SetAttribute("PickupId", id)
	coconut:SetAttribute("Conveyor", conveyor)
	if conveyor then
		addTag(coconut, "Travelator")
	else
		addTag(coconut, "CoconutPickup")
	end
	return coconut
end

-- A coconut is intentionally not interactable while it is still falling.
-- Adding the prompt only after landing avoids an action that the server must reject.
function WorldBuilder:EnableCoconutPickup(coconut: BasePart, id: string)
	if not coconut.Parent or coconut:FindFirstChildOfClass("ProximityPrompt") then return end
	self:_prompt(coconut, "CollectCoconut", id, "Pick up", "Fresh coconut", 9)
end

function WorldBuilder:SpawnChest(id: string, position: Vector3): Part
	local chest = part(self:_folder("Chests"), "TreasureChest", Vector3.new(3.1, 2.1, 2.1), CFrame.new(position), colors.Wood, Enum.Material.WoodPlanks)
	chest:SetAttribute("ChestId", id)
	addTag(chest, "TreasureChest")
	local lid = part(chest, "GoldLid", Vector3.new(3.25, 0.5, 2.25), CFrame.new(position + Vector3.new(0, 1.28, 0)), colors.Gold, Enum.Material.Metal)
	lid.CanCollide = false
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = colors.Gold
	sparkles.Parent = chest
	self:_prompt(chest, "ClaimTreasure", id, "Open chest", "Sunken treasure", 10)
	return chest
end

function WorldBuilder:Destroy()
	self._trove:Destroy()
	self._structureTrove:Destroy()
	for _, tileTrove in pairs(self._tileTroves) do
		tileTrove:Destroy()
	end
	if self.Root and self.Root.Parent then self.Root:Destroy() end
	self.Root = nil
end

return WorldBuilder
