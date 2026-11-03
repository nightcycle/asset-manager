--!strict
local Types = require(script.Parent.Types)
type Schema = Types.Schema
type AttributeDefinition = Types.AttributeDefinition
local Schema = {}

function Schema.Empty(): Schema
	return { version = 1, tags = {}, attributes = {} }
end

local function nameValid(name: string): boolean
	return #name > 0 and #name <= 80 and name:match("^[%a_][%w_]*$") ~= nil and name:sub(1, 3) ~= "RBX"
end

function Schema.Validate(schema: Schema): (boolean, string)
	if schema.version ~= 1 then
		return false, "Unsupported schema version"
	end
	if #schema.tags > 128 or #schema.attributes > 128 then
		return false, "Limit: 128 tags and 128 attributes"
	end
	local attributeNames: { Types.TagDefinition } = {}
	for _, definition in schema.attributes do
		table.insert(attributeNames, { name = definition.name, description = definition.description })
	end
	local lists = { schema.tags, attributeNames }
	for _, definitions in lists do
		local names: { [string]: boolean } = {}
		for _, definition in definitions do
			if not nameValid(definition.name) or names[definition.name] then
				return false, "Names must be unique identifiers, up to 80 characters, without the RBX prefix"
			end
			if not definition.description:find("%S") or #definition.description > 2000 then
				return false, "Every definition needs a description (1–2000 characters)"
			end
			names[definition.name] = true
		end
	end
	for _, definition in schema.attributes do
		if definition.kind == "number" then
			local low, high = definition.min, definition.max
			if
				not low
				or not high
				or low ~= low
				or high ~= high
				or math.abs(low) == math.huge
				or math.abs(high) == math.huge
				or low > high
			then
				return false, "Number attributes need finite minimum and maximum bounds"
			end
		elseif definition.kind == "enum" then
			local values = definition.values
			if not values or #values == 0 or #values > 128 then
				return false, "Enum attributes need 1–128 allowed values"
			end
			local seen: { [string]: boolean } = {}
			for _, value in values do
				if not value:find("%S") or #value > 200 or seen[value] then
					return false, "Enum values must be nonempty and unique"
				end
				seen[value] = true
			end
		elseif definition.kind ~= "boolean" then
			return false, "Unknown attribute kind"
		end
	end
	return true, ""
end

function Schema.ValidateValue(definition: AttributeDefinition, value: unknown): boolean
	if definition.kind == "boolean" then
		return type(value) == "boolean"
	end
	if definition.kind == "enum" then
		return type(value) == "string" and table.find(definition.values or {}, value) ~= nil
	end
	return type(value) == "number"
		and value == value
		and value >= (definition.min or 0)
		and value <= (definition.max or 0)
end

-- JSON and MCP inputs cross an untyped boundary. Decode into fresh typed tables before use.
function Schema.Decode(raw: unknown): (Schema?, string)
	if type(raw) ~= "table" then
		return nil, "Schema must be an object"
	end
	local data = raw :: { [string]: unknown }
	if data.version ~= 1 or type(data.tags) ~= "table" or type(data.attributes) ~= "table" then
		return nil, "Expected version 1, tags array, and attributes array"
	end
	local schema = Schema.Empty()
	for _, input in data.tags :: { unknown } do
		if type(input) ~= "table" then
			return nil, "Invalid tag definition"
		end
		local value = input :: { [string]: unknown }
		if type(value.name) ~= "string" or type(value.description) ~= "string" then
			return nil, "Invalid tag definition"
		end
		table.insert(schema.tags, { name = value.name, description = value.description })
	end
	for _, input in data.attributes :: { unknown } do
		if type(input) ~= "table" then
			return nil, "Invalid attribute definition"
		end
		local value = input :: { [string]: unknown }
		if type(value.name) ~= "string" or type(value.description) ~= "string" then
			return nil, "Invalid attribute definition"
		end
		if value.kind ~= "number" and value.kind ~= "enum" and value.kind ~= "boolean" then
			return nil, "Invalid attribute kind"
		end
		local definition: AttributeDefinition =
			{ name = value.name, description = value.description, kind = value.kind }
		if type(value.min) == "number" then
			definition.min = value.min
		end
		if type(value.max) == "number" then
			definition.max = value.max
		end
		if type(value.values) == "table" then
			local values: { string } = {}
			for _, item in value.values :: { unknown } do
				if type(item) ~= "string" then
					return nil, "Enum values must be strings"
				end
				table.insert(values, item)
			end
			definition.values = values
		end
		table.insert(schema.attributes, definition)
	end
	local valid, message = Schema.Validate(schema)
	return if valid then schema else nil, message
end

function Schema.ValidateAnnotation(schema: Schema, annotation: Types.Annotation): (boolean, string)
	for _, name in annotation.tags do
		local found = false
		for _, definition in schema.tags do
			if name == definition.name then
				found = true
				break
			end
		end
		if not found then
			return false, `Unknown tag: {name}`
		end
	end
	for name, value in annotation.attributes do
		local found: AttributeDefinition? = nil
		for _, definition in schema.attributes do
			if name == definition.name then
				found = definition
				break
			end
		end
		if not found or not Schema.ValidateValue(found, value) then
			return false, `Invalid value for attribute: {name}`
		end
	end
	return true, ""
end

function Schema.ParseValue(definition: AttributeDefinition, text: string): Types.Value?
	local value: Types.Value? = text
	if definition.kind == "number" then
		value = tonumber(text)
	elseif definition.kind == "boolean" then
		value = if text == "true" then true elseif text == "false" then false else nil
	end
	return if Schema.ValidateValue(definition, value) then value else nil
end

return Schema
