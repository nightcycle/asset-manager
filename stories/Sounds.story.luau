--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Settings = require(script.Parent.Parent.Source.Shared.ViewSettings)
local Story = require(script.Parent.Story)
return Story.Create("Silent audio visualization", { LightTheme = false, AutoPlay = true }, function(fixture, props)
	local sounds = React.useMemo(function(): { Instance }
		local result: { Instance } = {}
		for _, name in { "impact_water.mp3", "impact_explosion_03.mp3", "action_swim.mp3" } do
			local sound = Instance.new("Sound")
			sound.Name, sound.SoundId, sound.Volume = name, "rbxasset://sounds/" .. name, 0.25
			sound.Parent = fixture.root
			table.insert(result, sound)
		end
		return result
	end, {})
	local preferences = Settings.Default(false)
	preferences.autoPlay = props.controls.AutoPlay == true
	return React.createElement(
		App,
		{ key = tostring(preferences.autoPlay), selection = sounds, initialSettings = preferences }
	)
end)
