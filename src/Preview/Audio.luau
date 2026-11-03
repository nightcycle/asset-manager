--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Parent.Shared.Types)
local Audio = {}
function Audio.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
function Audio.Level(loudness: number): number
	return math.sqrt(math.clamp(loudness / 1000, 0, 1))
end
function Audio.Clone(source: Sound): Sound
	local sound = source:Clone()
	assert(sound, "Sound is not Archivable")
	sound.PlayOnRemove = false
	sound.Playing = false
	sound.TimePosition = 0
	if sound.SoundGroup then
		sound.SoundGroup = nil
	end
	sound.Volume = if source.Volume > 0 then math.min(source.Volume, 0.5) else 0.5
	sound.Looped = true
	sound.PlaybackRegionsEnabled = false
	for _, child in sound:GetDescendants() do
		if child:IsA("LuaSourceContainer") or child:IsA("Sound") then
			child:Destroy()
		end
	end
	return sound
end
function Audio.Mount(context: Types.PreviewContext)
	local source = context.source
	assert(source:IsA("Sound") and source.SoundId ~= "", "Set a SoundId to preview audio")
	local sound = Audio.Clone(source)
	-- Edit-mode audio must live in the widget, not in the place's SoundService.
	sound.Parent = context.host:FindFirstAncestorWhichIsA("PluginGui") or context.host
	context.onCleanup(function()
		sound:Stop()
		sound:Destroy()
	end)
	local canvas = Instance.new("Frame")
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.Parent = context.host
	context.onCleanup(function()
		canvas:Destroy()
	end)
	local function label(text: string): TextLabel
		local item = Instance.new("TextLabel")
		item.BackgroundTransparency = 1
		item.Text = text
		item.TextSize = 14
		item.Font = Enum.Font.SourceSans
		item.TextTruncate = Enum.TextTruncate.AtEnd
		item.Parent = canvas
		return item
	end
	local title = label(source.Name)
	title.Position, title.Size = UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 22)
	title.Font = Enum.Font.SourceSansSemibold
	local chart = Instance.new("Frame")
	chart.BackgroundTransparency = 1
	chart.Position, chart.Size = UDim2.fromOffset(12, 36), UDim2.new(1, -24, 1, -100)
	chart.ClipsDescendants = true
	chart.Parent = canvas
	local bars: { Frame } = {}
	local samples: { number } = table.create(48, 0)
	for index = 1, #samples do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.new((index - 1) / #samples, 0, 0.5, 0)
		bar.Size = UDim2.new(1 / #samples, -2, 0, 2)
		bar.Parent = chart
		table.insert(bars, bar)
	end
	local button = Instance.new("TextButton")
	button.Position, button.Size = UDim2.new(0, 12, 1, -54), UDim2.fromOffset(64, 28)
	button.BorderSizePixel = 0
	button.TextSize, button.Font, button.Text = 14, Enum.Font.SourceSansSemibold, "Play"
	button.Parent = canvas
	local timeLabel = label("0:00 / --:--")
	timeLabel.Position, timeLabel.Size = UDim2.new(0, 84, 1, -54), UDim2.new(1, -96, 0, 28)
	timeLabel.TextXAlignment = Enum.TextXAlignment.Right
	local state = label("Loading audio…")
	state.Position, state.Size = UDim2.new(0, 12, 1, -24), UDim2.new(1, -24, 0, 18)
	local progress = Instance.new("Frame")
	progress.BorderSizePixel = 0
	progress.Position, progress.Size = UDim2.new(0, 0, 1, -2), UDim2.fromOffset(0, 2)
	progress.Parent = canvas
	local autoPlay = context.options.autoPlay ~= false
	local requested, started, loadFailed = autoPlay, false, false
	local elapsed, sampleTime = 0, 0
	local function syncPlayback()
		if requested and context.options.playing and sound.IsLoaded then
			if not sound.IsPlaying then
				if started then
					sound:Resume()
				else
					sound:Play()
					started = true
				end
			end
		elseif sound.IsPlaying then
			sound:Pause()
		end
	end
	local clicked = button.Activated:Connect(function()
		requested = not requested
		if requested and context.play then
			context.play()
		end
		syncPlayback()
	end)
	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		if autoPlay ~= (context.options.autoPlay ~= false) then
			autoPlay = context.options.autoPlay ~= false
			requested = autoPlay
		end
		elapsed += dt
		sampleTime += dt
		syncPlayback()
		if sampleTime < 1 / 30 then
			return
		end
		sampleTime %= 1 / 30
		local loudness = if sound.IsPlaying then sound.PlaybackLoudness else 0
		table.remove(samples, 1)
		table.insert(samples, Audio.Level(loudness))
		local theme = settings().Studio.Theme
		local textColor = if context.palette
			then context.palette.text
			elseif context.options.background == "Light" then Color3.fromRGB(35, 38, 42)
			elseif context.options.background == "Dark" then Color3.fromRGB(235, 238, 242)
			else theme:GetColor(Enum.StudioStyleGuideColor.MainText)
		local accent = if context.palette then context.palette.accent else textColor
		for index, bar in bars do
			bar.Size = UDim2.new(1 / #bars, -2, math.max(0.02, samples[index] * 0.95), 0)
			bar.BackgroundColor3 = accent
		end
		for _, item in { title, timeLabel, state } do
			item.TextColor3 = textColor
		end
		button.TextColor3 = if context.palette
			then context.palette.buttonText
			else theme:GetColor(Enum.StudioStyleGuideColor.ButtonText)
		button.BackgroundColor3 = if context.palette
			then context.palette.button
			else theme:GetColor(Enum.StudioStyleGuideColor.Button)
		button.Text = if requested then "Pause" else "Play"
		local length = sound.TimeLength
		timeLabel.Text = Audio.Time(sound.TimePosition)
			.. " / "
			.. (if sound.IsLoaded then Audio.Time(length) else "--:--")
		progress.BackgroundColor3 = accent
		progress.Size = UDim2.new(if length > 0 then math.clamp(sound.TimePosition / length, 0, 1) else 0, 0, 0, 2)
		state.Text = if not sound.IsLoaded
			then (if loadFailed or elapsed > 15 then "Audio unavailable · check asset access" else "Loading audio…")
			elseif not context.options.playing then "Playback paused in preview options"
			elseif sound.IsPlaying then `Loudness {math.floor(loudness)} · looping`
			elseif requested then "Starting audio…"
			else "Click Play to preview"
	end)
	context.onCleanup(function()
		clicked:Disconnect()
		heartbeat:Disconnect()
	end)
	task.spawn(function()
		local ok = pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({ sound })
		end)
		if context.isAlive() then
			loadFailed = not ok
		end
	end)
	context.report("Audio preview · live loudness history")
end
return Audio
