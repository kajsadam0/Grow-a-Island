--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TypedRemote = require(ReplicatedStorage.Packages.TypedRemote)

type RE<T...> = TypedRemote.Event<T...>
type RF<T..., R...> = TypedRemote.Function<T..., R...>

-- Every request below has a single, harmless allowlisted ID (or no payload).
-- Rewards, quantities, prices, positions and multipliers are never client arguments.
local folder = script:FindFirstChild("GrowAnIslandRemotes")
if not folder and RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "GrowAnIslandRemotes"
	folder.Parent = script
end
if not folder then
	folder = script:WaitForChild("GrowAnIslandRemotes")
end

local func, event = TypedRemote.parent(folder)

return {
	StateChanged = event("StateChanged") :: RE<{ [string]: any }>,
	Toast = event("Toast") :: RE<string, string>,
	GetInitialState = func("GetInitialState") :: RF<(), ({ [string]: any })>,
	BuyCoconutPalm = event("BuyCoconutPalm") :: RE<>,
	BuyTravelator = event("BuyTravelator") :: RE<>,
	UpgradeShelter = event("UpgradeShelter") :: RE<>,
	UpgradeOxygen = event("UpgradeOxygen") :: RE<>,
	BuyExpansionTile = event("BuyExpansionTile") :: RE<string>,
	CollectCoconut = event("CollectCoconut") :: RE<string>,
	ClaimTreasure = event("ClaimTreasure") :: RE<string>,
	SellCoconuts = event("SellCoconuts") :: RE<string>,
	MoveCoconuts = event("MoveCoconuts") :: RE<string>,
	RequestRebirth = event("RequestRebirth") :: RE<>,
}
