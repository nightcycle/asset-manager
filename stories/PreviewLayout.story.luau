--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Settings = require(script.Parent.Parent.Source.Shared.ViewSettings)
local Story = require(script.Parent.Story)
return Story.Create(
	"Complete preview rows",
	{ LightTheme = false, Tall = false, Wide = false, Count = 14, PerPage = 16 },
	function(fixture, props)
		local samples = React.useMemo(function(): { Instance }
			local result: { Instance } = {}
			for index = 1, 64 do
				local part = Instance.new("Part")
				part.Name, part.Color, part.Size =
					"Sample " .. tostring(index), Color3.fromHSV(index / 64, 0.6, 0.9), Vector3.new(2, 2, 2)
				part.Shape, part.Parent =
					if index % 2 == 0 then Enum.PartType.Ball else Enum.PartType.Block, fixture.root
				table.insert(result, part)
			end
			return result
		end, {})
		local rawCount, rawPage = props.controls.Count, props.controls.PerPage
		local count = if type(rawCount) == "number" then math.clamp(math.floor(rawCount), 1, 64) else 14
		local perPage = if type(rawPage) == "number" then math.clamp(math.floor(rawPage), 1, 64) else 16
		local selected: { Instance } = {}
		for index = 1, count do
			table.insert(selected, samples[index])
		end
		local settings = Settings.Default(false)
		settings.minItems, settings.maxItems = perPage, perPage
		return React.createElement("Frame", {
			Size = if props.controls.Tall == true
				then UDim2.new(0, 240, 1, 0)
				elseif props.controls.Wide == true then UDim2.new(1, 0, 0, 240)
				else UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Preview = React.createElement(
				App,
				{ key = tostring(perPage), selection = selected, initialSettings = settings }
			),
		})
	end
)
