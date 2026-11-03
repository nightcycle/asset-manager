--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local UI = require(script.Parent.Controls)
local Types = require(script.Parent.Parent.Shared.Types)
local Schema = require(script.Parent.Parent.Shared.Schema)
local Database = require(script.Parent.Parent.Organizer.Database)
local e = React.createElement
export type Props = {
	schema: Types.Schema,
	selection: { Instance },
	database: Database.Database,
	report: (string) -> (),
	changed: () -> (),
}
return function(props: Props): React.ReactElement
	local tagText, setTagText = React.useState("")
	local attributeName, setAttributeName = React.useState("")
	local valueText, setValueText = React.useState("")
	local definition: Types.AttributeDefinition? = nil
	for _, item in props.schema.attributes do
		if item.name == attributeName then
			definition = item
		end
	end
	local hint = "Choose an attribute by its schema name."
	if definition then
		local bounds = if definition.kind == "number"
			then `{definition.min}…{definition.max}`
			elseif definition.kind == "enum" then table.concat(definition.values or {}, ", ")
			else "true, false"
		hint = `{definition.description} · Allowed: {bounds}`
	end
	local function apply(remove: boolean)
		local ok, message = pcall(function(): string?
			local tags: { string } = {}
			for tag in tagText:gmatch("[^,]+") do
				table.insert(tags, (tag:gsub("^%s*(.-)%s*$", "%1")))
			end
			local attributes: { [string]: Types.Value } = {}
			if not remove and attributeName ~= "" then
				assert(definition, "Unknown attribute; create it in Schema first")
				local value = Schema.ParseValue(definition, valueText)
				assert(value ~= nil, "Value is outside the allowed range")
				attributes[attributeName] = value
			end
			assert(#tags > 0 or next(attributes) ~= nil, "Enter a tag or attribute to apply")
			local annotations: { Types.Annotation } = {}
			for _, instance in props.selection do
				table.insert(
					annotations,
					{ path = props.database.Describe(instance).path, tags = tags, attributes = attributes }
				)
			end
			props.database.Apply(annotations, remove)
			return nil
		end)
		props.report(if ok then `Updated {#props.selection} selected assets` else tostring(message))
		if ok then
			props.changed()
		end
	end
	return e(UI.Column, nil, {
		Title = e(UI.Text, { text = `Edit metadata · {#props.selection} selected`, order = 1 }),
		Tags = e(
			UI.Input,
			{ text = tagText, change = setTagText, placeholder = "Tag names, comma separated", order = 2 }
		),
		Attribute = e(
			UI.Input,
			{ text = attributeName, change = setAttributeName, placeholder = "Attribute name (optional)", order = 3 }
		),
		Value = e(UI.Input, { text = valueText, change = setValueText, placeholder = "Attribute value", order = 4 }),
		Hint = e(UI.Text, { text = hint, height = 48, wrapped = true, order = 5 }),
		Actions = e(UI.Row, { order = 6 }, {
			Apply = e(UI.Button, {
				text = "Apply to selection",
				width = 146,
				order = 1,
				primary = true,
				disabled = #props.selection == 0,
				click = function()
					apply(false)
				end,
			}),
			Remove = e(UI.Button, {
				text = "Remove tags",
				width = 112,
				order = 2,
				disabled = #props.selection == 0,
				click = function()
					apply(true)
				end,
			}),
		}),
	})
end
