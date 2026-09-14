--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local function Button(scope: any, props: { [string]: any }): TextButton
	local enabled = props.Enabled
	local function isEnabled(): boolean
		if type(enabled) == "boolean" then return enabled end
		return Fusion.peek(enabled) == true
	end
	local background = if type(enabled) == "boolean"
		then (if enabled then (props.Color or Color3.fromRGB(54, 156, 124)) else Color3.fromRGB(85, 95, 104))
		else scope:Computed(function(use)
			return if use(enabled) then (props.Color or Color3.fromRGB(54, 156, 124)) else Color3.fromRGB(85, 95, 104)
		end)
	return scope:New("TextButton")({
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(210, 35),
		BackgroundColor3 = background,
		BorderSizePixel = 0,
		AutoButtonColor = type(enabled) == "boolean" and enabled,
		Active = if type(enabled) == "boolean" then enabled else scope:Computed(function(use) return use(enabled) == true end),
		Selectable = if type(enabled) == "boolean" then enabled else scope:Computed(function(use) return use(enabled) == true end),
		Text = props.Text or "Button",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = props.TextSize or 13,
		Font = Enum.Font.GothamBold,
		[scope.OnEvent("Activated")] = function()
			if isEnabled() and props.OnActivated then props.OnActivated() end
		end,
		[scope.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			scope:New("UIStroke")({ Color = Color3.fromRGB(255, 255, 255), Transparency = 0.76, Thickness = 1 }),
		},
	})
end

return Button
