--!strict
local React = require(script.Parent.Parent.Packages.React)
local Editor = require(script.Parent.Parent.Source.UI.SchemaEditor)
local UI = require(script.Parent.Parent.Source.UI.Controls)
local Story = require(script.Parent.Story)
return Story.Create("Schema editor", { LightTheme = false }, function(fixture)
	local schema, setSchema = React.useState(fixture.schema)
	local status, setStatus = React.useState("")
	local _, _, _, catalog = fixture.database.Query({ scope = "game" })
	return React.createElement(UI.Scroll, nil, {
		Editor = React.createElement(
			Editor,
			{ schema = schema, catalog = catalog, save = setSchema, report = setStatus }
		),
		Status = React.createElement(UI.Text, { text = status, height = 48, wrapped = true }),
	})
end)
