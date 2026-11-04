--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Parent.Shared.Types)
local Framing = require(script.Parent.Framing)
local Ribbons = {}

export type Point = { position: Vector2, width: number, alpha: number, distance: number }
export type Shape = { points: { Point }, center: Vector2, size: Vector2, length: number }
type Slice = { image: ImageLabel, mask: UIGradient }

local MAX_SEGMENTS = 64
local MAX_SLICES = 128
local TRAIL_HISTORY = 4
local TRAIL_SPEED = 1.5
local TRAIL_RADIUS = 4

local function numberAt(sequence: NumberSequence, time: number): number
	local keys = sequence.Keypoints
	for index = 2, #keys do
		local a, b = keys[index - 1], keys[index]
		if time <= b.Time then
			return a.Value + (b.Value - a.Value) * math.clamp((time - a.Time) / (b.Time - a.Time), 0, 1)
		end
	end
	return keys[#keys].Value
end

local function colorAt(sequence: ColorSequence, time: number): Color3
	local keys = sequence.Keypoints
	for index = 2, #keys do
		local a, b = keys[index - 1], keys[index]
		if time <= b.Time then
			return a.Value:Lerp(b.Value, math.clamp((time - a.Time) / (b.Time - a.Time), 0, 1))
		end
	end
	return keys[#keys].Value
end

-- Read local frames so detached assets work too; never move the source attachments.
local function attachmentFrame(attachment: Attachment): CFrame
	local frame = attachment.CFrame
	if attachment:IsA("Bone") then
		frame *= attachment.Transform
	end
	local parent = attachment.Parent
	while parent do
		if parent:IsA("BasePart") then
			return parent.CFrame * frame
		elseif parent:IsA("Attachment") then
			local offset = parent.CFrame
			if parent:IsA("Bone") then
				offset *= parent.Transform
			end
			frame = offset * frame
		end
		parent = parent.Parent
	end
	return frame
end

local function shape(points: { Point }, minimum: Vector2?, maximum: Vector2?): Shape
	local low, high = minimum or Vector2.zero, maximum or Vector2.zero
	for index, point in points do
		local radius = Vector2.one * point.width / 2
		if index == 1 and not minimum then
			low, high = point.position - radius, point.position + radius
		else
			low, high = low:Min(point.position - radius), high:Max(point.position + radius)
		end
	end
	return {
		points = points,
		center = (low + high) / 2,
		size = (high - low):Max(Vector2.one * 0.1),
		length = if #points > 0 then points[#points].distance else 0,
	}
end

function Ribbons.Beam(source: Beam): Shape
	local a = if source.Attachment0 then attachmentFrame(source.Attachment0) else CFrame.new(-4, 0, 0)
	local b = if source.Attachment1 then attachmentFrame(source.Attachment1) else CFrame.new(4, 0, 0)
	-- A single assigned attachment should not stretch a sample across the place.
	if source.Attachment0 and not source.Attachment1 then
		b = a * CFrame.new(8, 0, 0)
	elseif source.Attachment1 and not source.Attachment0 then
		a = b * CFrame.new(-8, 0, 0)
	end
	local p0, p3 = a.Position, b.Position
	local p1, p2 = p0 + a.RightVector * source.CurveSize0, p3 - b.RightVector * source.CurveSize1
	local chord = p3 - p0
	local right = if chord.Magnitude > 0.0001 then chord.Unit else Vector3.xAxis
	local up = Vector3.yAxis - right * right.Y
	if up.Magnitude < 0.0001 then
		up = Vector3.zAxis - right * right.Z
	end
	-- Show the curve's own plane instead of losing depth-only curvature.
	local bend0, bend1 = p1 - p0, p2 - p0
	bend0 -= right * bend0:Dot(right)
	bend1 -= right * bend1:Dot(right)
	local bend = if bend0.Magnitude >= bend1.Magnitude then bend0 else bend1
	if bend.Magnitude > 0.0001 then
		up = bend
	end
	up = up.Unit
	local points: { Point } = {}
	local count = math.clamp(source.Segments, 1, MAX_SEGMENTS)
	local distance = 0
	local previous = p0
	for index = 0, count do
		local t = index / count
		local s = 1 - t
		local position = p0 * s ^ 3 + p1 * (3 * s ^ 2 * t) + p2 * (3 * s * t ^ 2) + p3 * t ^ 3
		distance += (position - previous).Magnitude
		previous = position
		local offset = position - p0
		table.insert(points, {
			position = Vector2.new(offset:Dot(right), -offset:Dot(up)),
			width = math.max(0, source.Width0 + (source.Width1 - source.Width0) * t),
			alpha = t,
			distance = distance,
		})
	end
	return shape(points)
end

function Ribbons.Trail(source: Trail, time: number): Shape
	local width = 2
	if source.Attachment0 and source.Attachment1 then
		width = (attachmentFrame(source.Attachment1).Position - attachmentFrame(source.Attachment0).Position).Magnitude
	end
	local maximumWidth = 0
	for _, key in source.WidthScale.Keypoints do
		maximumWidth = math.max(maximumWidth, width * key.Value)
	end
	local extent = Vector2.one * (TRAIL_RADIUS + maximumWidth / 2)
	local points: { Point } = {}
	local lifetime = source.Lifetime
	if lifetime <= 0 then
		return shape(points, -extent, extent)
	end
	local duration = math.min(lifetime, TRAIL_HISTORY)
	if source.MaxLength > 0 then
		duration = math.min(duration, source.MaxLength / (TRAIL_RADIUS * TRAIL_SPEED))
	end
	local count = math.clamp(math.ceil(duration * 60), 1, MAX_SEGMENTS)
	local distance = 0
	for index = 0, count do
		local age = duration * index / count
		local angle = (time - age) * TRAIL_SPEED
		local position = Vector2.new(math.cos(angle), math.sin(angle)) * TRAIL_RADIUS
		local previous = points[#points]
		local step = if previous then (position - previous.position).Magnitude else 0
		if previous and step < source.MinLength then
			continue
		end
		distance += step
		table.insert(points, {
			position = position,
			width = math.max(0, width * numberAt(source.WidthScale, age / lifetime)),
			alpha = age / lifetime,
			distance = distance,
		})
	end
	-- A stable motion envelope prevents the preview from zooming on every frame.
	return shape(points, -extent, extent)
end

function Ribbons.TextureCycles(mode: Enum.TextureMode, textureLength: number, length: number): number
	local cycles = if mode == Enum.TextureMode.Stretch then textureLength else length / math.max(textureLength, 0.001)
	return math.clamp(cycles, 0.05, 32)
end

-- Mask a normalized portion of the whole image. Unlike ImageRectSize, this
-- does not require knowing the resolution of the source texture.
local function cropMask(first: number, last: number): NumberSequence
	local keys: { NumberSequenceKeypoint } = {}
	if first > 0.00001 then
		table.insert(keys, NumberSequenceKeypoint.new(0, 1))
		table.insert(keys, NumberSequenceKeypoint.new(first, 1))
		table.insert(keys, NumberSequenceKeypoint.new(math.min(first + 0.00001, (first + last) / 2), 0))
	else
		table.insert(keys, NumberSequenceKeypoint.new(0, 0))
	end
	if last < 0.99999 then
		table.insert(keys, NumberSequenceKeypoint.new(math.max(last - 0.00001, (first + last) / 2), 0))
		table.insert(keys, NumberSequenceKeypoint.new(last, 1))
		table.insert(keys, NumberSequenceKeypoint.new(1, 1))
	else
		table.insert(keys, NumberSequenceKeypoint.new(1, 0))
	end
	return NumberSequence.new(keys)
end

function Ribbons.Mount(context: Types.PreviewContext)
	local source = context.source
	assert(source:IsA("Beam") or source:IsA("Trail"), "Expected Beam or Trail")
	local layer = Instance.new("Frame")
	layer.Name = "RibbonPreview"
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.ClipsDescendants = true
	layer.Parent = context.host
	context.onCleanup(function()
		layer:Destroy()
	end)
	local slices: { Slice } = {}
	local elapsed = 0
	local function render()
		local sample = if source:IsA("Beam") then Ribbons.Beam(source) else Ribbons.Trail(source, elapsed)
		local pixels = context.host.AbsoluteSize
		local scale = Framing.Scale(sample.size, pixels * 0.94, context.options.scaleMode)
		local cycles = Ribbons.TextureCycles(source.TextureMode, source.TextureLength, sample.length)
		local phase = if source:IsA("Beam")
			then -elapsed * source.TextureSpeed
			elseif source.TextureMode == Enum.TextureMode.Static then -elapsed * TRAIL_RADIUS * TRAIL_SPEED / math.max(
				source.TextureLength,
				0.001
			)
			else 0
		local used = 0
		local textured = source.Texture ~= ""
		for index = 2, #sample.points do
			local a, b = sample.points[index - 1], sample.points[index]
			local delta = b.position - a.position
			local length = delta.Magnitude * scale
			local width = (a.width + b.width) * 0.5 * scale
			if length < 0.001 or width <= 0 then
				continue
			end
			local u0 = a.distance / math.max(sample.length, 0.001) * cycles + phase
			local u1 = b.distance / math.max(sample.length, 0.001) * cycles + phase
			if not textured then
				u0, u1 = 0, 1
			end
			local cursor = u0
			while cursor < u1 - 0.000001 and used < MAX_SLICES do
				local boundary = math.min(u1, math.floor(cursor) + 1)
				local first, last = cursor % 1, boundary - math.floor(cursor)
				if last - first < 0.0001 then
					cursor = boundary
					continue
				end
				used += 1
				local slice = slices[used]
				if not slice then
					local image = Instance.new("ImageLabel")
					image.Name = "RibbonSlice"
					image.AnchorPoint = Vector2.one / 2
					image.BorderSizePixel = 0
					image.Parent = layer
					local mask = Instance.new("UIGradient")
					mask.Parent = image
					slice = { image = image, mask = mask }
					slices[used] = slice
				end
				local image = slice.image
				local fullLength = length / math.max(u1 - u0, 0.000001)
				local offset = (math.floor(cursor) + 0.5 - u0) * fullLength
				local position = pixels / 2 + (a.position - sample.center) * scale + delta.Unit * offset
				local alpha = (a.alpha + b.alpha) / 2
				local transparency = math.clamp(numberAt(source.Transparency, alpha), 0, 1)
				image.Visible = pixels.X > 0 and pixels.Y > 0
				image.Position = UDim2.fromOffset(position.X, position.Y)
				image.Size = UDim2.fromOffset(fullLength, width)
				image.Rotation = math.deg(math.atan2(delta.Y, delta.X))
				image.Image = source.Texture
				image.ImageColor3 = colorAt(source.Color, alpha)
				image.BackgroundColor3 = image.ImageColor3
				image.ImageTransparency = transparency
				image.BackgroundTransparency = if textured then 1 else transparency
				slice.mask.Transparency = cropMask(first, last)
				cursor = boundary
			end
		end
		for index = used + 1, #slices do
			slices[index].image.Visible = false
		end
	end
	render()
	local connection = RunService.Heartbeat:Connect(function(dt: number)
		if context.options.playing then
			elapsed += math.min(dt, 0.1)
		end
		render()
	end)
	context.onCleanup(function()
		connection:Disconnect()
	end)
	local fallback = if source.Attachment0 and source.Attachment1 then "" else " · sample attachments"
	context.report(
		if source:IsA("Beam")
			then "Beam FX approximation · curve, width, and scrolling texture" .. fallback
			else "Trail FX approximation · looping sample motion · up to 4 seconds of history" .. fallback
	)
end

return Ribbons
