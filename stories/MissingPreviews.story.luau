--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Story = require(script.Parent.Story)
return Story.Create("Missing previews", { LightTheme = false }, function(fixture)
	local selection = React.useMemo(function(): { Instance }
		local unsupported, emptyModel, unavailable = Instance.new("Fire"), Instance.new("Model"), Instance.new("Part")
		unsupported.Name, emptyModel.Name, unavailable.Name = "No renderer", "No geometry", "Cannot clone"
		unavailable.Archivable = false
		local instances: { Instance } = { unsupported, emptyModel, unavailable }
		for _, item in instances do
			item.Parent = fixture.root
		end
		return instances
	end, {})
	return React.createElement(App, { selection = selection })
end)
