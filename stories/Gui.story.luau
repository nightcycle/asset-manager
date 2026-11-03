--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Story = require(script.Parent.Story)
return Story.Create(
	"GUI mounting",
	{ LightTheme = false, Screen = false, Fill = false, Tall = false },
	function(fixture, props)
		local samples = React.useMemo(function()
			local screen = Instance.new("ScreenGui")
			screen.Name, screen.Enabled, screen.Parent = "Disabled screen", false, fixture.root
			local panel = Instance.new("Frame")
			panel.Name, panel.Size, panel.Visible = "Hidden UI root", UDim2.fromOffset(420, 180), false
			panel.BackgroundColor3 = Color3.fromRGB(36, 52, 76)
			panel.Parent = fixture.root
			local title = Instance.new("TextLabel")
			title.Size, title.Position = UDim2.new(1, -32, 0, 50), UDim2.fromOffset(16, 12)
			title.BackgroundTransparency = 1
			title.Text, title.TextColor3, title.TextSize =
				"A hidden UI root, made visible", Color3.fromRGB(240, 246, 255), 24
			title.Parent = panel
			local button = Instance.new("TextButton")
			button.Position, button.Size = UDim2.fromOffset(24, 88), UDim2.new(1, -48, 0, 56)
			button.Text = "Child layout and styling are preserved"
			button.BackgroundColor3 = Color3.fromRGB(99, 166, 233)
			button.TextSize = 18
			button.Parent = panel
			local screenPanel = panel:Clone()
			screenPanel.Visible, screenPanel.AnchorPoint, screenPanel.Position =
				true, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
			screenPanel.Parent = screen
			return { screen = screen, panel = panel }
		end, {})
		local selection: { Instance } = { if props.controls.Screen == true then samples.screen else samples.panel }
		return React.createElement("Frame", {
			Size = if props.controls.Tall == true then UDim2.new(0, 260, 1, 0) else UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Preview = React.createElement(App, {
				key = tostring(props.controls.Fill),
				selection = selection,
				initialScaleMode = if props.controls.Fill == true then "Fill" else "Fit",
			}),
		})
	end
)
