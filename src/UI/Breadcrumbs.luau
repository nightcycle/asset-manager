--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local Navigation = require(script.Parent.Parent.Organizer.Navigation)
local UI = require(script.Parent.Controls)
local e = React.createElement
export type Props = { path: string, navigate: (string) -> () }
return function(props: Props): React.ReactElement
	local children: UI.Children = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
	}
	for index, crumb in Navigation.Breadcrumbs(props.path) do
		children[crumb.path] = e(Studio.Button, {
			Text = crumb.name,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28),
			LayoutOrder = index,
			Disabled = crumb.path == props.path,
			OnActivated = function()
				props.navigate(crumb.path)
			end,
		})
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Scroll = e("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = 2,
			[React.Change.AbsoluteCanvasSize] = function(scroll: ScrollingFrame)
				scroll.CanvasPosition = Vector2.new(math.max(0, scroll.AbsoluteCanvasSize.X - scroll.AbsoluteSize.X), 0)
			end,
		}, children),
	})
end
