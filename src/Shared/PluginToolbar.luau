--!strict
-- Each plugin ships its own module copy. CoreGui holds the actual shared toolbar reference.
local PluginToolbar = {}
export type Handle = { SetActive: (boolean) -> (), Destroy: () -> () }

function PluginToolbar.Register(
	pluginInstance: Plugin,
	id: string,
	title: string,
	icon: string,
	click: () -> ()
): Handle
	local coreGui = game:GetService("CoreGui")
	local name = "Nightcycle.AssetTools.Toolbar.v1"
	local existing = coreGui:FindFirstChild(name)
	local shared: ObjectValue
	if existing and existing:IsA("ObjectValue") then
		shared = existing
	else
		shared = Instance.new("ObjectValue")
		shared.Name, shared.Archivable, shared.Parent = name, false, coreGui
	end
	local alive, active = true, false
	local button: PluginToolbarButton? = nil
	local buttonConnection: RBXScriptConnection? = nil
	local function bind()
		if not alive then
			return
		end
		local toolbar = shared.Value
		if not toolbar then
			local createdToolbar = pluginInstance:CreateToolbar("Asset Tools")
			createdToolbar.Name = "Nightcycle.AssetTools.Toolbar"
			shared.Value = createdToolbar
			toolbar = createdToolbar
		end
		assert(toolbar and toolbar:IsA("PluginToolbar"), "Invalid Asset Tools toolbar")
		local reference = shared:FindFirstChild(id)
		local current = if reference and reference:IsA("ObjectValue") then reference.Value else nil
		if not current then
			local created = toolbar:CreateButton(id, "Toggle " .. title, icon, title)
			created.Name = id
			local ref = Instance.new("ObjectValue")
			ref.Name, ref.Value, ref.Parent = id, created, shared
			current = created
		end
		assert(current and current:IsA("PluginToolbarButton"), "Invalid Asset Tools button")
		if current == button then
			return
		end
		if buttonConnection then
			buttonConnection:Disconnect()
		end
		button = current
		current.Icon = icon
		current.Enabled, current.ClickableWhenViewportHidden = true, true
		current:SetActive(active)
		buttonConnection = current.Click:Connect(click)
	end
	local changed = shared:GetPropertyChangedSignal("Value"):Connect(function()
		-- Let the old plugin finish unloading before a remaining plugin takes ownership.
		task.defer(bind)
	end)
	bind()
	return {
		SetActive = function(value: boolean)
			active = value
			if button and shared.Value then
				button:SetActive(value)
			end
		end,
		Destroy = function()
			if not alive then
				return
			end
			alive = false
			changed:Disconnect()
			if buttonConnection then
				buttonConnection:Disconnect()
			end
			local toolbar = shared.Value
			for _, reference in shared:GetChildren() do
				reference:Destroy()
			end
			shared.Value = nil
			if toolbar then
				toolbar:Destroy()
			end
			-- Remaining registrations recreate the group and restore their enabled states.
			-- Destroying the toolbar also removes unloaded buttons from Studio's drawer.
		end,
	}
end
return PluginToolbar
