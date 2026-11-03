--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local Settings = require(script.Parent.Parent.Shared.ViewSettings)
local UI = require(script.Parent.Controls)
local e = React.createElement
return function(
	props: { value: Settings.Settings, change: (Settings.Settings) -> (), capacity: number? }
): React.ReactElement
	local fixed = Settings.PageSize(props.value)
	local draft, setDraft = React.useState(tostring(fixed or props.capacity or 24))
	local message, setMessage = React.useState("")
	React.useEffect(function()
		setDraft(tostring(fixed or props.capacity or 24))
		setMessage("")
	end, { props.value.viewMode, fixed or 0, props.capacity or 0 } :: { unknown })
	return e(UI.Column, nil, {
		Title = e(UI.Text, { text = props.value.viewMode .. " items per page", order = 1 }),
		Automatic = e(Studio.Checkbox, {
			Label = "Automatic page size",
			Value = fixed == nil,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 2,
			OnChanged = function()
				props.change(Settings.WithPageSize(props.value, if fixed then nil else props.capacity or 24))
			end,
		}),
		Count = if fixed then e(UI.Input, { text = draft, change = setDraft, order = 3 }) else nil,
		Apply = if fixed
			then e(UI.Button, {
				text = "Apply items per page",
				order = 4,
				click = function()
					local count = tonumber(draft)
					if not count or count % 1 ~= 0 or count < 1 or count > 200 then
						setMessage("Enter a whole number from 1 to 200.")
						return
					end
					setMessage("")
					props.change(Settings.WithPageSize(props.value, count))
				end,
			})
			else nil,
		Help = e(UI.Text, {
			text = if fixed
				then "Saved separately for List and Grid."
				else "Grid loads 3× the automatic item count, within the limits below.",
			wrapped = true,
			height = 42,
			order = 5,
		}),
		Error = if message ~= "" then e(UI.Text, { text = message, wrapped = true, height = 40, order = 6 }) else nil,
	})
end
