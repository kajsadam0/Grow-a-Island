--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local InteractionController = {}
InteractionController.__index = InteractionController

function InteractionController.new(app: any)
	local self = setmetatable({}, InteractionController)
	self._app = app
	Remotes.StateChanged.OnClientEvent:Connect(function(state)
		if type(state) == "table" then app:SetState(state) end
	end)
	Remotes.Toast.OnClientEvent:Connect(function(kind, text)
		if type(kind) == "string" and type(text) == "string" then app:Toast(kind, text) end
	end)
	task.spawn(function()
		local state = Remotes.GetInitialState:InvokeServer()
		if type(state) == "table" then app:SetState(state) end
	end)
	return self
end

function InteractionController:Send(action: string, id: string?)
	if action == "BuyCoconutPalm" then Remotes.BuyCoconutPalm:FireServer()
	elseif action == "BuyTravelator" then Remotes.BuyTravelator:FireServer()
	elseif action == "UpgradeShelter" then Remotes.UpgradeShelter:FireServer()
	elseif action == "UpgradeOxygen" then Remotes.UpgradeOxygen:FireServer()
	elseif action == "BuyExpansionTile" and type(id) == "string" then Remotes.BuyExpansionTile:FireServer(id)
	elseif action == "CollectCoconut" and type(id) == "string" then Remotes.CollectCoconut:FireServer(id)
	elseif action == "ClaimTreasure" and type(id) == "string" then Remotes.ClaimTreasure:FireServer(id)
	elseif action == "SellCoconuts" and type(id) == "string" then Remotes.SellCoconuts:FireServer(id)
	elseif action == "MoveCoconuts" and type(id) == "string" then Remotes.MoveCoconuts:FireServer(id)
	elseif action == "RequestRebirth" then Remotes.RequestRebirth:FireServer()
	end
end

return InteractionController
