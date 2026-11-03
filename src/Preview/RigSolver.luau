--!strict
local Sampler = require(script.Parent.AnimationSampler)
local RigSolver = {}
export type Rig = { joints: { Motor6D }, bones: { Bone } }
function RigSolver.Build(model: Model, root: BasePart): Rig
	local children: { [BasePart]: { Motor6D } } = {}
	local bones: { Bone } = {}
	for _, instance in model:GetDescendants() do
		if instance:IsA("Motor6D") and instance.Part0 and instance.Part1 then
			local list = children[instance.Part0] or {}
			children[instance.Part0] = list
			table.insert(list, instance)
		elseif instance:IsA("Bone") then
			table.insert(bones, instance)
		end
	end
	local joints: { Motor6D } = {}
	local pending: { BasePart } = { root }
	local visited: { [BasePart]: boolean } = { [root] = true }
	while #pending > 0 do
		local part = table.remove(pending) :: BasePart
		local edges: { Motor6D } = children[part] or {}
		for _, joint in edges do
			local child = joint.Part1
			if child and not visited[child] then
				visited[child] = true
				table.insert(joints, joint)
				table.insert(pending, child)
			end
		end
	end
	return { joints = joints, bones = bones }
end
function RigSolver.Apply(rig: Rig, clip: Sampler.Clip, time: number)
	for _, joint in rig.joints do
		local parent, child = joint.Part0, joint.Part1
		if parent and child then
			local sample = clip.channels[child.Name]
			local pose = if sample then sample(time) else CFrame.identity
			joint.Transform = pose
			child.CFrame = parent.CFrame * joint.C0 * pose * joint.C1:Inverse()
		end
	end
	for _, bone in rig.bones do
		local sample = clip.channels[bone.Name]
		bone.Transform = if sample then sample(time) else CFrame.identity
	end
end
return RigSolver
