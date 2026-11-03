--!strict
-- Run after building the development place and both production plugin models.
local fs = require("@lune/fs")
local luneRoblox = require("@lune/roblox")
-- Lune exports Roblox datatypes at runtime but its generated definitions omit them.
-- Keep the conversion at this boundary; the builder below uses engine instance types.
local roblox = (luneRoblox :: unknown) :: {
	Instance: typeof(Instance),
	Vector3: typeof(Vector3),
	Vector2: typeof(Vector2),
	CFrame: typeof(CFrame),
	Color3: typeof(Color3),
	UDim2: typeof(UDim2),
	Enum: typeof(Enum),
	NumberRange: typeof(NumberRange),
	NumberSequence: typeof(NumberSequence),
	ColorSequence: typeof(ColorSequence),
	deserializePlace: (string) -> DataModel,
	deserializeModel: (string) -> { Instance },
	serializePlace: (DataModel) -> string,
}
local serde = require("@lune/serde")
local Instance = roblox.Instance
local Vector3, CFrame, Color3 = roblox.Vector3, roblox.CFrame, roblox.Color3
local UDim2, Enum = roblox.UDim2, roblox.Enum
type Asset = { source: Instance, category: string, subcategory: string }

local place = roblox.deserializePlace(fs.readFile("build/development.rbxl"))
local workspace = place:GetService("Workspace")
local replicatedStorage = place:GetService("ReplicatedStorage")
local serverStorage = place:GetService("ServerStorage")
workspace:SetAttribute("AssetToolsDemo", true)

local function folder(name: string, parent: Instance): Instance
	local result = Instance.new("Folder")
	result.Name, result.Parent = name, parent
	return result
end

