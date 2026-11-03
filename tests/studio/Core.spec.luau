--!strict
local Source = script.Parent.Parent.Source
local Schema = require(Source.Shared.Schema)
local Paths = require(Source.Shared.Paths)
local Pagination = require(Source.Shared.Pagination)
local Types = require(Source.Shared.Types)
local Database = require(Source.Organizer.Database)
local Bridge = require(Source.Organizer.Bridge)
local Registry = require(Source.Preview.Registry)
local Cleanup = require(Source.Shared.Cleanup)
local PreviewSelection = require(Source.Preview.Selection)

return function(): number
	local count = 0
	local function check(condition: boolean, message: string)
		assert(condition, message)
		count += 1
	end
	local schema: Types.Schema = {
		version = 1,
		tags = { { name = "Nature", description = "Natural assets" } },
		attributes = {
			{ name = "Score", description = "Visual complexity", kind = "number", min = 0, max = 5 },
			{ name = "Biome", description = "Environment", kind = "enum", values = { "Forest", "Desert" } },
			{ name = "Stylized", description = "Exaggerated shape", kind = "boolean" },
		},
	}
	check(Schema.Validate(schema), "Valid schema rejected")
	check(Schema.ValidateValue(schema.attributes[1], 0), "Inclusive minimum")
	check(Schema.ValidateValue(schema.attributes[1], 5), "Inclusive maximum")
	check(not Schema.ValidateValue(schema.attributes[1], 6), "Out-of-range accepted")
	check(not Schema.ValidateValue(schema.attributes[1], 0 / 0), "NaN accepted")
	check(not Schema.ValidateValue(schema.attributes[1], math.huge), "Infinity accepted")
	check(not Schema.ValidateValue(schema.attributes[1], "1"), "Wrong type accepted")
	check(Schema.ValidateValue(schema.attributes[2], "Forest"), "Enum value rejected")
	check(not Schema.ValidateValue(schema.attributes[2], "Ocean"), "Unknown enum accepted")
	check(Schema.ParseValue(schema.attributes[3], "false") == false, "False lost as nil")
	check(Schema.Decode({ version = 2, tags = {}, attributes = {} }) == nil, "Future schema version accepted")
	check(
		Schema.Decode({ version = 1, tags = { { name = "NoDescription" } }, attributes = {} }) == nil,
		"Missing description accepted"
	)
	local duplicates = Schema.Empty()
	duplicates.tags = { schema.tags[1], schema.tags[1] }
	check(not Schema.Validate(duplicates), "Duplicate names accepted")
	local invalidBounds = Schema.Empty()
	invalidBounds.attributes = { { name = "Score", description = "Score", kind = "number", min = 2, max = 1 } }
	check(not Schema.Validate(invalidBounds), "Inverted range accepted")
	check(
		not Schema.ValidateAnnotation(schema, { path = "game", tags = { "Unknown" }, attributes = {} }),
		"Unknown tag accepted"
	)

	local container = Instance.new("Folder")
	local configuration = Instance.new("Configuration")
	configuration.Parent = container
	local nestedPart = Instance.new("Part")
	nestedPart.Parent = configuration
	local model = Instance.new("Model")
	model.Parent = configuration
	local modelPart = Instance.new("Part")
	modelPart.Parent = model
	local empty = Instance.new("Folder")
	empty.Parent = container
	local expanded, containers = PreviewSelection.Expand({ container, configuration, nestedPart })
	check(#expanded == 2 and #containers == 3, "Containers or duplicate children became preview tiles")
	check(expanded[1] == nestedPart and expanded[2] == model, "Nested expansion lost child order or split a Model")
	check(#PreviewSelection.Expand({ empty }) == 0, "Empty container became a fallback preview")
	local added = Instance.new("Part")
	added.Parent = empty
	expanded = PreviewSelection.Expand({ container })
	check(#expanded == 3 and expanded[3] == added, "Added child missing from expanded selection")
	nestedPart.Parent = nil
	expanded = PreviewSelection.Expand({ container, added })
	check(#expanded == 2 and expanded[1] == model and expanded[2] == added, "Removed child or overlap persisted")
	nestedPart:Destroy()
	container:Destroy()

	local root = Instance.new("Folder")
	root.Name = "Root"
	local assets = Instance.new("Folder")
	assets.Name = "Assets/100%.测试"
	assets.Parent = root
	local part = Instance.new("Part")
	part.Name = "Rock"
	part.Parent = assets
	local path = Paths.Of(part, root)
	check(path ~= nil and Paths.Resolve(path :: string, root) == part, "Escaped path round trip")
	check(Paths.Resolve("game/Assets%2f100%25.%E6%B5%8B%E8%AF%95/Rock", root) == nil, "Noncanonical path accepted")
	check(Paths.Resolve("game/Missing", root) == nil, "Missing path accepted")
	local twin = Instance.new("Part")
	twin.Name = part.Name
	twin.Parent = assets
	check(Paths.Of(part, root) == nil, "Ambiguous path generated")
	check(Paths.Resolve(path :: string, root) == nil, "Ambiguous path resolved")
	twin:Destroy()
	local database = Database.new(root, root, false)
	database.SaveSchema(schema)
	check((database.ReadSchema().attributes[2].values or {})[1] == "Forest", "Schema persistence")
	part:SetAttribute("External", "preserved")
	part:AddTag("Unmanaged")
	database.Apply({
		{ path = path :: string, tags = { "Nature" }, attributes = { Score = 3, Biome = "Forest", Stylized = false } },
	})
	check(part:HasTag("Nature") and part:GetAttribute("Score") == 3, "Annotation not applied")
	check(
		part:GetAttribute("Stylized") == false
			and part:HasTag("Unmanaged")
			and part:GetAttribute("External") == "preserved",
		"Unmanaged metadata or false lost"
	)
	local found, total = database.Query({
		scope = Paths.Of(assets, root) :: string,
		tags = { "Nature" },
		attributes = { Stylized = false } :: { [string]: Types.Value },
		limit = 1,
	})
	check(total == 1 and #found == 1 and found[1].path == path, "Scoped combined query")
	local _, emptyTotal = database.Query({ scope = "game", search = "missing" })
	check(emptyTotal == 0, "Search mismatch")
	local outside = Instance.new("Part")
	outside.Name = "Other"
	outside:AddTag("Nature")
	outside.Parent = root
	local _, scopedTotal = database.Query({ scope = Paths.Of(assets, root) :: string, tags = { "Nature" } })
	check(scopedTotal == 1, "Scope leaked to sibling")
	local page, all = database.Query({ scope = "game", tags = { "Nature" }, offset = 1, limit = 1 })
	check(#page == 1 and all == 2, "Query pagination")
	local ok = pcall(function()
		database.Apply({
			{ path = path :: string, tags = {}, attributes = { Score = 4 } },
			{ path = Paths.Of(outside, root) :: string, tags = {}, attributes = { Score = 99 } },
		})
	end)
	check(not ok and part:GetAttribute("Score") == 3, "Invalid batch partially changed targets")
	database.Apply({ { path = path :: string, tags = { "Nature" }, attributes = {} } }, true)
	check(not part:HasTag("Nature") and part:HasTag("Unmanaged"), "Tag removal affected unrelated tags")
	local proposed: { Types.Annotation } = {}
	local previewed: Instance? = nil
	local hooks: Bridge.Hooks = {
		preview = function(instance)
			previewed = instance
		end,
		propose = function(batch)
			proposed = batch
		end,
	}
	Bridge.Handle(database, hooks, { action = "preview", path = path })
	check(previewed == part, "MCP preview didn't reach UI")
	Bridge.Handle(
		database,
		hooks,
		{ action = "propose", annotations = { { path = path, tags = { "Nature" }, attributes = { Score = 5 } } } }
	)
	check(
		#proposed == 1 and part:GetAttribute("Score") == 3 and not part:HasTag("Nature"),
		"MCP proposal mutated metadata"
	)
	check(
		not pcall(
			Bridge.Handle,
			database,
			hooks,
			{ action = "propose", annotations = { { path = path, tags = {}, attributes = { Score = 9 } } } }
		),
		"MCP accepted invalid classification"
	)
	check(
		not pcall(Bridge.Handle, database, hooks, { action = "query", scope = "game", limit = math.huge }),
		"MCP accepted unbounded pagination"
	)
	check(
		not pcall(Bridge.Handle, database, hooks, { action = "execute", code = "print('no')" }),
		"MCP arbitrary execution accepted"
	)
	part.Name = "Renamed"
	check(not pcall(function()
		database.Apply(proposed)
	end), "Stale proposal path accepted")
	local saved = root:FindFirstChild("AssetToolsSchema") :: StringValue
	saved.Value = "{}"
	check(not pcall(database.ReadSchema), "Corrupt schema silently loaded")
	check(not pcall(database.SaveSchema, schema) and saved.Value == "{}", "Corrupt schema silently overwritten")

	for _, item in { { 0, 9, 4, 1, 1, 1, 0 }, { 10, 8, 4, 3, 3, 9, 10 }, { 2, 0, 1, 1, 2, 1, 1 } } do
		local current, pages, first, last = Pagination.Page(item[1], item[2], item[3])
		check(current == item[4] and pages == item[5] and first == item[6] and last == item[7], "Page boundary failure")
	end
	check(Registry.Resolve(part).id == "geometry", "Part renderer")
	local classes: { [string]: string } = {
		Animation = "animation",
		ParticleEmitter = "particles",
		Decal = "image",
		Texture = "image",
		ImageLabel = "image",
		Sound = "sound",
		TextLabel = "gui",
		Configuration = "fallback",
	}
	for class, renderer in classes do
		local instance = Instance.new(class)
		check(Registry.Resolve(instance).id == renderer, `Wrong renderer for {class}`)
		instance:Destroy()
	end
	local cleanup = Cleanup.new()
	local order = {}
	cleanup:Add(function()
		table.insert(order, 1)
	end)
	cleanup:Add(function()
		table.insert(order, 2)
	end)
	cleanup:Destroy()
	cleanup:Destroy()
	cleanup:Add(function()
		table.insert(order, 3)
	end)
	check(table.concat(order, ",") == "2,1,3", "Cleanup is not idempotent/LIFO or leaked a late resource")
	root:Destroy()
	return count
end
