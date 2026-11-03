--!strict
local React = require(script.Parent.Packages.React)
local Host = require(script.Parent.Source.Shared.PluginHost)
local App = require(script.Parent.Source.Preview.App)
local Types = require(script.Parent.Source.Shared.Types)
local pluginInstance = plugin
assert(pluginInstance, "Previewer must run as a Studio plugin")
local background: Types.Background = "Studio"
local ok, saved = pcall(function(): unknown
	return pluginInstance:GetSetting("PreviewBackground")
end)
if ok and (saved == "Studio" or saved == "Dark" or saved == "Light") then
	background = saved
end
Host.Start(pluginInstance, "Nightcycle.AssetPreviewer.v1", "Asset Previewer", function()
	return React.createElement(App, {
		initialBackground = background,
		onBackground = function(value: Types.Background)
			background = value
			local stored, message = pcall(function(): string?
				pluginInstance:SetSetting("PreviewBackground", value)
				return nil
			end)
			if not stored then
				warn("Unable to save preview background: " .. tostring(message))
			end
		end,
	})
end)
