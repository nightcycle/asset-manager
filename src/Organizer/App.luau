--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local UI = require(script.Parent.Parent.UI.Controls)
local PreviewCard = require(script.Parent.Parent.UI.PreviewCard)
local SchemaEditor = require(script.Parent.Parent.UI.SchemaEditor)
local AnnotationEditor = require(script.Parent.Parent.UI.AnnotationEditor)
local useSelection = require(script.Parent.Parent.UI.useSelection)
local Types = require(script.Parent.Parent.Shared.Types)
local Paths = require(script.Parent.Parent.Shared.Paths)
local Schema = require(script.Parent.Parent.Shared.Schema)
local Database = require(script.Parent.Database)
local Bridge = require(script.Parent.Bridge)
local e = React.createElement
export type Props = {
	database: Database.Database,
	selection: { Instance }?,
	onSelect: (({ Instance }) -> ())?,
	bridgeParent: Instance?,
}

return function(props: Props): React.ReactElement
	local database = props.database
	local selection = useSelection(props.selection)
	local tab, setTab = React.useState("Browse")
	local status, setStatus = React.useState("Define tags and attributes in Schema to get started.")
	local revision, setRevision = React.useState(0)
	local scope, setScope = React.useState("game")
	local search, setSearch = React.useState("")
	local tags, setTags = React.useState("")
	local filterName, setFilterName = React.useState("")
	local filterValue, setFilterValue = React.useState("")
	local page, setPage = React.useState(1)
	local records, setRecords = React.useState({} :: { Types.Record })
	local total, setTotal = React.useState(0)
	local loading, setLoading = React.useState(false)
	local preview, setPreview = React.useState(nil :: Instance?)
	local proposals, setProposals = React.useState({} :: { Types.Annotation })
	local proposalTargets = React.useRef({} :: { Instance })
	local bridgeEnabled, setBridgeEnabled = React.useState(false)
	local function refresh()
		setRevision(function(value)
			return value + 1
		end)
	end
	local schemaResult = React.useMemo(function()
		local ok, value = pcall(database.ReadSchema)
		return {
			schema = if ok then value :: Types.Schema else Schema.Empty(),
			error = if ok then "" else tostring(value),
		}
	end, { database, revision } :: { unknown })
	local schema = schemaResult.schema
	React.useEffect(function(): (() -> ())?
		local history = game:GetService("ChangeHistoryService")
		local undo = history.OnUndo:Connect(refresh)
		local redo = history.OnRedo:Connect(refresh)
		return function()
			undo:Disconnect()
			redo:Disconnect()
		end
	end, {} :: { unknown })
	React.useEffect(function()
		setPage(1)
	end, { scope, search, tags, filterName, filterValue } :: { unknown })
	React.useEffect(function(): (() -> ())?
		local cancelled = false
		setLoading(true)
		task.delay(0.25, function()
			if cancelled then
				return
			end
			local ok, message = pcall(function(): string?
				local requestedTags: { string } = {}
				for tag in tags:gmatch("[^,]+") do
					table.insert(requestedTags, (tag:gsub("^%s*(.-)%s*$", "%1")))
				end
				local attributes: { [string]: Types.Value } = {}
				if filterName ~= "" then
					local found: Types.AttributeDefinition? = nil
					for _, definition in schema.attributes do
						if definition.name == filterName then
							found = definition
						end
					end
					assert(found, "Filter attribute must exist in Schema")
					local value = Schema.ParseValue(found, filterValue)
					assert(value ~= nil, "Filter value is outside its allowed range")
					attributes[filterName] = value
				end
				local result, count, ambiguous = database.Query({
					scope = scope,
					search = search,
					tags = requestedTags,
					attributes = attributes,
					offset = (page - 1) * 50,
					limit = 50,
				}, function()
					return cancelled
				end)
				if cancelled then
					return nil
				end
				if page > math.max(1, math.ceil(count / 50)) then
					setPage(math.max(1, math.ceil(count / 50)))
				end
				setRecords(result)
				setTotal(count)
				if ambiguous > 0 then
					setStatus(`Skipped {ambiguous} ambiguous paths; rename duplicate siblings to address them.`)
				end
				return nil
			end)
			if not cancelled then
				setLoading(false)
				if not ok then
					setStatus(tostring(message))
					setRecords({})
					setTotal(0)
				end
			end
		end)
		return function()
			cancelled = true
		end
	end, { database, scope, search, tags, filterName, filterValue, page, revision } :: { unknown })
	React.useEffect(function(): (() -> ())?
		if not bridgeEnabled or not props.bridgeParent then
			return nil
		end
		local ok, stop = pcall(function()
			return Bridge.Start(database, {
				preview = function(instance)
					setPreview(instance)
					setTab("Preview")
				end,
				propose = function(batch)
					assert(#proposalTargets.current == 0, "Review or dismiss the current proposal batch first")
					local targets: { Instance } = {}
					for _, annotation in batch do
						table.insert(targets, database.Resolve(annotation.path))
					end
					proposalTargets.current = targets
					setProposals(batch)
					setTab("Review")
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
	local function selectInstances(instances: { Instance })
		if props.onSelect then
			props.onSelect(instances)
		else
			game:GetService("Selection"):Set(instances)
		end
	end
	local resultRows: UI.Children = {}
	for index, record in records do
		resultRows[record.path] = e(UI.Button, {
			text = record.fullName .. "  [" .. record.className .. "]",
			order = index,
			click = function()
				local ok, result = pcall(database.Resolve, record.path)
				if ok then
					setPreview(result)
					setTab("Preview")
					selectInstances({ result })
				else
					setStatus(tostring(result))
				end
			end,
		})
	end
	local reviewRows: UI.Children = {}
	for index, annotation in proposals do
		local values = {}
		for key, value in annotation.attributes do
			table.insert(values, key .. " = " .. tostring(value))
		end
		table.sort(values)
		local target = proposalTargets.current[index]
		reviewRows[tostring(index)] = e(UI.Text, {
			text = (if target then target:GetFullName() else annotation.path) .. "\nTags: " .. table.concat(
				annotation.tags,
				", "
			) .. "\n" .. table.concat(values, "; "),
			height = 84,
			wrapped = true,
			order = index,
		})
	end
	local body: React.ReactNode
	if tab == "Schema" then
		body = e(SchemaEditor, {
			schema = schema,
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
	elseif tab == "Preview" and preview then
		body = e(UI.Column, nil, {
			Back = e(UI.Button, {
				text = "‹ Back to results",
				order = 1,
				click = function()
					setTab("Browse")
				end,
			}),
			Card = e(PreviewCard, {
				source = preview,
				options = { background = "Studio", playing = true, mirrorLighting = true },
				size = UDim2.new(1, 0, 0, 320),
				order = 2,
			}),
			Edit = e(UI.Column, { order = 3 }, {
				Editor = e(AnnotationEditor, {
					schema = schema,
					selection = selection,
					database = database,
					report = setStatus,
					changed = refresh,
				}),
			}),
		})
	elseif tab == "Review" then
		body = e(UI.Column, nil, {
			Title = e(UI.Text, { text = `{#proposals} proposed classifications`, order = 1 }),
			Actions = e(UI.Row, { order = 2 }, {
				Apply = e(UI.Button, {
					text = "Apply proposals",
					width = 140,
					primary = true,
					disabled = #proposals == 0,
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
						setStatus(
							if ok then "Classifications applied. Use Studio Undo to revert." else tostring(message)
						)
						if ok then
							proposalTargets.current = {}
							setProposals({})
							refresh()
						end
					end,
				}),
				Dismiss = e(UI.Button, {
					text = "Dismiss",
					width = 86,
					click = function()
						proposalTargets.current = {}
						setProposals({})
					end,
				}),
			}),
			Rows = e(UI.Column, { order = 3 }, reviewRows),
		})
	else
		body = e(UI.Column, nil, {
			Scope = e(UI.Input, { text = scope, change = setScope, placeholder = "game/Workspace/Assets", order = 1 }),
			Actions = e(UI.Row, { order = 2 }, {
				Scope = e(UI.Button, {
					text = "Scope to selection",
					width = 144,
					disabled = #selection ~= 1,
					click = function()
						local path, message = Paths.Of(selection[1], database.Root)
						if path then
							setScope(path)
						else
							setStatus(message or "Invalid scope")
						end
					end,
				}),
				Refresh = e(UI.Button, { text = "Refresh", width = 80, click = refresh }),
			}),
			Search = e(
				UI.Input,
				{ text = search, change = setSearch, placeholder = "Search names, classes, or paths", order = 3 }
			),
			Tags = e(
				UI.Input,
				{ text = tags, change = setTags, placeholder = "Require all tags, comma separated", order = 4 }
			),
			FilterName = e(
				UI.Input,
				{ text = filterName, change = setFilterName, placeholder = "Filter by attribute (optional)", order = 5 }
			),
			FilterValue = e(
				UI.Input,
				{ text = filterValue, change = setFilterValue, placeholder = "Attribute equals…", order = 6 }
			),
			Count = e(UI.Text, {
				text = if loading then "Searching…" else `{total} matches · click a row to select and preview`,
				order = 7,
			}),
			Results = e("Frame", { Size = UDim2.new(1, 0, 0, 210), BackgroundTransparency = 1, LayoutOrder = 8 }, {
				Scroll = e(UI.Scroll, nil, resultRows),
			}),
			Pager = e(
				"Frame",
				{ Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 9 },
				{ Pager = e(UI.Pager, { page = page, pages = math.max(1, math.ceil(total / 50)), change = setPage }) }
			),
			Preview = if preview
				then e(PreviewCard, {
					source = preview,
					options = { background = "Studio", playing = true, mirrorLighting = true },
					size = UDim2.new(1, 0, 0, 250),
					order = 10,
				})
				else nil,
			Edit = e("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 11,
			}, {
				Editor = e(AnnotationEditor, {
					schema = schema,
					selection = selection,
					database = database,
					report = setStatus,
					changed = refresh,
				}),
			}),
		})
	end
	return e(UI.Scroll, nil, {
		Title = e(UI.Text, { text = "ORGANIZER", order = 1 }),
		Tabs = e(UI.Row, { order = 2 }, {
			Browse = e(UI.Button, {
				text = "Browse",
				width = 84,
				primary = tab == "Browse",
				order = 1,
				click = function()
					setTab("Browse")
				end,
			}),
			Schema = e(UI.Button, {
				text = "Schema",
				width = 84,
				primary = tab == "Schema",
				order = 2,
				click = function()
					setTab("Schema")
				end,
			}),
			Review = e(UI.Button, {
				text = `Review ({#proposals})`,
				width = 98,
				primary = tab == "Review",
				order = 3,
				click = function()
					setTab("Review")
				end,
			}),
		}),
		Status = e(UI.Text, {
			text = if schemaResult.error ~= "" then schemaResult.error else status,
			height = 54,
			wrapped = true,
			order = 3,
		}),
		Bridge = if props.bridgeParent
			then e(UI.Button, {
				text = if bridgeEnabled then "Studio MCP bridge: on" else "Enable Studio MCP bridge",
				order = 4,
				click = function()
					setBridgeEnabled(not bridgeEnabled)
				end,
			})
			else nil,
		Body = e("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 5,
		}, { Content = body }),
	})
end
