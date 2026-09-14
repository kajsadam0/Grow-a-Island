--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Trove = require(ReplicatedStorage.Packages.Trove)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local ProfileTypes = require(ReplicatedStorage.Shared.Types.ProfileTypes)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlantService = require(script.Parent.PlantService)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)
local WorldBuilder = require(script.Parent.WorldBuilder)

type PlayerData = ProfileTypes.PlayerData
type ClientState = ProfileTypes.ClientState

type PickupRecord = {
	Instance: BasePart,
	SpawnedAt: number,
	GroundPosition: Vector3,
	Available: boolean,
}
type ConveyorRecord = { Instance: BasePart, StartedAt: number }
type ChestRecord = { Instance: BasePart?, NextSpawnAt: number }
type OxygenRecord = { Value: number, LastUpdatedAt: number, Underwater: boolean, LastPushedAt: number }

local GameService = {}
GameService.__index = GameService
-- First playable rule: one private island owner per server until multiplayer exists.
GameService.MAX_ACTIVE_PLAYERS = EconomyConfig.MaxActivePlayers

local CHEST_POINTS = {
	Vector3.new(-54, -23.5, -36),
	Vector3.new(57, -23.5, -44),
	Vector3.new(-63, -23.5, 42),
	Vector3.new(63, -23.5, 49),
	Vector3.new(4, -23.5, 73),
}

local function countTable(map: { [string]: any }): number
	local total = 0
	for _ in pairs(map) do total += 1 end
	return total
end

function GameService.new()
	local self = setmetatable({}, GameService)
	self._trove = Trove.new()
	self._owner = nil :: Player?
	self._world = WorldBuilder.new(function(player, action, id)
		self:_handle(player, action, id)
	end)
	self._pickups = {} :: { [string]: PickupRecord }
	self._conveyor = {} :: { [string]: ConveyorRecord }
	self._chests = {} :: { [string]: ChestRecord }
	self._oxygen = {} :: { [Player]: OxygenRecord }
	self._clientReady = {} :: { [Player]: boolean }
	self._cooldowns = {} :: { [Player]: { [string]: number } }
	self._busy = {} :: { [Player]: { [string]: boolean } }
	self._random = Random.new()
	self._nextPickupId = 0
	self._nextConveyorId = 0
	self._lastProductionAt = 0
	return self
end

function GameService:_toast(player: Player, kind: string, message: string)
	if self._clientReady[player] then
		Remotes.Toast:FireClient(player, kind, message)
	end
end

function GameService:_getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	return nil
end

function GameService:_isNear(player: Player, instance: Instance, radius: number): boolean
	local root = self:_getRoot(player)
	if not root then return false end
	local point: Vector3?
	if instance:IsA("BasePart") then
		point = instance.Position
	elseif instance:IsA("Model") then
		point = instance:GetPivot().Position
	end
	return point ~= nil and (root.Position - point).Magnitude <= radius
end

function GameService:_nearTag(player: Player, tag: string, radius: number): boolean
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if self._world.Root and instance:IsDescendantOf(self._world.Root) and self:_isNear(player, instance, radius) then
			return true
		end
	end
	return false
end

function GameService:_isOwnerReady(player: Player): boolean
	return self._owner == player and DataService.IsReady(player)
end

