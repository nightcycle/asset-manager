--!strict
local React = require(script.Parent.Packages.React)
local Host = require(script.Parent.Source.Shared.PluginHost)
local App = require(script.Parent.Source.Organizer.App)
local Database = require(script.Parent.Source.Organizer.Database)
local Settings = require(script.Parent.Source.Shared.ViewSettings)
local pluginInstance = plugin
assert(pluginInstance, "Organizer must run as a Studio plugin")
local storage = game:GetService("ServerStorage")
local database = Database.new(game, storage, true)
local viewSettings = Settings.Read(pluginInstance, "OrganizerViewSettings", true)
Host.Start(pluginInstance, "Nightcycle.AssetOrganizer.v1", "Asset Organizer", function()
	return React.createElement(App, {
		database = database,
		bridgeParent = storage,
		initialSettings = viewSettings,
		onSettings = function(value: Settings.Settings)
			viewSettings = value
			Settings.Save(pluginInstance, "OrganizerViewSettings", value)
		end,
	})
end)
