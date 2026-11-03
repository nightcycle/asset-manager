--!strict
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Types = require(script.Parent.Parent.Shared.Types)
local Schema = require(script.Parent.Parent.Shared.Schema)
local Paths = require(script.Parent.Parent.Shared.Paths)
local Query = require(script.Parent.Query)
local Catalog = require(script.Parent.Catalog)
local Hierarchy = require(script.Parent.Parent.Shared.Hierarchy)
export type Database = {
	ReadSchema: () -> Types.Schema,
	SaveSchema: (Types.Schema) -> (),
	Describe: (Instance) -> Types.Record,
	Query: (Types.Query, (() -> boolean)?) -> ({ Types.Record }, number, number, Types.Catalog),
	Apply: ({ Types.Annotation }, boolean?) -> (),
	Resolve: (string) -> Instance,
	Root: Instance,
}
local Database = {}
local SCHEMA_NAME = "AssetToolsSchema"

function Database.new(root: Instance, storage: Instance, recordChanges: boolean): Database
	local inCoreGui = Hierarchy.IsExcluded
	local function resolve(path: string): Instance
		local instance, message = Paths.Resolve(path, root)
		assert(instance, message)
		assert(not inCoreGui(instance), "CoreGui instances are excluded from Organizer")
		return instance
	end
	local function schemaValue(): StringValue?
		local existing = storage:FindFirstChild(SCHEMA_NAME)
		assert(not existing or existing:IsA("StringValue"), "AssetToolsSchema name is occupied by a different class")
		return existing :: StringValue?
	end
	local function readSchema(): Types.Schema
		local value = schemaValue()
		if not value then
			return Schema.Empty()
		end
		local raw: unknown = HttpService:JSONDecode(value.Value)
		local schema, message = Schema.Decode(raw)
		assert(schema, `Saved schema is invalid: {message}. Repair AssetToolsSchema before editing.`)
		return schema
	end
	local function transaction(name: string, apply: () -> (), rollback: () -> ())
		local recording: string? = nil
		if recordChanges then
			recording = ChangeHistoryService:TryBeginRecording("AssetTools." .. name, name)
			assert(recording, "Another Studio recording is active; finish it before editing assets")
		end
		local ok, message = pcall(function(): string?
			apply()
			return nil
		end)
		if not ok then
			local restored, restoreError = pcall(function(): string?
				rollback()
				return nil
			end)
			if recording then
				ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
			end
			assert(restored, `Edit failed and rollback failed: {tostring(restoreError)}`)
			error(tostring(message))
		end
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
	end
	local function describeAt(instance: Instance, path: string): Types.Record
		local service = Hierarchy.IsService(instance) or instance:IsA("DataModel")
		local attributes: { [string]: Types.Value } = {}
		local rawAttributes: { [string]: unknown } = if service then {} else instance:GetAttributes()
		for key, value in rawAttributes do
			if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
				attributes[key] = value
			end
		end
		local tags: { string } = if service then {} else instance:GetTags()
		table.sort(tags)
		return {
			path = path,
			name = instance.Name,
			fullName = instance:GetFullName(),
			className = if service then "Folder" else instance.ClassName,
			sourceClassName = instance.ClassName,
			kind = if Hierarchy.IsFolder(instance) then "folder" else "asset",
			selectable = not service and instance ~= root,
			tags = tags,
			attributes = attributes,
		}
	end
	local function describe(instance: Instance): Types.Record
		assert(not inCoreGui(instance), "CoreGui instances are excluded from Organizer")
		local path, message = Paths.Of(instance, root)
		assert(path, message)
		return describeAt(instance, path)
	end
	return {
		Root = root,
		Resolve = resolve,
		ReadSchema = readSchema,
		Describe = describe,
		SaveSchema = function(schema)
			readSchema() -- Never silently replace a malformed or newer persisted schema.
			local valid, message = Schema.Validate(schema)
			assert(valid, message)
			local json = HttpService:JSONEncode(schema)
			local previous = schemaValue()
			local oldValue = if previous then previous.Value else ""
			local created: StringValue? = nil
			transaction("Edit asset schema", function()
				if previous then
					previous.Value = json
				else
					local value = Instance.new("StringValue")
					created = value
					value.Name = SCHEMA_NAME
					value.Value = json
					value.Parent = storage
				end
			end, function()
				if created then
					created:Destroy()
				end
				if previous then
					previous.Value = oldValue
				end
			end)
		end,
		Query = function(query, cancelled)
			local scope, scopeError = Paths.Resolve(query.scope, root)
			assert(scope, scopeError)
			if inCoreGui(scope) then
				return {}, 0, 0, Catalog.Empty()
			end
			assert(
				not query.browse or Hierarchy.IsFolder(scope) or scope == root,
				"Open a service, Folder, or Configuration to browse its children"
			)
			local catalog = Catalog.New()
			local offset = math.max(0, math.floor(query.offset or 0))
			local limit = math.clamp(math.floor(query.limit or 100), 1, 200)
			local results: { Types.Record } = {}
			local total, ambiguous, scanned = 0, 0, 0
			-- Iterative traversal yields every 250 nodes, without allocating GetDescendants for the entire place.
			type Entry = { instance: Instance, path: string?, depth: number }
			local stack: { Entry } = { { instance = scope, path = query.scope, depth = 0 } }
			local savedSchema = storage:FindFirstChild(SCHEMA_NAME)
			local function hidden(instance: Instance): boolean
				return instance:IsA("CoreGui")
					or instance == savedSchema
					or (
						instance.Name == "AssetToolsMCP"
						and instance:IsA("BindableFunction")
						and not instance.Archivable
					)
			end
			-- Cache folder contents once per query, including branches of only empty folders.
			-- Files remain atomic, and private plugin data cannot make a folder appear populated.
			local populated: { [Instance]: boolean } = {}
			if query.browse then
				local pending: { Instance } = { scope }
				local folders: { Instance } = {}
				while #pending > 0 do
					if cancelled and cancelled() then
						return {}, 0, 0, Catalog.Empty()
					end
					local folder = table.remove(pending) :: Instance
					populated[folder] = false
					table.insert(folders, folder)
					for _, child in folder:GetChildren() do
						if not hidden(child) then
							if Hierarchy.IsFolder(child) then
								table.insert(pending, child)
							else
								populated[folder] = true
							end
						end
						scanned += 1
						if scanned % 250 == 0 then
							task.wait()
							if cancelled and cancelled() then
								return {}, 0, 0, Catalog.Empty()
							end
						end
					end
				end
				for index = #folders, 1, -1 do
					local folder = folders[index]
					local parent = folder.Parent
					if populated[folder] and parent and populated[parent] ~= nil then
						populated[parent] = true
					end
				end
			end
			while #stack > 0 do
				if cancelled and cancelled() then
					return {}, 0, 0, Catalog.Empty()
				end
				local entry = table.remove(stack) :: Entry
				local instance, path = entry.instance, entry.path
				if hidden(instance) or (query.browse and Hierarchy.IsFolder(instance) and not populated[instance]) then
					continue
				end
				local children: { Instance } = if not query.browse
						or Hierarchy.IsFolder(instance)
						or instance == root
					then instance:GetChildren()
					else {}
				local names: { [string]: number } = {}
				for _, child in children do
					names[child.Name] = (names[child.Name] or 0) + 1
				end
				table.sort(children, function(a, b)
					if query.browse and Hierarchy.IsFolder(a) ~= Hierarchy.IsFolder(b) then
						return Hierarchy.IsFolder(a)
					end
					return a.Name < b.Name
				end)
				for i = #children, 1, -1 do
					local child = children[i]
					table.insert(stack, {
						instance = child,
						path = if path and names[child.Name] == 1 then path .. "/" .. Paths.Encode(child.Name) else nil,
						depth = entry.depth + 1,
					})
				end
				local service = Hierarchy.IsService(instance) or instance:IsA("DataModel")
				if path and (query.browse or not service) then
					local record = describeAt(instance, path)
					if not query.browse or entry.depth > 0 then
						Catalog.Add(catalog, record)
					end
					local included = if query.browse
						then entry.depth > 0 and (query.recursive ~= false or entry.depth == 1)
						else query.recursive ~= false or entry.depth <= 1
					if included and Query.Matches(record, query) then
						total += 1
						if total > offset and #results < limit then
							table.insert(results, record)
						end
					end
				elseif not path then
					ambiguous += 1
				end
				scanned += 1
				if scanned % 250 == 0 then
					task.wait()
				end
			end
			return results, total, ambiguous, Catalog.Finish(catalog)
		end,
		Apply = function(annotations, removeTags)
			assert(#annotations > 0 and #annotations <= 200, "Apply 1–200 annotations at a time")
			local schema = readSchema()
			local targets: { Instance } = {}
			local snapshots: { { tags: { string }, attributes: { [string]: unknown } } } = {}
			local seen: { [Instance]: boolean } = {}
			for _, annotation in annotations do
				local valid, message = Schema.ValidateAnnotation(schema, annotation)
				assert(valid, message)
				local instance = resolve(annotation.path)
				assert(not Hierarchy.IsService(instance), "Services are navigation folders, not annotation targets")
				assert(instance ~= root and instance ~= schemaValue(), "Cannot annotate the database or DataModel root")
				assert(not seen[instance], "Duplicate target in annotation batch")
				seen[instance] = true
				table.insert(targets, instance)
				table.insert(snapshots, { tags = instance:GetTags(), attributes = instance:GetAttributes() })
			end
			transaction("Annotate assets", function()
				for index, annotation in annotations do
					local instance = targets[index]
					for _, tag in annotation.tags do
						if removeTags then
							instance:RemoveTag(tag)
						else
							instance:AddTag(tag)
						end
					end
					for name, value in annotation.attributes do
						instance:SetAttribute(name, value)
					end
				end
			end, function()
				for index, instance in targets do
					local snapshot = snapshots[index]
					for _, tag in instance:GetTags() do
						instance:RemoveTag(tag)
					end
					for _, tag in snapshot.tags do
						instance:AddTag(tag)
					end
					for name in annotations[index].attributes do
						instance:SetAttribute(name, snapshot.attributes[name])
					end
				end
			end)
		end,
	}
end
return Database
