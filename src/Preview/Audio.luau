--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Parent.Shared.Types)
local Playback = require(script.Parent.Playback)
local Audio = {}
function Audio.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
function Audio.Level(loudness: number): number
	return math.sqrt(math.clamp(loudness / 1000, 0, 1))
end
function Audio.Record(samples: { number }, position: number, length: number, loudness: number)
	if length <= 0 or #samples == 0 then
		return
	end
	local index = math.clamp(math.floor(position / length * #samples) + 1, 1, #samples)
	samples[index] = math.max(samples[index], Audio.Level(loudness))
end
function Audio.SetAudible(sound: Sound, audible: boolean, previous: boolean, volume: number): boolean
	-- Keep the decoder running for PlaybackLoudness. The control only gates output.
	if audible and not previous then
		sound.TimePosition = 0
	end
	sound.Volume = if audible then volume else 0
	return audible
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
	local volume = sound.Volume
	sound.Volume = 0
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
	local chart = Instance.new("Frame")
	chart.BackgroundTransparency = 1
	chart.Position, chart.Size = UDim2.fromOffset(12, 12), UDim2.new(1, -24, 1, -48)
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
	local timeLabel = label("0:00 / --:--")
	timeLabel.Position, timeLabel.Size = UDim2.new(0, 12, 1, -28), UDim2.new(1, -24, 0, 24)
	local audible, loadFailed, reportedUnavailable = false, false, false
	local elapsed, sampleTime = 0, 0
	local function syncPlayback()
		if sound.IsLoaded then
			audible = Audio.SetAudible(sound, Playback.Audible(context.options), audible, volume)
			if not sound.IsPlaying then
				sound:Play()
			end
		end
	end
	local heartbeat = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		sampleTime += dt
		syncPlayback()
		if sampleTime < 1 / 30 then
			return
		end
		sampleTime %= 1 / 30
		local loudness = sound.PlaybackLoudness
		Audio.Record(samples, sound.TimePosition, sound.TimeLength, loudness)
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
			bar.BackgroundTransparency = if audible then 0 else 0.25
		end
		timeLabel.TextColor3 = textColor
		local length = sound.TimeLength
		timeLabel.Text = Audio.Time(sound.TimePosition)
			.. " / "
			.. (if sound.IsLoaded then Audio.Time(length) else "--:--")
		if not sound.IsLoaded and (loadFailed or elapsed > 15) and not reportedUnavailable then
			reportedUnavailable = true
			context.report("Audio unavailable · check asset access", "error")
		elseif sound.IsLoaded and reportedUnavailable then
			reportedUnavailable = false
			context.report("")
		end
	end)
	context.onCleanup(function()
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
	context.report("")
end
return Audio
