--!strict
local Types = require(script.Parent.Parent.Shared.Types)
local R15 = require(script.Parent.R15)
local World = require(script.Parent.World)
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
	context.report("Dressing R15 mannequin…", "loading")
	local rig = R15.Create(context)
	if not rig then
		return
	end
	Clothing.Apply(context.source, rig)
	World.Mount(context, rig)
	context.report("Classic clothing · R15 mannequin")
end
return Clothing
