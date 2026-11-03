--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Story = require(script.Parent.Story)
return Story.Create("Images, flipbooks, and R15", {
	LightTheme = false,
	ImageId = "rbxasset://textures/particles/sparkles_main.dds",
	AnimationId = "",
	Flipbook = false,
}, function(fixture, props)
	local image = fixture.selection[13] :: ImageLabel
	local animation = React.useMemo(function()
		local instance = Instance.new("Animation")
		instance.Name = "R15 animation (set AnimationId control)"
		instance.Parent = fixture.root
		return instance
	end, {})
	React.useEffect(function()
		if type(props.controls.ImageId) == "string" then
			image.Image = props.controls.ImageId
		end
		if type(props.controls.AnimationId) == "string" then
			animation.AnimationId = props.controls.AnimationId
		end
		image:SetAttribute("Preview_FlipbookColumns", if props.controls.Flipbook then 4 else nil)
		image:SetAttribute("Preview_FlipbookRows", 4)
		image:SetAttribute("Preview_FrameWidth", 256)
		image:SetAttribute("Preview_FrameHeight", 256)
		image:SetAttribute("Preview_FPS", 16)
	end, { props.controls.ImageId, props.controls.AnimationId, props.controls.Flipbook } :: { unknown })
	local selected: { Instance } = { image, fixture.selection[14] }
	if props.controls.AnimationId ~= "" then
		table.insert(selected, animation)
	end
	return React.createElement(App, { selection = selected })
end)
