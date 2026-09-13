--!strict

local Players = game:GetService("Players")

local App = require(script.Parent.UI.App)
local InteractionController = require(script.Parent.Controllers.InteractionController)
require(script.Parent.Controllers.PlacementController)
require(script.Parent.Controllers.VFXController)
require(script.Parent.Controllers.WeatherController)

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local controller: any
local app = App.new(playerGui, function(action, id)
	controller:Send(action, id)
end)
controller = InteractionController.new(app)
