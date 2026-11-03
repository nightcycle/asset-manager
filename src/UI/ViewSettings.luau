--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local Settings = require(script.Parent.Parent.Shared.ViewSettings)
local UI = require(script.Parent.Controls)
local ExplorerPages = require(script.Parent.ExplorerPageSettings)
local e = React.createElement
export type Props = {
	value: Settings.Settings,
	change: (Settings.Settings) -> (),
	organizer: boolean?,
	capacity: number?,
}
return function(props: Props): React.ReactElement
	local minimum, setMinimum = React.useState(tostring(props.value.minItems))
	local maximum, setMaximum = React.useState(tostring(props.value.maxItems))
	local errorText, setError = React.useState("")
	React.useEffect(function()
		setMinimum(tostring(props.value.minItems))
		setMaximum(tostring(props.value.maxItems))
	end, { props.value.minItems, props.value.maxItems })
	local cap = if props.organizer then 200 else 64
	return e(UI.Column, nil, {
		Mode = if props.organizer
			then e(UI.Dropdown, {
				items = { { id = "List", label = "List view" }, { id = "Grid", label = "Grid view" } },
				selected = props.value.viewMode :: string,
				clearable = false,
				order = 1,
				change = function(value: string?)
					if value == "List" or value == "Grid" then
						local updated = table.clone(props.value)
						updated.viewMode = value
						props.change(updated)
					end
				end,
			})
			else nil,
		ExplorerPages = if props.organizer
			then e(UI.Column, { order = 3 }, {
				Editor = e(ExplorerPages, { value = props.value, change = props.change, capacity = props.capacity }),
			})
			else nil,
		Autoplay = e(Studio.Checkbox, {
			Label = "Auto-play assets",
			Value = props.value.autoPlay,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 2,
			OnChanged = function()
				local updated = table.clone(props.value)
				updated.autoPlay = not updated.autoPlay
				props.change(updated)
			end,
		}),
		Limits = if not props.organizer or Settings.PageSize(props.value) == nil
			then e(UI.Column, { order = 4 }, {
				Label = e(UI.Text, {
					text = `Items per page · automatic ({props.value.minItems}–{props.value.maxItems})`,
					wrapped = true,
					height = 40,
					order = 4,
				}),
				MinLabel = e(UI.Text, { text = "Minimum items per page", order = 5 }),
				Min = e(UI.Input, { text = minimum, change = setMinimum, order = 6 }),
				MaxLabel = e(UI.Text, { text = "Maximum items per page", order = 7 }),
				Max = e(UI.Input, { text = maximum, change = setMaximum, order = 8 }),
				Apply = e(UI.Button, {
					text = "Apply page limits",
					order = 9,
					click = function()
						local low, high = tonumber(minimum), tonumber(maximum)
						if
							not low
							or not high
							or low % 1 ~= 0
							or high % 1 ~= 0
							or low < 1
							or high > cap
							or low > high
						then
							setError(`Use whole numbers from 1 to {cap}, with minimum ≤ maximum.`)
							return
						end
						local updated = table.clone(props.value)
						updated.minItems, updated.maxItems = low, high
						setError("")
						props.change(updated)
					end,
				}),
				Error = if errorText ~= ""
					then e(UI.Text, { text = errorText, wrapped = true, height = 48, order = 10 })
					else nil,
			})
			else nil,
	})
end
