--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Parent.Shared.Types)
local Framing = require(script.Parent.Framing)
local World = require(script.Parent.World)
local Gui = {}
function Gui.CanvasSize(source: Instance, fallback: Vector2): Vector2
	if source:IsA("SurfaceGui") then
		return source.CanvasSize
	elseif source:IsA("GuiObject") then
		local size = source.AbsoluteSize
		if size.X > 0 and size.Y > 0 then
			return size
		end
		return Vector2.new(
			math.max(1, source.Size.X.Scale * fallback.X + source.Size.X.Offset),
			math.max(1, source.Size.Y.Scale * fallback.Y + source.Size.Y.Offset)
		)
	end
	return fallback
end
function Gui.Clone(source: Instance): Instance
	local clone = source:Clone()
	assert(clone, "GUI is not Archivable")
	World.Sanitize(clone)
	if clone:IsA("GuiObject") then
		clone.Visible = true
		clone.AnchorPoint = Vector2.zero
		clone.Position = UDim2.new()
	elseif clone:IsA("LayerCollector") then
		clone.Enabled = true
	end
	return clone
end
function Gui.Mount(context: Types.PreviewContext)
	local camera = workspace.CurrentCamera
	local fallback = if camera and camera.ViewportSize.X > 0 then camera.ViewportSize else Vector2.new(1280, 720)
	local size = Gui.CanvasSize(context.source, fallback)
	local clone = Gui.Clone(context.source)
	context.onCleanup(function()
		clone:Destroy()
	end)
	local canvas = Instance.new("Frame")
	canvas.Name = "GuiCanvas"
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromOffset(size.X, size.Y)
	canvas.Parent = context.host
	context.onCleanup(function()
		canvas:Destroy()
	end)
	local scale = Instance.new("UIScale")
	scale.Parent = canvas
	if clone:IsA("GuiObject") then
		clone.Size = UDim2.fromScale(1, 1)
		clone.Parent = canvas
	else
		-- LayerCollectors cannot draw inside a Frame; their children use this virtual canvas.
		for _, child in clone:GetChildren() do
			child.Parent = canvas
		end
	end
	local function fit()
		local pixels = context.host.AbsoluteSize
		scale.Scale = Framing.Scale(size, pixels, context.options.scaleMode)
		canvas.Position = UDim2.fromOffset((pixels.X - size.X * scale.Scale) / 2, (pixels.Y - size.Y * scale.Scale) / 2)
	end
	local mode = context.options.scaleMode
	local resized = context.host:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	local changed = RunService.Heartbeat:Connect(function()
		if mode ~= context.options.scaleMode then
			mode = context.options.scaleMode
			fit()
		end
	end)
	context.onCleanup(function()
		resized:Disconnect()
		changed:Disconnect()
	end)
	fit()
	context.report("GUI preview · root shown · scripts excluded")
end
return Gui
