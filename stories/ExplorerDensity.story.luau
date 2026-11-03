--!strict
local Root = script.Parent.Parent
local React = require(Root.Packages.React)
local App = require(Root.Source.Organizer.App)
local Settings = require(Root.Source.Shared.ViewSettings)
local Story = require(script.Parent.Story)
return Story.Create(
	"Explorer fitted pages",
	{ LightTheme = false, ItemsPerPage = 12, Grid = true, Narrow = false },
	function(fixture, props)
		React.useMemo(function()
			local folder = Instance.new("Folder")
			folder.Name, folder.Parent = "Density", fixture.root
			for index = 1, 210 do
				local source = fixture.selection[(index - 1) % 12 + 1]:Clone()
				if source then
					source.Name, source.Parent = `Example asset with a wrapping name {index}`, folder
				end
			end
			return folder
		end, { fixture })
		local requested = props.controls.ItemsPerPage
		local count = if type(requested) == "number" then math.clamp(math.floor(requested), 1, 200) else 48
		local value = Settings.Default(true)
		value.viewMode = if props.controls.Grid == true then "Grid" else "List"
		value = Settings.WithPageSize(value, count)
		return React.createElement("Frame", {
			Size = if props.controls.Narrow == true then UDim2.new(0, 320, 1, 0) else UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Explorer = React.createElement(App, {
				key = tostring(count) .. value.viewMode,
				database = fixture.database,
				selection = {},
				onSelect = function() end,
				initialSettings = value,
				initialScope = "game/Density",
			}),
		})
	end
)
