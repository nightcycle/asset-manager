--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Parent.Shared.Types)
local Particles = {}
type Particle = {
	label: ImageLabel,
	age: number,
	life: number,
	velocity: Vector2,
	position: Vector2,
	spin: number,
	rotation: number,
	seed: number,
}

local function numberAt(sequence: NumberSequence, time: number, seed: number): number
	local keys = sequence.Keypoints
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if time <= b.Time then
			local alpha = (time - a.Time) / math.max(b.Time - a.Time, 0.001)
			return a.Value + (b.Value - a.Value) * alpha + (a.Envelope + (b.Envelope - a.Envelope) * alpha) * seed
		end
	end
	return keys[#keys].Value
end
local function colorAt(sequence: ColorSequence, time: number): Color3
	local keys = sequence.Keypoints
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if time <= b.Time then
			return a.Value:Lerp(b.Value, (time - a.Time) / math.max(b.Time - a.Time, 0.001))
		end
	end
	return keys[#keys].Value
end

function Particles.Mount(context: Types.PreviewContext)
	local source = context.source
	assert(source:IsA("ParticleEmitter"), "Expected ParticleEmitter")
	context.report("Animated FX approximation · screen projection · max 128 particles")
	local particles: { Particle } = {}
	local random = Random.new(137)
	local credit = 0
	local grid = if source.FlipbookLayout == Enum.ParticleFlipbookLayout.Grid2x2
		then 2
		elseif source.FlipbookLayout == Enum.ParticleFlipbookLayout.Grid4x4 then 4
		elseif source.FlipbookLayout == Enum.ParticleFlipbookLayout.Grid8x8 then 8
		else 1
	local textureSize = source:GetAttribute("Preview_TextureSize")
	local cell = (if type(textureSize) == "number" then math.clamp(textureSize, 1, 8192) else 1024) / grid
	local function spawn()
		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Image = source.Texture
		label.Parent = context.host
		local spread = math.rad(random:NextNumber(-source.SpreadAngle.X, source.SpreadAngle.X))
		local direction = source.EmissionDirection
		local angle = if direction == Enum.NormalId.Bottom
			then math.pi
			elseif direction == Enum.NormalId.Left then -math.pi / 2
			elseif direction == Enum.NormalId.Right then math.pi / 2
			else 0
		local speed = random:NextNumber(source.Speed.Min, source.Speed.Max)
		table.insert(particles, {
			label = label,
			age = 0,
			life = math.max(0.05, random:NextNumber(source.Lifetime.Min, source.Lifetime.Max)),
			position = Vector2.zero,
			velocity = Vector2.new(math.sin(angle + spread), -math.cos(angle + spread)) * speed,
			spin = random:NextNumber(source.RotSpeed.Min, source.RotSpeed.Max),
			rotation = random:NextNumber(source.Rotation.Min, source.Rotation.Max),
			seed = random:NextNumber(-1, 1),
		})
	end
	local connection = RunService.Heartbeat:Connect(function(rawDt)
		local dt = if context.options.playing then math.min(rawDt, 0.1) * source.TimeScale else 0
		credit += dt * math.clamp(source.Rate, 1, 128)
		while credit >= 1 and #particles < 128 do
			credit -= 1
			spawn()
		end
		credit = math.min(credit, 1)
		local pixels = context.host.AbsoluteSize
		local extent = if context.options.scaleMode == "Fill"
			then math.max(pixels.X, pixels.Y)
			else math.min(pixels.X, pixels.Y)
		local scale = extent / math.max(12, source.Speed.Max * source.Lifetime.Max * 1.5)
		for index = #particles, 1, -1 do
			local particle = particles[index]
			particle.age += dt
			if particle.age >= particle.life then
				particle.label:Destroy()
				table.remove(particles, index)
				continue
			end
			particle.velocity = (particle.velocity + Vector2.new(source.Acceleration.X, -source.Acceleration.Y) * dt)
				* math.exp(-source.Drag * dt)
			particle.position += particle.velocity * dt
			local alpha = particle.age / particle.life
			local size = math.max(0, numberAt(source.Size, alpha, particle.seed)) * scale
			local label = particle.label
			label.Position = UDim2.new(0.5, particle.position.X * scale, 0.65, particle.position.Y * scale)
			label.Size = UDim2.fromOffset(size, size)
			label.ImageColor3 = colorAt(source.Color, alpha)
			label.ImageTransparency = math.clamp(numberAt(source.Transparency, alpha, particle.seed), 0, 1)
			label.Rotation = particle.rotation + particle.age * particle.spin
			if grid > 1 then
				local mode = source.FlipbookMode
				local count = grid * grid
				local frame = if mode == Enum.ParticleFlipbookMode.OneShot
					then math.min(count - 1, math.floor(alpha * count))
					else math.floor(particle.age * source.FlipbookFramerate.Min) % count
				if mode == Enum.ParticleFlipbookMode.Random then
					frame = math.floor((particle.seed + 1) * 0.5 * (count - 1))
				end
				if mode == Enum.ParticleFlipbookMode.PingPong then
					local step = math.floor(particle.age * source.FlipbookFramerate.Min) % (2 * (count - 1))
					frame = if step < count then step else 2 * (count - 1) - step
				end
				label.ImageRectSize = Vector2.new(cell, cell)
				label.ImageRectOffset = Vector2.new((frame % grid) * cell, math.floor(frame / grid) * cell)
			end
		end
	end)
	context.onCleanup(function()
		connection:Disconnect()
		for _, particle in particles do
			particle.label:Destroy()
		end
	end)
end
return Particles
