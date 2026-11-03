--!strict
local Types = require(script.Parent.Parent.Shared.Types)
local World = require(script.Parent.World)
local Image = require(script.Parent.Image)
local Surface = {}
local meshUris = {
	"rbxasset://models/AssetImporter/previewMesh.mesh",
	"rbxasset://models/MaterialManager/smooth_sphere.mesh",
}
local faceRotations: { [string]: CFrame } = {
	Front = CFrame.Angles(0, math.pi, 0),
	Back = CFrame.identity,
	Right = CFrame.Angles(0, -math.pi / 2, 0),
	Left = CFrame.Angles(0, math.pi / 2, 0),
	Top = CFrame.Angles(math.pi / 2, 0, 0),
	Bottom = CFrame.Angles(-math.pi / 2, 0, 0),
}
function Surface.Apply(source: Instance, mesh: MeshPart): Instance
	assert(source:IsA("SurfaceAppearance") or source:IsA("Decal"), "Expected a surface appearance, decal, or texture")
	local clone = (source :: Instance):Clone()
	assert(clone, "Surface is not Archivable")
	World.Sanitize(clone)
	clone.Parent = mesh
	if source:IsA("Decal") then
		-- Face is preserved; rotate the sample so the selected face faces the camera.
		mesh.CFrame = faceRotations[source.Face.Name]
	end
	return clone
end
function Surface.Variant(source: MaterialVariant, name: string, parent: Instance): Part
	local variant = source:Clone()
	assert(variant, "MaterialVariant is not Archivable")
	variant.Name, variant.Archivable, variant.Parent = name, false, parent
	local part = Instance.new("Part")
	part.Name = "MaterialSample"
	part.Shape = if source.MaterialPattern == Enum.MaterialPattern.Organic
		then Enum.PartType.Ball
		else Enum.PartType.Block
	part.Size, part.Color = Vector3.new(4, 4, 4), Color3.new(1, 1, 1)
	part.Material, part.MaterialVariant = source.BaseMaterial, name
	World.Sanitize(part)
	return part
end
local function meshAsync(): MeshPart
	local message = "Built-in preview mesh unavailable"
	for _, uri in meshUris do
		local ok, result = pcall(function(): MeshPart
			return game:GetService("AssetService"):CreateMeshPartAsync(Content.fromUri(uri), {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Precise,
			})
		end)
		if ok then
			result.Name = "SurfaceSample"
			result.TextureID = ""
			result.Color, result.Material = Color3.new(1, 1, 1), Enum.Material.SmoothPlastic
			local size = result.Size
			result.Size = size * (4 / math.max(size.X, size.Y, size.Z, 0.001))
			World.Sanitize(result)
			return result
		end
		message = tostring(result)
	end
	error(message)
end
function Surface.Mount(context: Types.PreviewContext)
	local model = Instance.new("Model")
	context.onCleanup(function()
		model:Destroy()
	end)
	local source = context.source
	if source:IsA("MaterialVariant") then
		-- Native variants must be registered under MaterialService. This isolated,
		-- non-archivable clone never overrides a place material and is cleaned up.
		local temporary = Instance.new("Folder")
		temporary.Name, temporary.Archivable = "_AssetToolsPreview", false
		temporary:SetAttribute("_AssetToolsPreview", true)
		context.onCleanup(function()
			temporary:Destroy()
		end)
		temporary.Parent = game:GetService("MaterialService")
		local part =
			Surface.Variant(source, "AssetTools_" .. game:GetService("HttpService"):GenerateGUID(false), temporary)
		part.Parent = model
		World.Mount(context, model)
		context.report(
			if part.Shape == Enum.PartType.Ball then "Organic material · sphere" else "Regular material · cube"
		)
		return
	end
	context.report("Loading surface sample…", "loading")
	local ok, mesh = pcall(meshAsync)
	if ok then
		context.onCleanup(function()
			mesh:Destroy()
		end)
	end
	if not context.isAlive() then
		return
	end
	if not ok then
		assert(Image.Asset(source) ~= "", tostring(mesh))
		Image.Mount(context)
		context.report("Mesh unavailable · texture image")
		return
	end
	Surface.Apply(source, mesh)
	mesh.Parent = model
	World.Mount(context, model)
	context.report("Surface sample · drag to orbit · scroll to zoom")
end
return Surface
