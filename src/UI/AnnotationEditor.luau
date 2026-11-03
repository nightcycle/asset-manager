--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local UI = require(script.Parent.Controls)
local Types = require(script.Parent.Parent.Shared.Types)
local Schema = require(script.Parent.Parent.Shared.Schema)
local Database = require(script.Parent.Parent.Organizer.Database)
local Catalog = require(script.Parent.Parent.Organizer.Catalog)
local TagPicker = require(script.Parent.TagPicker)
local e = React.createElement
export type Props = {
	schema: Types.Schema,
	selection: { Instance },
	database: Database.Database,
	report: (string) -> (),
	changed: () -> (),
	catalog: Types.Catalog?,
}
return function(props: Props): React.ReactElement
	local tags, setTags = React.useState({} :: { string })
	local attributeName, setAttributeName = React.useState("")
	local valueText, setValueText = React.useState("")
	local catalog = props.catalog or Catalog.Empty()
	local definition: Types.AttributeDefinition? = nil
	for _, item in props.schema.attributes do
		if item.name == attributeName then
			definition = item
		end
	end
	local values: { string } = {}
	for _, value in Catalog.Values(catalog, attributeName, definition) do
		table.insert(values, tostring(value))
	end
	local hint =
		"Choose tags or an attribute. Define descriptions and allowed values in Schema before applying existing unmanaged metadata."
	if definition then
		local bounds = if definition.kind == "number"
			then `{definition.min}…{definition.max}`
			elseif definition.kind == "enum" then table.concat(definition.values or {}, ", ")
			else "true, false"
		hint = `{definition.description} · Allowed: {bounds}`
	end
	local function apply(remove: boolean)
		local ok, message = pcall(function(): string?
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
			TagPicker,
			{ choices = Catalog.TagNames(catalog, props.schema), selected = tags, change = setTags, order = 2 }
		),
		Attribute = e(UI.Dropdown, {
			items = UI.Choices(Catalog.AttributeNames(catalog, props.schema)),
			selected = if attributeName ~= "" then attributeName else nil,
			change = function(name: string?)
				setAttributeName(name or "")
				setValueText("")
			end,
			placeholder = "Attribute (optional)",
			order = 3,
		}),
		Value = if attributeName == ""
			then nil
			elseif definition and definition.kind == "number" then e(UI.Suggest, {
				text = valueText,
				change = setValueText,
				suggestions = values,
				placeholder = "Attribute value",
				order = 4,
			})
			else e(UI.Dropdown, {
				items = UI.Choices(values),
				selected = if valueText ~= "" then valueText else nil,
				change = function(value: string?)
					setValueText(value or "")
				end,
				placeholder = "Attribute value",
				order = 4,
			}),
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
