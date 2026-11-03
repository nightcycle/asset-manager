--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Story = require(script.Parent.Story)
return Story.Create("Images, audio, and R15", {
	LightTheme = false,
	ImageId = "rbxasset://textures/particles/sparkles_main.dds",
	AnimationId = "",
	SoundId = "rbxasset://sounds/electronicpingshort.wav",
	ShowAudio = true,
	Flipbook = false,
}, function(fixture, props)
	local image = fixture.selection[13] :: ImageLabel
	local animation = React.useMemo(function()
		local instance = Instance.new("Animation")
		instance.Name = "R15 animation (set AnimationId control)"
		instance.Parent = fixture.root
		return instance
	end, {})
	local localClip = React.useMemo(function()
		local clip = Instance.new("KeyframeSequence")
		clip.Name, clip.Parent = "Local R15 wave", fixture.root
		for _, time in { 0, 0.5, 1 } do
			local key = Instance.new("Keyframe")
			key.Time, key.Parent = time, clip
			local pose = Instance.new("Pose")
			pose.Name, pose.Weight = "RightUpperArm", 1
			pose.CFrame = CFrame.Angles(0, 0, if time == 0.5 then math.rad(110) else 0)
			pose.EasingStyle = Enum.PoseEasingStyle.Linear
			pose.Parent = key
		end
		return clip
	end, {})
	local sound = React.useMemo(function()
		local instance = Instance.new("Sound")
		instance.Name, instance.Volume, instance.Parent = "Audio preview", 0.4, fixture.root
		return instance
	end, {})
	React.useEffect(
		function()
			if type(props.controls.ImageId) == "string" then
				image.Image = props.controls.ImageId
			end
			if type(props.controls.AnimationId) == "string" then
				animation.AnimationId = props.controls.AnimationId
			end
			if type(props.controls.SoundId) == "string" then
				sound.SoundId = props.controls.SoundId
			end
			image:SetAttribute("Preview_FlipbookColumns", if props.controls.Flipbook then 4 else nil)
			image:SetAttribute("Preview_FlipbookRows", 4)
			image:SetAttribute("Preview_FrameWidth", 256)
			image:SetAttribute("Preview_FrameHeight", 256)
			image:SetAttribute("Preview_FPS", 16)
		end,
		{ props.controls.ImageId, props.controls.AnimationId, props.controls.SoundId, props.controls.Flipbook } :: { unknown }
	)
	local selected: { Instance } = { image, fixture.selection[14] }
	if props.controls.AnimationId ~= "" then
		table.insert(selected, animation)
	else
		table.insert(selected, localClip)
	end
	if props.controls.ShowAudio == true then
		table.insert(selected, sound)
	end
	return React.createElement(App, { selection = selected })
end)
