--!strict
local React = require(script.Parent.Packages.React)
local Host = require(script.Parent.Source.Shared.PluginHost)
local PluginIcons = require(script.Parent.Source.Generated.PluginIcons)
local App = require(script.Parent.Source.Preview.App)
local Types = require(script.Parent.Source.Shared.Types)
local Settings = require(script.Parent.Source.Shared.ViewSettings)
local pluginInstance = plugin
assert(pluginInstance, "Previewer must run as a Studio plugin")
local background: Types.Background = "Studio"
local ok, saved = pcall(function(): unknown
	return pluginInstance:GetSetting("PreviewBackground")
end)
if ok and (saved == "Studio" or saved == "Dark" or saved == "Light") then
	background = saved
end
local scaleMode: Types.ScaleMode = "Fit"
local scaleOk, savedScale = pcall(function(): unknown
	return pluginInstance:GetSetting("PreviewScaleMode")
end)
if scaleOk and (savedScale == "Fit" or savedScale == "Fill") then
	scaleMode = savedScale
end
local viewSettings = Settings.Read(pluginInstance, "PreviewViewSettings", false)
Host.Start(pluginInstance, "Nightcycle.AssetPreviewer.v1", "Asset Previewer", PluginIcons.Previewer, function()
	return React.createElement(App, {
		initialBackground = background,
		initialScaleMode = scaleMode,
		initialSettings = viewSettings,
		onSettings = function(value: Settings.Settings)
			viewSettings = value
			Settings.Save(pluginInstance, "PreviewViewSettings", value)
		end,
		onScaleMode = function(value: Types.ScaleMode)
			scaleMode = value
			local stored, message = pcall(function(): string?
				pluginInstance:SetSetting("PreviewScaleMode", value)
				return nil
			end)
			if not stored then
				warn("Unable to save preview framing: " .. tostring(message))
			end
		end,
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
