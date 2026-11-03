--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local e = React.createElement
local Controls = {}
export type Children = { [string]: React.ReactNode }

function Controls.Text(
	props: { text: string, height: number?, muted: boolean?, order: number?, wrapped: boolean? }
): React.ReactElement
	local theme = Studio.useTheme()
	return e("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, props.height or 24),
		LayoutOrder = props.order,
		Text = props.text,
		TextColor3 = theme:GetColor(
			Enum.StudioStyleGuideColor.MainText,
			if props.muted then Enum.StudioStyleGuideModifier.Disabled else Enum.StudioStyleGuideModifier.Default
		),
		Font = Enum.Font.SourceSans,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = props.wrapped or false,
		TextTruncate = if props.wrapped then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
	})
end
function Controls.Button(props: {
	text: string,
	click: () -> (),
	width: number?,
	order: number?,
	disabled: boolean?,
	primary: boolean?,
}): React.ReactElement
	return e(if props.primary then Studio.MainButton else Studio.Button, {
		Text = props.text,
		OnActivated = props.click,
		Disabled = props.disabled,
		Size = UDim2.new(if props.width then 0 else 1, props.width or 0, 0, 28),
		LayoutOrder = props.order,
	})
end
function Controls.Input(
	props: { text: string, change: (string) -> (), placeholder: string?, order: number? }
): React.ReactElement
	return e(Studio.TextInput, {
		Text = props.text,
		OnChanged = props.change,
		PlaceholderText = props.placeholder,
		ClearTextOnFocus = false,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = props.order,
	})
end
function Controls.Row(props: { children: React.ReactNode, order: number?, height: number? }): React.ReactElement
	return e(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, props.height or 28), LayoutOrder = props.order },
		{
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			Children = e(React.Fragment, nil, props.children),
		}
	)
end
function Controls.Column(props: { children: React.ReactNode, order: number? }): React.ReactElement
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.order,
	}, {
		Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }),
		Children = e(React.Fragment, nil, props.children),
	})
end
function Controls.Scroll(props: { children: React.ReactNode }): React.ReactElement
	local theme = Studio.useTheme()
	return e("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderSizePixel = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = theme:GetColor(Enum.StudioStyleGuideColor.ScrollBar),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 10),
		}),
		Layout = e("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		Children = e(React.Fragment, nil, props.children),
	})
end
function Controls.Pager(props: { page: number, pages: number, change: (number) -> () }): React.ReactElement
	return e(Controls.Row, nil, {
		Previous = e(Controls.Button, {
			text = "‹",
			width = 38,
			order = 1,
			disabled = props.page <= 1,
			click = function()
				props.change(props.page - 1)
			end,
		}),
		Count = e("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(120, 28), LayoutOrder = 2 }, {
			Label = e(Controls.Text, { text = `Page {props.page} / {props.pages}` }),
		}),
		Next = e(Controls.Button, {
			text = "›",
			width = 38,
			order = 3,
			disabled = props.page >= props.pages,
			click = function()
				props.change(props.page + 1)
			end,
		}),
	})
end
return Controls
