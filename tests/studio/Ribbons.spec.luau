--!strict
local Source = script.Parent.Parent.Source
local Ribbons = require(Source.Preview.Ribbons)
local Registry = require(Source.Preview.Registry)
local Playback = require(Source.Preview.Playback)
local Selection = require(Source.Preview.Selection)

return function(): number
	local count = 0
	local function check(condition: boolean, message: string)
		assert(condition, message)
		count += 1
	end
	local root = Instance.new("Folder")
	local beam, trail = Instance.new("Beam"), Instance.new("Trail")
	beam.Parent, trail.Parent = root, root
	check(Registry.Resolve(beam).id == "beam" and Registry.Resolve(trail).id == "trail", "Missing FX renderers")
	check(Playback.HasControls(beam) and Playback.HasControls(trail), "FX playback controls missing")
	check(#Selection.Expand({ root }) == 2, "Container expansion omitted Beam or Trail")
	beam.Segments, beam.Width0, beam.Width1 = 8, 2, 0
	beam.CurveSize0, beam.CurveSize1 = 0, 0
	local sample = Ribbons.Beam(beam)
	check(#sample.points == 9 and math.abs(sample.length - 8) < 0.001, "Detached Beam lacks sample endpoints")
	check(sample.points[1].width == 2 and sample.points[9].width == 0, "Beam endpoint widths lost")
	check(sample.size.X >= 9 and sample.size.Y >= 2, "Beam framing clips its width")
	local part = Instance.new("Part")
	part.CFrame, part.Parent = CFrame.new(100, 20, 40), root
	local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.pi / 2)
	b.CFrame = CFrame.new(8, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2)
	a.Parent, b.Parent = part, part
	beam.Attachment0, beam.Attachment1 = a, b
	beam.CurveSize0, beam.CurveSize1 = 4, 4
	sample = Ribbons.Beam(beam)
	check(math.abs(sample.points[5].position.Y + 3) < 0.001, "Beam cubic controls use incorrect attachment axes")
	check((sample.points[9].position - Vector2.new(8, 0)).Magnitude < 0.001, "Beam endpoints lost their spacing")
	part.CFrame *= CFrame.Angles(0.8, 0.4, 0.7)
	local rotated = Ribbons.Beam(beam)
	check(
		(rotated.points[5].position - sample.points[5].position).Magnitude < 0.001,
		"Projection lost rotated curvature"
	)
	b.CFrame = CFrame.new(12, 0, 0) * b.CFrame.Rotation
	check(Ribbons.Beam(beam).points[9].position.X > 11.99, "External attachment edits are stale")
	local single = Instance.new("Beam")
	single.Attachment0 = a
	local singleSample = Ribbons.Beam(single)
	check(
		math.abs(singleSample.points[#singleSample.points].position.X - 8) < 0.001,
		"One missing attachment used the world origin"
	)
	single:Destroy()
	beam.Attachment1 = a
	beam.CurveSize0, beam.CurveSize1 = 0, 0
	beam.Segments = 1000
	sample = Ribbons.Beam(beam)
	check(#sample.points <= 65 and sample.size.X > 0 and sample.length == 0, "Degenerate Beam is unbounded or invalid")
	local bone = Instance.new("Bone")
	bone.CFrame, bone.Transform, bone.Parent = CFrame.new(2, 0, 0), CFrame.new(3, 0, 0), part
	a.CFrame, a.Parent = CFrame.identity, bone
	b.CFrame = CFrame.new(10, 0, 0)
	beam.Attachment0, beam.Attachment1 = a, b
	check(math.abs(Ribbons.Beam(beam).length - 5) < 0.001, "Nested Bone transform was ignored")
	trail.Lifetime, trail.MinLength, trail.MaxLength = 1, 0, 0
	trail.WidthScale = NumberSequence.new(1, 0)
	local initial, moved = Ribbons.Trail(trail, 0), Ribbons.Trail(trail, 0.5)
	check(#initial.points > 2 and initial.length > 0, "Paused Trail starts empty")
	check(initial.points[1].width == 2 and initial.points[#initial.points].width == 0, "Trail width sequence was lost")
	check(initial.points[#initial.points].alpha == 1, "Trail samples do not expire at their lifetime")
	check(initial.center == moved.center and initial.size == moved.size, "Trail framing moves during playback")
	check((initial.points[1].position - moved.points[1].position).Magnitude > 1, "Trail sample path is static")
	trail.Attachment0, trail.Attachment1 = a, b
	check(math.abs(Ribbons.Trail(trail, 0).points[1].width - 5) < 0.001, "Trail ignored attachment spacing")
	trail.MaxLength = 1
	sample = Ribbons.Trail(trail, 0)
	check(
		sample.length <= 1.001 and sample.points[#sample.points].alpha < 1,
		"Trail MaxLength does not truncate history"
	)
	trail.MinLength = 100
	check(#Ribbons.Trail(trail, 0).points == 1, "Trail MinLength was ignored")
	trail.MinLength, trail.MaxLength, trail.Lifetime = 0, 0, 20
	sample = Ribbons.Trail(trail, 0)
	check(#sample.points <= 65 and sample.points[#sample.points].alpha <= 0.2, "Long Trail history is not bounded")
	trail.Lifetime = 0
	check(#Ribbons.Trail(trail, 0).points == 0, "Zero-lifetime Trail still draws history")
	check(Ribbons.TextureCycles(Enum.TextureMode.Stretch, 3, 10) == 3, "Stretch ignores repeat count")
	check(Ribbons.TextureCycles(Enum.TextureMode.Wrap, 2, 10) == 5, "Wrap ignores texture length")
	check(Ribbons.TextureCycles(Enum.TextureMode.Static, 2, 10) == 5, "Static ignores texture length")
	check(Ribbons.TextureCycles(Enum.TextureMode.Wrap, 0, 10) <= 32, "Zero texture length creates unbounded slices")
	check(a.Parent == bone and beam.Attachment0 == a and beam.Parent == root, "Preview changed source hierarchy")
	root:Destroy()
	return count
end
