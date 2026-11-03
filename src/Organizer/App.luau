--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local UI = require(script.Parent.Parent.UI.Controls)
local Drawer = require(script.Parent.Parent.UI.Drawer)
local TagChips = require(script.Parent.Parent.UI.TagChips)
local TagPicker = require(script.Parent.Parent.UI.TagPicker)
local InstanceRow = require(script.Parent.Parent.UI.InstanceRow)
local Previewer = require(script.Parent.Parent.Preview.App)
local SchemaEditor = require(script.Parent.Parent.UI.SchemaEditor)
local AnnotationEditor = require(script.Parent.Parent.UI.AnnotationEditor)
local useSelection = require(script.Parent.Parent.UI.useSelection)
local Types = require(script.Parent.Parent.Shared.Types)
local Schema = require(script.Parent.Parent.Shared.Schema)
local Database = require(script.Parent.Database)
local Catalog = require(script.Parent.Catalog)
local Bridge = require(script.Parent.Bridge)
local Navigation = require(script.Parent.Navigation)
local Hierarchy = require(script.Parent.Parent.Shared.Hierarchy)
local Icons = require(script.Parent.Parent.UI.Icons)
local Breadcrumbs = require(script.Parent.Parent.UI.Breadcrumbs)
local Pagination = require(script.Parent.Parent.Shared.Pagination)
local Settings = require(script.Parent.Parent.Shared.ViewSettings)
local SettingsEditor = require(script.Parent.Parent.UI.ViewSettings)
local e = React.createElement
export type Props = {
	database: Database.Database,
	selection: { Instance }?,
	onSelect: (({ Instance }) -> ())?,
	bridgeParent: Instance?,
	initialDrawer: string?,
	initialScope: string?,
	initialSettings: Settings.Settings?,
	onSettings: ((Settings.Settings) -> ())?,
}