function GameService:_getState(player: Player): ClientState
	local data = DataService.Get(player)
	if not data then
		return {
			Ready = false,
			Coins = 0,
			CarriedCoconuts = 0,
			CarryCapacity = EconomyConfig.Coconut.CarryCapacity,
			StoredCoconuts = 0,
			StorageCapacity = 0,
			Oxygen = EconomyConfig.Oxygen.BaseSeconds,
			OxygenMaximum = EconomyConfig.Oxygen.BaseSeconds,
			Underwater = false,
			OxygenUpgradeLevel = 0,
			ShelterLevel = 0,
			CoconutPalmPurchased = false,
			TravelatorPurchased = false,
			PurchasedTiles = {},
			RebirthCount = 0,
			RebirthMultiplier = 1,
			RebirthReady = false,
			Tutorial = {
				PalmBought = false,
				Collected = false,
				Sold = false,
				TravelatorBought = false,
				TreasureFound = false,
				Expanded = false,
			},
		}
	end
	local oxygen = self._oxygen[player]
	local maximum = EconomyConfig.GetOxygenSeconds(data.OxygenUpgradeLevel)
	local purchasedCount = countTable(data.PurchasedTiles)
	return {
		Ready = true,
		Coins = data.Coins,
		CarriedCoconuts = data.CarriedCoconuts,
		CarryCapacity = EconomyConfig.Coconut.CarryCapacity,
		StoredCoconuts = data.StoredCoconuts,
		StorageCapacity = EconomyConfig.StorageCapacityByShelter[data.ShelterLevel] or 0,
		Oxygen = if oxygen then oxygen.Value else maximum,
		OxygenMaximum = maximum,
		Underwater = if oxygen then oxygen.Underwater else false,
		OxygenUpgradeLevel = data.OxygenUpgradeLevel,
		ShelterLevel = data.ShelterLevel,
		CoconutPalmPurchased = data.CoconutPalmPurchased,
		TravelatorPurchased = data.TravelatorPurchased,
		PurchasedTiles = data.PurchasedTiles,
		RebirthCount = data.RebirthCount,
		RebirthMultiplier = data.RebirthMultiplier,
		RebirthReady = data.ShelterLevel >= 3 and purchasedCount >= self._world:GetExpansionTileCount(),
		Tutorial = data.Tutorial,
	}
end

function GameService:_pushState(player: Player)
	if self._clientReady[player] and self:_isOwnerReady(player) then
		Remotes.StateChanged:FireClient(player, self:_getState(player) :: any)
	end
end

function GameService:_moveToRespawn(player: Player)
	local data = DataService.Get(player)
	if not data then return end
	local target = self._world.SpawnCFrames[data.ShelterLevel] or self._world.SpawnCFrames[0]
	if not target then return end
	local root = self:_getRoot(player)
	if root then root.CFrame = target end
end

function GameService:_onCharacter(player: Player)
	task.defer(function()
		if not self:_isOwnerReady(player) then return end
		local character = player.Character
		if not character then return end
		local root = character:WaitForChild("HumanoidRootPart", 8)
		if root and root:IsA("BasePart") then self:_moveToRespawn(player) end
	end)
end

function GameService:_setupPlayer(player: Player)
	self._trove:Connect(player.CharacterAdded, function()
		self:_onCharacter(player)
	end)
	if player.Character then self:_onCharacter(player) end
end

function GameService:_resetWorld(data: PlayerData)
	self._pickups = {}
	self._conveyor = {}
	self._chests = {}
	self._world:Build(data)
	self._lastProductionAt = os.clock()
	for index = 1, EconomyConfig.Treasure.ChestCount do
		self._chests[string.format("Chest_%d", index)] = { Instance = nil, NextSpawnAt = os.clock() + 1 + index * 0.15 }
	end
end

function GameService:_canUseAction(player: Player, action: string): boolean
	if not self:_isOwnerReady(player) then return false end
	local cooldownGroup = if action == "CollectCoconut" then "Collect"
		elseif action == "ClaimTreasure" then "Chest"
		elseif action == "SellCoconuts" then "Sell"
		elseif action == "MoveCoconuts" then "Storage"
		elseif action == "RequestRebirth" then "Rebirth"
		else "Purchase"
	local cooldown = EconomyConfig.ActionCooldowns[cooldownGroup] or 0.35
	local now = os.clock()
	self._cooldowns[player] = self._cooldowns[player] or {}
	if now - (self._cooldowns[player][action] or 0) < cooldown then return false end
	self._cooldowns[player][action] = now
	self._busy[player] = self._busy[player] or {}
	if self._busy[player][action] then return false end
	self._busy[player][action] = true
	return true
end

function GameService:_finishAction(player: Player, action: string)
	if self._busy[player] then self._busy[player][action] = nil end
end

function GameService:_spend(player: Player, price: number): boolean
	local data = DataService.Get(player)
	if not data or not EconomyService.CanAfford(data.Coins, price) then return false end
	return DataService.Mutate(player, function(profile)
		if profile.Coins >= price then profile.Coins -= price end
	end)
end

