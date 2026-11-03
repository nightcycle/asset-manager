--!strict
-- Simulate engine lifetime/events to test two independently loaded copies of the plugin module.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local function signal(): any
	local handlers: { [any]: () -> () } = {}
	return {
		Connect = function(_, callback)
			local connection = {}
			handlers[connection] = callback
			connection.Disconnect = function()
				handlers[connection] = nil
			end
			return connection
		end,
		Fire = function()
			for _, callback in table.clone(handlers) do
				callback()
			end
		end,
	}
end

local instances: { any } = {}
local deferred: { () -> () } = {}
local function new(className: string): any
	local properties: any = { ClassName = className, Name = className, Changed = signal(), Click = signal() }
	local object: any = setmetatable({}, {
		__index = properties,
		__newindex = function(_, key, value)
			local previous = properties[key]
			properties[key] = value
			if key == "Value" and previous ~= value then
				properties.Changed.Fire()
			end
		end,
	})
	properties.IsA = function(_, name)
		return name == className
	end
	properties.GetChildren = function()
		local children = {}
		for _, item in instances do
			if item.Parent == object then
				table.insert(children, item)
			end
		end
		return children
	end
	properties.FindFirstChild = function(_, name)
		for _, child in object:GetChildren() do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	properties.GetPropertyChangedSignal = function()
		return properties.Changed
	end
	properties.Destroy = function()
		if properties.destroyed then
			return
		end
		properties.destroyed = true
		for _, child in object:GetChildren() do
			child:Destroy()
		end
		object.Parent = nil
		for _, item in instances do
			if item.Value == object then
				item.Value = nil
			end
		end
	end
	properties.SetActive = function(_, value)
		assert(not properties.destroyed, "SetActive called on a destroyed toolbar button")
		properties.active = value
	end
	table.insert(instances, object)
	return object
end
local function flush()
	local iterations = 0
	while #deferred > 0 do
		iterations += 1
		assert(iterations < 100, "Toolbar recreation did not settle")
		table.remove(deferred, 1)()
	end
end
local coreGui = new("CoreGui")
local function plugin(): any
	return {
		CreateToolbar = function(_, title)
			local toolbar = new("PluginToolbar")
			-- Native objects start unnamed and unparented, even though their UI metadata exists.
			toolbar.Name = "Instance"
			toolbar.title = title
			toolbar.CreateButton = function(_, id, _, icon, text)
				assert(not toolbar:FindFirstChild(id), "Duplicate button ID")
				local button = new("PluginToolbarButton")
				button.Name, button.Icon, button.Text, button.Parent = "Instance", icon, text, toolbar
				return button
			end
			return toolbar
		end,
	}
end
local function load(): any
	return luau.load(fs.readFile("src/Shared/PluginToolbar.luau"), {
		injectGlobals = true,
		environment = {
			game = {
				GetService = function()
					return coreGui
				end,
			},
			Instance = { new = new },
			task = {
				defer = function(callback)
					table.insert(deferred, callback)
				end,
			},
		},
	})()
end
local function activeToolbar(): any
	local found = nil
	for _, item in instances do
		if item.ClassName == "PluginToolbar" and not item.destroyed then
			assert(not found, "Plugins created separate toolbar groups")
			found = item
		end
	end
	return found
end
for _, removeOwner in { true, false } do
	local clicks = { 0, 0 }
	local first = load().Register(plugin(), "Previewer", "Asset Previewer", "preview-icon", function()
		clicks[1] += 1
	end)
	local second = load().Register(plugin(), "Organizer", "Asset Organizer", "organizer-icon", function()
		clicks[2] += 1
	end)
	first.SetActive(true)
	second.SetActive(true)
	flush()
	local toolbar = activeToolbar()
	assert(
		toolbar.title == "Asset Tools"
			and toolbar.Name == "Nightcycle.AssetTools.Toolbar"
			and #toolbar:GetChildren() == 2,
		"Missing named shared group buttons"
	)
	assert(toolbar:FindFirstChild("Previewer").Icon == "preview-icon", "Missing preview icon")
	assert(toolbar:FindFirstChild("Organizer").Icon == "organizer-icon", "Missing organizer icon")
	toolbar:FindFirstChild("Organizer").Click.Fire()
	assert(clicks[1] == 0 and clicks[2] == 1, "Toolbar dispatched the wrong plugin")
	local removed = if removeOwner then first else second
	local survivor = if removeOwner then second else first
	local survivorId = if removeOwner then "Organizer" else "Previewer"
	removed.Destroy()
	removed.Destroy()
	flush()
	toolbar = activeToolbar()
	assert(
		#toolbar:GetChildren() == 1 and toolbar:FindFirstChild(survivorId).active,
		"Unloading lost the remaining plugin/state or retained a dead button"
	)
	local reloaded = load().Register(
		plugin(),
		if removeOwner then "Previewer" else "Organizer",
		"Reloaded",
		"new-icon",
		function() end
	)
	flush()
	assert(#activeToolbar():GetChildren() == 2, "Reload did not restore the group")
	survivor.Destroy()
	reloaded.Destroy()
	flush()
	assert(not activeToolbar(), "Unloading both plugins left a toolbar")
end
print("Verified shared toolbar, icon routing, owner/non-owner unload, reload, and final cleanup")
