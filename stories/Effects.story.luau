--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Story = require(script.Parent.Story)
return Story.Create("Beams, trails, and particles", {
	LightTheme = false,
	Texture = "rbxasset://textures/particles/sparkles_main.dds",
	Textured = false,
	Curve = 4,
	Lifetime = 1.5,
}, function(fixture, props)
	local effects = React.useMemo(function()
		local beam, trail = Instance.new("Beam"), Instance.new("Trail")
		beam.Name, trail.Name = "Curved Beam", "Sweeping Trail"
		beam.Width0, beam.Width1, beam.Segments = 1.2, 0.2, 48
		beam.Color = ColorSequence.new(Color3.fromRGB(80, 210, 255), Color3.fromRGB(210, 100, 255))
		trail.Color = ColorSequence.new(Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 70, 140))
		trail.WidthScale, trail.Transparency = NumberSequence.new(1, 0), NumberSequence.new(0, 1)
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.CFrame = CFrame.new(-4, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
		b.CFrame = CFrame.new(4, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2)
		a.Parent, b.Parent = beam, beam
		beam.Attachment0, beam.Attachment1 = a, b
		beam.Parent, trail.Parent = fixture.root, fixture.root
		return { beam = beam, trail = trail }
	end, {})
	React.useEffect(
		function()
			local texture = if props.controls.Textured == true and type(props.controls.Texture) == "string"
				then props.controls.Texture
				else ""
			effects.beam.Texture, effects.trail.Texture = texture, texture
			if type(props.controls.Curve) == "number" then
				effects.beam.CurveSize0, effects.beam.CurveSize1 = props.controls.Curve, props.controls.Curve
			end
			if type(props.controls.Lifetime) == "number" then
				effects.trail.Lifetime = math.clamp(props.controls.Lifetime, 0, 20)
			end
		end,
		{ props.controls.Texture, props.controls.Textured, props.controls.Curve, props.controls.Lifetime } :: { unknown }
	)
	local selected: { Instance } = { effects.beam, effects.trail, fixture.selection[14] }
	return React.createElement(App, { selection = selected })
end)
