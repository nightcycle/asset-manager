--!strict
local Root = script.Parent.Parent
local React = require(Root.Packages.React)
local Studio = require(Root.Packages.StudioComponents)
local PluginIcons = require(Root.Source.Generated.PluginIcons)
local Story = require(script.Parent.Story)
return Story.Create("Plugin icons", { LightTheme = false }, function()
	local children: { [string]: React.ReactNode } = {
		Layout = React.createElement(
			"UIListLayout",
			{ FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16) }
		),
	}
	for name, icon in PluginIcons :: { [string]: string } do
		children[name] = React.createElement("ImageLabel", {
			Size = UDim2.fromOffset(64, 64),
			BackgroundTransparency = 1,
			Image = icon,
			ScaleType = Enum.ScaleType.Fit,
		})
	end
	return React.createElement(Studio.Background, nil, children)
end)
