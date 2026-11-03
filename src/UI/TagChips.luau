--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local Types = require(script.Parent.Parent.Shared.Types)
local UI = require(script.Parent.Controls)
local e = React.createElement
export type Props = { tags: { Types.TagCount }, selected: { string }, toggle: (string) -> (), limit: number? }
return function(props: Props): React.ReactElement
	local theme = Studio.useTheme()
	local children: UI.Children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
	}
	local shown: { Types.TagCount } = {}
	local seen: { [string]: boolean } = {}
	local counts: { [string]: number } = {}
	for _, tag in props.tags do
		counts[tag.name] = tag.count
		if #shown < (props.limit or #props.tags) then
			table.insert(shown, tag)
			seen[tag.name] = true
		end
	end
	for _, name in props.selected do
		if not seen[name] then
			table.insert(shown, { name = name, count = counts[name] or 0 })
		end
	end
	for index, tag in shown do
		local selected = table.find(props.selected, tag.name) ~= nil
		local modifier = if selected
			then Enum.StudioStyleGuideModifier.Selected
			else Enum.StudioStyleGuideModifier.Default
		children["Tag_" .. tag.name] = e("TextButton", {
			Text = (if selected then "✓ " else "") .. tag.name .. ` · {tag.count}`,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28),
			LayoutOrder = index,
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Button, modifier),
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.ButtonText, modifier),
			BorderSizePixel = 0,
			Font = Enum.Font.SourceSans,
			TextSize = 14,
			[React.Event.Activated] = function()
				props.toggle(tag.name)
			end,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Padding = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
		})
	end
	if #shown == 0 then
		children.Empty = e(UI.Text, { text = "No tags in this scope", muted = true })
	end
	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar),
	}, children)
end
