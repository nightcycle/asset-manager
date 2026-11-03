--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Story = require(script.Parent.Story)
return Story.Create(
	"Materials and surfaces",
	{ LightTheme = false, ColorMap = "rbxasset://textures/ui/LegacyRbxGui/brickSide.png" },
	function(fixture, props)
		local assets = React.useMemo(function()
			local organic, regular = Instance.new("MaterialVariant"), Instance.new("MaterialVariant")
			organic.Name, organic.BaseMaterial, organic.MaterialPattern =
				"Organic sphere", Enum.Material.Grass, Enum.MaterialPattern.Organic
			regular.Name, regular.BaseMaterial, regular.MaterialPattern =
				"Regular cube", Enum.Material.Brick, Enum.MaterialPattern.Regular
			local surface, decal, texture =
				Instance.new("SurfaceAppearance"), Instance.new("Decal"), Instance.new("Texture")
			surface.Name, decal.Name, texture.Name = "Surface appearance", "Decal", "Tiled texture"
			texture.StudsPerTileU, texture.StudsPerTileV = 1, 1
			local selection: { Instance } = { organic, regular, surface, decal, texture }
			for _, item in selection do
				item.Parent = fixture.root
			end
			return {
				organic = organic,
				regular = regular,
				surface = surface,
				decal = decal,
				texture = texture,
				selection = selection,
			}
		end, {})
		React.useEffect(function()
			if type(props.controls.ColorMap) == "string" then
				local map = props.controls.ColorMap
				assets.organic.ColorMap, assets.regular.ColorMap, assets.surface.ColorMap = map, map, map
				assets.decal.Texture, assets.texture.Texture = map, map
			end
		end, { props.controls.ColorMap } :: { unknown })
		return React.createElement(App, { selection = assets.selection })
	end
)
