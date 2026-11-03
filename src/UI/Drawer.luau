--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local UI = require(script.Parent.Controls)
local Icons = require(script.Parent.Icons)
local e = React.createElement
local PANEL_WIDTH = 380
local OUTSIDE_GAP = 12
export type Props = { title: string, close: () -> (), children: React.ReactNode }
return function(props: Props): React.ReactElement
	local theme = Studio.useTheme()
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		-- Sink input across the whole widget while the drawer is open.
		Active = true,
		ZIndex = 20,
	}, {
		Scrim = e("TextButton", {
			-- Only the exposed area dismisses the drawer; never overlap its controls.
			Size = UDim2.new(1, -PANEL_WIDTH, 1, 0),
			Text = "",
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.5,
			Active = true,
			AutoButtonColor = false,
			BorderSizePixel = 0,
			[React.Event.Activated] = props.close,
		}, {
			Limit = e("UISizeConstraint", { MinSize = Vector2.new(OUTSIDE_GAP, 0) }),
		}),
		Panel = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(1, -OUTSIDE_GAP, 1, 0),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			Active = true,
			ZIndex = 2,
		}, {
			Limit = e("UISizeConstraint", { MaxSize = Vector2.new(PANEL_WIDTH, 100000) }),
			Title = e(
				"Frame",
				{ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -64, 0, 28), BackgroundTransparency = 1 },
				{
					Text = e(UI.Text, { text = props.title }),
				}
			),
			Close = e(Icons.Button, {
				name = "close",
				position = UDim2.new(1, -40, 0, 8),
				size = UDim2.fromOffset(28, 28),
				click = props.close,
			}),
			Content = e(
				"Frame",
				{ Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), BackgroundTransparency = 1 },
				{
					Scroll = e(UI.Scroll, nil, props.children),
				}
			),
		}),
	})
end
