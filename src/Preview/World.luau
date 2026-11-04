--!strict
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Parent.Shared.Types)
local Framing = require(script.Parent.Framing)
local World = {}

function World.Sanitize(root: Instance)
	local descendants = root:GetDescendants()
	table.insert(descendants, root)
	for _, instance in descendants do
		if instance:IsA("LuaSourceContainer") then
			instance:Destroy()
		elseif instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanTouch = false
			instance.CanQuery = false
		elseif instance:IsA("Sound") then
			instance:Destroy()
		end
	end
end

function World.Mount(context: Types.PreviewContext, model: Model, framePoints: { Vector3 }?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Active = not context.options.thumbnail
	viewport.Parent = context.host
	context.onCleanup(function()
		viewport:Destroy()
	end)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	model.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.FieldOfViewMode = Enum.FieldOfViewMode.Vertical
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local points = framePoints or Framing.Points(model)
	local yaw, pitch, zoom = math.rad(35), math.rad(18), 1
	local dragging = false
	local last = Vector2.zero
	local function fit()
		local pixels = viewport.AbsoluteSize
		if pixels.X <= 0 or pixels.Y <= 0 then
			return
		end
		local aspect = pixels.X / pixels.Y
		local direction = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
		local center, distance = Framing.Solve(points, direction, aspect, camera.FieldOfView, context.options.scaleMode)
		camera.CFrame = CFrame.lookAt(center + direction * distance * zoom, center)
		camera.Focus = CFrame.new(center)
	end
	local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
		local connection = signal:Connect(callback)
		context.onCleanup(function()
			connection:Disconnect()
		end)
	end
	connect(viewport:GetPropertyChangedSignal("AbsoluteSize"), fit)
	local mode = context.options.scaleMode
	connect(RunService.Heartbeat, function()
		if mode ~= context.options.scaleMode then
			mode = context.options.scaleMode
			fit()
		end
	end)
	if not context.options.thumbnail then
		connect(viewport.InputBegan, function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
				last = Vector2.new(input.Position.X, input.Position.Y)
			end
		end)
		connect(viewport.InputEnded, function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
		connect(viewport.MouseLeave, function()
			dragging = false
		end)
		connect(viewport.InputChanged, function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				zoom = math.clamp(zoom * (0.9 ^ input.Position.Z), 0.25, 5)
				fit()
			elseif dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local position = Vector2.new(input.Position.X, input.Position.Y)
				local delta = position - last
				last = position
				yaw -= delta.X * 0.01
				pitch = math.clamp(pitch + delta.Y * 0.01, -1.4, 1.4)
				fit()
			end
		end)
	end
	local skyClone: Sky? = nil
	local function lighting()
		if context.options.mirrorLighting then
			viewport.Ambient = Lighting.Ambient:Lerp(Lighting.OutdoorAmbient, 0.5)
			local brightness = math.clamp(Lighting.Brightness / 2, 0, 1)
			local shift = Lighting.ColorShift_Top
			viewport.LightColor = Color3.new(
				math.clamp(brightness + shift.R, 0, 1),
				math.clamp(brightness + shift.G, 0, 1),
				math.clamp(brightness + shift.B, 0, 1)
			)
			viewport.LightDirection = -Lighting:GetSunDirection()
		else
			viewport.Ambient = Color3.fromRGB(150, 150, 150)
			viewport.LightColor = Color3.fromRGB(255, 255, 255)
			viewport.LightDirection = Vector3.new(-1, -1, -1)
		end
	end
	local skyConnection: RBXScriptConnection? = nil
	local function syncSky()
		if skyClone then
			skyClone:Destroy()
			skyClone = nil
		end
		if skyConnection then
			skyConnection:Disconnect()
			skyConnection = nil
		end
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky and context.options.mirrorLighting then
			skyClone = sky:Clone()
			if skyClone then
				skyClone.Parent = viewport
			end
			skyConnection = sky.Changed:Connect(function()
				if skyClone then
					skyClone:Destroy()
				end
				skyClone = sky:Clone()
				if skyClone then
					skyClone.Parent = viewport
				end
			end)
		else
			-- PBR maps need a cubemap even when the place has no explicit Sky.
			local defaultSky = Instance.new("Sky")
			defaultSky.Parent = viewport
			skyClone = defaultSky
		end
	end
	context.onCleanup(function()
		if skyConnection then
			skyConnection:Disconnect()
		end
	end)
	connect(Lighting.Changed, lighting)
	connect(Lighting.ChildAdded, syncSky)
	connect(Lighting.ChildRemoved, syncSky)
	lighting()
	syncSky()
	fit()
	return viewport
end

function World.Geometry(context: Types.PreviewContext)
	local source = context.source
	if source:IsA("SpecialMesh") and source.Parent then
		source = source.Parent
	end
	local clone = source:Clone()
	if not clone then
		error("This instance is not Archivable; enable Archivable to preview it")
	end
	context.onCleanup(function()
		clone:Destroy()
	end)
	World.Sanitize(clone)
	local model = Instance.new("Model")
	context.onCleanup(function()
		model:Destroy()
	end)
	clone.Parent = model
	if not model:FindFirstChildWhichIsA("BasePart", true) then
		error("No 3D parts inside this selection")
	end
	World.Mount(context, model)
	if
		model:FindFirstChildWhichIsA("ParticleEmitter", true)
		or model:FindFirstChildWhichIsA("Beam", true)
		or model:FindFirstChildWhichIsA("Trail", true)
	then
		context.report(
			"Drag to orbit · scroll to zoom. Select an emitter, Beam, or Trail for its animated FX preview."
		)
	else
		context.report("Drag to orbit · scroll to zoom")
	end
end

return World
