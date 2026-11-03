--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local Studio = require(Packages.StudioComponents)
local Cleanup = require(script.Parent.Cleanup)
local PluginHost = {}

function PluginHost.Start(pluginInstance: Plugin, id: string, title: string, render: () -> React.ReactNode)
	local cleanup = Cleanup.new()
	-- Stable IDs and overridePreviousState=false let Studio restore docking, size, and visibility.
	local initiallyEnabled = game:GetService("Workspace"):GetAttribute("AssetToolsDemo") == true
	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, initiallyEnabled, false, 480, 640, 320, 300)
	local widget = pluginInstance:CreateDockWidgetPluginGuiAsync(id, info)
	widget.Title = title
	widget.Name = id
	widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local toolbar = pluginInstance:CreateToolbar("Asset Tools")
	local button = toolbar:CreateButton(id, "Toggle " .. title, "", title)
	button.ClickableWhenViewportHidden = true
	local root = ReactRoblox.createRoot(widget)
	local function sync()
		button:SetActive(widget.Enabled)
		root:render(
			if widget.Enabled
				then React.createElement(Studio.PluginProvider, { Plugin = pluginInstance }, { App = render() })
				else nil
		)
	end
	local click = button.Click:Connect(function()
		widget.Enabled = not widget.Enabled
	end)
	local enabled = widget:GetPropertyChangedSignal("Enabled"):Connect(sync)
	cleanup:Add(function()
		root:unmount()
		widget:Destroy()
		toolbar:Destroy()
	end)
	cleanup:Add(function()
		click:Disconnect()
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
