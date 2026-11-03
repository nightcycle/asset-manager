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
local Playback = require(Source.Preview.Playback)
local Surface = require(Source.Preview.Surface)
local Image = require(Source.Preview.Image)
local Selection = require(Source.Preview.Selection)
local Hierarchy = require(Source.Shared.Hierarchy)
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
	columns, rows = Pagination.Grid(16, 1200, 300)
	check(columns == 8 and rows == 2, "Wide panel forced sixteen previews into a narrow strip")
	columns, rows = Pagination.Grid(16, 300, 1200)
	check(columns == 2 and rows == 8, "Tall panel forced sixteen previews into a short strip")
	columns, rows = Pagination.Grid(7, 720, 360)
	check(columns == 7 and rows == 1, "Prime preview count left an incomplete row")
	columns, rows = Pagination.Grid(7, 360, 720)
	check(columns == 1 and rows == 7, "Portrait prime count should fill a vertical column")
	columns, rows = Pagination.Grid(14, 720, 360)
	check(columns == 7 and rows == 2, "Fourteen previews should use two complete rows")
	columns, rows = Pagination.Grid(0, 0, 0)
	check(columns == 1 and rows == 1, "Empty preview layout is invalid")
	for _, bounds in { Vector2.new(240, 960), Vector2.new(500, 500), Vector2.new(960, 240) } do
		for items = 1, 64 do
			columns, rows = Pagination.Grid(items, bounds.X, bounds.Y)
			check(columns * rows == items, "Preview layout contains unused slots")
		end
	end
	local _, _, lastFirst, lastLast = Pagination.Page(30, 2, 16)
	columns, rows = Pagination.Grid(lastLast - lastFirst + 1, 720, 360)
	check(columns == 7 and rows == 2, "The last page should also use complete rows")
	check(Settings.Default(false).maxItems == 16, "Default preview target is not sixteen")
	check(Pagination.PreviewCapacity(500, 360, 1, 16) == 16, "Normal dock did not reach sixteen previews")
	check(Pagination.PreviewCapacity(200, 200, 1, 16) == 4, "Small dock did not reduce preview capacity")
	check(Pagination.PreviewCapacity(800, 800, 1, 64) == 64, "Higher configured preview limits were ignored")
	check(Pagination.PreviewCapacity(1, 1, 8, 16) == 8, "Preview minimum was ignored")
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
	local aSound, bSound, notSound = Instance.new("Sound"), Instance.new("Sound"), Instance.new("Part")
	local soundSelection: { Instance } = { notSound, aSound, bSound }
	check(Playback.Sound(soundSelection, 1, 3, nil) == aSound, "Multiple sounds did not choose the first sound")
	check(Playback.Sound(soundSelection, 1, 3, bSound) == bSound, "Manual audio selection did not transfer playback")
	check(Playback.Sound(soundSelection, 3, 3, aSound) == bSound, "Off-page sound prevented visible sound playback")
	check(Playback.Sound(soundSelection, 1, 1, nil) == nil, "Non-sound selection acquired audio playback")
	check(
		not Playback.Audible({ playing = true, audioEnabled = false, background = "Studio", mirrorLighting = true }),
		"Secondary sound was audible"
	)
	check(
		not Playback.Audible({ playing = false, audioEnabled = true, background = "Studio", mirrorLighting = true }),
		"Paused audio was audible"
	)
	aSound.TimePosition = 7
	Audio.SetAudible(aSound, false, true, 0.4)
	check(aSound.Volume == 0 and aSound.TimePosition == 7, "Silent analysis reset its playback position")
	Audio.SetAudible(aSound, true, false, 0.4)
	check(
		math.abs(aSound.Volume - 0.4) < 0.0001 and aSound.TimePosition == 0,
		"Listening did not restart at zero with volume"
	)
	aSound.TimePosition = 2
	Audio.SetAudible(aSound, true, true, 0.4)
	check(aSound.TimePosition == 2, "Listening restarted on every frame")
	local envelope = table.create(4, 0)
	Audio.Record(envelope, 0, 4, 250)
	Audio.Record(envelope, 0.5, 4, 100)
	Audio.Record(envelope, 3.9, 4, 1000)
	check(
		envelope[1] == 0.5 and envelope[4] == 1 and envelope[2] == 0,
		"Audio envelope lost peaks or placed them at the wrong time"
	)
	Audio.Record(envelope, 0, 0, 1000)
	check(envelope[1] == 0.5, "Unloaded audio changed its stored envelope")
	aSound:Destroy()
	bSound:Destroy()
	notSound:Destroy()
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
	local explorerSettings = Settings.Default(true)
	check(Settings.ExplorerCapacity(explorerSettings, 8) == 8, "List automatic page size changed")
	explorerSettings.viewMode = "Grid"
	check(Settings.ExplorerCapacity(explorerSettings, 8) == 24, "Grid did not triple its previous page size")
	check(
		Settings.ExplorerCapacity(explorerSettings, 18) == 54
			and Settings.ExplorerCapacity(explorerSettings, 100) == 100,
		"Grid density ignored size or configured maximum"
	)
	local fixedGrid = Settings.WithPageSize(explorerSettings, 72)
	check(
		Settings.ExplorerCapacity(fixedGrid, 8) == 72 and Settings.ExplorerCapacity(fixedGrid, 80) == 72,
		"Fixed grid page size changed on resize"
	)
	check(Settings.PageSize(explorerSettings) == nil, "Changing page size mutated the previous settings")
	fixedGrid.viewMode = "List"
	local fixedBoth = Settings.WithPageSize(fixedGrid, 17)
	check(
		Settings.PageSize(fixedBoth) == 17 and fixedBoth.gridPageSize == 72,
		"List and Grid page sizes overwrote each other"
	)
	fixedBoth.viewMode = "Grid"
	local automaticAgain = Settings.WithPageSize(fixedBoth, nil)
	check(
		Settings.ExplorerCapacity(automaticAgain, 8) == 24 and automaticAgain.listPageSize == 17,
		"Restoring automatic Grid erased the saved List count"
	)
	local restoredPages = Settings.Decode({ listPageSize = 33.8, gridPageSize = 400, viewMode = "Grid" }, true)
	check(
		restoredPages.listPageSize == 33 and Settings.ExplorerCapacity(restoredPages, 8) == 200,
		"Saved page sizes did not validate or override automatic limits"
	)
	local invalidPages = Settings.Decode({ listPageSize = 0 / 0, gridPageSize = -5 }, true)
	check(
		invalidPages.listPageSize == nil and invalidPages.gridPageSize == nil,
		"Invalid page settings did not fall back to automatic"
	)
	check(
		Settings.Decode({ listPageSize = 20, gridPageSize = 40 }, false).gridPageSize == nil,
		"Explorer page overrides leaked into Previewer"
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
	local shirt, pants = Instance.new("Shirt"), Instance.new("Pants")
	shirt.ShirtTemplate, pants.PantsTemplate = "rbxassetid://123", "rbxassetid://456"
	check(
		Image.Asset(shirt) == shirt.ShirtTemplate and Image.Asset(pants) == pants.PantsTemplate,
		"Clothing fallback did not expose the actual template image"
	)
	shirt:Destroy()
	pants:Destroy()
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
	local selectedPose = single:GetChildren()[1] :: Pose
	selectedPose.Weight = 0.5
	local poseClip = Sampler.Compile(selectedPose)
	local expectedPose = CFrame.identity:Lerp(selectedPose.CFrame, 0.5)
	check(
		poseClip.length == 0 and #poseClip.nodes == 5 and poseClip.channels.Tip == nil,
		"Pose selection lost its descendants or merged duplicate branches"
	)
	check(
		(poseClip.nodes[1].sample(0).LookVector - expectedPose.LookVector).Magnitude < 0.0001
			and selectedPose.Parent == single,
		"Pose weight was ignored or the original pose was moved"
	)
	local detachedPose = selectedPose:Clone()
	assert(detachedPose)
	check(#Sampler.Compile(detachedPose).nodes == 5, "Detached Pose clone failed to compile")
	detachedPose:Destroy()
	check(
		not Playback.HasControls(selectedPose) and not Playback.HasControls(single),
		"Static poses acquired playback controls"
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
	local private = Instance.new("Folder")
	private:SetAttribute("_AssetToolsPreview", true)
	local material = Instance.new("MaterialVariant")
	material.Name, material.BaseMaterial, material.MaterialPattern =
		"Original", Enum.Material.Grass, Enum.MaterialPattern.Organic
	local sphere = Surface.Variant(material, "UniquePreview", private)
	check(
		sphere.Shape == Enum.PartType.Ball
			and sphere.Material == Enum.Material.Grass
			and sphere.MaterialVariant == "UniquePreview",
		"Organic material did not render on its own sphere variant"
	)
	material.MaterialPattern = Enum.MaterialPattern.Regular
	local cube = Surface.Variant(material, "SecondPreview", private)
	check(
		cube.Shape == Enum.PartType.Block and material.Name == "Original" and material.Parent == nil,
		"Regular material was not a cube or modified the source"
	)
	local variant = private:FindFirstChild("UniquePreview") :: MaterialVariant
	check(not variant.Archivable and variant ~= material, "Preview material can persist into a saved place")
	check(
		Hierarchy.IsExcluded(variant) and #Selection.Expand({ private }) == 0,
		"Temporary preview materials leaked into asset selection"
	)
	sphere:Destroy()
	cube:Destroy()
	private:Destroy()
	material:Destroy()
	local mesh = Instance.new("MeshPart")
	local appearance = Instance.new("SurfaceAppearance")
	appearance.ColorMap, appearance.NormalMap = "rbxassetid://123", "rbxassetid://456"
	local appearanceClone = Surface.Apply(appearance, mesh) :: SurfaceAppearance
	check(
		appearanceClone.ColorMap == appearance.ColorMap
			and appearanceClone.NormalMap == appearance.NormalMap
			and appearanceClone.Parent == mesh
			and appearance.Parent == nil,
		"Surface preview lost PBR maps or moved its source"
	)
	appearance:Destroy()
	local normals: { [string]: Vector3 } = {
		Front = -Vector3.zAxis,
		Back = Vector3.zAxis,
		Top = Vector3.yAxis,
		Bottom = -Vector3.yAxis,
		Left = -Vector3.xAxis,
		Right = Vector3.xAxis,
	}
	for _, face in Enum.NormalId:GetEnumItems() do
		local decal = Instance.new("Decal")
		decal.Face, decal.Transparency, decal.Texture = face, 0.25, "rbxassetid://123"
		local copied = Surface.Apply(decal, mesh) :: Decal
		local normal = mesh.CFrame:VectorToWorldSpace(normals[face.Name])
		check(
			normal:Dot(Vector3.zAxis) > 0.99
				and copied.Face == face
				and copied.Transparency == decal.Transparency
				and copied.Texture == decal.Texture,
			"Decal face points away from camera or lost appearance"
		)
		decal:Destroy()
	end
	local texture = Instance.new("Texture")
	texture.StudsPerTileU, texture.StudsPerTileV, texture.OffsetStudsU = 2, 3, 0.5
	local textureClone = Surface.Apply(texture, mesh) :: Texture
	check(
		textureClone.StudsPerTileU == 2 and textureClone.StudsPerTileV == 3 and textureClone.OffsetStudsU == 0.5,
		"Texture sample lost tiling or offset"
	)
	texture:Destroy()
	mesh:Destroy()
	return count
end
