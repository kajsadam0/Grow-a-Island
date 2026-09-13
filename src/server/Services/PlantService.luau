--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

-- Crop facade for the central scheduler. Adding another crop later does not
-- require changing reward logic or creating one task per plant.
local PlantService = {}

function PlantService.GetProductionInterval(cropId: string): number?
	if cropId == EconomyConfig.Coconut.Id then return EconomyConfig.Coconut.ProductionInterval end
	return nil
end

function PlantService.GetSellValue(cropId: string): number?
	if cropId == EconomyConfig.Coconut.Id then return EconomyConfig.Coconut.SellValue end
	return nil
end

function PlantService.GetHandPickupLimit(cropId: string): number?
	if cropId == EconomyConfig.Coconut.Id then return 8 end
	return nil
end

return PlantService
