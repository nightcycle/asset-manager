--!strict
local Types = require(script.Parent.Parent.Shared.Types)
local R15 = require(script.Parent.R15)
local World = require(script.Parent.World)
local Image = require(script.Parent.Image)
local Clothing = {}
function Clothing.Apply(source: Instance, rig: Model): Instance
	assert(source:IsA("Shirt") or source:IsA("Pants") or source:IsA("ShirtGraphic"), "Expected classic clothing")
	local clone = (source :: Instance):Clone()
	assert(clone, "Clothing is not Archivable")
	World.Sanitize(clone)
	clone.Parent = rig
	return clone
end
function Clothing.Mount(context: Types.PreviewContext)
	assert(Image.Asset(context.source) ~= "", "Set a clothing template image to preview this item")
	-- Classic shirt/pants compositing can fail in edit-mode viewports. Always expose
	-- the actual template instead of displaying an apparently undressed mannequin.
	if context.source:IsA("Shirt") or context.source:IsA("Pants") then
		Image.Mount(context)
		context.report("Classic clothing · template image")
		return
	end
	context.report("Dressing R15 mannequin…", "loading")
	local ok, rig = pcall(R15.Create, context)
	if not context.isAlive() then
		return
	end
	if not ok or not rig then
		Image.Mount(context)
		context.report("T-shirt · image preview")
		return
	end
	Clothing.Apply(context.source, rig)
	World.Mount(context, rig)
	context.report("Classic clothing · R15 mannequin")
end
return Clothing
