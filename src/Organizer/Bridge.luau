--!strict
local HttpService = game:GetService("HttpService")
local Types = require(script.Parent.Parent.Shared.Types)
local Schema = require(script.Parent.Parent.Shared.Schema)
local Database = require(script.Parent.Database)
local Capture = require(script.Parent.Capture)
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

function Bridge.Handle(database: Database.Database, hooks: Hooks, raw: unknown, capture: Capture.Controller?): unknown
	local request = dictionary(raw)
	local action = text(request.action)
	if action == "capture" then
		assert(capture, "Capture sessions require a running Studio bridge")
		local instance = database.Resolve(text(request.path))
		local record = database.Describe(instance)
		assert(record.selectable, "Services are navigation folders, not capture targets")
		return {
			record = record,
			capture = capture.Begin(instance),
			nextStep = "Poll captureStatus with id until ready, call Studio screen_capture without camera overrides, then finishCapture with id in a finally block. The stage expires after 120 seconds.",
		}
	end
	if action == "captureStatus" or action == "finishCapture" then
		assert(capture, "Capture sessions require a running Studio bridge")
		local id = text(request.id)
		return if action == "captureStatus" then capture.Status(id) else capture.Finish(id)
	end
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
		for _, key in { "browse", "recursive" } do
			local value = request[key]
			if value ~= nil then
				assert(type(value) == "boolean", "Browse and recursive must be booleans")
				if key == "browse" then
					query.browse = value
				else
					query.recursive = value
				end
			end
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
		assert(database.Describe(instance).selectable, "Services are navigation folders, not preview targets")
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
			local target = database.Resolve(annotation.path)
			assert(database.Describe(target).selectable, "Services are navigation folders, not annotation targets")
			table.insert(annotations, annotation)
		end
		assert(#annotations > 0, "Empty proposal")
		hooks.propose(annotations)
		return {
			pending = #annotations,
			message = "Proposals queued for review in Organizer. No instance metadata has changed.",
		}
	end
	error("Unknown action; supported: schema, query, preview, capture, captureStatus, finishCapture, propose")
end

function Bridge.Start(database: Database.Database, hooks: Hooks, parent: Instance): () -> ()
	assert(not parent:FindFirstChild("AssetToolsMCP"), "An AssetToolsMCP bridge is already active")
	local endpoint = Instance.new("BindableFunction")
	endpoint.Name = "AssetToolsMCP"
	endpoint.Archivable = false
	local capture = Capture.new()
	local destroying = endpoint.Destroying:Connect(capture.Destroy)
	endpoint.OnInvoke = function(json: unknown): string
		local ok, response = pcall(function(): unknown
			assert(type(json) == "string" and #json <= 262144, "Expected JSON of at most 256 KiB")
			local encoded = json
			return Bridge.Handle(database, hooks, HttpService:JSONDecode(encoded), capture)
		end)
		return HttpService:JSONEncode(
			if ok then { ok = true, result = response } else { ok = false, error = tostring(response) }
		)
	end
	endpoint.Parent = parent
	return function()
		capture.Destroy()
		destroying:Disconnect()
		endpoint:Destroy()
	end
end
return Bridge
