--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeatherService = require(script.Parent.Services.WeatherService)
local MonetizationService = require(script.Parent.Services.MonetizationService)
local GameService = require(script.Parent.Services.GameService)

-- Start reusable CollectionService components before generated tagged parts exist.
require(script.Parent.Components.WorldBehaviours)

WeatherService.Start()
MonetizationService.Start()

local gameService = GameService.new()
gameService:Start()

game:BindToClose(function()
	gameService:Destroy()
	require(script.Parent.Services.DataService).ReleaseAll()
	if #Players:GetPlayers() > 0 then task.wait(2) end
end)

ReplicatedStorage:SetAttribute("GrowAnIslandBooted", true)
