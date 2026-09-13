--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

-- Price lookup facade. GameService alone commits purchases after validation.
local ShopService = {}

function ShopService.GetPalmCost(): number
	return EconomyConfig.Coconut.PalmCost
end

function ShopService.GetTravelatorCost(): number
	return EconomyConfig.Coconut.TravelatorCost
end

function ShopService.GetShelterStage(level: number)
	return EconomyConfig.Shelters[level]
end

function ShopService.GetOxygenUpgrade(level: number)
	return EconomyConfig.Oxygen.Upgrades[level]
end

return ShopService
