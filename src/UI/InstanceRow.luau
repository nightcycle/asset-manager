--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local Types = require(script.Parent.Parent.Shared.Types)
local e = React.createElement
export type Props = { record: Types.Record, selected: boolean, click: () -> (), order: number }
return function(props: Props): React.ReactElement
	local theme = Studio.useTheme()
	local hovered, setHovered = React.useState(false)
	local modifier = if props.selected
		then Enum.StudioStyleGuideModifier.Selected
		elseif hovered then Enum.StudioStyleGuideModifier.Hover
		else Enum.StudioStyleGuideModifier.Default
	return e(Studio.Background, { Size = UDim2.new(1, 0, 0, 48), LayoutOrder = props.order }, {
		Button = e("TextButton", {
			Size = UDim2.new(1, 0, 0, 48),
			LayoutOrder = props.order,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Item, modifier),
			[React.Event.Activated] = props.click,
			[React.Event.MouseEnter] = function()
				setHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setHovered(false)
			end,
		}, {
			Name = e("TextLabel", {
				Size = UDim2.new(1, -16, 0, 23),
				Position = UDim2.fromOffset(8, 2),
				BackgroundTransparency = 1,
				Text = props.record.name .. "  ·  " .. props.record.className,
				Font = Enum.Font.SourceSansSemibold,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText, modifier),
			}),
			Path = e("TextLabel", {
				Size = UDim2.new(1, -16, 0, 20),
				Position = UDim2.fromOffset(8, 25),
				BackgroundTransparency = 1,
				Text = props.record.fullName,
				Font = Enum.Font.SourceSans,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText, modifier),
			}),
		}),
	})
end
