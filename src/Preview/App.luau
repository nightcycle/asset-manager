--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local UI = require(script.Parent.Parent.UI.Controls)
local PreviewCard = require(script.Parent.Parent.UI.PreviewCard)
local PreviewMenu = require(script.Parent.Parent.UI.PreviewMenu)
local Icons = require(script.Parent.Parent.UI.Icons)
local useSelection = require(script.Parent.Parent.UI.useSelection)
local usePreviewSelection = require(script.Parent.Parent.UI.usePreviewSelection)
local Types = require(script.Parent.Parent.Shared.Types)
local Pagination = require(script.Parent.Parent.Shared.Pagination)
local Settings = require(script.Parent.Parent.Shared.ViewSettings)
local Playback = require(script.Parent.Playback)
local e = React.createElement
export type Props = {
	selection: { Instance }?,
	initialBackground: Types.Background?,
	onBackground: ((Types.Background) -> ())?,
	initialScaleMode: Types.ScaleMode?,
	onScaleMode: ((Types.ScaleMode) -> ())?,
	initialSettings: Settings.Settings?,
	onSettings: ((Settings.Settings) -> ())?,
}

return function(props: Props): React.ReactElement
	local theme = Studio.useTheme()
	local selected = useSelection(props.selection)
	local selection = usePreviewSelection(selected)
	local page, setPage = React.useState(1)
	local preferredSound, setPreferredSound = React.useState(nil :: Instance?)
	local settings, setSettings = React.useState(props.initialSettings or Settings.Default(false))
	local options, setOptions = React.useState({
		background = props.initialBackground or "Studio",
		playing = settings.autoPlay,
		autoPlay = settings.autoPlay,
		mirrorLighting = true,
		scaleMode = props.initialScaleMode or "Fit",
	} :: Types.PreviewOptions)
	local menuOpen, setMenuOpen = React.useState(false)
	local hovered, setHovered = React.useState(false)
	local size, setSize = React.useState(Vector2.new(500, 400))
	local capacity = Pagination.PreviewCapacity(size.X, math.max(1, size.Y - 40), settings.minItems, settings.maxItems)
	local previousCapacity = React.useRef(capacity)
	local current, pages, first, last = Pagination.Page(#selection, page, capacity)
	local count = math.max(0, last - first + 1)
	local columns, rows = Pagination.Grid(count, size.X, size.Y - (if pages > 1 then 40 else 0))
	local gutter = if count > 1 then 2 else 0
	local audibleSound = Playback.Sound(selection, first, last, preferredSound)
	React.useEffect(function()
		setPage(1)
	end, { selection } :: { unknown })
	React.useEffect(function()
		setPreferredSound(nil)
		setOptions(function(previous)
			local updated = table.clone(previous)
			updated.playing = updated.autoPlay ~= false
			return updated
		end)
	end, { selection, current } :: { unknown })
	React.useEffect(function()
		local previous = previousCapacity.current
		previousCapacity.current = capacity
		setPage(function(value)
			return math.floor((value - 1) * previous / capacity) + 1
		end)
	end, { capacity })
	local cards: UI.Children = {}
	for index = first, last do
		local offset = index - first
		local source = selection[index]
		local cardOptions = table.clone(options)
		cardOptions.audioEnabled = source == audibleSound
		cards[tostring(index)] = e(PreviewCard, {
			source = source,
			options = cardOptions,
			minimal = true,
			onPlay = function()
				if source:IsA("Sound") then
					setPreferredSound(source)
				end
				local updated = table.clone(options)
				updated.playing = true
				setOptions(updated)
			end,
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
				else "This selection has no supported assets to preview.",
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
			[React.Change.AbsoluteSize] = function(frame: Frame)
				setSize(frame.AbsoluteSize)
			end,
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
				then e(Icons.Button, {
					name = "more_horiz",
					anchorPoint = Vector2.new(1, 0),
					position = UDim2.new(1, -8, 0, 8),
					size = UDim2.fromOffset(32, 28),
					zIndex = 5,
					click = function()
						setMenuOpen(true)
					end,
				})
				else nil,
			Menu = if menuOpen
				then e(PreviewMenu, {
					options = options,
					capacity = capacity,
					settings = settings,
					changeSettings = function(value: Settings.Settings)
						setSettings(value)
						if value.autoPlay ~= settings.autoPlay then
							local updated = table.clone(options)
							updated.autoPlay, updated.playing = value.autoPlay, value.autoPlay
							setOptions(updated)
						end
						if props.onSettings then
							props.onSettings(value)
						end
					end,
					changeOptions = function(updated: Types.PreviewOptions)
						setOptions(updated)
						if updated.background ~= options.background and props.onBackground then
							props.onBackground(updated.background)
						end
						if updated.scaleMode ~= options.scaleMode and props.onScaleMode then
							props.onScaleMode(updated.scaleMode or "Fit")
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
