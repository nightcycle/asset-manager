--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local UI = require(script.Parent.Controls)
local Drawer = require(script.Parent.Drawer)
local Types = require(script.Parent.Parent.Shared.Types)
local Settings = require(script.Parent.Parent.Shared.ViewSettings)
local SettingsEditor = require(script.Parent.ViewSettings)
local e = React.createElement
export type Props = {
	options: Types.PreviewOptions,
	changeOptions: (Types.PreviewOptions) -> (),
	capacity: number,
	settings: Settings.Settings,
	changeSettings: (Settings.Settings) -> (),
	close: () -> (),
}

return function(props: Props): React.ReactElement
	React.useEffect(function()
		local connection = game:GetService("UserInputService").InputBegan:Connect(function(input: InputObject)
			if input.KeyCode == Enum.KeyCode.Escape then
				props.close()
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { props.close } :: { unknown })
	return e(Drawer, { title = "Preview options", close = props.close }, {
		Background = e(UI.Button, {
			text = "Background: " .. props.options.background,
			order = 2,
			click = function()
				local updated = table.clone(props.options)
				updated.background = if updated.background == "Studio"
					then "Dark"
					elseif updated.background == "Dark" then "Light"
					else "Studio"
				props.changeOptions(updated)
			end,
		}),
		Framing = e(UI.Dropdown, {
			items = {
				{ id = "Fit", label = "Fit · show the whole asset" },
				{ id = "Fill", label = "Fill · crop to fill the preview" },
			},
			selected = (props.options.scaleMode or "Fit") :: string,
			clearable = false,
			order = 3,
			change = function(value: string?)
				if value == "Fit" or value == "Fill" then
					local updated = table.clone(props.options)
					updated.scaleMode = value
					props.changeOptions(updated)
				end
			end,
		}),
		Count = e(
			UI.Text,
			{ text = `{props.capacity} previews per page at this window size`, wrapped = true, height = 40, order = 5 }
		),
		Lighting = e(Studio.Checkbox, {
			Label = "Match place lighting",
			Value = props.options.mirrorLighting,
			OnChanged = function()
				local updated = table.clone(props.options)
				updated.mirrorLighting = not updated.mirrorLighting
				props.changeOptions(updated)
			end,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 6,
		}),
		Settings = e(
			UI.Column,
			{ order = 7 },
			{ Editor = e(SettingsEditor, { value = props.settings, change = props.changeSettings }) }
		),
		Close = e(UI.Button, { text = "Done", order = 8, click = props.close }),
	})
end
