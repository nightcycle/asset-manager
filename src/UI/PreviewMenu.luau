--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local UI = require(script.Parent.Controls)
local Types = require(script.Parent.Parent.Shared.Types)
local e = React.createElement
export type Props = {
	options: Types.PreviewOptions,
	changeOptions: (Types.PreviewOptions) -> (),
	capacity: number,
	changeCapacity: (number) -> (),
	close: () -> (),
}

return function(props: Props): React.ReactElement
	local theme = Studio.useTheme()
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
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10 }, {
		Scrim = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			ZIndex = 1,
			[React.Event.Activated] = props.close,
		}),
		Panel = e("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(260, 234),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			Active = true,
			ZIndex = 2,
		}, {
			Padding = e("UIPadding", {
				PaddingTop = UDim.new(0, 10),
				PaddingBottom = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			Content = e(UI.Column, nil, {
				Title = e(UI.Text, { text = "Preview options", order = 1 }),
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
				Playback = e(UI.Button, {
					text = if props.options.playing then "Pause playback" else "Resume playback",
					order = 3,
					click = function()
						local updated = table.clone(props.options)
						updated.playing = not updated.playing
						props.changeOptions(updated)
					end,
				}),
				Count = e(UI.Button, {
					text = `{props.capacity} previews per page`,
					order = 4,
					click = function()
						props.changeCapacity(if props.capacity == 1 then 4 elseif props.capacity == 4 then 9 else 1)
					end,
				}),
				Lighting = e(Studio.Checkbox, {
					Label = "Match place lighting",
					Value = props.options.mirrorLighting,
					OnChanged = function()
						local updated = table.clone(props.options)
						updated.mirrorLighting = not updated.mirrorLighting
						props.changeOptions(updated)
					end,
					Size = UDim2.new(1, 0, 0, 24),
					LayoutOrder = 5,
				}),
				Close = e(UI.Button, { text = "Done", order = 6, click = props.close }),
			}),
		}),
	})
end
