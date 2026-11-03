--!strict
local Types = require(script.Parent.Parent.Shared.Types)
local World = require(script.Parent.World)
local Image = require(script.Parent.Image)
local Particles = require(script.Parent.Particles)
local Gui = require(script.Parent.Gui)
local Animation = require(script.Parent.Animation)
local Audio = require(script.Parent.Audio)
local Clothing = require(script.Parent.Clothing)
local Surface = require(script.Parent.Surface)
local Registry = {}
local renderers: { Types.Renderer } = {}
function Registry.Register(renderer: Types.Renderer, priority: number?)
	for _, existing in renderers do
		assert(existing.id ~= renderer.id, `Duplicate renderer: {renderer.id}`)
	end
	local position = priority or (#renderers + 1)
	if not priority then
		for index, existing in renderers do
			if existing.id == "fallback" then
				position = index
				break
			end
		end
	end
	table.insert(renderers, position, renderer)
end
function Registry.Resolve(source: Instance): Types.Renderer
	for _, renderer in renderers do
		if renderer.supports(source) then
			return renderer
		end
	end
	error("Missing fallback renderer")
end
Registry.Register({
	id = "animation",
	label = "Animation / pose",
	supports = function(i)
		return i:IsA("Animation") or i:IsA("AnimationClip") or i:IsA("Keyframe") or i:IsA("Pose")
	end,
	mount = Animation.Mount,
})
Registry.Register({
	id = "clothing",
	label = "Classic clothing",
	supports = function(i)
		return i:IsA("Shirt") or i:IsA("Pants") or i:IsA("ShirtGraphic")
	end,
	mount = Clothing.Mount,
})
Registry.Register({
	id = "particles",
	label = "Particle FX",
	supports = function(i)
		return i:IsA("ParticleEmitter")
	end,
	mount = Particles.Mount,
})
Registry.Register({
	id = "surface",
	label = "Material / surface",
	supports = function(i)
		return i:IsA("MaterialVariant") or i:IsA("SurfaceAppearance") or i:IsA("Decal")
	end,
	mount = Surface.Mount,
})
Registry.Register({
	id = "image",
	label = "Image / flipbook",
	supports = function(i)
		return (i:IsA("ImageLabel") or i:IsA("ImageButton")) and i:GetAttribute("Preview_FlipbookColumns") ~= nil
	end,
	mount = Image.Mount,
})
Registry.Register({
	id = "geometry",
	label = "3D viewport",
	supports = function(i)
		return i:IsA("BasePart")
			or i:IsA("Model")
			or i:IsA("Accessory")
			or i:IsA("Tool")
			or i:IsA("SpecialMesh")
			or (i:IsA("Folder") and i:FindFirstChildWhichIsA("BasePart", true) ~= nil)
	end,
	mount = World.Geometry,
})
Registry.Register({
	id = "gui",
	label = "User interface",
	supports = function(i)
		return i:IsA("GuiObject") or i:IsA("LayerCollector")
	end,
	mount = Gui.Mount,
})
Registry.Register({
	id = "sound",
	label = "Audio",
	supports = function(i)
		return i:IsA("Sound")
	end,
	mount = Audio.Mount,
})
Registry.Register({
	id = "fallback",
	label = "Instance details",
	supports = function(_)
		return true
	end,
	mount = function(context)
		context.report("No preview available for " .. context.source.ClassName)
	end,
})
return Registry
