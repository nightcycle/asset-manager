--!strict
local HttpService = game:GetService("HttpService")
local Types = require(script.Parent.Parent.Shared.Types)
local Schema = require(script.Parent.Parent.Shared.Schema)
local Database = require(script.Parent.Database)
local Bridge = {}
export type Hooks = { preview: (Instance) -> (), propose: ({ Types.Annotation }) -> () }

local function dictionary(raw: unknown): { [string]: unknown }
	assert(type(raw) == "table", "Expected an object")
	return raw :: { [string]: unknown }
end
local function text(raw: unknown): string
	assert(type(raw) == "string" and #raw <= 4096, "Expected a string of at most 4096 characters")
	return raw
end
local function strings(raw: unknown): { string }
	assert(type(raw) == "table", "Expected an array")
	local result: { string } = {}
	for _, value in raw :: { unknown } do
		assert(#result < 128, "Too many values")
		table.insert(result, text(value))
	end
	return result
end
local function values(raw: unknown): { [string]: Types.Value }
	local result: { [string]: Types.Value } = {}
	local count = 0
	for key, value in dictionary(raw) do
		count += 1
		assert(count <= 128 and type(key) == "string", "Too many attributes or invalid name")
		assert(
			type(value) == "string" or type(value) == "boolean" or type(value) == "number",
			"Unsupported attribute value"
		)
		result[key] = value
	end
	return result
end

function Bridge.Handle(database: Database.Database, hooks: Hooks, raw: unknown): unknown
	local request = dictionary(raw)
	local action = text(request.action)
	if action == "schema" then
		return database.ReadSchema()
	end
	if action == "query" then
		local query: Types.Query = { scope = text(request.scope) }
		if request.search ~= nil then
			query.search = text(request.search)
		end
		if request.className ~= nil then
			query.className = text(request.className)
		end
		if request.tags ~= nil then
			query.tags = strings(request.tags)
		end
		if request.attributes ~= nil then
			query.attributes = values(request.attributes)
		end
		for _, key in { "offset", "limit" } do
			local value = request[key]
			if value ~= nil then
				assert(
					type(value) == "number" and value == value and math.abs(value) < 1e9,
					"Invalid pagination number"
				)
				if key == "offset" then
					query.offset = value
				else
					query.limit = value
				end
			end
		end
		local records, total, ambiguous, catalog = database.Query(query)
		return { records = records, total = total, ambiguous = ambiguous, catalog = catalog }
	end
	if action == "preview" then
		local instance = database.Resolve(text(request.path))
		hooks.preview(instance)
		return {
			record = database.Describe(instance),
			nextStep = "Capture the visible Organizer preview with your Studio screenshot tool; UI rendering is asynchronous.",
		}
	end
	if action == "propose" then
		assert(type(request.annotations) == "table", "Expected annotations array")
		local annotations: { Types.Annotation } = {}
		local schema = database.ReadSchema()
		for _, item in request.annotations :: { unknown } do
			assert(#annotations < 200, "At most 200 proposals per batch")
			local input = dictionary(item)
			local annotation: Types.Annotation =
				{ path = text(input.path), tags = strings(input.tags), attributes = values(input.attributes) }
			local valid, message = Schema.ValidateAnnotation(schema, annotation)
			assert(valid, message)
			database.Resolve(annotation.path)
			table.insert(annotations, annotation)
		end
		assert(#annotations > 0, "Empty proposal")
		hooks.propose(annotations)
		return {
			pending = #annotations,
			message = "Proposals queued for review in Organizer. No instance metadata has changed.",
		}
	end
	error("Unknown action; supported: schema, query, preview, propose")
end

function Bridge.Start(database: Database.Database, hooks: Hooks, parent: Instance): () -> ()
	assert(not parent:FindFirstChild("AssetToolsMCP"), "An AssetToolsMCP bridge is already active")
	local endpoint = Instance.new("BindableFunction")
	endpoint.Name = "AssetToolsMCP"
	endpoint.Archivable = false
	endpoint.OnInvoke = function(json: unknown): string
		local ok, response = pcall(function(): unknown
			assert(type(json) == "string" and #json <= 262144, "Expected JSON of at most 256 KiB")
			local encoded = json
			return Bridge.Handle(database, hooks, HttpService:JSONDecode(encoded))
		end)
		return HttpService:JSONEncode(
			if ok then { ok = true, result = response } else { ok = false, error = tostring(response) }
		)
	end
	endpoint.Parent = parent
	return function()
		endpoint:Destroy()
	end
end
return Bridge
