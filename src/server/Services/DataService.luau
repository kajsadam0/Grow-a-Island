--!strict

-- DataService is deliberately the only module that imports ProfileStore.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local ProfileTypes = require(ReplicatedStorage.Shared.Types.ProfileTypes)

type PlayerData = ProfileTypes.PlayerData

local SCHEMA_VERSION = 1
local template: PlayerData = {
	SchemaVersion = SCHEMA_VERSION,
	Coins = 25,
	CoconutPalmPurchased = false,
	TravelatorPurchased = false,
	CarriedCoconuts = 0,
	StoredCoconuts = 0,
	OxygenUpgradeLevel = 0,
	ShelterLevel = 0,
	PurchasedTiles = {},
	Tutorial = {
		PalmBought = false,
		Collected = false,
		Sold = false,
		TravelatorBought = false,
		TreasureFound = false,
		Expanded = false,
	},
	RebirthCount = 0,
	RebirthMultiplier = 1,
}

local store = ProfileStore.New("GrowAnIsland_PlayerData_v1", template)
if RunService:IsStudio() then
	-- Studio uses a session-owning mock profile, so testing never creates live data.
	store = store.Mock
end

local DataService = {}
local profiles: { [Player]: any } = {}
local changed = Instance.new("BindableEvent")
changed.Name = "DataChanged"
DataService.Changed = changed.Event

local function isNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function repairData(data: any)
	-- Reconcile adds new fields; these checks make corrupted values safe before gameplay.
	if type(data) ~= "table" then
		return
	end
	data.SchemaVersion = SCHEMA_VERSION
	for _, key in ipairs({ "Coins", "CarriedCoconuts", "StoredCoconuts", "OxygenUpgradeLevel", "ShelterLevel", "RebirthCount", "RebirthMultiplier" }) do
		if not isNumber(data[key]) then
			data[key] = (template :: any)[key]
		end
	end
	data.Coins = math.max(0, math.floor(data.Coins))
	data.CarriedCoconuts = math.max(0, math.floor(data.CarriedCoconuts))
	data.StoredCoconuts = math.max(0, math.floor(data.StoredCoconuts))
	data.OxygenUpgradeLevel = math.max(0, math.floor(data.OxygenUpgradeLevel))
	data.ShelterLevel = math.clamp(math.floor(data.ShelterLevel), 0, 3)
	data.RebirthCount = math.max(0, math.floor(data.RebirthCount))
	data.RebirthMultiplier = math.max(1, data.RebirthMultiplier)
	if type(data.CoconutPalmPurchased) ~= "boolean" then data.CoconutPalmPurchased = false end
	if type(data.TravelatorPurchased) ~= "boolean" then data.TravelatorPurchased = false end
	if type(data.PurchasedTiles) ~= "table" then data.PurchasedTiles = {} end
	if type(data.Tutorial) ~= "table" then data.Tutorial = {} end
	for key, default in pairs(template.Tutorial) do
		if type(data.Tutorial[key]) ~= "boolean" then
			data.Tutorial[key] = default
		end
	end
end

function DataService.Load(player: Player): PlayerData?
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		return nil
	end
	profile:Reconcile()
	repairData(profile.Data)
	if player.Parent ~= Players then
		profile:EndSession()
		return nil
	end
	profiles[player] = profile
	profile.OnSessionEnd:Connect(function()
		if profiles[player] == profile then
			profiles[player] = nil
			if player.Parent == Players then
				player:Kick("Your save session ended. Please rejoin safely.")
			end
		end
	end)
	changed:Fire(player)
	return profile.Data :: PlayerData
end

function DataService.IsReady(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile:IsActive()
end

function DataService.Get(player: Player): PlayerData?
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return nil
	end
	return profile.Data :: PlayerData
end

function DataService.Mutate(player: Player, mutator: (PlayerData) -> ()): boolean
	local data = DataService.Get(player)
	if not data then
		return false
	end
	mutator(data)
	changed:Fire(player)
	return true
end

function DataService.Release(player: Player)
	local profile = profiles[player]
	profiles[player] = nil
	if profile and profile:IsActive() then
		profile:EndSession()
	end
end

function DataService.ReleaseAll()
	for player in pairs(profiles) do
		DataService.Release(player)
	end
end

return DataService
