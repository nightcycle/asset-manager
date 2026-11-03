--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local Types = require(script.Parent.Parent.Shared.Types)
local Cleanup = require(script.Parent.Parent.Shared.Cleanup)
local Registry = require(script.Parent.Parent.Preview.Registry)
local Icons = require(script.Parent.Icons)
local Playback = require(script.Parent.Parent.Preview.Playback)
local PlaybackOverlay = require(script.Parent.PlaybackOverlay)
local PreviewPlaceholder = require(script.Parent.PreviewPlaceholder)
local e = React.createElement
export type Props = {
	source: Instance,
	options: Types.PreviewOptions,
	size: UDim2?,
	position: UDim2?,
	order: number?,
	minimal: boolean?,
	thumbnail: boolean?,
	fallbackIcon: Icons.Name?,
	onPlay: (() -> ())?,
}
return function(props: Props): React.ReactElement
	local theme = Studio.useTheme()
	local host = React.useRef(nil :: Frame?)
	local hovered, setHovered = React.useState(false)
	local playing, setPlaying = React.useState(props.options.playing)
	React.useEffect(function()
		setPlaying(props.options.playing)
	end, { props.source, props.options.playing } :: { unknown })
	local liveOptions = React.useRef(table.clone(props.options))
	liveOptions.current.playing = playing
	liveOptions.current.mirrorLighting = props.options.mirrorLighting
	liveOptions.current.background = props.options.background
	liveOptions.current.scaleMode = props.options.scaleMode
	liveOptions.current.autoPlay = props.options.autoPlay
	liveOptions.current.audioEnabled = props.options.audioEnabled
	local status, setStatus =
		React.useState({ text = "", kind = "info" } :: { text: string, kind: Types.PreviewStatusKind })
	local revision, setRevision = React.useState(0)
	local source = props.source
	local renderer = Registry.Resolve(source)
	local minimal = props.minimal or renderer.id == "sound"
	local missing = renderer.id == "fallback" or status.kind == "error"
	local active: boolean = playing and (not source:IsA("Sound") or props.options.audioEnabled ~= false)
	local background = if props.options.background == "Dark"
		then Color3.fromRGB(28, 30, 34)
		elseif props.options.background == "Light" then Color3.fromRGB(238, 240, 243)
		else theme:GetColor(Enum.StudioStyleGuideColor.ViewPortBackground)
	local palette = React.useRef({} :: Types.PreviewPalette)
	palette.current.text = if props.options.background == "Light"
		then Color3.fromRGB(35, 38, 42)
		elseif props.options.background == "Dark" then Color3.fromRGB(235, 238, 242)
		else theme:GetColor(Enum.StudioStyleGuideColor.MainText)
	palette.current.accent = palette.current.text
	palette.current.button = theme:GetColor(Enum.StudioStyleGuideColor.Button)
	palette.current.buttonText = theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
	React.useEffect(function(): (() -> ())?
		local scheduled = false
		local alive = true
		local connections: { RBXScriptConnection } = {}
		local function changed()
			if scheduled then
				return
			end
			scheduled = true
			task.delay(0.2, function()
				if alive then
					setRevision(function(value)
						return value + 1
					end)
				end
				scheduled = false
			end)
		end
		table.insert(connections, source.Changed:Connect(changed))
		table.insert(connections, source.AttributeChanged:Connect(changed))
		table.insert(connections, source.DescendantAdded:Connect(changed))
		table.insert(connections, source.DescendantRemoving:Connect(changed))
		local descendants: { Instance } = if props.thumbnail then {} else source:GetDescendants()
		for index = 1, math.min(#descendants, 1000) do
			table.insert(connections, descendants[index].Changed:Connect(changed))
		end
		return function()
			alive = false
			for _, connection in connections do
				connection:Disconnect()
			end
		end
	end, { source, revision, props.thumbnail == true } :: { unknown })
	React.useEffect(function(): (() -> ())?
		local parent = host.current
		if not parent then
			return nil
		end
		local cleanup = Cleanup.new()
		local alive = true
		local content = Instance.new("Frame")
		content.Name = "PreviewContent"
		content.Size = UDim2.fromScale(1, 1)
		content.BackgroundTransparency = 1
		content.ClipsDescendants = true
		content.Parent = parent
		cleanup:Add(function()
			content:Destroy()
		end)
		setStatus({ text = "", kind = "info" })
		task.spawn(function()
			local ok, message = pcall(function(): string?
				renderer.mount({
					host = content,
					source = source,
					options = liveOptions.current,
					palette = palette.current,
					report = function(text, kind)
						if alive then
							setStatus({ text = text, kind = kind or "info" })
						end
					end,
					onCleanup = function(callback)
						cleanup:Add(callback)
					end,
					isAlive = function()
						return alive
					end,
				})
				return nil
			end)
			if not ok then
				cleanup:Destroy()
				if alive then
					setStatus({ text = "Preview unavailable: " .. tostring(message), kind = "error" })
				end
			end
		end)
		return function()
			alive = false
			cleanup:Destroy()
		end
	end, { source, revision, props.options.mirrorLighting } :: { unknown })
	return e("Frame", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		LayoutOrder = props.order,
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		ClipsDescendants = true,
	}, {
		Playback = if not props.thumbnail
				and not missing
				and Playback.HasControls(source)
				and (hovered or not active or source:IsA("Sound"))
			then e(PlaybackOverlay, {
				playing = active :: boolean,
				subtle = renderer.id == "sound",
				click = function()
					setPlaying(not active)
					if not active and props.onPlay then
						props.onPlay()
					end
				end,
			})
			else nil,
		Title = if minimal
			then nil
			else e("TextLabel", {
				Size = UDim2.new(1, -16, 0, 26),
				Position = UDim2.fromOffset(8, 0),
				BackgroundTransparency = 1,
				Text = `{source.Name} · {renderer.label}`,
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
				TextSize = 15,
				Font = Enum.Font.SourceSansSemibold,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		Host = e("Frame", {
			ref = host,
			Position = if minimal then UDim2.new() else UDim2.fromOffset(1, 26),
			Size = if minimal then UDim2.fromScale(1, 1) else UDim2.new(1, -2, 1, -66),
			BackgroundColor3 = background,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			[React.Event.MouseEnter] = function()
				setHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setHovered(false)
			end,
		}),
		Fallback = if missing
			then e("Frame", {
				Position = if minimal then UDim2.new() else UDim2.fromOffset(1, 26),
				Size = if minimal then UDim2.fromScale(1, 1) else UDim2.new(1, -2, 1, -66),
				BackgroundColor3 = background,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, { Icon = e(PreviewPlaceholder, { color = palette.current.text }) })
			elseif props.thumbnail and status.kind == "loading" then e("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 3,
			}, {
				Icon = e(
					Icons.Image,
					{ name = props.fallbackIcon or "insert_drive_file", size = UDim2.fromScale(1, 1) }
				),
			})
			else nil,
		Status = if props.thumbnail or (minimal and status.kind == "info")
			then nil
			else e("TextLabel", {
				Position = UDim2.new(0, 8, 1, -39),
				Size = UDim2.new(1, -16, 0, 38),
				BackgroundTransparency = if minimal then 0.1 else 1,
				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
				BorderSizePixel = 0,
				ZIndex = 3,
				Text = status.text,
				TextWrapped = true,
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
				TextSize = 13,
				Font = Enum.Font.SourceSans,
			}),
	})
end
