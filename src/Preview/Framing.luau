--!strict
local Types = require(script.Parent.Parent.Shared.Types)
local Framing = {}
function Framing.Corners(box: CFrame, size: Vector3): { Vector3 }
	local points: { Vector3 } = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(points, box:PointToWorldSpace(size * Vector3.new(x, y, z) * 0.5))
			end
		end
	end
	return points
end
function Framing.Points(model: Model): { Vector3 }
	local points: { Vector3 } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Transparency < 1 and item.LocalTransparencyModifier < 1 then
			for _, point in Framing.Corners(item.CFrame, item.Size) do
				table.insert(points, point)
			end
		end
	end
	if #points == 0 then
		local box, size = model:GetBoundingBox()
		return Framing.Corners(box, size)
	end
	return points
end
function Framing.Solve(
	points: { Vector3 },
	direction: Vector3,
	aspect: number,
	fov: number,
	mode: Types.ScaleMode?
): (Vector3, number)
	assert(#points > 0, "Cannot frame an empty point set")
	local low, high = points[1], points[1]
	for _, point in points do
		low = low:Min(point)
		high = high:Max(point)
	end
	local origin = (low + high) / 2
	local backward = direction.Unit
	local upHint = if math.abs(backward.Y) > 0.999 then Vector3.zAxis else Vector3.yAxis
	local right = upHint:Cross(backward).Unit
	local view = CFrame.fromMatrix(origin, right, backward:Cross(right), backward)
	local tanY = math.tan(math.rad(fov / 2))
	local tanX = tanY * math.max(aspect, 0.01)
	-- Solve both frustum edge constraints, including depth; leave only a 2% border.
	if mode ~= "Fill" then
		tanX *= 0.98
		tanY *= 0.98
	end
	local maxX, minX, maxY, minY, nearest = -math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, point in points do
		local p = view:PointToObjectSpace(point)
		maxX, minX = math.max(maxX, p.X + p.Z * tanX), math.min(minX, p.X - p.Z * tanX)
		maxY, minY = math.max(maxY, p.Y + p.Z * tanY), math.min(minY, p.Y - p.Z * tanY)
		nearest = math.max(nearest, p.Z)
	end
	local horizontal, vertical = (maxX - minX) / (2 * tanX), (maxY - minY) / (2 * tanY)
	local distance = if mode == "Fill" then math.min(horizontal, vertical) else math.max(horizontal, vertical)
	return view:PointToWorldSpace(Vector3.new((maxX + minX) / 2, (maxY + minY) / 2, 0)),
		math.max(distance, nearest + 0.6)
end
function Framing.Scale(content: Vector2, viewport: Vector2, mode: Types.ScaleMode?): number
	local x = math.max(viewport.X, 1) / math.max(content.X, 1)
	local y = math.max(viewport.Y, 1) / math.max(content.Y, 1)
	return if mode == "Fill" then math.max(x, y) else math.min(x, y)
end
function Framing.Distance(
	box: CFrame,
	size: Vector3,
	direction: Vector3,
	aspect: number,
	fov: number,
	mode: Types.ScaleMode?
): number
	local _, distance = Framing.Solve(Framing.Corners(box, size), direction, aspect, fov, mode)
	return distance
end
return Framing
