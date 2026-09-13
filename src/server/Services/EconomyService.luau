--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

local EconomyService = {}

function EconomyService.CanAfford(coins: number, price: number): boolean
	return type(coins) == "number" and type(price) == "number" and price >= 0 and coins >= price
end

function EconomyService.GetIncomeMultiplier(rebirthMultiplier: number): number
	return math.max(EconomyConfig.Rebirth.BaseMultiplier, rebirthMultiplier)
end

function EconomyService.ApplyIncome(baseAmount: number, rebirthMultiplier: number): number
	return math.max(0, math.floor(baseAmount * EconomyService.GetIncomeMultiplier(rebirthMultiplier) + 0.5))
end

function EconomyService.GetExpansionCost(purchasedCount: number): number
	return EconomyConfig.GetExpansionCost(purchasedCount)
end

return EconomyService