function GameService:_buyPalm(player: Player)
	local data = DataService.Get(player)
	if not data or data.CoconutPalmPurchased then return end
	if not self:_nearTag(player, "PlantSlot", 13) then return end
	if not self:_spend(player, ShopService.GetPalmCost()) then
		self:_toast(player, "Warning", "You need more Coins for the first palm.")
		return
	end
	DataService.Mutate(player, function(profile)
		profile.CoconutPalmPurchased = true
		profile.Tutorial.PalmBought = true
	end)
	self._world:RefreshProgress(DataService.Get(player) :: PlayerData)
	self:_toast(player, "Success", "Your coconut palm is planted! Fresh coconuts will appear soon.")
end

function GameService:_buyTravelator(player: Player)
	local data = DataService.Get(player)
	if not data or data.TravelatorPurchased then return end
	if not data.CoconutPalmPurchased or not self:_nearTag(player, "TravelatorBuildSite", 14) then return end
	if not self:_spend(player, ShopService.GetTravelatorCost()) then
		self:_toast(player, "Warning", "You need more Coins for the travelator.")
		return
	end
	DataService.Mutate(player, function(profile)
		profile.TravelatorPurchased = true
		profile.Tutorial.TravelatorBought = true
	end)
	self._world:RefreshProgress(DataService.Get(player) :: PlayerData)
	self:_toast(player, "Success", "Travelator online! New coconuts now sell automatically.")
end

function GameService:_upgradeShelter(player: Player)
	local data = DataService.Get(player)
	if not data or data.ShelterLevel >= 3 or not self:_nearTag(player, "ShelterBuildSite", 14) then return end
	local nextLevel = data.ShelterLevel + 1
	local definition = ShopService.GetShelterStage(nextLevel)
	if not definition or not self:_spend(player, definition.Cost) then
		self:_toast(player, "Warning", "You need more Coins for this shelter stage.")
		return
	end
	DataService.Mutate(player, function(profile)
		profile.ShelterLevel = nextLevel
	end)
	self._world:RefreshProgress(DataService.Get(player) :: PlayerData)
	self:_moveToRespawn(player)
	self:_toast(player, "Success", definition.Name .. " built! Your protected respawn and storage improved.")
end

function GameService:_upgradeOxygen(player: Player)
	local data = DataService.Get(player)
	if not data or not self:_nearTag(player, "OxygenTank", 12) then return end
	local nextLevel = data.OxygenUpgradeLevel + 1
	local definition = ShopService.GetOxygenUpgrade(nextLevel)
	if not definition then
		self:_toast(player, "Info", "Your oxygen tank is already maxed.")
		return
	end
	if not self:_spend(player, definition.Cost) then
		self:_toast(player, "Warning", "You need more Coins for this tank.")
		return
	end
	DataService.Mutate(player, function(profile)
		profile.OxygenUpgradeLevel = nextLevel
	end)
	local oxygen = self._oxygen[player]
	if oxygen then oxygen.Value = definition.Seconds end
	self._world:RefreshProgress(DataService.Get(player) :: PlayerData)
	self:_toast(player, "Success", definition.Name .. ": " .. tostring(definition.Seconds) .. " seconds of oxygen.")
end

function GameService:_isTileAdjacent(data: PlayerData, tileId: string): boolean
	local target = EconomyConfig.Expansion.Tiles[tileId]
	if not target then return false end
	if math.abs(target.X) + math.abs(target.Z) == 1 then return true end
	for ownedId in pairs(data.PurchasedTiles) do
		local owned = EconomyConfig.Expansion.Tiles[ownedId]
		if owned and math.abs(owned.X - target.X) + math.abs(owned.Z - target.Z) == 1 then return true end
	end
	return false
end

