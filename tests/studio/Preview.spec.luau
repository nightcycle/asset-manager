--!strict
local Source = script.Parent.Parent.Source
local Pagination = require(Source.Shared.Pagination)
local Framing = require(Source.Preview.Framing)
local Gui = require(Source.Preview.Gui)
local Audio = require(Source.Preview.Audio)
local Sampler = require(Source.Preview.AnimationSampler)
local Solver = require(Source.Preview.RigSolver)
local Registry = require(Source.Preview.Registry)
local Settings = require(Source.Shared.ViewSettings)
local BonePreview = require(Source.Preview.BonePreview)
local Clothing = require(Source.Preview.Clothing)
local R15 = require(Source.Preview.R15)
return function(): number
	local count = 0
	local function check(condition: boolean, message: string)
		assert(condition, message)
		count += 1
	end
	local columns, rows = Pagination.Grid(4, 240, 960)
	check(columns == 1 and rows == 4, "Tall panel did not switch to a vertical list")
	columns, rows = Pagination.Grid(4, 960, 240)
	check(columns == 4 and rows == 1, "Wide panel did not switch to a horizontal list")
	columns, rows = Pagination.Grid(4, 500, 500)
	check(columns == 2 and rows == 2, "Square panel lost its grid")
	columns, rows = Pagination.Grid(2, 400, 600)
	check(columns == 1 and rows == 2, "Portrait pair should stack vertically")
	check(Framing.Scale(Vector2.new(200, 100), Vector2.new(100, 100), "Fit") == 0.5, "Fit cropped a 2D asset")
	check(Framing.Scale(Vector2.new(200, 100), Vector2.new(100, 100), "Fill") == 1, "Fill did not cover the preview")
	local fit = Framing.Distance(CFrame.identity, Vector3.new(8, 2, 2), Vector3.zAxis, 1, 40, "Fit")
	local fill = Framing.Distance(CFrame.identity, Vector3.new(8, 2, 2), Vector3.zAxis, 1, 40, "Fill")
	check(fit > fill and fill > 1, "3D framing did not distinguish fit/fill or crossed the near face")
	local root = Instance.new("ImageLabel")
	root.Visible = false
	root.Size = UDim2.fromOffset(240, 80)
	local text = Instance.new("TextLabel")
	text.Name, text.Text, text.Parent = "Child", "Preserve me", root
	text.Visible = false
	local scriptChild = Instance.new("LocalScript")
	scriptChild.Parent = root
	local previewGui = Gui.Clone(root) :: ImageLabel
	check(previewGui.Visible and not root.Visible, "GUI preview mutated source visibility or kept its root hidden")
	check((previewGui:FindFirstChild("Child") :: TextLabel).Text == "Preserve me", "Image UI lost its children")
	check(
		not (previewGui:FindFirstChild("Child") :: TextLabel).Visible,
		"GUI preview forced hidden descendants visible"
	)
	check(
		not previewGui:FindFirstChildOfClass("LocalScript") and scriptChild.Parent == root,
		"GUI sanitization changed the source"
	)
	check(Registry.Resolve(root).id == "gui", "UI image selection bypassed the GUI renderer")
	root:SetAttribute("Preview_FlipbookColumns", 4)
	check(Registry.Resolve(root).id == "image", "Explicit flipbook lost its animated renderer")
	previewGui:Destroy()
	root:Destroy()
	local screen = Instance.new("ScreenGui")
	screen.Enabled = false
	local screenClone = Gui.Clone(screen) :: ScreenGui
	check(screenClone.Enabled and not screen.Enabled, "Disabled GUI collector was not enabled on its clone")
	screenClone:Destroy()
	screen:Destroy()
	check(Audio.Time(125.9) == "2:05" and Audio.Time(0) == "0:00", "Audio duration formatting failed")
	check(Audio.Level(0) == 0 and Audio.Level(250) == 0.5 and Audio.Level(2000) == 1, "Loudness mapping is not bounded")
	local sourceSound = Instance.new("Sound")
	sourceSound.Volume, sourceSound.PlayOnRemove = 0, true
	local sound = Audio.Clone(sourceSound)
	check(
		sound.Volume > 0 and not sound.PlayOnRemove and sound.Looped,
		"Preview sound remains silent or plays on cleanup"
	)
	check(sourceSound.Volume == 0 and sourceSound.PlayOnRemove, "Preview sound changed the original")
	sound:Destroy()
	sourceSound.PlayOnRemove = false
	sourceSound:Destroy()
	local sequence = Instance.new("KeyframeSequence")
	for _, time in { 2, 0 } do
		local key = Instance.new("Keyframe")
		key.Time, key.Parent = time, sequence
		local pose = Instance.new("Pose")
		pose.Name, pose.CFrame, pose.Weight = "LowerTorso", CFrame.new(time * 2, 0, 0), 1
		pose.EasingStyle = Enum.PoseEasingStyle.Linear
		pose.Parent = key
	end
	local clip = Sampler.Compile(sequence)
	check(
		clip.length == 2 and math.abs(clip.channels.LowerTorso(1).X - 2) < 0.0001,
		"Unsorted keyframes did not interpolate"
	)
	check(
		clip.channels.LowerTorso(-1).X == 0 and clip.channels.LowerTorso(5).X == 4,
		"Sampler did not hold channel endpoints"
	)
	check(Sampler.Time(2.5, 2) == 0.5 and Sampler.Time(10, 0) == 0, "Animation looping or zero-length sampling failed")
	local keys: { Sampler.Key } = {
		{
			time = 0,
			pose = CFrame.new(2, 0, 0),
			weight = 0.5,
			style = Enum.PoseEasingStyle.Constant,
			direction = Enum.PoseEasingDirection.In,
		},
		{
			time = 1,
			pose = CFrame.new(8, 0, 0),
			weight = 1,
			style = Enum.PoseEasingStyle.Linear,
			direction = Enum.PoseEasingDirection.In,
		},
	}
	check(Sampler.Interpolate(keys, 0.5).X == 1, "Constant weighted pose should hold until the next key")
	check(Sampler.Interpolate(keys, 1).X == 8, "Exact final key was not applied")
	local rig = Instance.new("Model")
	local rootPart, torso, head = Instance.new("Part"), Instance.new("Part"), Instance.new("Part")
	rootPart.Name, torso.Name, head.Name = "HumanoidRootPart", "LowerTorso", "Head"
	rootPart.Parent, torso.Parent, head.Parent = rig, rig, rig
	rootPart.CFrame = CFrame.new(10, 0, 0)
	local neck, waist = Instance.new("Motor6D"), Instance.new("Motor6D")
	neck.Part0, neck.Part1, neck.C0, neck.Parent = torso, head, CFrame.new(0, 2, 0), head
	waist.Part0, waist.Part1, waist.C0, waist.C1, waist.Parent =
		rootPart, torso, CFrame.new(0, 1, 0), CFrame.new(0, 0.5, 0), torso
	Solver.Apply(Solver.Build(rig, rootPart), clip, 1)
	check(
		(torso.CFrame.Position - Vector3.new(12, 0.5, 0)).Magnitude < 0.0001,
		"Custom solver lost C0/C1 or sampled translation"
	)
	check(
		(head.CFrame.Position - Vector3.new(12, 2.5, 0)).Magnitude < 0.0001,
		"Custom solver evaluated descendants before their parents"
	)
	sequence:Destroy()
	rig:Destroy()
	check(Pagination.Capacity(720, 540, 180, 180, 1, 25) == 12, "Adaptive pagination ignored window dimensions")
	check(Pagination.Capacity(10, 10, 180, 180, 4, 25) == 4, "Adaptive pagination ignored the configured minimum")
	check(Pagination.Capacity(3000, 2000, 180, 180, 1, 16) == 16, "Adaptive pagination exceeded the configured maximum")
	local savedSettings = Settings.Decode({ minItems = 20, maxItems = 10, autoPlay = false, viewMode = "Grid" }, true)
	check(
		savedSettings.minItems == 10
			and savedSettings.maxItems == 10
			and not savedSettings.autoPlay
			and savedSettings.viewMode == "Grid",
		"Saved settings failed to normalize limits or retain autoplay/grid"
	)
	check(
		Settings.Decode({ minItems = 0 / 0, maxItems = math.huge }, false).autoPlay,
		"Invalid settings disabled default autoplay"
	)
	local points = Framing.Corners(CFrame.new(100, 10, -50) * CFrame.Angles(0.4, 0.7, 0.2), Vector3.new(8, 3, 2))
	for _, aspect in { 0.2, 0.5, 1, 2, 5 } do
		local direction = Vector3.new(1, 0.4, 1).Unit
		local center, distance = Framing.Solve(points, direction, aspect, 40, "Fit")
		local right = Vector3.yAxis:Cross(direction).Unit
		local camera = CFrame.fromMatrix(center + direction * distance, right, direction:Cross(right), direction)
		local extent = 0
		for _, point in points do
			local p = camera:PointToObjectSpace(point)
			local x = math.abs(p.X) / (-p.Z * math.tan(math.rad(20)) * aspect)
			local y = math.abs(p.Y) / (-p.Z * math.tan(math.rad(20)))
			extent = math.max(extent, x, y)
			check(
				p.Z < 0 and x <= 1 and y <= 1,
				`Fit cropped a rotated bounding box at aspect {aspect}: {x}, {y}, {p.Z}`
			)
		end
		check(extent >= 0.95, "Fit left excessive padding on both axes")
	end
	local clothingRig = Instance.new("Model")
	for _, class in { "Shirt", "Pants", "ShirtGraphic" } do
		local garment = Instance.new(class)
		local applied = Clothing.Apply(garment, clothingRig)
		check(
			applied ~= garment
				and applied.ClassName == class
				and applied.Parent == clothingRig
				and garment.Parent == nil,
			"Clothing preview moved or changed the source"
		)
		garment:Destroy()
	end
	clothingRig:Destroy()
	local skeletonClip = Instance.new("KeyframeSequence")
	for _, time in { 0, 1 } do
		local key = Instance.new("Keyframe")
		key.Time, key.Parent = time, skeletonClip
		local rootPose = Instance.new("Pose")
		rootPose.Name, rootPose.Parent, rootPose.Weight = "RootBone", key, 1
		rootPose.CFrame = CFrame.Angles(0, 0, time * math.pi / 2)
		rootPose.EasingStyle = Enum.PoseEasingStyle.Linear
		for _, name in { "Left", "Right" } do
			local branch = Instance.new("Pose")
			branch.Name, branch.Parent, branch.Weight = name, rootPose, 1
			local tip = Instance.new("Pose")
			tip.Name, tip.Parent, tip.Weight = "Tip", branch, 1
		end
	end
	local skeleton = Sampler.Compile(skeletonClip)
	check(
		#skeleton.nodes == 5 and skeleton.channels.Tip == nil and not R15.Matches(skeleton.channels),
		"Duplicate bone names collapsed or an unrelated rig matched R15"
	)
	local proxy = BonePreview.Create(skeleton, skeletonClip)
	BonePreview.Apply(proxy, 0)
	local before = proxy.entries[#proxy.entries].marker.CFrame.Position
	BonePreview.Apply(proxy, 1)
	check(
		proxy.schematic and (proxy.entries[#proxy.entries].marker.CFrame.Position - before).Magnitude > 1,
		"Stand-in bones did not inherit parent motion"
	)
	proxy.model:Destroy()
	local single = skeletonClip:GetChildren()[2] :: Keyframe
	single.Time = 5
	local singleClip = Sampler.Compile(single)
	check(
		singleClip.length == 0
			and #singleClip.nodes == 5
			and (singleClip.nodes[1].sample(0).LookVector - (single:GetChildren()[1] :: Pose).CFrame.LookVector).Magnitude
				< 0.0001,
		"Standalone Keyframe was not shown as its authored pose"
	)
	skeletonClip:Destroy()
	local restRig = Instance.new("Model")
	local base = Instance.new("Part")
	base.CFrame, base.Parent = CFrame.new(10, 0, 0), restRig
	local rootBone = Instance.new("Bone")
	rootBone.Name, rootBone.CFrame, rootBone.Parent = "RootBone", CFrame.new(0, 2, 0), base
	local tipBone = Instance.new("Bone")
	tipBone.Name, tipBone.CFrame, tipBone.Parent = "Tip", CFrame.new(0, 3, 0), rootBone
	local key = Instance.new("Keyframe")
	key.Parent = restRig
	local rootPose = Instance.new("Pose")
	rootPose.Name, rootPose.Parent, rootPose.Weight = "RootBone", key, 1
	local tipPose = Instance.new("Pose")
	tipPose.Name, tipPose.Parent, tipPose.Weight = "Tip", rootPose, 1
	local restProxy = BonePreview.Create(Sampler.Compile(key), key)
	BonePreview.Apply(restProxy, 0)
	check(
		not restProxy.schematic
			and (restProxy.entries[2].marker.CFrame.Position - Vector3.new(10, 5, 0)).Magnitude < 0.0001,
		"Stand-in ignored original Bone rest offsets"
	)
	restProxy.model:Destroy()
	restRig:Destroy()
	local upgraded = Instance.new("Model")
	local upper, lower = Instance.new("Part"), Instance.new("Part")
	upper.Name, lower.Name, upper.Parent, lower.Parent = "HumanoidRootPart", "LowerTorso", upgraded, upgraded
	local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.Name, b.Name, a.Parent, b.Parent = "RootRigAttachment", "RootRigAttachment", upper, lower
	a.CFrame, b.CFrame = CFrame.new(0, 1, 0), CFrame.new(0, -1, 0)
	R15.EnsureMotors(upgraded)
	R15.EnsureMotors(upgraded)
	local reconstructed = Solver.Build(upgraded, upper)
	check(
		#reconstructed.joints == 1 and reconstructed.joints[1].C0 == a.CFrame and reconstructed.joints[1].C1 == b.CFrame,
		"R15 attachment fallback lost rest offsets or duplicated joints"
	)
	upper.Transparency, lower.Transparency, lower.LocalTransparencyModifier = 1, 0, 0
	upper.Size, lower.Size, lower.CFrame = Vector3.new(1000, 1000, 1000), Vector3.new(2, 2, 2), CFrame.identity
	local visiblePoints = Framing.Points(upgraded)
	local maximumExtent = 0
	for _, point in visiblePoints do
		maximumExtent = math.max(maximumExtent, point.Magnitude)
	end
	check(#visiblePoints == 8 and maximumExtent < 2, "Invisible helper parts inflated preview framing")
	upgraded:Destroy()
	return count
end
