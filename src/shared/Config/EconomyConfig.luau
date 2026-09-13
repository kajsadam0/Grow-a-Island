--!strict
-- First-pass balancing. A completed first rebirth is intended to take roughly
-- 2.5–3.5 hours of ordinary play, including island walking and optional dives.
local EconomyConfig = {
	StartingCoins = 25,
	MaxActivePlayers = 1,
	Coconut = {
		Id = "Coconut",
		ProductionInterval = 4, -- Active-server production only; never offline income.
		SellValue = 12,
		CarryCapacity = 6,
		PalmCost = 25,
		TravelatorCost = 800,
		TravelTime = 5.5,
	},
	StorageCapacityByShelter = {
		[0] = 0,
		[1] = 18,
		[2] = 48,
		[3] = 120,
	},
	Shelters = {
		[1] = { Id = "Camp", Name = "Campfire & Tent", Cost = 900 },
		[2] = { Id = "Hut", Name = "Island Hut", Cost = 2300 },
		[3] = { Id = "Tropical", Name = "Finished Tropical Shelter", Cost = 5200 },
	},
	Oxygen = {
		BaseSeconds = 10, -- Exactly ten seconds at upgrade level zero.
		Upgrades = {
			[1] = { Name = "Pocket Air Tank", Cost = 450, Seconds = 15 },
			[2] = { Name = "Explorer Tank", Cost = 1300, Seconds = 21 },
			[3] = { Name = "Pearl Diver Tank", Cost = 3100, Seconds = 30 },
		},
	},
	Treasure = {
		MinimumReward = 28,
		MaximumReward = 52,
		RespawnSeconds = 78,
		ChestCount = 5,
	},
	Rebirth = {
		BaseMultiplier = 1,
		MultiplierPerRebirth = 0.15,
	},
	Expansion = {
		TileSize = 42,
		BaseCost = 260,
		CostStep = 45,
		BiomeIds = { "Beach", "Jungle", "Cliff", "Lagoon" },
	},
	ActionCooldowns = {
		Purchase = 0.35,
		Collect = 0.22,
		Sell = 0.45,
		Storage = 0.35,
		Chest = 0.5,
		Rebirth = 1,
	},
}

-- A fixed 5x5 connected island grid. The starter tile is 0_0; every other
-- tile must be purchased from an owned neighbour. IDs are stable persistence IDs.
local tiles: { [string]: { X: number, Z: number } } = {}
for x = -2, 2 do
	for z = -2, 2 do
		if not (x == 0 and z == 0) then
			tiles[`{x}_{z}`] = { X = x, Z = z }
		end
	end
end
EconomyConfig.Expansion.Tiles = tiles

function EconomyConfig.GetExpansionCost(purchasedCount: number): number
	return EconomyConfig.Expansion.BaseCost + EconomyConfig.Expansion.CostStep * purchasedCount
end

function EconomyConfig.GetOxygenSeconds(level: number): number
	if level <= 0 then
		return EconomyConfig.Oxygen.BaseSeconds
	end
	local upgrade = EconomyConfig.Oxygen.Upgrades[level]
	return if upgrade then upgrade.Seconds else EconomyConfig.Oxygen.BaseSeconds
end

return table.freeze(EconomyConfig)