local libraries = roblox.deserializeModel(fs.readFile("demo/assets/lib.rbxm"))
assert(#libraries == 1 and libraries[1].Name == "lib", "Expected the supplied lib Folder")
local library = libraries[1]
library.Parent = replicatedStorage
local assets: { Asset } = {}
local function collect(parent: Instance, category: string, subcategory: string)
	local children = parent:GetChildren()
	table.sort(children, function(a, b)
		return a.Name < b.Name
	end)
	for _, child in children do
		if child:IsA("Folder") then
			collect(child, if parent == library then child.Name else category, child.Name)
		elseif child:IsA("Model") or child:IsA("BasePart") then
			table.insert(assets, { source = child :: Instance, category = category, subcategory = subcategory })
		end
	end
end
collect(library, "Library", "Library")
assert(#assets > 0, "Library has no displayable assets")

local function partsOf(root: Instance): { BasePart }
	local parts: { BasePart } = {}
	if root:IsA("BasePart") then
		table.insert(parts, root)
	end
	for _, child in root:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return parts
end

local function bounds(parts: { BasePart }): (Vector3, Vector3)
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, part in parts do
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local corner = part.CFrame * (part.Size * Vector3.new(x, y, z) * 0.5)
					low = Vector3.new(math.min(low.X, corner.X), math.min(low.Y, corner.Y), math.min(low.Z, corner.Z))
					high =
						Vector3.new(math.max(high.X, corner.X), math.max(high.Y, corner.Y), math.max(high.Z, corner.Z))
				end
			end
		end
	end
	return (low + high) * 0.5, high - low
end

local function part(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Instance
	local result = Instance.new("Part")
	result.Name, result.Size, result.CFrame = name, size, CFrame.new(position)
	result.Color, result.Material = color, Enum.Material.SmoothPlastic
	result.Anchored, result.CanCollide = true, true
	result.TopSurface, result.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	result.Parent = parent
	return result
end

local gallery = folder("AssetGallery", workspace)
local environment = folder("DemoEnvironment", workspace)
local columns, spacing = 12, 20
local rows = math.ceil(#assets / columns)
local categoryFolders: { [string]: Instance } = {}
local manifest = {}
for index, asset in assets do
	local categoryFolder = categoryFolders[asset.category]
	if not categoryFolder then
		categoryFolder = folder(asset.category, gallery)
		categoryFolders[asset.category] = categoryFolder
	end
	local model = Instance.new("Model")
	model.Name = string.format("%03d_%s", index, asset.source.Name)
	local clone = asset.source:Clone()
	assert(clone, "Library asset is not Archivable")
	clone.Parent = model
	local parts = partsOf(model)
	assert(#parts > 0, "Library model contains no parts")
	local center, size = bounds(parts)
	local scale = math.min(12 / math.max(size.X, 0.001), 16 / math.max(size.Y, 0.001), 12 / math.max(size.Z, 0.001))
	local x, z = ((index - 1) % columns) * spacing, math.floor((index - 1) / columns) * spacing
	local target = Vector3.new(x, 1.25 + size.Y * scale * 0.5, z)
	for _, sourcePart in parts do
		local transform = sourcePart.CFrame
		sourcePart.CFrame = CFrame.new(target + (transform.Position - center) * scale) * transform.Rotation
		sourcePart.Size *= scale
		sourcePart.Anchored = true
	end
	model:SetAttribute("Category", asset.category)
	model:SetAttribute("Complexity", math.min(5, #parts - 1))
	model:SetAttribute("Reviewed", false)
	model:SetAttribute("Origin", "Library")
	model:SetAttribute("DisplayScale", scale)
	model:AddTag("DemoAsset")
	model:AddTag("Geometry")
	model.Parent = categoryFolder
	local pedestal = part(
		string.format("Stand_%03d", index),
		Vector3.new(16, 1, 16),
		Vector3.new(x, 0.5, z),
		Color3.fromRGB(51, 59, 71),
		environment
	)
	local label = Instance.new("BillboardGui")
	label.Name, label.Size, label.StudsOffset = "AssetLabel", UDim2.fromOffset(230, 45), Vector3.new(0, 1, -8)
	label.MaxDistance, label.AlwaysOnTop, label.Adornee = 100, false, pedestal
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 0.2
	text.BackgroundColor3, text.TextColor3 = Color3.fromRGB(25, 29, 35), Color3.fromRGB(235, 239, 245)
	text.TextSize, text.TextWrapped = 14, true
	text.Text = string.format("%03d  %s / %s\n%s", index, asset.category, asset.subcategory, asset.source.Name)
	text.Parent, label.Parent = label, pedestal
	table.insert(manifest, {
		name = model.Name,
		fullName = model:GetFullName(),
		category = asset.category,
		source = asset.source:GetFullName(),
		partCount = #parts,
		displayScale = scale,
	})
end

part(
	"Ground",
	Vector3.new(columns * spacing + 40, 1, rows * spacing + 80),
	Vector3.new((columns - 1) * spacing / 2, -0.5, (rows - 1) * spacing / 2),
	Color3.fromRGB(96, 108, 112),
	environment
)
local spawn = Instance.new("SpawnLocation")
spawn.Name, spawn.Anchored, spawn.Neutral = "DemoSpawn", true, true
spawn.Size, spawn.CFrame, spawn.Duration = Vector3.new(8, 1, 8), CFrame.new(0, 1, -22), 0
spawn.Parent = environment
local board =
	part("StartHere", Vector3.new(70, 17, 1), Vector3.new(40, 9, -32), Color3.fromRGB(28, 34, 45), environment)
local surface = Instance.new("SurfaceGui")
surface.Face, surface.CanvasSize, surface.Parent = Enum.NormalId.Front, roblox.Vector2.new(1400, 340), board
local welcome = Instance.new("TextLabel")
welcome.Size, welcome.BackgroundTransparency = UDim2.fromScale(1, 1), 1
welcome.TextSize = 36
welcome.TextColor3, welcome.TextWrapped = Color3.fromRGB(236, 243, 255), true
welcome.Text =
	`ASSET TOOLS — DEMO\n{#assets} library assets · select or multi-select to preview\nPlugins → Asset Tools → Asset Previewer / Asset Organizer\nOriginal library: ReplicatedStorage.lib\nMedia tests: ReplicatedStorage.PreviewExamples\nOrganizer: scope to Workspace.AssetGallery · tag DemoAsset`
welcome.Parent = surface

local examples = folder("PreviewExamples", replicatedStorage)
local function example(instance: Instance, tag: string): Instance
	instance:AddTag("DemoAsset")
	instance:AddTag(tag)
	instance:SetAttribute("Category", "Examples")
	instance:SetAttribute("Complexity", 0)
	instance:SetAttribute("Reviewed", false)
	instance:SetAttribute("Origin", "Fixture")
	instance.Parent = examples
	return instance
end
local image = Instance.new("ImageLabel")
image.Name, image.Image, image.ImageColor3 =
	"Image_Sparkles", "rbxasset://textures/particles/sparkles_main.dds", Color3.fromRGB(255, 190, 85)
example(image, "Image")
local decal = Instance.new("Decal")
decal.Name, decal.Texture = "Decal_Sparkles", image.Image
example(decal, "Image")
local flipbook = Instance.new("ImageLabel")
flipbook.Name, flipbook.Image = "Flipbook_4x4_ReplaceImageWithYourSheet", image.Image
flipbook:SetAttribute("Preview_FlipbookColumns", 4)
flipbook:SetAttribute("Preview_FlipbookRows", 4)
flipbook:SetAttribute("Preview_FrameWidth", 64)
flipbook:SetAttribute("Preview_FrameHeight", 64)
flipbook:SetAttribute("Preview_FPS", 12)
example(flipbook, "Image")
local emitter = Instance.new("ParticleEmitter")
emitter.Name, emitter.Texture = "FX_Sparkles", image.Image
emitter.Rate, emitter.Lifetime, emitter.Speed = 32, roblox.NumberRange.new(1, 2), roblox.NumberRange.new(2, 5)
emitter.SpreadAngle = roblox.Vector2.new(35, 35)
emitter.Color = roblox.ColorSequence.new(Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 80, 130))
emitter.Size, emitter.Transparency = roblox.NumberSequence.new(0.7, 0), roblox.NumberSequence.new(0, 1)
example(emitter, "FX")
local animation = Instance.new("Animation")
animation.Name, animation.AnimationId = "Animation_R15_Idle", "rbxassetid://507766388"
example(animation, "Animation")
local sound = Instance.new("Sound")
sound.Name, sound.SoundId, sound.Volume = "Audio_ImpactWater", "rbxasset://sounds/impact_water.mp3", 0.25
example(sound, "Audio")
local soundExamples: { [string]: string } =
	{ Audio_Explosion = "impact_explosion_03.mp3", Audio_Swimming = "action_swim.mp3" }
for name, uri in soundExamples do
	local other = Instance.new("Sound")
	other.Name, other.SoundId, other.Volume = name, "rbxasset://sounds/" .. uri, 0.25
	example(other, "Audio")
end
local gui = Instance.new("TextLabel")
gui.Name, gui.Text, gui.BackgroundColor3 = "GUI_Label", "A GUI asset preview", Color3.fromRGB(44, 64, 90)
gui.TextColor3, gui.TextSize, gui.Size = Color3.fromRGB(240, 246, 255), 24, UDim2.fromOffset(240, 80)
gui.Visible = false
example(gui, "GUI")
local screen = Instance.new("ScreenGui")
screen.Name, screen.Enabled = "GUI_DisabledScreen", false
local screenLabel = gui:Clone()
assert(screenLabel)
screenLabel.Visible = true
screenLabel.AnchorPoint, screenLabel.Position = roblox.Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
screenLabel.Text, screenLabel.Parent = "A disabled screen, previewed visibly", screen
example(screen, "GUI")
local localClip = Instance.new("KeyframeSequence")
localClip.Name = "Animation_LocalR15Wave"
for _, time in { 0, 0.5, 1 } do
	local key = Instance.new("Keyframe")
	key.Time, key.Parent = time, localClip
	local pose = Instance.new("Pose")
	pose.Name, pose.Weight, pose.EasingStyle = "RightUpperArm", 1, Enum.PoseEasingStyle.Linear
	pose.CFrame = CFrame.Angles(0, 0, if time == 0.5 then math.rad(110) else 0)
	pose.Parent = key
end
example(localClip, "Animation")
local bones = Instance.new("KeyframeSequence")
bones.Name = "Animation_BoneStandIn"
for _, time in { 0, 0.5, 1 } do
	local key = Instance.new("Keyframe")
	key.Time, key.Parent = time, bones
	local rootPose = Instance.new("Pose")
	rootPose.Name, rootPose.Weight, rootPose.Parent = "CreatureRoot", 1, key
	for index = 1, 3 do
		local limb = Instance.new("Pose")
		limb.Name, limb.Weight, limb.Parent = "Limb" .. tostring(index), 1, rootPose
		limb.CFrame = CFrame.Angles(0, 0, if time == 0.5 then (index - 2) * math.pi / 3 else 0)
		limb.EasingStyle = Enum.PoseEasingStyle.Linear
		local tip = Instance.new("Pose")
		tip.Name, tip.Weight, tip.Parent = "Tip", 1, limb
	end
end
example(bones, "Animation")
local poseExample = bones:GetChildren()[2]:Clone()
assert(poseExample)
poseExample.Name = "Keyframe_StandalonePose"
example(poseExample, "Animation")
local branch = poseExample:GetChildren()[1]:Clone()
assert(branch)
branch.Name = "Pose_StandaloneBranch"
example(branch, "Animation")
local graphic = Instance.new("ShirtGraphic")
graphic.Name, graphic.Graphic = "Clothing_TShirt", image.Image
example(graphic, "Geometry")
local shirt, pants = Instance.new("Shirt"), Instance.new("Pants")
shirt.Name, pants.Name = "Clothing_Shirt_SetTemplate", "Clothing_Pants_SetTemplate"
example(shirt, "Geometry")
example(pants, "Geometry")
for _, organic in { true, false } do
	local material = Instance.new("MaterialVariant")
	material.Name = if organic then "Material_OrganicSphere" else "Material_RegularCube"
	material.BaseMaterial = if organic then Enum.Material.Grass else Enum.Material.Brick
	material.MaterialPattern = if organic then Enum.MaterialPattern.Organic else Enum.MaterialPattern.Regular
	material.ColorMap = "rbxasset://textures/ui/LegacyRbxGui/brickSide.png"
	material.StudsPerTile = 2
	example(material, "Geometry")
end
local appearance = Instance.new("SurfaceAppearance")
appearance.Name, appearance.ColorMap = "SurfaceAppearance_Mesh", "rbxasset://textures/ui/LegacyRbxGui/brickSide.png"
example(appearance, "Geometry")
local texture = Instance.new("Texture")
texture.Name, texture.Texture = "Texture_TiledMesh", appearance.ColorMap
texture.StudsPerTileU, texture.StudsPerTileV = 1, 1
example(texture, "Image")
local fallback = Instance.new("StringValue")
fallback.Name = "Fallback_StringValue"
example(fallback, "Other")
local unsupported = Instance.new("Fire")
unsupported.Name = "Fallback_Fire"
example(unsupported, "Other")
local nonAssets = Instance.new("Configuration")
nonAssets.Name = "Hidden_NonAssetsOnly"
for _, class in { "ModuleScript", "StringValue", "Folder" } do
	local child = Instance.new(class)
	child.Parent = nonAssets
end
example(nonAssets, "Other")

local tags: { { name: string, description: string } } = {}
local descriptions: { [string]: string } = {
	DemoAsset = "An asset supplied by this test place, suitable for preview and metadata exercises",
	Geometry = "A three-dimensional prop or model",
	Image = "A still image, decal, or sprite sheet",
	FX = "An animated particle effect",
	Animation = "An animation clip or pose for an R15 rig or bone stand-in",
	Audio = "A sound asset",
	GUI = "A user interface asset",
	Other = "An instance used to test fallback previews",
}
for name, description in descriptions do
	table.insert(tags, { name = name, description = description })
end
table.sort(tags, function(a, b)
	return a.name < b.name
end)
local categories = { "Examples" }
for category in categoryFolders do
	table.insert(categories, category)
end
table.sort(categories)
local schema = Instance.new("StringValue")
schema.Name = "AssetToolsSchema"
local attributes: { { [string]: unknown } } = {
	{
		name = "Category",
		description = "Source library category, or Examples for media test fixtures",
		kind = "enum",
		values = categories,
	},
	{
		name = "Complexity",
		description = "Visual complexity from 0 to 5; demo defaults use part count and can be corrected",
		kind = "number",
		min = 0,
		max = 5,
	},
	{ name = "Reviewed", description = "Whether a person has reviewed this asset's metadata", kind = "boolean" },
	{
		name = "Origin",
		description = "Whether the asset came from the supplied library or a demo fixture",
		kind = "enum",
		values = { "Library", "Fixture" },
	},
}
schema.Value = serde.encode("json", { version = 1, tags = tags, attributes = attributes })
schema.Parent = serverStorage

local plugins = folder("PluginBuilds", serverStorage)
for _, name in { "Previewer", "Organizer" } do
	local roots = roblox.deserializeModel(fs.readFile(`build/Asset{name}.rbxm`))
	assert(#roots == 1, "Expected one plugin model")
	roots[1].Parent = plugins
end
local notes = Instance.new("StringValue")
notes.Name = "START_HERE"
notes.Value = fs.readFile("demo/README.txt")
notes.Parent = replicatedStorage

local lighting = place:GetService("Lighting")
lighting.ClockTime, lighting.Brightness = 14, 2
lighting.Ambient, lighting.OutdoorAmbient = Color3.fromRGB(100, 111, 134), Color3.fromRGB(145, 149, 160)
local camera = Instance.new("Camera")
camera.Name, camera.CameraType = "Camera", Enum.CameraType.Fixed
camera.CFrame = CFrame.lookAt(Vector3.new(62, 40, -95), Vector3.new(45, 4, 24))
camera.Focus, camera.Parent = CFrame.new(45, 4, 24), workspace
workspace.CurrentCamera = camera

fs.writeFile("build/AssetToolsDemo.rbxl", roblox.serializePlace(place))
fs.writeFile("build/demo-manifest.json", serde.encode("json", {
	libraryDescendants = #library:GetDescendants(),
	galleryCount = #assets,
	exampleCount = #examples:GetChildren(),
	assets = manifest,
}, true) .. "\n")
print(
	`Built AssetToolsDemo.rbxl: {#assets} gallery assets, {#library:GetDescendants()} original library descendants, {#examples:GetChildren()} media fixtures`
)
