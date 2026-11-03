--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Parent.Shared.Types)
local World = require(script.Parent.World)
local Sampler = require(script.Parent.AnimationSampler)
local RigSolver = require(script.Parent.RigSolver)
local R15 = require(script.Parent.R15)
local BonePreview = require(script.Parent.BonePreview)
local Framing = require(script.Parent.Framing)
local Animation = {}
function Animation.Mount(context: Types.PreviewContext)
	context.report("Loading animation poses…", "loading")
	local source = context.source
	local clip: Instance
	if source:IsA("AnimationClip") or source:IsA("Keyframe") or source:IsA("Pose") then
		local clone = source:Clone()
		assert(clone, "Animation clip is not Archivable")
		clip = clone
	else
		assert(source:IsA("Animation") and source.AnimationId ~= "", "Set an AnimationId to preview this animation")
		clip = game:GetService("AnimationClipProvider"):GetAnimationClipAsync(source.AnimationId)
	end
	context.onCleanup(function()
		clip:Destroy()
	end)
	if not context.isAlive() then
		return
	end
	local sampled = Sampler.Compile(clip)
	local apply: (number) -> ()
	local model: Model
	local label = "R15"
	local solver: RigSolver.Rig? = nil
	local r15: Model? = nil
	if R15.Matches(sampled.channels) then
		context.report("Loading R15 preview rig…", "loading")
		local ok, result = pcall(R15.Create, context)
		if not context.isAlive() then
			return
		end
		if ok and result then
			r15 = result
			R15.EnsureMotors(result)
			local root = result:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				solver = RigSolver.Build(result, root)
			end
		end
	end
	local matching = false
	if solver then
		for _, joint in solver.joints do
			if joint.Part1 and sampled.channels[joint.Part1.Name] then
				matching = true
				break
			end
		end
	end
	if r15 and solver and matching then
		model = r15
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:Destroy()
		end
		local activeSolver = solver
		apply = function(time)
			RigSolver.Apply(activeSolver, sampled, time)
		end
	else
		if r15 then
			r15:Destroy()
		end
		local proxy = BonePreview.Create(sampled, source)
		model = proxy.model
		context.onCleanup(function()
			proxy.model:Destroy()
		end)
		label = if proxy.schematic then "Schematic bones" else "Rig bones"
		apply = function(time)
			BonePreview.Apply(proxy, time)
		end
	end
	-- A stable frame covers sampled motion instead of zooming in and out every heartbeat.
	local framePoints: { Vector3 } = {}
	local samples = if sampled.length > 0 then 16 else 0
	for index = 0, samples do
		apply(if samples > 0 then sampled.length * index / samples else 0)
		for _, point in Framing.Points(model) do
			table.insert(framePoints, point)
		end
		if index % 4 == 3 then
			task.wait()
			if not context.isAlive() then
				return
			end
		end
	end
	apply(0)
	World.Mount(context, model, framePoints)
	local elapsed, lastReport = 0, -1
	local failed = false
	local connection = RunService.Heartbeat:Connect(function(dt)
		if failed then
			return
		end
		if context.options.playing then
			elapsed += dt
		end
		local time = Sampler.Time(elapsed, sampled.length)
		local ok, message = pcall(function(): string?
			apply(time)
			return nil
		end)
		if not ok then
			failed = true
			context.report("Animation sampling failed: " .. tostring(message), "error")
		elseif elapsed - lastReport >= 0.25 then
			lastReport = elapsed
			context.report(`{label} · {string.format("%.1f", time)} / {string.format("%.1f", sampled.length)} s`)
		end
	end)
	context.onCleanup(function()
		connection:Disconnect()
	end)
	context.report(`{label} · {string.format("%.1f", sampled.length)} s`)
end
return Animation
