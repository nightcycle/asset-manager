--!strict
local React = require(script.Parent.Parent.Packages.React)
local UI = require(script.Parent.Parent.Source.UI.Controls)
local Story = require(script.Parent.Story)
return Story.Create("Core controls", { LightTheme = false }, function()
	local text, setText = React.useState("")
	local page, setPage = React.useState(1)
	local choice, setChoice = React.useState("")
	return React.createElement(UI.Scroll, nil, {
		Title = React.createElement(UI.Text, { text = "StudioComponents controls", order = 1 }),
		Input = React.createElement(UI.Input, { text = text, change = setText, placeholder = "Type here", order = 2 }),
		Button = React.createElement(UI.Button, {
			text = "Primary action",
			primary = true,
			click = function()
				setText("Clicked")
			end,
			order = 3,
		}),
		Disabled = React.createElement(
			UI.Button,
			{ text = "Disabled", disabled = true, click = function() end, order = 4 }
		),
		Pager = React.createElement(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 28), LayoutOrder = 5, BackgroundTransparency = 1 },
			{
				Control = React.createElement(UI.Pager, { page = page, pages = 5, change = setPage }),
			}
		),
		Dropdown = React.createElement(UI.Dropdown, {
			items = UI.Choices({ "Forest", "Urban", "Desert" }),
			selected = if choice ~= "" then choice else nil,
			change = function(value: string?)
				setChoice(value or "")
			end,
			placeholder = "Choose an observed value…",
			order = 6,
		}),
		Suggestion = React.createElement(UI.Suggest, {
			text = text,
			change = setText,
			suggestions = { "Nature", "Prop" },
			placeholder = "New or existing name",
			order = 7,
		}),
	})
end)
