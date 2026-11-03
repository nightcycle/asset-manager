--!strict
local Sampler = {}
local Paths = require(script.Parent.Parent.Shared.Paths)
export type Key = {
	time: number,
	pose: CFrame,
	weight: number,
	style: Enum.PoseEasingStyle,
	direction: Enum.PoseEasingDirection,
}
export type Node = { id: string, name: string, parent: string?, sample: (number) -> CFrame }
export type Clip = { length: number, channels: { [string]: (number) -> CFrame }, nodes: { Node } }
function Sampler.Interpolate(keys: { Key }, time: number): CFrame
	if #keys == 0 then
		return CFrame.identity
	end
	local first, last = keys[1], keys[#keys]
	if time <= first.time then
		return CFrame.identity:Lerp(first.pose, first.weight)
	end
	if time >= last.time then
		return CFrame.identity:Lerp(last.pose, last.weight)
	end
	local low, high = 1, #keys
	while high - low > 1 do
		local middle = math.floor((low + high) / 2)
		if keys[middle].time <= time then
			low = middle
		else
			high = middle
		end
	end
	local a, b = keys[low], keys[high]
	local alpha = (time - a.time) / math.max(b.time - a.time, 0.00001)
	if a.style == Enum.PoseEasingStyle.Constant then
		alpha = 0
	elseif a.style ~= Enum.PoseEasingStyle.Linear then
		local style = if a.style == Enum.PoseEasingStyle.Elastic
			then Enum.EasingStyle.Elastic
			elseif a.style == Enum.PoseEasingStyle.Bounce then Enum.EasingStyle.Bounce
			else Enum.EasingStyle.Cubic
		local direction = if a.direction == Enum.PoseEasingDirection.In
			then Enum.EasingDirection.In
			elseif a.direction == Enum.PoseEasingDirection.Out then Enum.EasingDirection.Out
			else Enum.EasingDirection.InOut
		alpha = game:GetService("TweenService"):GetValue(alpha, style, direction)
	end
	return CFrame.identity:Lerp(a.pose:Lerp(b.pose, alpha), math.clamp(a.weight + (b.weight - a.weight) * alpha, 0, 1))
end
function Sampler.Compile(clip: Instance): Clip
	local length = 0
	local channels: { [string]: (number) -> CFrame } = {}
	local nodesById: { [string]: Node } = {}
	local function nodeFor(instance: Instance, boundary: Instance): Node
		local segments: { string } = {}
		local cursor: Instance? = instance
		while cursor and cursor ~= boundary do
			table.insert(segments, 1, Paths.Encode(cursor.Name))
			cursor = cursor.Parent
		end
		local id = table.concat(segments, "/")
		local existing = nodesById[id]
		if existing then
			return existing
		end
		local node: Node = {
			id = id,
			name = instance.Name,
			parent = if #segments > 1 then table.concat(segments, "/", 1, #segments - 1) else nil,
			sample = function()
				return CFrame.identity
			end,
		}
		nodesById[id] = node
		return node
	end
	if clip:IsA("KeyframeSequence") or clip:IsA("Keyframe") then
		local tracks: { [string]: { Key } } = {}
		local keyframes: { Instance } = if clip:IsA("Keyframe") then { clip } else clip:GetChildren()
		for _, keyframe in keyframes do
			if not keyframe:IsA("Keyframe") then
				continue
			end
			local time = if clip:IsA("Keyframe") then 0 else keyframe.Time
			length = math.max(length, time)
			for _, pose in keyframe:GetDescendants() do
				if not pose:IsA("Pose") then
					continue
				end
				local node = nodeFor(pose, keyframe)
				local keys = tracks[node.id] or {}
				tracks[node.id] = keys
				table.insert(keys, {
					time = time,
					pose = pose.CFrame,
					weight = math.clamp(pose.Weight, 0, 1),
					style = pose.EasingStyle,
					direction = pose.EasingDirection,
				})
			end
		end
		for id, keys in tracks do
			table.sort(keys, function(a, b)
				return a.time < b.time
			end)
			nodesById[id].sample = function(time)
				return Sampler.Interpolate(keys, time)
			end
		end
	elseif clip:IsA("CurveAnimation") then
		for _, instance in clip:GetDescendants() do
			if instance:IsA("FloatCurve") and instance.Length > 0 then
				length = math.max(length, instance:GetKeyAtIndex(instance.Length).Time)
			elseif instance:IsA("RotationCurve") and instance.Length > 0 then
				length = math.max(length, instance:GetKeyAtIndex(instance.Length).Time)
			end
			if not instance:IsA("Folder") then
				continue
			end
			local node = nodeFor(instance, clip)
			local position = instance:FindFirstChild("Position")
			local rotation = instance:FindFirstChild("Rotation")
			local positionCurve: Vector3Curve? = if position and position:IsA("Vector3Curve") then position else nil
			local rotationCurve: (EulerRotationCurve | RotationCurve)? = nil
			if rotation then
				if rotation:IsA("EulerRotationCurve") then
					rotationCurve = rotation
				elseif rotation:IsA("RotationCurve") then
					rotationCurve = rotation
				end
			end
			if not positionCurve and not rotationCurve then
				continue
			end
			node.sample = function(time)
				local p = if positionCurve
					then Vector3.new(
						positionCurve:X():GetValueAtTime(time) or 0,
						positionCurve:Y():GetValueAtTime(time) or 0,
						positionCurve:Z():GetValueAtTime(time) or 0
					)
					else Vector3.zero
				local r = CFrame.identity
				if rotationCurve then
					r = if rotationCurve:IsA("EulerRotationCurve")
						then rotationCurve:GetRotationAtTime(time)
						else rotationCurve:GetValueAtTime(time) or CFrame.identity
				end
				return CFrame.new(p) * r
			end
		end
	else
		error("Unsupported animation clip class: " .. clip.ClassName)
	end
	local nodes: { Node } = {}
	local names: { [string]: number } = {}
	for _, node in nodesById do
		table.insert(nodes, node)
		names[node.name] = (names[node.name] or 0) + 1
	end
	table.sort(nodes, function(a, b)
		local _, depthA = a.id:gsub("/", "")
		local _, depthB = b.id:gsub("/", "")
		return if depthA == depthB then a.id < b.id else depthA < depthB
	end)
	for _, node in nodes do
		if names[node.name] == 1 then
			channels[node.name] = node.sample
		end
	end
	assert(#nodes > 0, "Animation has no joint pose channels")
	return { length = length, channels = channels, nodes = nodes }
end
function Sampler.Time(elapsed: number, length: number): number
	return if length > 0 then elapsed % length else 0
end
return Sampler
