--!strict
local Types = require(script.Parent.Parent.Shared.Types)
local Schema = require(script.Parent.Parent.Shared.Schema)
local Catalog = {}
export type Builder = { tags: { [string]: number }, attributes: { [string]: { [string]: Types.Value } } }

function Catalog.Empty(): Types.Catalog
	return { tags = {}, attributes = {} }
end
function Catalog.New(): Builder
	return { tags = {}, attributes = {} }
end
function Catalog.ValueId(value: Types.Value): string
	return typeof(value) .. ":" .. tostring(value)
end
function Catalog.ValueLabel(value: Types.Value): string
	return if type(value) == "string" then string.format("%q", value) else tostring(value)
end
local function sortValues(values: { Types.Value })
	table.sort(values, function(a, b)
		if type(a) == "number" and type(b) == "number" then
			return a < b
		end
		return Catalog.ValueId(a) < Catalog.ValueId(b)
	end)
end
function Catalog.Add(builder: Builder, record: Types.Record)
	for _, tag in record.tags do
		builder.tags[tag] = (builder.tags[tag] or 0) + 1
	end
	for name, value in record.attributes do
		if type(value) == "number" and (value ~= value or math.abs(value) == math.huge) then
			continue
		end
		local values = builder.attributes[name] or {}
		values[Catalog.ValueId(value)] = value
		builder.attributes[name] = values
	end
end
function Catalog.Finish(builder: Builder): Types.Catalog
	local result = Catalog.Empty()
	for name, count in builder.tags do
		table.insert(result.tags, { name = name, count = count })
	end
	table.sort(result.tags, function(a, b)
		return if a.count == b.count then a.name < b.name else a.count > b.count
	end)
	for name, unique in builder.attributes do
		local values: { Types.Value } = {}
		for _, value in unique do
			table.insert(values, value)
		end
		sortValues(values)
		result.attributes[name] = values
	end
	return result
end
local function names(unique: { [string]: boolean }): { string }
	local result: { string } = {}
	for name in unique do
		table.insert(result, name)
	end
	table.sort(result)
	return result
end
function Catalog.TagNames(catalog: Types.Catalog, schema: Types.Schema): { string }
	local unique: { [string]: boolean } = {}
	for _, tag in catalog.tags do
		unique[tag.name] = true
	end
	for _, tag in schema.tags do
		unique[tag.name] = true
	end
	return names(unique)
end
function Catalog.AttributeNames(catalog: Types.Catalog, schema: Types.Schema): { string }
	local unique: { [string]: boolean } = {}
	for name in catalog.attributes do
		unique[name] = true
	end
	for _, definition in schema.attributes do
		unique[definition.name] = true
	end
	return names(unique)
end
function Catalog.Values(catalog: Types.Catalog, name: string, definition: Types.AttributeDefinition?): { Types.Value }
	local values: { Types.Value } = {}
	local observed: { Types.Value } = catalog.attributes[name] or {}
	for _, value in observed do
		if not definition or Schema.ValidateValue(definition, value) then
			table.insert(values, value)
		end
	end
	local function add(value: Types.Value)
		if not table.find(values, value) then
			table.insert(values, value)
		end
	end
	if definition then
		if definition.kind == "enum" then
			local allowed: { string } = definition.values or {}
			for _, value in allowed do
				add(value)
			end
		elseif definition.kind == "boolean" then
			add(false)
			add(true)
		end
	end
	sortValues(values)
	return values
end
return Catalog
