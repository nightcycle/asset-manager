--!strict
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Parent.Shared.Types)
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

function World.Mount(context: Types.PreviewContext, model: Model): ViewportFrame
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
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local box, size = model:GetBoundingBox()
	local center = box.Position
	local radius = math.max(size.Magnitude * 0.5, 0.5)
	local yaw, pitch, zoom = math.rad(35), math.rad(18), 1
	local dragging = false
	local last = Vector2.zero
	local function fit()
		local pixels = viewport.AbsoluteSize
		local aspect = math.max(0.1, pixels.X / math.max(pixels.Y, 1))
		local halfFov = math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * math.min(aspect, 1))
		local distance = radius / math.sin(halfFov) * 1.12 * zoom
		local direction = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
		camera.CFrame = CFrame.lookAt(center + direction * distance, center)
	end
	local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
		local connection = signal:Connect(callback)
		context.onCleanup(function()
			connection:Disconnect()
		end)
	end
	connect(viewport:GetPropertyChangedSignal("AbsoluteSize"), fit)
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
	if model:FindFirstChildWhichIsA("ParticleEmitter", true) then
		context.report("Drag to orbit · scroll to zoom. Select an emitter for its animated FX preview.")
	else
		context.report("Drag to orbit · scroll to zoom")
	end
end

function World.Animation(context: Types.PreviewContext)
	local animation = context.source
	assert(animation:IsA("Animation"), "Expected Animation")
	context.report("Loading R15 rig and animation…", "loading")
	local description = Instance.new("HumanoidDescription")
	context.onCleanup(function()
		description:Destroy()
	end)
	local rig = game:GetService("Players")
		:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	context.onCleanup(function()
		rig:Destroy()
	end)
	if not context.isAlive() then
		return
	end
	World.Sanitize(rig)
	World.Mount(context, rig)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "R15 rig has no Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local track = animator:LoadAnimation(animation)
	context.onCleanup(function()
		track:Stop(0)
		track:Destroy()
	end)
	track.Looped = true
	track:Play(0)
	local joints: { Motor6D } = {}
	for _, instance in rig:GetDescendants() do
		if instance:IsA("Motor6D") then
			table.insert(joints, instance)
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	local function pose(part: BasePart)
		for _, joint in joints do
			local child = joint.Part1
			if joint.Part0 == part and child then
				child.CFrame = part.CFrame * joint.C0 * joint.Transform * joint.C1:Inverse()
				pose(child)
			end
		end
	end
	local elapsed = 0
	local lastReport = -1
	local connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if context.options.playing then
			animator:StepAnimations(math.min(dt, 0.1))
		end
		if root and root:IsA("BasePart") then
			pose(root)
		end
		if elapsed - lastReport < 0.25 then
			return
		end
		lastReport = elapsed
		if track.Length > 0 then
			context.report(
				`R15 · {string.format("%.1f", track.TimePosition)} / {string.format("%.1f", track.Length)} s`
			)
		elseif elapsed > 10 then
			context.report("Animation unavailable: check asset permissions and R15 compatibility", "error")
		end
	end)
	context.onCleanup(function()
		connection:Disconnect()
	end)
end
return World
