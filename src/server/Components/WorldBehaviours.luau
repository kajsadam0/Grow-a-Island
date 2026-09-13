--!strict

-- Lightweight reusable behaviours for generated, tagged gameplay parts.
-- GameService owns rules/rewards; components only enforce safe server physics defaults.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Component = require(ReplicatedStorage.Packages.Component)

local function serverOwn(instance: Instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
	end
end

local CoconutPickup = Component.new({ Tag = "CoconutPickup", Ancestors = { workspace } })
function CoconutPickup:Construct()
	serverOwn(self.Instance)
end

local Travelator = Component.new({ Tag = "Travelator", Ancestors = { workspace } })
function Travelator:Construct()
	serverOwn(self.Instance)
end

local TreasureChest = Component.new({ Tag = "TreasureChest", Ancestors = { workspace } })
function TreasureChest:Construct()
	serverOwn(self.Instance)
end

local SellZone = Component.new({ Tag = "SellZone", Ancestors = { workspace } })
function SellZone:Construct()
	serverOwn(self.Instance)
end

local DiveZone = Component.new({ Tag = "DiveZone", Ancestors = { workspace } })
function DiveZone:Construct()
	serverOwn(self.Instance)
end

return {
	CoconutPickup = CoconutPickup,
	Travelator = Travelator,
	TreasureChest = TreasureChest,
	SellZone = SellZone,
	DiveZone = DiveZone,
}
