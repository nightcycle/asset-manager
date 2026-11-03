--!strict
local React = require(script.Parent.Parent.Packages.React)
local Editor = require(script.Parent.Parent.Source.UI.AnnotationEditor)
local UI = require(script.Parent.Parent.Source.UI.Controls)
local Story = require(script.Parent.Story)
return Story.Create("Metadata editor", { LightTheme = false }, function(fixture)
	local status, setStatus = React.useState("")
	return React.createElement(UI.Scroll, nil, {
		Editor = React.createElement(Editor, {
			schema = fixture.schema,
			database = fixture.database,
			selection = { fixture.selection[1] },
			report = setStatus,
			changed = function() end,
		}),
		Status = React.createElement(UI.Text, { text = status, height = 48, wrapped = true }),
	})
end)
