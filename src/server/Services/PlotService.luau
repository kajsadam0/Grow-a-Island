--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

-- Stable tile queries shared by gameplay and the runtime world renderer.
local PlotService = {}

function PlotService.GetTilePosition(tileId: string): Vector3?
	local definition = EconomyConfig.Expansion.Tiles[tileId]
	if not definition then return nil end
	return Vector3.new(definition.X * EconomyConfig.Expansion.TileSize, 0, definition.Z * EconomyConfig.Expansion.TileSize)
end

function PlotService.GetExpansionTileCount(): number
	local count = 0
	for _ in pairs(EconomyConfig.Expansion.Tiles) do count += 1 end
	return count
end

function PlotService.AreOrthogonallyAdjacent(firstId: string, secondId: string): boolean
	local first = EconomyConfig.Expansion.Tiles[firstId]
	local second = EconomyConfig.Expansion.Tiles[secondId]
	return first ~= nil and second ~= nil and math.abs(first.X - second.X) + math.abs(first.Z - second.Z) == 1
end

return PlotService
