--!strict
local Database = require(script.Parent.Parent.Source.Organizer.Database)
local Types = require(script.Parent.Parent.Source.Shared.Types)
local Fixtures = {}
export type Fixture = { root: Folder, selection: { Instance }, database: Database.Database, schema: Types.Schema }
function Fixtures.new(): Fixture
	local root = Instance.new("Folder")
	root.Name = "StoryDataModel"
	local assets = Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = root
	local selection: { Instance } = {}
	for index = 1, 12 do
		local part = Instance.new("Part")
		part.Name = string.format("Prop_%02d", index)
		part.Size = Vector3.new(2 + index % 3, 2 + index % 4, 2)
		part.Shape = if index % 2 == 0 then Enum.PartType.Ball else Enum.PartType.Block
		part.Color = Color3.fromHSV(index / 12, 0.55, 0.85)
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part:AddTag(if index % 2 == 0 then "Nature" else "Prop")
		part:SetAttribute("Complexity", index % 6)
		part:SetAttribute("Biome", if index % 2 == 0 then "Forest" else "Urban")
		part.Parent = assets
		table.insert(selection, part)
	end
	local image = Instance.new("ImageLabel")
	image.Name = "SparkTexture"
	image.Image = "rbxasset://textures/particles/sparkles_main.dds"
	image.Parent = assets
	table.insert(selection, image)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = image.Image
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 187, 80), Color3.fromRGB(255, 80, 140))
	emitter.Rate = 24
	emitter.Speed = NumberRange.new(2, 5)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Size = NumberSequence.new(0.7, 0)
	emitter.Parent = assets
	table.insert(selection, emitter)
	local fallback = Instance.new("StringValue")
	fallback.Name = "UnsupportedClass"
	fallback.Parent = assets
	table.insert(selection, fallback)
	local schema: Types.Schema = {
		version = 1,
		tags = {
			{ name = "Nature", description = "Organic outdoor assets such as trees, rocks, and foliage" },
			{ name = "Prop", description = "Manufactured set dressing and reusable objects" },
		},
		attributes = {
			{
				name = "Complexity",
				description = "Visual complexity from simple silhouette to intricate detail",
				kind = "number",
				min = 0,
				max = 5,
			},
			{
				name = "Biome",
				description = "The environment that visually suits the asset",
				kind = "enum",
				values = { "Forest", "Urban", "Desert" },
			},
			{
				name = "Stylized",
				description = "Uses exaggerated forms rather than realistic proportions",
				kind = "boolean",
			},
		},
	}
	local database = Database.new(root, root, false)
	database.SaveSchema(schema)
	return { root = root, selection = selection, database = database, schema = schema }
end
return Fixtures
