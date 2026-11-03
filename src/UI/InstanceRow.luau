--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local Types = require(script.Parent.Parent.Shared.Types)
local Icons = require(script.Parent.Icons)
local Thumbnail = require(script.Parent.Thumbnail)
local e = React.createElement
export type Props = {
	record: Types.Record,
	source: Instance?,
	selected: boolean,
	click: () -> (),
	order: number,
	thumbnails: boolean?,
	showPath: boolean?,
	grid: boolean?,
	autoPlay: boolean?,
}
return function(props: Props): React.ReactElement
	local theme = Studio.useTheme()
	local grid = props.grid == true
	local row = React.useRef(nil :: Frame?)
	local visible, setVisible = React.useState(false)
	local hovered, setHovered = React.useState(false)
	React.useLayoutEffect(function()
		local frame = row.current
		if not frame then
			return
		end
		local scroll = frame:FindFirstAncestorWhichIsA("ScrollingFrame")
		local function update()
			if not scroll then
				setVisible(true)
				return
			end
			local top, bottom = scroll.AbsolutePosition.Y, scroll.AbsolutePosition.Y + scroll.AbsoluteSize.Y
			setVisible(
				frame.AbsoluteSize.Y > 0
					and frame.AbsolutePosition.Y < bottom
					and frame.AbsolutePosition.Y + frame.AbsoluteSize.Y > top
			)
		end
		local connections = {
			frame:GetPropertyChangedSignal("AbsolutePosition"):Connect(update),
			frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update),
		}
		if scroll then
			table.insert(connections, scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(update))
			table.insert(connections, scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
		end
		update()
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, {} :: { unknown })
	local modifier = if props.selected
		then Enum.StudioStyleGuideModifier.Selected
		elseif hovered then Enum.StudioStyleGuideModifier.Hover
		else Enum.StudioStyleGuideModifier.Default
	return e("Frame", {
		ref = row,
		Size = UDim2.new(1, 0, 0, 56),
		LayoutOrder = props.order,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Item, modifier),
	}, {
		Icon = e("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = if grid
				then UDim2.new(1, -16, 1, if props.showPath then -108 else -76)
				else UDim2.fromOffset(40, 40),
			BackgroundTransparency = 1,
		}, {
			Content = if props.record.kind == "folder"
				then e(Icons.Image, { name = "folder", size = UDim2.fromScale(1, 1) })
				else e(Thumbnail, {
					source = props.source,
					active = visible and props.thumbnails ~= false,
					autoPlay = props.autoPlay,
				}),
		}),
		Name = e("TextLabel", {
			Size = if grid then UDim2.new(1, -12, 0, 56) else UDim2.new(1, -90, 0, 24),
			Position = if grid
				then UDim2.new(0, 6, 1, if props.showPath then -92 else -60)
				else UDim2.fromOffset(58, if props.showPath then 4 else 16),
			BackgroundTransparency = 1,
			Text = if grid
				then props.record.name
				else props.record.name .. "  ·  " .. (if props.record.kind == "folder"
					then "Folder"
					else props.record.className),
			Font = Enum.Font.SourceSansSemibold,
			TextSize = 15,
			TextXAlignment = if grid then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
			TextYAlignment = if grid then Enum.TextYAlignment.Top else Enum.TextYAlignment.Center,
			TextWrapped = grid,
			TextTruncate = if grid then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText, modifier),
		}),
		Path = if props.showPath
			then e("TextLabel", {
				Size = if grid then UDim2.new(1, -12, 0, 32) else UDim2.new(1, -90, 0, 20),
				Position = if grid then UDim2.new(0, 6, 1, -36) else UDim2.fromOffset(58, 29),
				BackgroundTransparency = 1,
				Text = props.record.fullName,
				Font = Enum.Font.SourceSans,
				TextSize = 13,
				TextXAlignment = if grid then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
				TextWrapped = grid,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText, modifier),
			})
			else nil,
		Arrow = if props.record.kind == "folder" and not grid
			then e(
				Icons.Image,
				{ name = "chevron_right", position = UDim2.new(1, -28, 0, 18), size = UDim2.fromOffset(20, 20) }
			)
			else nil,
		-- The row owns input; thumbnails cannot play audio, orbit, or consume scrolling.
		HitTarget = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 5,
			[React.Event.Activated] = props.click,
			[React.Event.MouseEnter] = function()
				setHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setHovered(false)
			end,
		}),
	})
end