return function(props: Props): React.ReactElement
	local database = props.database
	local settings, setSettings = React.useState(props.initialSettings or Settings.Default(true))
	local size, setSize = React.useState(Vector2.new(480, 640))
	local function changeSettings(value: Settings.Settings)
		setSettings(value)
		if props.onSettings then
			props.onSettings(value)
		end
	end
	local rawSelection = useSelection(props.selection)
	local selection = React.useMemo(function(): { Instance }
		local assets: { Instance } = {}
		for _, instance in rawSelection do
			local ok, record = pcall(database.Describe, instance)
			if ok and (record :: Types.Record).selectable then
				table.insert(assets, instance)
			end
		end
		return assets
	end, { database, rawSelection } :: { unknown })
	local drawerOpen, setDrawerOpen = React.useState(props.initialDrawer ~= nil)
	local view, setView = React.useState(props.initialDrawer or "Filters")
	local status, setStatus = React.useState("")
	local queryError, setQueryError = React.useState("")
	local revision, setRevision = React.useState(0)
	local history, setHistory = React.useState(Navigation.New(props.initialScope or "game"))
	local scope = history.entries[history.index]
	local scopeDraft, setScopeDraft = React.useState(scope)
	local search, setSearch = React.useState("")
	local tags, setTags = React.useState({} :: { string })
	local filterName, setFilterName = React.useState("")
	local filterState, setFilterState = React.useState({ value = nil } :: { value: Types.Value? })
	local filterValue = filterState.value
	local searchView = search ~= "" or #tags > 0 or (filterName ~= "" and filterValue ~= nil)
	local grid = settings.viewMode == "Grid"
	local gridHeight = if searchView then 216 else 184
	local gridColumns = math.max(1, math.floor((size.X - 26 + 8) / 152))
	local capacity = Pagination.Capacity(
		math.max(size.X - 26 + 8, 1),
		math.max(size.Y - 80 - 94 - 20 + 8, 1),
		if grid then 152 else math.max(size.X, 1),
		if grid then gridHeight + 8 else 64,
		settings.minItems,
		settings.maxItems
	)
	local function setFilterValue(value: Types.Value?)
		setFilterState({ value = value })
	end
	local page, setPage = React.useState(1)
	local previousCapacity = React.useRef(capacity)
	React.useEffect(function()
		local previous = previousCapacity.current
		previousCapacity.current = capacity
		setPage(function(value)
			return math.floor((value - 1) * previous / capacity) + 1
		end)
	end, { capacity })
	local records, setRecords = React.useState({} :: { Types.Record })
	local catalog, setCatalog = React.useState(Catalog.Empty())
	local total, setTotal = React.useState(0)
	local loading, setLoading = React.useState(false)
	local previewState, setPreviewState = React.useState({ source = nil } :: { source: Instance? })
	local preview = previewState.source
	local function setPreview(source: Instance?)
		setPreviewState({ source = source })
	end
	local proposals, setProposals = React.useState({} :: { Types.Annotation })
	local proposalTargets = React.useRef({} :: { Instance })
	local bridgeEnabled, setBridgeEnabled = React.useState(false)
	local previewSelection = React.useMemo(function(): { Instance }
		return if preview then { preview } else {}
	end, { previewState } :: { unknown })
	local function refresh()
		setRevision(function(value)
			return value + 1
		end)
	end
	local function navigate(path: string, updatedHistory: Navigation.History?)
		local ok, message = pcall(function(): string?
			local target = database.Resolve(path)
			assert(Hierarchy.IsFolder(target) or target == database.Root, "Open a service, Folder, or Configuration")
			return nil
		end)
		if not ok then
			setStatus(tostring(message))
			setQueryError(tostring(message))
			return
		end
		setHistory(updatedHistory or Navigation.Visit(history, path))
		setScopeDraft(path)
		setPage(1)
		setSearch("")
		setTags({})
		setFilterName("")
		setFilterValue(nil)
		setQueryError("")
		setRecords({})
	end
	local function moveHistory(offset: number)
		local updated = Navigation.Move(history, offset)
		navigate(updated.entries[updated.index], updated)
	end
	local function openDrawer(section: string?)
		if section then
			setView(section)
		end
		setDrawerOpen(true)
		refresh()
	end
	local function toggleTag(name: string)
		local updated = table.clone(tags)
		local index = table.find(updated, name)
		if index then
			table.remove(updated, index)
		else
			table.insert(updated, name)
		end
		setTags(updated)
	end
	local schemaResult = React.useMemo(function()
		local ok, value = pcall(database.ReadSchema)
		return {
			schema = if ok then value :: Types.Schema else Schema.Empty(),
			error = if ok then "" else tostring(value),
		}
	end, { database, revision } :: { unknown })
	local schema = schemaResult.schema
	React.useEffect(function()
		local history = game:GetService("ChangeHistoryService")
		local undo, redo = history.OnUndo:Connect(refresh), history.OnRedo:Connect(refresh)
		return function()
			undo:Disconnect()
			redo:Disconnect()
		end
	end, {} :: { unknown })
	React.useEffect(function()
		local first = selection[1]
		if first then
			local ok = pcall(database.Describe, first)
			setPreview(if ok then first else nil)
		else
			setPreview(nil)
		end
	end, { database, selection } :: { unknown })
	React.useEffect(function()
		setPage(1)
	end, { scope, search, tags, filterName, filterState } :: { unknown })
	React.useEffect(
		function()
			local cancelled = false
			setLoading(true)
			task.delay(0.25, function()
				if cancelled then
					return
				end
				local ok, message = pcall(function(): string?
					local attributes: { [string]: Types.Value } = {}
					if filterName ~= "" and filterValue ~= nil then
						attributes[filterName] = filterValue
					end
					local result, count, ambiguous, discovered = database.Query({
						scope = scope,
						browse = true,
						recursive = searchView,
						search = search,
						tags = tags,
						attributes = attributes,
						offset = (page - 1) * capacity,
						limit = capacity,
					}, function()
						return cancelled
					end)
					if cancelled then
						return nil
					end
					if page > math.max(1, math.ceil(count / capacity)) then
						setPage(math.max(1, math.ceil(count / capacity)))
					end
					setRecords(result)
					setTotal(count)
					setCatalog(discovered)
					setQueryError("")
					if ambiguous > 0 then
						setStatus(`Skipped {ambiguous} ambiguous paths; rename duplicate siblings to address them.`)
					end
					return nil
				end)
				if not cancelled then
					setLoading(false)
					if not ok then
						setQueryError(tostring(message))
						setRecords({})
						setTotal(0)
						setCatalog(Catalog.Empty())
					end
				end
			end)
			return function()
				cancelled = true
			end
		end,
		{ database, scope, search, tags, filterName, filterState, searchView, page, capacity, revision } :: { unknown }
	)
	React.useEffect(function(): (() -> ())?
		if not bridgeEnabled or not props.bridgeParent then
			return nil
		end
		local ok, stop = pcall(function()
			return Bridge.Start(database, {
				preview = function(instance)
					setPreview(instance)
					openDrawer("Selection")
				end,
				propose = function(batch)
					assert(#proposalTargets.current == 0, "Review or dismiss the current proposal batch first")
					local targets: { Instance } = {}
					for _, annotation in batch do
						table.insert(targets, database.Resolve(annotation.path))
					end
					proposalTargets.current = targets
					setProposals(batch)
					openDrawer("Review")
				end,
			}, props.bridgeParent :: Instance)
		end)
		if not ok then
			setStatus(tostring(stop))
			setBridgeEnabled(false)
			return nil
		end
		return stop
	end, { bridgeEnabled, database } :: { unknown })
	local selectedPaths: { [string]: boolean } = {}
	for _, instance in selection do
		local ok, record = pcall(database.Describe, instance)
		if ok then
			selectedPaths[(record :: Types.Record).path] = true
		end
	end
	local resultRows: UI.Children = {}
	for index, record in records do
		local resolved, source = pcall(database.Resolve, record.path)
		resultRows[record.path] = e(InstanceRow, {
			record = record,
			source = if resolved and record.kind == "asset" then source else nil,
			thumbnails = not drawerOpen,
			showPath = searchView,
			grid = grid,
			autoPlay = settings.autoPlay,
			selected = record.kind == "asset" and selectedPaths[record.path] == true,
			order = index,
			click = function()
				local ok, instance = pcall(database.Resolve, record.path)
				if ok then
					local currentRecord = database.Describe(instance)
					if currentRecord.kind == "folder" then
						navigate(record.path, nil)
						return
					end
					if not currentRecord.selectable then
						return
					end
					setPreview(instance)
					if props.onSelect then
						props.onSelect({ instance })
					else
						game:GetService("Selection"):Set({ instance })
					end
				else
					setQueryError(tostring(instance))
				end
			end,
		})
	end
	if #records == 0 or queryError ~= "" then
		resultRows.Message = e(UI.Text, {
			text = if queryError ~= ""
				then queryError
				elseif loading then "Searching…"
				else "No matching instances. Adjust your search or filters.",
			height = 70,
			wrapped = true,
			order = 0,
		})
	end
	local availableAttributes = Catalog.AttributeNames(catalog, schema)
	if filterName ~= "" and not table.find(availableAttributes, filterName) then
		table.insert(availableAttributes, filterName)
	end
	local filterValues = Catalog.Values(catalog, filterName, nil)
	if filterValue ~= nil and not table.find(filterValues, filterValue) then
		table.insert(filterValues, filterValue)
	end
	local valueChoices: { UI.Choice } = {}
	for _, value in filterValues do
		table.insert(valueChoices, { id = Catalog.ValueId(value), label = Catalog.ValueLabel(value) })
	end
	local drawerBody: React.ReactNode
	if view == "Settings" then
		drawerBody = e(SettingsEditor, { value = settings, change = changeSettings, organizer = true })
	elseif view == "Schema" then
		drawerBody = e(SchemaEditor, {
			schema = schema,
			catalog = catalog,
			report = setStatus,
			save = function(updated: Types.Schema)
				local ok, message = pcall(function(): string?
					database.SaveSchema(updated)
					return nil
				end)
				setStatus(if ok then "Schema saved in this place." else tostring(message))
				refresh()
			end,
		})
	elseif view == "Selection" then
		drawerBody = e(UI.Column, nil, {
			Preview = if preview
				then e("Frame", { Size = UDim2.new(1, 0, 0, 260), BackgroundTransparency = 1, LayoutOrder = 1 }, {
					App = e(Previewer, {
						key = tostring(settings.autoPlay),
						selection = previewSelection,
						initialSettings = Settings.Decode({ autoPlay = settings.autoPlay }, false),
					}),
				})
				else nil,
			Edit = e(UI.Column, { order = 2 }, {
				Editor = e(AnnotationEditor, {
					schema = schema,
					catalog = catalog,
					selection = selection,
					database = database,
					report = setStatus,
					changed = refresh,
				}),
			}),
		})
	elseif view == "Review" then
		local rows: UI.Children = {}
		for index, annotation in proposals do
			local values = {}
			for key, value in annotation.attributes do
				table.insert(values, key .. " = " .. Catalog.ValueLabel(value))
			end
			table.sort(values)
			local target = proposalTargets.current[index]
			rows[tostring(index)] = e(UI.Text, {
				text = (if target then target:GetFullName() else annotation.path) .. "\nTags: " .. table.concat(
					annotation.tags,
					", "
				) .. "\n" .. table.concat(values, "; "),
				height = 84,
				wrapped = true,
				order = index,
			})
		end
		drawerBody = e(UI.Column, nil, {
			Title = e(UI.Text, { text = `{#proposals} proposed classifications`, order = 1 }),
			Apply = e(UI.Button, {
				text = "Apply proposals",
				primary = true,
				disabled = #proposals == 0,
				order = 2,
				click = function()
					local ok, message = pcall(function(): string?
						for index, annotation in proposals do
							assert(
								database.Resolve(annotation.path) == proposalTargets.current[index],
								"A proposed asset was moved or replaced; request fresh classifications"
							)
						end
						database.Apply(proposals)
						return nil
					end)
					setStatus(if ok then "Classifications applied. Use Studio Undo to revert." else tostring(message))
					if ok then
						proposalTargets.current = {}
						setProposals({})
						refresh()
					end
				end,
			}),
			Dismiss = e(UI.Button, {
				text = "Dismiss proposals",
				disabled = #proposals == 0,
				order = 3,
				click = function()
					proposalTargets.current = {}
					setProposals({})
				end,
			}),
			Rows = e(UI.Column, { order = 4 }, rows),
		})
	else
		drawerBody = e(UI.Column, nil, {
			ScopeLabel = e(UI.Text, { text = "Folder location", order = 1 }),
			Scope = e(
				UI.Input,
				{ text = scopeDraft, change = setScopeDraft, placeholder = "game/Workspace/Assets", order = 2 }
			),
			Open = e(UI.Button, {
				text = "Open location",
				order = 3,
				click = function()
					navigate(scopeDraft, nil)
				end,
			}),
			SelectionScope = e(UI.Button, {
				text = "Open selected folder or containing folder",
				disabled = #rawSelection ~= 1,
				order = 4,
				click = function()
					local target: Instance? = rawSelection[1]
					while target and not Hierarchy.IsFolder(target) and target ~= database.Root do
						target = target.Parent
					end
					if not target then
						return
					end
					local ok, record = pcall(database.Describe, target)
					if ok then
						navigate((record :: Types.Record).path, nil)
					else
						setStatus(tostring(record))
					end
				end,
			}),
			WholePlace = e(UI.Button, {
				text = "Open place root",
				order = 5,
				click = function()
					navigate("game", nil)
				end,
			}),
			TagsLabel = e(UI.Text, { text = "Require all tags", order = 6 }),
			Tags = e(
				TagPicker,
				{ choices = Catalog.TagNames(catalog, schema), selected = tags, change = setTags, order = 7 }
			),
			AttributeLabel = e(UI.Text, { text = "Attribute equals", order = 8 }),
			Attribute = e(UI.Dropdown, {
				items = UI.Choices(availableAttributes),
				selected = if filterName ~= "" then filterName else nil,
				placeholder = "Choose an attribute…",
				order = 9,
				change = function(name: string?)
					setFilterName(name or "")
					setFilterValue(nil)
				end,
			}),
			Value = if filterName ~= ""
				then e(UI.Dropdown, {
					items = valueChoices,
					selected = if filterValue ~= nil then Catalog.ValueId(filterValue) else nil,
					placeholder = "Choose an observed value…",
					order = 10,
					change = function(id: string?)
						local chosen: Types.Value? = nil
						for _, value in filterValues do
							if Catalog.ValueId(value) == id then
								chosen = value
								break
							end
						end
						setFilterValue(chosen)
					end,
				})
				else nil,
			Clear = e(UI.Button, {
				text = "Clear filters",
				order = 11,
				click = function()
					setTags({})
					setFilterName("")
					setFilterValue(nil)
					setSearch("")
				end,
			}),
			Refresh = e(UI.Button, { text = "Refresh instances and suggestions", order = 12, click = refresh }),
			Bridge = if props.bridgeParent
				then e(UI.Button, {
					text = if bridgeEnabled then "Studio MCP bridge: on" else "Enable Studio MCP bridge",
					order = 13,
					click = function()
						setBridgeEnabled(not bridgeEnabled)
					end,
				})
				else nil,
		})
	end
	local pages = math.max(1, math.ceil(total / capacity))
	local footerHeight = if pages > 1 then 94 else 58
	local activeFilters = #tags + (if filterName ~= "" and filterValue ~= nil then 1 else 0)
	local notice = if schemaResult.error ~= ""
		then schemaResult.error
		elseif queryError ~= "" then queryError
		else status
	return e(Studio.Background, {
		[React.Change.AbsoluteSize] = function(frame: Frame)
			setSize(frame.AbsoluteSize)
		end,
	}, {
		Toolbar = e(
			"Frame",
			{ Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 28), BackgroundTransparency = 1 },
			{
				Search = e(Studio.TextInput, {
					Text = search,
					OnChanged = setSearch,
					PlaceholderText = "Search this folder…",
					ClearTextOnFocus = false,
					Size = UDim2.new(1, -130, 1, 0),
				}),
				ViewMode = e(Icons.Button, {
					name = if grid then "view_list" else "grid_view",
					text = if grid then "List" else "Grid",
					position = UDim2.new(1, -122, 0, 0),
					size = UDim2.fromOffset(76, 28),
					click = function()
						local updated = table.clone(settings)
						updated.viewMode = if grid then "List" else "Grid"
						changeSettings(updated)
					end,
				}),
				Menu = e(Icons.Button, {
					name = "menu",
					position = UDim2.new(1, -38, 0, 0),
					size = UDim2.fromOffset(38, 28),
					click = function()
						openDrawer(nil)
					end,
				}),
			}
		),
		Navigation = e(
			"Frame",
			{ Position = UDim2.fromOffset(8, 44), Size = UDim2.new(1, -16, 0, 32), BackgroundTransparency = 1 },
			{
				Back = e(Icons.Button, {
					name = "arrow_back",
					disabled = history.index <= 1,
					click = function()
						moveHistory(-1)
					end,
				}),
				Forward = e(Icons.Button, {
					name = "arrow_forward",
					position = UDim2.fromOffset(32, 0),
					disabled = history.index >= #history.entries,
					click = function()
						moveHistory(1)
					end,
				}),
				Up = e(Icons.Button, {
					name = "arrow_upward",
					position = UDim2.fromOffset(64, 0),
					disabled = scope == "game",
					click = function()
						local parent = Navigation.Parent(scope)
						if parent then
							navigate(parent, nil)
						end
					end,
				}),
				Crumbs = e(
					"Frame",
					{ Position = UDim2.fromOffset(100, 0), Size = UDim2.new(1, -100, 1, 0), BackgroundTransparency = 1 },
					{
						Path = e(Breadcrumbs, {
							path = scope,
							navigate = function(path: string)
								navigate(path, nil)
							end,
						}),
					}
				),
			}
		),
		List = e("Frame", {
			Position = UDim2.fromOffset(0, 80),
			Size = UDim2.new(1, 0, 1, -80 - footerHeight),
			BackgroundTransparency = 1,
		}, {
			Rows = e(UI.Scroll, {
				key = scope .. ":" .. tostring(page) .. settings.viewMode,
				gridColumns = if grid and #records > 0 then gridColumns else nil,
				cellWidth = math.max(1, math.floor((size.X - 26 - 8 * (gridColumns - 1)) / gridColumns)),
				cellHeight = gridHeight,
			}, resultRows),
		}),
		Footer = e("Frame", {
			Position = UDim2.new(0, 8, 1, -footerHeight),
			Size = UDim2.new(1, -16, 0, footerHeight),
			BackgroundTransparency = 1,
		}, {
			Pager = if pages > 1
				then e("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, {
					Controls = e(UI.Pager, { page = page, pages = pages, change = setPage }),
				})
				else nil,
			Count = e("Frame", {
				Position = UDim2.fromOffset(0, if pages > 1 then 34 else 0),
				Size = UDim2.new(1, 0, 0, 20),
				BackgroundTransparency = 1,
			}, {
				Text = e(UI.Text, {
					text = if loading
						then "Searching…"
						else `{total} items` .. (if activeFilters > 0 then ` · {activeFilters} filters` else ""),
					height = 20,
					muted = true,
				}),
			}),
			Tags = e("Frame", {
				Position = UDim2.fromOffset(0, if pages > 1 then 56 else 22),
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
			}, {
				Chips = e(TagChips, { tags = catalog.tags, selected = tags, toggle = toggleTag, limit = 12 }),
			}),
		}),
		Drawer = if drawerOpen
			then e(Drawer, {
				title = "Organizer",
				close = function()
					setDrawerOpen(false)
				end,
			}, {
				Sections = e(UI.Dropdown, {
					clearable = false,
					items = {
						{ id = "Filters", label = "Filters and scope" },
						{ id = "Selection", label = "Selected instances" },
						{ id = "Schema", label = "Tag and attribute schema" },
						{ id = "Review", label = `Review proposals ({#proposals})` },
						{ id = "Settings", label = "View and playback settings" },
					},
					selected = view,
					change = function(value: string?)
						if value then
							setView(value)
						end
					end,
					order = 1,
				}),
				Notice = if notice ~= ""
					then e(UI.Text, { text = notice, height = 64, wrapped = true, order = 2 })
					else nil,
				Body = e(UI.Column, { order = 3 }, { Content = drawerBody }),
			})
			else nil,
	})
end
