--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local Studio = require(Packages.StudioComponents)
local Cleanup = require(script.Parent.Cleanup)
local PluginToolbar = require(script.Parent.PluginToolbar)
local PluginHost = {}

function PluginHost.Start(
	pluginInstance: Plugin,
	id: string,
	title: string,
	icon: string,
	render: () -> React.ReactNode
)
	local cleanup = Cleanup.new()
	local widget: DockWidgetPluginGui? = nil
	local togglePending = false
	-- Register native controls before the yielding widget creation call.
	local button = PluginToolbar.Register(pluginInstance, id, title, icon, function()
		local current = widget
		if current then
			current.Enabled = not current.Enabled
		else
			togglePending = not togglePending
		end
	end)
	-- Stable IDs and overridePreviousState=false let Studio restore docking, size, and visibility.
	local initiallyEnabled = game:GetService("Workspace"):GetAttribute("AssetToolsDemo") == true
	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, initiallyEnabled, false, 480, 640, 320, 300)
	local created = pluginInstance:CreateDockWidgetPluginGuiAsync(id, info)
	widget = created
	created.Title = title
	created.Name = id
	created.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if togglePending then
		created.Enabled = not created.Enabled
	end
	local root = ReactRoblox.createRoot(created)
	local function sync()
		button.SetActive(created.Enabled)
		root:render(
			if created.Enabled
				then React.createElement(Studio.PluginProvider, { Plugin = pluginInstance }, { App = render() })
				else nil
		)
	end
	local enabled = created:GetPropertyChangedSignal("Enabled"):Connect(sync)
	cleanup:Add(function()
		root:unmount()
		created:Destroy()
		button.Destroy()
	end)
	cleanup:Add(function()
		enabled:Disconnect()
	end)
	local unloading = pluginInstance.Unloading:Connect(function()
		cleanup:Destroy()
	end)
	cleanup:Add(function()
		unloading:Disconnect()
	end)
	sync()
end
return PluginHost