function GameService:_buyTile(player: Player, tileId: string)
	if type(tileId) ~= "string" or #tileId > 12 then return end
	local data = DataService.Get(player)
	local definition = EconomyConfig.Expansion.Tiles[tileId]
	if not data or not definition or data.PurchasedTiles[tileId] then return end
	local approximatePosition = PlotService.GetTilePosition(tileId)
	local root = self:_getRoot(player)
	if not root or not approximatePosition or (root.Position - approximatePosition).Magnitude > 19 then return end
	if not self:_isTileAdjacent(data, tileId) then
		self:_toast(player, "Warning", "Expand from a connected island tile.")
		return
	end
	local cost = EconomyService.GetExpansionCost(countTable(data.PurchasedTiles))
	if not self:_spend(player, cost) then
		self:_toast(player, "Warning", "You need $" .. tostring(cost) .. " Coins for this tile.")
		return
	end
	local biome = EconomyConfig.Expansion.BiomeIds[self._random:NextInteger(1, #EconomyConfig.Expansion.BiomeIds)]
	DataService.Mutate(player, function(profile)
		profile.PurchasedTiles[tileId] = biome
		profile.Tutorial.Expanded = true
	end)
	self._world:BuildPurchasedTile(tileId, biome)
	self._world:RefreshProgress(DataService.Get(player) :: PlayerData)
	self:_toast(player, "Biome", biome .. " tile discovered!")
end

function GameService:_collectCoconut(player: Player, pickupId: string)
	if type(pickupId) ~= "string" or #pickupId > 40 then return end
	local record = self._pickups[pickupId]
	local data = DataService.Get(player)
	if not record or not data or not record.Instance.Parent then return end
	if not record.Available then
		self:_toast(player, "Info", "That coconut is still falling.")
		return
	end
	if not self:_isNear(player, record.Instance, 10) then
		self:_toast(player, "Info", "Move closer to collect that coconut.")
		return
	end
	if data.CarriedCoconuts >= EconomyConfig.Coconut.CarryCapacity then
		self:_toast(player, "Warning", "Your hands are full. Sell or store coconuts first.")
		return
	end
	self._pickups[pickupId] = nil
	record.Instance:Destroy()
	DataService.Mutate(player, function(profile)
		profile.CarriedCoconuts += 1
		profile.Tutorial.Collected = true
	end)
end

function GameService:_sellCoconuts(player: Player, mode: string)
	if type(mode) ~= "string" or (mode ~= "All" and mode ~= "Carried" and mode ~= "Stored") then return end
	if not self:_nearTag(player, "SellZone", 14) then return end
	local data = DataService.Get(player)
	if not data then return end
	local amount = if mode == "All" then data.CarriedCoconuts + data.StoredCoconuts
		elseif mode == "Carried" then data.CarriedCoconuts
		else data.StoredCoconuts
	if amount <= 0 then
		self:_toast(player, "Info", "No coconuts ready to sell.")
		return
	end
	local reward = EconomyService.ApplyIncome(amount * EconomyConfig.Coconut.SellValue, data.RebirthMultiplier)
	DataService.Mutate(player, function(profile)
		if mode == "All" or mode == "Carried" then profile.CarriedCoconuts = 0 end
		if mode == "All" or mode == "Stored" then profile.StoredCoconuts = 0 end
		profile.Coins += reward
		profile.Tutorial.Sold = true
	end)
	self:_toast(player, "Coins", "Sold " .. tostring(amount) .. " coconuts for $" .. tostring(reward) .. ".")
end

function GameService:_moveCoconuts(player: Player, mode: string)
	if type(mode) ~= "string" or (mode ~= "Deposit" and mode ~= "Withdraw") then return end
	if not self:_nearTag(player, "CoconutStorage", 12) then return end
	local data = DataService.Get(player)
	if not data then return end
	local capacity = EconomyConfig.StorageCapacityByShelter[data.ShelterLevel] or 0
	if capacity <= 0 then
		self:_toast(player, "Warning", "Build the campfire shelter to unlock storage.")
		return
	end
	if mode == "Deposit" then
		local amount = math.min(data.CarriedCoconuts, capacity - data.StoredCoconuts)
		if amount <= 0 then return end
		DataService.Mutate(player, function(profile)
			profile.CarriedCoconuts -= amount
			profile.StoredCoconuts += amount
		end)
		self:_toast(player, "Info", "Stored " .. tostring(amount) .. " coconuts.")
	else
		local amount = math.min(data.StoredCoconuts, EconomyConfig.Coconut.CarryCapacity - data.CarriedCoconuts)
		if amount <= 0 then return end
		DataService.Mutate(player, function(profile)
			profile.StoredCoconuts -= amount
			profile.CarriedCoconuts += amount
		end)
		self:_toast(player, "Info", "Withdrew " .. tostring(amount) .. " coconuts.")
	end
end

function GameService:_claimChest(player: Player, chestId: string)
	if type(chestId) ~= "string" or #chestId > 32 then return end
	local record = self._chests[chestId]
	local data = DataService.Get(player)
	if not record or not data or not record.Instance or not record.Instance.Parent or not self:_isNear(player, record.Instance, 11) then return end
	local root = self:_getRoot(player)
	if not root or root.Position.Y >= WorldBuilder.WaterSurfaceY - 0.5 then return end
	local reward = EconomyService.ApplyIncome(self._random:NextInteger(EconomyConfig.Treasure.MinimumReward, EconomyConfig.Treasure.MaximumReward), data.RebirthMultiplier)
	record.Instance:Destroy()
	record.Instance = nil
	record.NextSpawnAt = os.clock() + EconomyConfig.Treasure.RespawnSeconds
	DataService.Mutate(player, function(profile)
		profile.Coins += reward
		profile.Tutorial.TreasureFound = true
	end)
	self:_toast(player, "Treasure", "Sunken treasure found: +$" .. tostring(reward) .. " Coins!")
end

function GameService:_rebirth(player: Player)
	local data = DataService.Get(player)
	if not data or not self:_nearTag(player, "RebirthShrine", 13) then return end
	if data.ShelterLevel < 3 or countTable(data.PurchasedTiles) < self._world:GetExpansionTileCount() then
		self:_toast(player, "Warning", "Finish every island tile and the tropical shelter first.")
		return
	end
	DataService.Mutate(player, function(profile)
		local nextCount = profile.RebirthCount + 1
		profile.Coins = EconomyConfig.StartingCoins
		profile.CoconutPalmPurchased = false
		profile.TravelatorPurchased = false
		profile.CarriedCoconuts = 0
		profile.StoredCoconuts = 0
		profile.OxygenUpgradeLevel = 0
		profile.ShelterLevel = 0
		profile.PurchasedTiles = {}
		profile.Tutorial = {
			PalmBought = false,
			Collected = false,
			Sold = false,
			TravelatorBought = false,
			TreasureFound = false,
			Expanded = false,
		}
		profile.RebirthCount = nextCount
		profile.RebirthMultiplier = EconomyConfig.Rebirth.BaseMultiplier + nextCount * EconomyConfig.Rebirth.MultiplierPerRebirth
	end)
	local newData = DataService.Get(player) :: PlayerData
	self._oxygen[player] = {
		Value = EconomyConfig.Oxygen.BaseSeconds,
		LastUpdatedAt = os.clock(),
		Underwater = false,
		LastPushedAt = 0,
	}
	self:_resetWorld(newData)
	self:_moveToRespawn(player)
	self:_toast(player, "Rebirth", "Island reborn! Income efficiency is now x" .. string.format("%.2f", newData.RebirthMultiplier) .. ".")
end

function GameService:_handle(player: Player, action: string, id: string?)
	if type(action) ~= "string" or not self:_canUseAction(player, action) then return end
	local ok, err = pcall(function()
		if action == "BuyCoconutPalm" then
			self:_buyPalm(player)
		elseif action == "BuyTravelator" then
			self:_buyTravelator(player)
		elseif action == "UpgradeShelter" then
			self:_upgradeShelter(player)
		elseif action == "UpgradeOxygen" then
			self:_upgradeOxygen(player)
		elseif action == "BuyExpansionTile" and id then
			self:_buyTile(player, id)
		elseif action == "CollectCoconut" and id then
			self:_collectCoconut(player, id)
		elseif action == "ClaimTreasure" and id then
			self:_claimChest(player, id)
		elseif action == "SellCoconuts" and id then
			self:_sellCoconuts(player, id)
		elseif action == "MoveCoconuts" and id then
			self:_moveCoconuts(player, id)
		elseif action == "RequestRebirth" then
			self:_rebirth(player)
		end
	end)
	self:_finishAction(player, action)
	if not ok then warn("[GrowAnIsland] Rejected action error " .. action .. ": " .. tostring(err)) end
end

function GameService:_spawnProduction()
	local player = self._owner
	if not player then return end
	local data = DataService.Get(player)
	if not data or not data.CoconutPalmPurchased then return end
	if data.TravelatorPurchased then
		self._nextConveyorId += 1
		local id = string.format("Conveyor_%d", self._nextConveyorId)
		local instance = self._world:SpawnCoconut(id, WorldBuilder.TravelStart, true)
		self._conveyor[id] = { Instance = instance, StartedAt = os.clock() }
	else
		if countTable(self._pickups) >= (PlantService.GetHandPickupLimit(EconomyConfig.Coconut.Id) or 8) then return end
		self._nextPickupId += 1
		local id = string.format("Coconut_%d", self._nextPickupId)
		local offset = Vector3.new(self._random:NextNumber(-2.4, 2.4), 0, self._random:NextNumber(-2.4, 2.4))
		local groundPosition = Vector3.new(-13, 2.8, 3) + offset
		local instance = self._world:SpawnCoconut(id, groundPosition + Vector3.new(0, 6.7, 0), false)
		self._pickups[id] = {
			Instance = instance,
			SpawnedAt = os.clock(),
			GroundPosition = groundPosition,
			Available = false,
		}
	end
end

function GameService:_updateProduction(now: number)
	if now - self._lastProductionAt >= (PlantService.GetProductionInterval(EconomyConfig.Coconut.Id) or EconomyConfig.Coconut.ProductionInterval) then
		self._lastProductionAt = now
		self:_spawnProduction()
	end
	local player = self._owner
	for id, pickup in pairs(self._pickups) do
		if not pickup.Instance.Parent then
			self._pickups[id] = nil
		elseif not pickup.Available then
			local dropRatio = math.clamp((now - pickup.SpawnedAt) / 0.8, 0, 1)
			local eased = 1 - (1 - dropRatio) * (1 - dropRatio)
			pickup.Instance.CFrame = CFrame.new(pickup.GroundPosition + Vector3.new(0, (1 - eased) * 6.7, 0))
			if dropRatio >= 1 then
				pickup.Available = true
				self._world:EnableCoconutPickup(pickup.Instance, id)
			end
		end
	end
	for id, record in pairs(self._conveyor) do
		if not record.Instance.Parent then
			self._conveyor[id] = nil
		else
			local ratio = math.clamp((now - record.StartedAt) / EconomyConfig.Coconut.TravelTime, 0, 1)
			local position = WorldBuilder.TravelStart:Lerp(WorldBuilder.TravelEnd, ratio)
			record.Instance.CFrame = CFrame.new(position + Vector3.new(0, math.sin(ratio * math.pi) * 0.5, 0))
			if ratio >= 1 then
				record.Instance:Destroy()
				self._conveyor[id] = nil
				if player then
					local data = DataService.Get(player)
					if data then
						local reward = EconomyService.ApplyIncome(EconomyConfig.Coconut.SellValue, data.RebirthMultiplier)
						DataService.Mutate(player, function(profile)
							profile.Coins += reward
						end)
					end
				end
			end
		end
	end
end

function GameService:_updateChests(now: number)
	for id, record in pairs(self._chests) do
		if not record.Instance and now >= record.NextSpawnAt then
			local index = tonumber(string.match(id, "%d+")) or 1
			local point = CHEST_POINTS[index]
			if point then record.Instance = self._world:SpawnChest(id, point) end
		end
	end
end

function GameService:_updateOxygen(now: number)
	local player = self._owner
	if not player then return end
	local data = DataService.Get(player)
	local root = self:_getRoot(player)
	local record = self._oxygen[player]
	if not data or not root or not record then return end
	local maximum = EconomyConfig.GetOxygenSeconds(data.OxygenUpgradeLevel)
	local horizontal = Vector2.new(root.Position.X, root.Position.Z).Magnitude <= WorldBuilder.OceanRadius
	local underwater = horizontal and root.Position.Y < WorldBuilder.WaterSurfaceY - 0.5
	local delta = math.min(now - record.LastUpdatedAt, 0.25)
	record.LastUpdatedAt = now
	if underwater then
		record.Value = math.max(0, record.Value - delta)
	else
		record.Value = maximum
	end
	local changed = underwater ~= record.Underwater
	record.Underwater = underwater
	if record.Value <= 0 then
		record.Value = maximum
		record.Underwater = false
		player:LoadCharacter()
		self:_toast(player, "Warning", "Out of oxygen — returned safely to your island.")
	elseif changed or (underwater and now - record.LastPushedAt >= 0.2) then
		record.LastPushedAt = now
		self:_pushState(player)
	end
end

function GameService:Start()
	Remotes.GetInitialState.OnServerInvoke = function(player)
		-- The client connects its listeners before invoking this function. Do not
		-- enqueue state events for a client which has failed to finish booting.
		self._clientReady[player] = true
		return self:_getState(player) :: any
	end
	self._trove:Connect(Remotes.BuyCoconutPalm.OnServerEvent, function(player) self:_handle(player, "BuyCoconutPalm") end)
	self._trove:Connect(Remotes.BuyTravelator.OnServerEvent, function(player) self:_handle(player, "BuyTravelator") end)
	self._trove:Connect(Remotes.UpgradeShelter.OnServerEvent, function(player) self:_handle(player, "UpgradeShelter") end)
	self._trove:Connect(Remotes.UpgradeOxygen.OnServerEvent, function(player) self:_handle(player, "UpgradeOxygen") end)
	self._trove:Connect(Remotes.BuyExpansionTile.OnServerEvent, function(player, id) self:_handle(player, "BuyExpansionTile", if type(id) == "string" then id else nil) end)
	self._trove:Connect(Remotes.CollectCoconut.OnServerEvent, function(player, id) self:_handle(player, "CollectCoconut", if type(id) == "string" then id else nil) end)
	self._trove:Connect(Remotes.ClaimTreasure.OnServerEvent, function(player, id) self:_handle(player, "ClaimTreasure", if type(id) == "string" then id else nil) end)
	self._trove:Connect(Remotes.SellCoconuts.OnServerEvent, function(player, id) self:_handle(player, "SellCoconuts", if type(id) == "string" then id else nil) end)
	self._trove:Connect(Remotes.MoveCoconuts.OnServerEvent, function(player, id) self:_handle(player, "MoveCoconuts", if type(id) == "string" then id else nil) end)
	self._trove:Connect(Remotes.RequestRebirth.OnServerEvent, function(player) self:_handle(player, "RequestRebirth") end)
	self._trove:Connect(DataService.Changed, function(player)
		if player == self._owner then self:_pushState(player) end
	end)
	self._trove:Connect(Players.PlayerAdded, function(player)
		if self._owner or #Players:GetPlayers() > GameService.MAX_ACTIVE_PLAYERS then
			player:Kick("Grow an Island is currently a private one-player island. Please try a fresh server.")
			return
		end
		self._owner = player
		task.spawn(function()
			local data = DataService.Load(player)
			if not data then
				if player.Parent == Players then player:Kick("We could not safely start your save session. Please rejoin.") end
				if self._owner == player then self._owner = nil end
				return
			end
			self._oxygen[player] = {
				Value = EconomyConfig.GetOxygenSeconds(data.OxygenUpgradeLevel),
				LastUpdatedAt = os.clock(),
				Underwater = false,
				LastPushedAt = 0,
			}
			self:_resetWorld(data)
			self:_setupPlayer(player)
			self:_pushState(player)
			self:_toast(player, "Welcome", "Welcome to Grow an Island! Start by planting your first coconut palm.")
		end)
	end)
	self._trove:Connect(Players.PlayerRemoving, function(player)
		self._cooldowns[player] = nil
		self._busy[player] = nil
		self._oxygen[player] = nil
		self._clientReady[player] = nil
		DataService.Release(player)
		if self._owner == player then
			self._owner = nil
			self._world:Destroy()
			self._pickups = {}
			self._conveyor = {}
			self._chests = {}
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		if not self._owner then
			self._owner = player
			task.defer(function()
				local data = DataService.Load(player)
				if data then
					self._oxygen[player] = { Value = EconomyConfig.GetOxygenSeconds(data.OxygenUpgradeLevel), LastUpdatedAt = os.clock(), Underwater = false, LastPushedAt = 0 }
					self:_resetWorld(data)
					self:_setupPlayer(player)
					self:_pushState(player)
				end
			end)
		else
			player:Kick("Grow an Island is currently a private one-player island. Please try a fresh server.")
		end
	end
	self._trove:Connect(RunService.Heartbeat, function()
		local now = os.clock()
		self:_updateProduction(now)
		self:_updateChests(now)
		self:_updateOxygen(now)
	end)
end

function GameService:Destroy()
	self._world:Destroy()
	self._trove:Destroy()
end

return GameService
