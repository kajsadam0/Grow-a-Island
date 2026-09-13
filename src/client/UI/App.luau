--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Button = require(script.Components.Button)
local Panel = require(script.Components.Panel)

local App = {}

local initialState = {
	Ready = false,
	Coins = 0,
	CarriedCoconuts = 0,
	CarryCapacity = 6,
	StoredCoconuts = 0,
	StorageCapacity = 0,
	Oxygen = 10,
	OxygenMaximum = 10,
	Underwater = false,
	OxygenUpgradeLevel = 0,
	ShelterLevel = 0,
	CoconutPalmPurchased = false,
	TravelatorPurchased = false,
	PurchasedTiles = {},
	RebirthCount = 0,
	RebirthMultiplier = 1,
	RebirthReady = false,
	Tutorial = {},
}

local function taskLine(done: boolean, text: string): string
	return (if done then "✓ " else "○ ") .. text
end

function App.new(playerGui: PlayerGui, send: (string, string?) -> ())
	local scope = Fusion.scoped(Fusion)
	local state = scope:Value(initialState)
	local toast = scope:Value({ Kind = "", Text = "", Visible = false })
	local celebration = scope:Value(false)

	local coinText = scope:Computed(function(use)
		local value = use(state)
		return "$" .. tostring(value.Coins) .. "  COINS"
	end)
	local inventoryText = scope:Computed(function(use)
		local value = use(state)
		return "Hands  " .. tostring(value.CarriedCoconuts) .. "/" .. tostring(value.CarryCapacity)
			.. "     Storage  " .. tostring(value.StoredCoconuts) .. "/" .. tostring(value.StorageCapacity)
	end)
	local oxygenText = scope:Computed(function(use)
		local value = use(state)
		if not value.Underwater then return "Oxygen  surface air" end
		return "Oxygen  " .. string.format("%.1f", value.Oxygen) .. "s / " .. tostring(value.OxygenMaximum) .. "s"
	end)
	local oxygenColor = scope:Computed(function(use)
		local value = use(state)
		if not value.Underwater then return Color3.fromRGB(129, 220, 224) end
		if value.Oxygen <= 3 then return Color3.fromRGB(255, 116, 98) end
		return Color3.fromRGB(105, 211, 255)
	end)
	local rebirthText = scope:Computed(function(use)
		local value = use(state)
		return "REBIRTH " .. tostring(value.RebirthCount) .. "   x" .. string.format("%.2f", value.RebirthMultiplier) .. " income"
	end)
	local tutorialText = scope:Computed(function(use)
		local value = use(state)
		local guide = value.Tutorial
		return table.concat({
			taskLine(guide.PalmBought == true, "Buy a coconut palm"),
			taskLine(guide.Collected == true, "Collect coconuts"),
			taskLine(guide.Sold == true, "Sell coconuts"),
			taskLine(guide.TravelatorBought == true, "Buy the travelator"),
			taskLine(guide.TreasureFound == true, "Find ocean treasure"),
			taskLine(guide.Expanded == true, "Expand the island"),
		}, "\n")
	end)
	local progressText = scope:Computed(function(use)
		local value = use(state)
		local owned = 0
		for _ in pairs(value.PurchasedTiles) do owned += 1 end
		return "Island tiles " .. tostring(owned) .. "/24  •  Shelter " .. tostring(value.ShelterLevel) .. "/3"
	end)
	local readyText = scope:Computed(function(use)
		return if use(state).Ready then "" else "Loading your protected island save…"
	end)
	local palmEnabled = scope:Computed(function(use) return not use(state).CoconutPalmPurchased end)
	local travelatorEnabled = scope:Computed(function(use)
		local value = use(state)
		return value.CoconutPalmPurchased and not value.TravelatorPurchased
	end)
	local shelterEnabled = scope:Computed(function(use) return use(state).ShelterLevel < 3 end)
	local oxygenEnabled = scope:Computed(function(use) return use(state).OxygenUpgradeLevel < 3 end)

	local gui = scope:New("ScreenGui")({
		Name = "GrowAnIslandUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
		[scope.Children] = {
			Panel(scope, {
				Name = "Hud",
				Size = UDim2.fromOffset(345, 104),
				Position = UDim2.fromOffset(18, 18),
				Children = {
					scope:New("TextLabel")({
						Size = UDim2.new(1, -22, 0, 26),
						Position = UDim2.fromOffset(11, 8),
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamBlack,
						Text = coinText,
						TextColor3 = Color3.fromRGB(255, 229, 119),
						TextSize = 20,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						Size = UDim2.new(1, -22, 0, 21),
						Position = UDim2.fromOffset(11, 38),
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamMedium,
						Text = inventoryText,
						TextColor3 = Color3.fromRGB(235, 250, 245),
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						Size = UDim2.new(1, -22, 0, 23),
						Position = UDim2.fromOffset(11, 66),
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamBold,
						Text = oxygenText,
						TextColor3 = oxygenColor,
						TextSize = 14,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
			Panel(scope, {
				Name = "Guide",
				Size = UDim2.fromOffset(270, 190),
				Position = UDim2.new(1, -18, 0, 18),
				AnchorPoint = Vector2.new(1, 0),
				Children = {
					scope:New("TextLabel")({
						Size = UDim2.new(1, -20, 0, 25),
						Position = UDim2.fromOffset(10, 10),
						BackgroundTransparency = 1,
						Text = "ISLAND TASK GUIDE",
						TextColor3 = Color3.fromRGB(255, 229, 119),
						Font = Enum.Font.GothamBold,
						TextSize = 15,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						Size = UDim2.new(1, -20, 1, -44),
						Position = UDim2.fromOffset(10, 37),
						BackgroundTransparency = 1,
						Text = tutorialText,
						TextColor3 = Color3.fromRGB(233, 248, 243),
						Font = Enum.Font.GothamMedium,
						TextSize = 13,
						LineHeight = 1.48,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
					}),
				},
			}),
			Panel(scope, {
				Name = "BuildMenu",
				Size = UDim2.fromOffset(300, 330),
				Position = UDim2.new(0, 18, 1, -18),
				AnchorPoint = Vector2.new(0, 1),
				Children = {
					scope:New("TextLabel")({
						Size = UDim2.new(1, -20, 0, 25),
						Position = UDim2.fromOffset(10, 9),
						BackgroundTransparency = 1,
						Text = "BUILD & UPGRADES",
						TextColor3 = Color3.fromRGB(255, 229, 119),
						Font = Enum.Font.GothamBold,
						TextSize = 15,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						Size = UDim2.new(1, -20, 0, 19),
						Position = UDim2.fromOffset(10, 34),
						BackgroundTransparency = 1,
						Text = "Stand at the matching marked site, then use E or a button.",
						TextColor3 = Color3.fromRGB(174, 219, 219),
						Font = Enum.Font.Gotham,
						TextSize = 11,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("TextLabel")({
						Size = UDim2.new(1, -20, 0, 15),
						Position = UDim2.fromOffset(10, 51),
						BackgroundTransparency = 1,
						Text = "Shelter $900 / $2300 / $5200  |  Air $450 / $1300 / $3100",
						TextColor3 = Color3.fromRGB(255, 218, 145),
						Font = Enum.Font.Gotham,
						TextSize = 10,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					scope:New("Frame")({
						Name = "Buttons",
						Size = UDim2.new(1, -20, 1, -77),
						Position = UDim2.fromOffset(10, 70),
						BackgroundTransparency = 1,
						[scope.Children] = {
							scope:New("UIListLayout")({
								Padding = UDim.new(0, 7),
								HorizontalAlignment = Enum.HorizontalAlignment.Center,
							}),
							Button(scope, { Text = "Plant coconut palm  •  $25", Enabled = palmEnabled, OnActivated = function() send("BuyCoconutPalm") end }),
							Button(scope, { Text = "Build travelator  •  $800", Enabled = travelatorEnabled, Color = Color3.fromRGB(69, 132, 165), OnActivated = function() send("BuyTravelator") end }),
							Button(scope, { Text = "Improve shelter  •  staged costs", Enabled = shelterEnabled, Color = Color3.fromRGB(181, 119, 76), OnActivated = function() send("UpgradeShelter") end }),
							Button(scope, { Text = "Upgrade oxygen tank  •  10s base", Enabled = oxygenEnabled, Color = Color3.fromRGB(58, 148, 178), OnActivated = function() send("UpgradeOxygen") end }),
							Button(scope, { Text = "Sell carried coconuts", Enabled = true, Color = Color3.fromRGB(53, 161, 123), OnActivated = function() send("SellCoconuts", "Carried") end }),
							Button(scope, { Text = "Withdraw stored coconuts", Enabled = true, Color = Color3.fromRGB(93, 139, 179), OnActivated = function() send("MoveCoconuts", "Withdraw") end }),
						},
					}),
				},
			}),
			Panel(scope, {
				Name = "Progress",
				Size = UDim2.fromOffset(390, 67),
				Position = UDim2.new(0.5, 0, 1, -18),
				AnchorPoint = Vector2.new(0.5, 1),
				Children = {
					scope:New("TextLabel")({
						Size = UDim2.new(1, -20, 0, 23),
						Position = UDim2.fromOffset(10, 8),
						BackgroundTransparency = 1,
						Text = progressText,
						TextColor3 = Color3.fromRGB(231, 248, 244),
						Font = Enum.Font.GothamBold,
						TextSize = 14,
					}),
					scope:New("TextLabel")({
						Size = UDim2.new(1, -20, 0, 21),
						Position = UDim2.fromOffset(10, 34),
						BackgroundTransparency = 1,
						Text = rebirthText,
						TextColor3 = Color3.fromRGB(255, 223, 102),
						Font = Enum.Font.GothamBold,
						TextSize = 13,
					}),
				},
			}),
			scope:New("TextLabel")({
				Name = "Toast",
				Size = UDim2.fromOffset(470, 48),
				Position = UDim2.new(0.5, 0, 0, 138),
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(23, 57, 68),
				BackgroundTransparency = scope:Computed(function(use) return if use(toast).Visible then 0.08 else 1 end),
				BorderSizePixel = 0,
				Visible = scope:Computed(function(use) return use(toast).Visible end),
				Text = scope:Computed(function(use) return use(toast).Text end),
				TextColor3 = Color3.fromRGB(255, 246, 203),
				Font = Enum.Font.GothamBold,
				TextSize = 16,
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
					scope:New("UIStroke")({ Color = Color3.fromRGB(255, 219, 110), Transparency = 0.4 }),
				},
			}),
			scope:New("TextLabel")({
				Name = "Loading",
				Size = UDim2.fromOffset(450, 45),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = readyText,
				TextColor3 = Color3.fromRGB(255, 245, 204),
				Font = Enum.Font.GothamBold,
				TextSize = 19,
			}),
			scope:New("TextLabel")({
				Name = "Celebration",
				Size = UDim2.fromScale(1, 0.14),
				Position = UDim2.fromScale(0, 0.37),
				BackgroundTransparency = 1,
				Visible = celebration,
				Text = "✦  ISLAND REBORN  ✦",
				TextColor3 = Color3.fromRGB(255, 227, 100),
				TextStrokeTransparency = 0.35,
				Font = Enum.Font.GothamBlack,
				TextScaled = true,
			}),
		},
	})

	local app = {}
	function app:SetState(newState: { [string]: any })
		if type(newState) == "table" then state:set(newState) end
	end
	function app:Toast(kind: string, text: string)
		toast:set({ Kind = kind, Text = text, Visible = true })
		if kind == "Rebirth" then
			celebration:set(true)
			task.delay(3, function() celebration:set(false) end)
		end
		task.delay(4, function()
			local current = Fusion.peek(toast)
			if current.Text == text then toast:set({ Kind = "", Text = "", Visible = false }) end
		end)
	end
	function app:Destroy()
		Fusion.doCleanup(scope)
	end
	return app
end

return App
