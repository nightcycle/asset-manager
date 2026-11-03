--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Story = require(script.Parent.Story)
return Story.Create("Sixteen square slots", { LightTheme = false, Tall = false, Wide = false }, function(fixture, props)
	local selected = React.useMemo(function(): { Instance }
		local result: { Instance } = {}
		for index = 1, 32 do
			local part = Instance.new("Part")
			part.Name, part.Color, part.Size =
				"Sample " .. tostring(index), Color3.fromHSV(index / 32, 0.6, 0.9), Vector3.new(2, 2, 2)
			part.Shape, part.Parent = if index % 2 == 0 then Enum.PartType.Ball else Enum.PartType.Block, fixture.root
			table.insert(result, part)
		end
		return result
	end, {})
	return React.createElement("Frame", {
		Size = if props.controls.Tall == true
			then UDim2.new(0, 240, 1, 0)
			elseif props.controls.Wide == true then UDim2.new(1, 0, 0, 240)
			else UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, { Preview = React.createElement(App, { selection = selected }) })
end)
