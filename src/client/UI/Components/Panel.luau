--!strict

local function Panel(scope: any, props: { [string]: any }): Frame
	return scope:New("Frame")({
		Name = props.Name or "Panel",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = props.Color or Color3.fromRGB(20, 48, 63),
		BackgroundTransparency = props.Transparency or 0.12,
		BorderSizePixel = 0,
		[scope.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, props.Radius or 12) }),
			scope:New("UIStroke")({ Color = Color3.fromRGB(204, 242, 237), Transparency = 0.68, Thickness = 1 }),
			props.Children,
		},
	})
end

return Panel
