--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local UI = require(script.Parent.Parent.UI.Controls)
local PreviewCard = require(script.Parent.Parent.UI.PreviewCard)
local PreviewMenu = require(script.Parent.Parent.UI.PreviewMenu)
local useSelection = require(script.Parent.Parent.UI.useSelection)
local usePreviewSelection = require(script.Parent.Parent.UI.usePreviewSelection)
local Types = require(script.Parent.Parent.Shared.Types)
local Pagination = require(script.Parent.Parent.Shared.Pagination)
local e = React.createElement
export type Props = {
	selection: { Instance }?,
	initialBackground: Types.Background?,
	onBackground: ((Types.Background) -> ())?,
}

return function(props: Props): React.ReactElement
	local theme = Studio.useTheme()
	local selected = useSelection(props.selection)
	local selection = usePreviewSelection(selected)
	local page, setPage = React.useState(1)
	local capacity, setCapacity = React.useState(4)
	local options, setOptions = React.useState({
		background = props.initialBackground or "Studio",
		playing = true,
		mirrorLighting = true,
	} :: Types.PreviewOptions)
	local menuOpen, setMenuOpen = React.useState(false)
	local hovered, setHovered = React.useState(false)
	local size, setSize = React.useState(Vector2.new(500, 400))
	local current, pages, first, last = Pagination.Page(#selection, page, capacity)
	local count = math.max(0, last - first + 1)
	local columns, rows = Pagination.Grid(count, size.X, size.Y)
	local gutter = if count > 1 then 2 else 0
	React.useEffect(function()
		setPage(1)
	end, { selection, capacity } :: { unknown })
	local cards: UI.Children = {}
	for index = first, last do
		local offset = index - first
		cards[tostring(index)] = e(PreviewCard, {
			source = selection[index],
			options = options,
			minimal = true,
			size = UDim2.new(1 / columns, -gutter * 2, 1 / rows, -gutter * 2),
			position = UDim2.new((offset % columns) / columns, gutter, math.floor(offset / columns) / rows, gutter),
		})
	end
	if #selection == 0 then
		cards.Empty = e("TextLabel", {
			Size = UDim2.new(1, -32, 1, 0),
			Position = UDim2.fromOffset(16, 0),
			BackgroundTransparency = 1,
			Text = if #selected == 0
				then "Select assets in Explorer to preview them."
				else "This selection has no children to preview.",
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
			Font = Enum.Font.SourceSans,
			TextSize = 16,
			TextWrapped = true,
		})
	end
	return e(Studio.Background, nil, {
		Content = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			[React.Event.MouseEnter] = function()
				setHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setHovered(false)
			end,
		}, {
			Grid = e("Frame", {
				Size = UDim2.new(1, 0, 1, if pages > 1 then -40 else 0),
				BackgroundTransparency = 1,
				[React.Change.AbsoluteSize] = function(frame: Frame)
					setSize(frame.AbsoluteSize)
				end,
			}, cards),
			Pager = if pages > 1
				then e("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, -6),
					Size = UDim2.fromOffset(208, 28),
					BackgroundTransparency = 1,
				}, {
					Controls = e(UI.Pager, { page = current, pages = pages, change = setPage }),
				})
				else nil,
			MenuButton = if hovered and not menuOpen
				then e(Studio.Button, {
					Text = "⋯",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 8),
					Size = UDim2.fromOffset(32, 28),
					ZIndex = 5,
					OnActivated = function()
						setMenuOpen(true)
					end,
				})
				else nil,
			Menu = if menuOpen
				then e(PreviewMenu, {
					options = options,
					capacity = capacity,
					changeCapacity = setCapacity,
					changeOptions = function(updated: Types.PreviewOptions)
						setOptions(updated)
						if updated.background ~= options.background and props.onBackground then
							props.onBackground(updated.background)
						end
					end,
					close = function()
						setMenuOpen(false)
					end,
				})
				else nil,
		}),
	})
end
