--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local UI = require(script.Parent.Controls)
local Types = require(script.Parent.Parent.Shared.Types)
local Schema = require(script.Parent.Parent.Shared.Schema)
local Catalog = require(script.Parent.Parent.Organizer.Catalog)
local e = React.createElement
export type Props = { schema: Types.Schema, save: (Types.Schema) -> (), report: (string) -> (), catalog: Types.Catalog? }
return function(props: Props): React.ReactElement
	local kind, setKind = React.useState("tag")
	local name, setName = React.useState("")
	local description, setDescription = React.useState("")
	local minimum, setMinimum = React.useState("0")
	local maximum, setMaximum = React.useState("1")
	local choices, setChoices = React.useState("")
	local catalog = props.catalog or Catalog.Empty()
	local observedValues: { string } = {}
	local observed: { Types.Value } = catalog.attributes[name] or {}
	for _, value in observed do
		if type(value) == "string" then
			table.insert(observedValues, value)
		end
	end
	local function save()
		local schema: Types.Schema =
			{ version = 1, tags = table.clone(props.schema.tags), attributes = table.clone(props.schema.attributes) }
		if kind == "tag" then
			local definition: Types.TagDefinition = { name = name, description = description }
			local replaced = false
			for index, item in schema.tags do
				if item.name == name then
					schema.tags[index] = definition
					replaced = true
				end
			end
			if not replaced then
				table.insert(schema.tags, definition)
			end
		else
			local definition: Types.AttributeDefinition = { name = name, description = description, kind = "boolean" }
			if kind == "number" then
				definition.kind = "number"
				definition.min = tonumber(minimum)
				definition.max = tonumber(maximum)
			elseif kind == "enum" then
				definition.kind = "enum"
				local values: { string } = {}
				for value in choices:gmatch("[^,]+") do
					table.insert(values, (value:gsub("^%s*(.-)%s*$", "%1")))
				end
				definition.values = values
			end
			local replaced = false
			for index, item in schema.attributes do
				if item.name == name then
					schema.attributes[index] = definition
					replaced = true
				end
			end
			if not replaced then
				table.insert(schema.attributes, definition)
			end
		end
		local valid, message = Schema.Validate(schema)
		if not valid then
			props.report(message)
			return
		end
		props.save(schema)
	end
	local definitions: UI.Children = {}
	for index, definition in props.schema.tags do
		definitions["tag" .. definition.name] = e(UI.Button, {
			text = "Tag · " .. definition.name,
			order = index,
			click = function()
				setKind("tag")
				setName(definition.name)
				setDescription(definition.description)
			end,
		})
	end
	for index, definition in props.schema.attributes do
		definitions["attribute" .. definition.name] = e(UI.Button, {
			text = definition.kind .. " · " .. definition.name,
			order = #props.schema.tags + index,
			click = function()
				setKind(definition.kind)
				setName(definition.name)
				setDescription(definition.description)
				setMinimum(tostring(definition.min or 0))
				setMaximum(tostring(definition.max or 1))
				setChoices(table.concat(definition.values or {}, ", "))
			end,
		})
	end
	return e(UI.Column, nil, {
		Help = e(UI.Text, {
			text = "Define what an asset means. Descriptions guide both people and machine vision.",
			height = 42,
			wrapped = true,
			order = 1,
		}),
		Kind = e(UI.Dropdown, {
			clearable = false,
			items = UI.Choices({ "tag", "number", "enum", "boolean" }),
			selected = kind,
			order = 2,
			change = function(value: string?)
				if value then
					setKind(value)
				end
			end,
		}),
		Name = e(UI.Suggest, {
			text = name,
			change = setName,
			placeholder = "New or existing name",
			order = 3,
			suggestions = if kind == "tag"
				then Catalog.TagNames(catalog, props.schema)
				else Catalog.AttributeNames(catalog, props.schema),
		}),
		Description = e(UI.Input, {
			text = description,
			change = setDescription,
			placeholder = "Required: describe when this definition applies",
			order = 4,
		}),
		Min = if kind == "number"
			then e(UI.Input, { text = minimum, change = setMinimum, placeholder = "Minimum (inclusive)", order = 5 })
			else nil,
		Max = if kind == "number"
			then e(UI.Input, { text = maximum, change = setMaximum, placeholder = "Maximum (inclusive)", order = 6 })
			else nil,
		Choices = if kind == "enum"
			then e(
				UI.Input,
				{ text = choices, change = setChoices, placeholder = "Allowed values, comma separated", order = 5 }
			)
			else nil,
		ObservedChoices = if kind == "enum" and #observedValues > 0
			then e(UI.Dropdown, {
				items = UI.Choices(observedValues),
				placeholder = "Add a value found in this scope…",
				order = 6,
				change = function(value: string?)
					if value then
						setChoices(if choices == "" then value else choices .. ", " .. value)
					end
				end,
			})
			else nil,
		Bounds = e(UI.Text, {
			text = if kind == "boolean"
				then "Allowed values: true, false"
				elseif kind == "number" then "Bounds are inclusive. NaN and infinity are rejected."
				elseif kind == "enum" then "Only the listed string values are accepted."
				else "Tags are either present or absent.",
			height = 38,
			wrapped = true,
			order = 7,
		}),
		Save = e(UI.Button, { text = "Save definition", primary = true, click = save, order = 8 }),
		Title = e(UI.Text, { text = "Existing definitions · click to edit", order = 9 }),
		Definitions = e(UI.Column, { order = 10 }, definitions),
	})
end
