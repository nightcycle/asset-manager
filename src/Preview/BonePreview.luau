--!strict
local Sampler = require(script.Parent.AnimationSampler)
local BonePreview = {}
type Rest = { before: CFrame, after: CFrame, base: CFrame, rootOnly: boolean? }
type Entry = { node: Sampler.Node, marker: Part, link: Part?, rest: Rest }
export type Rig = { model: Model, entries: { Entry }, schematic: boolean }
local function restData(source: Instance): { [string]: Rest }
	local model = source:FindFirstAncestorOfClass("Model")
	local result: { [string]: Rest } = {}
	if not model then
		return result
	end
	local counts: { [string]: number } = {}
	local parts: { [string]: BasePart } = {}
	local partCounts: { [string]: number } = {}
	local function put(name: string, rest: Rest)
		counts[name] = (counts[name] or 0) + 1
		result[name] = rest
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			parts[item.Name] = item
			partCounts[item.Name] = (partCounts[item.Name] or 0) + 1
		end
		if item:IsA("Bone") then
			local base = CFrame.identity
			local parent = item.Parent
			local chain: { Bone } = {}
			while parent and parent:IsA("Bone") do
				table.insert(chain, 1, parent)
				parent = parent.Parent
			end
			if parent and parent:IsA("BasePart") then
				base = parent.CFrame
			end
			for _, bone in chain do
				base *= bone.CFrame
			end
			put(item.Name, { before = item.CFrame, after = CFrame.identity, base = base })
		elseif item:IsA("Motor6D") and item.Part0 and item.Part1 then
			put(item.Part1.Name, { before = item.C0, after = item.C1:Inverse(), base = item.Part0.CFrame })
		end
	end
	for name, count in counts do
		if count > 1 then
			result[name] = nil
		end
	end
	for name, part in parts do
		if not counts[name] and partCounts[name] == 1 then
			result[name] = { before = CFrame.identity, after = CFrame.identity, base = part.CFrame, rootOnly = true }
		end
	end
	return result
end
function BonePreview.Create(clip: Sampler.Clip, source: Instance): Rig
	local model = Instance.new("Model")
	model.Name = "AnimationBoneStandIn"
	local rests = restData(source)
	local entries: { Entry } = {}
	local siblingCounts: { [string]: number } = {}
	local siblingIndices: { [string]: number } = {}
	for _, node in clip.nodes do
		local key = node.parent or ""
		siblingCounts[key] = (siblingCounts[key] or 0) + 1
	end
	local schematic = false
	for index, node in clip.nodes do
		local key = node.parent or ""
		local rank = (siblingIndices[key] or 0) + 1
		siblingIndices[key] = rank
		local rest: Rest? = rests[node.name]
		if rest and rest.rootOnly and node.parent then
			rest = nil
		end
		if not rest then
			schematic = true
			local x = (rank - (siblingCounts[key] + 1) / 2) * (if node.parent then 1.4 else 3)
			rest = {
				before = CFrame.new(x, if node.parent then 1.4 else 0, 0),
				after = CFrame.identity,
				base = CFrame.identity,
			}
		end
		assert(rest)
		local marker = Instance.new("Part")
		marker.Name, marker.Shape, marker.Size = node.name, Enum.PartType.Ball, Vector3.new(0.3, 0.3, 0.3)
		marker.Anchored, marker.CanCollide, marker.CanTouch, marker.CanQuery = true, false, false, false
		marker.Color = Color3.fromHSV((index * 0.13) % 1, 0.35, 0.95)
		marker.Material = Enum.Material.SmoothPlastic
		marker.Parent = model
		local link: Part? = nil
		if node.parent then
			local segment = Instance.new("Part")
			segment.Name, segment.Shape, segment.Anchored = node.name .. "_Bone", Enum.PartType.Cylinder, true
			segment.CanCollide, segment.CanTouch, segment.CanQuery = false, false, false
			segment.Color, segment.Material, segment.Parent = marker.Color, Enum.Material.SmoothPlastic, model
			link = segment
		end
		table.insert(entries, { node = node, marker = marker, link = link, rest = rest })
	end
	return { model = model, entries = entries, schematic = schematic }
end
function BonePreview.Apply(rig: Rig, time: number)
	local transforms: { [string]: CFrame } = {}
	for _, entry in rig.entries do
		local parent = if entry.node.parent then transforms[entry.node.parent] else nil
		local pose = (parent or entry.rest.base) * entry.rest.before * entry.node.sample(time) * entry.rest.after
		transforms[entry.node.id] = pose
		entry.marker.CFrame = pose
		local link = entry.link
		if link and parent then
			local delta = pose.Position - parent.Position
			local length = delta.Magnitude
			link.Transparency = if length > 0.001 then 0 else 1
			if length > 0.001 then
				link.Size = Vector3.new(length, 0.14, 0.14)
				link.CFrame = CFrame.lookAt((pose.Position + parent.Position) / 2, pose.Position)
					* CFrame.Angles(0, math.pi / 2, 0)
			end
		end
	end
end
return BonePreview
