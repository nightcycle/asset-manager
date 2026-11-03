--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Story = require(script.Parent.Story)
return Story.Create("Previewer", {
	LightTheme = false,
	EmptySelection = false,
	SinglePreview = false,
	SelectFolder = true,
	SelectConfiguration = false,
	Tall = false,
	Wide = false,
}, function(fixture, props)
	local configuration = React.useMemo(function()
		local instance = Instance.new("Configuration")
		instance.Name = "Container"
		instance.Parent = fixture.root
		local nested = Instance.new("Folder")
		nested.Name, nested.Parent = "Nested", instance
		for index = 1, 6 do
			local clone = fixture.selection[index]:Clone()
			assert(clone)
			clone.Parent = nested
		end
		return instance
	end, {})
	local selection: { Instance } = if props.controls.EmptySelection == true
		then {}
		elseif props.controls.SinglePreview == true then { fixture.selection[1] }
		elseif props.controls.SelectConfiguration == true then { configuration }
		elseif props.controls.SelectFolder == true then { fixture.root:FindFirstChild("Assets") :: Instance }
		else fixture.selection
	return React.createElement("Frame", {
		Size = if props.controls.Tall == true
			then UDim2.new(0, 240, 1, 0)
			elseif props.controls.Wide == true then UDim2.new(1, 0, 0, 180)
			else UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, { Preview = React.createElement(App, { selection = selection }) })
end)
