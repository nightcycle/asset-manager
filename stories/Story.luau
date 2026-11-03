--!strict
local Root = script.Parent.Parent
local React = require(Root.Packages.React)
local ReactRoblox = require(Root.Packages.ReactRoblox)
local UILabs = require(Root.DevPackages.UILabs)
local Studio = require(Root.Packages.StudioComponents)
local Fixtures = require(script.Parent.Fixtures)
local Story = {}
export type Props = { controls: { [string]: unknown } }
function Story.Create(
	name: string,
	controls: { [string]: unknown },
	render: (Fixtures.Fixture, Props) -> React.ReactNode
)
	return UILabs.CreateReactStory(
		{ name = name, react = React, reactRoblox = ReactRoblox, controls = controls },
		function(props: Props)
			local fixture = React.useMemo(Fixtures.new, {})
			React.useEffect(function()
				return function()
					fixture.root:Destroy()
				end
			end, {})
			local themeName = if props.controls.LightTheme == true then "Light" else "Dark"
			local theme: StudioTheme? = nil
			for _, candidate in settings().Studio:GetAvailableThemes() do
				if candidate.Name == themeName then
					theme = candidate
				end
			end
			return React.createElement(
				Studio.ThemeContext.Provider,
				{ value = theme },
				{ Content = render(fixture, props) }
			)
		end
	)
end
return Story
