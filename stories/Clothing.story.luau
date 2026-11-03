--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Story = require(script.Parent.Story)
return Story.Create("Classic clothing", {
	LightTheme = false,
	ShirtTemplate = "",
	PantsTemplate = "",
	TShirtImage = "rbxasset://textures/particles/sparkles_main.dds",
}, function(fixture, props)
	local garments = React.useMemo(function()
		local shirt, pants, graphic = Instance.new("Shirt"), Instance.new("Pants"), Instance.new("ShirtGraphic")
		shirt.Name, pants.Name, graphic.Name = "Shirt (set template)", "Pants (set template)", "T-shirt graphic"
		shirt.Parent, pants.Parent, graphic.Parent = fixture.root, fixture.root, fixture.root
		return { shirt = shirt, pants = pants, graphic = graphic }
	end, {})
	React.useEffect(function()
		if type(props.controls.ShirtTemplate) == "string" then
			garments.shirt.ShirtTemplate = props.controls.ShirtTemplate
		end
		if type(props.controls.PantsTemplate) == "string" then
			garments.pants.PantsTemplate = props.controls.PantsTemplate
		end
		if type(props.controls.TShirtImage) == "string" then
			garments.graphic.Graphic = props.controls.TShirtImage
		end
	end, { props.controls.ShirtTemplate, props.controls.PantsTemplate, props.controls.TShirtImage } :: { unknown })
	local selection: { Instance } = { garments.shirt, garments.pants, garments.graphic }
	return React.createElement(App, { selection = selection })
end)
