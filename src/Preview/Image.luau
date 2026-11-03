--!strict
local RunService = game:GetService("RunService")
local Types = require(script.Parent.Parent.Shared.Types)
local Image = {}
function Image.Asset(source: Instance): string
	if source:IsA("Decal") or source:IsA("Texture") then
		return source.Texture
	end
	if source:IsA("ImageLabel") or source:IsA("ImageButton") then
		return source.Image
	end
	if source:IsA("ParticleEmitter") then
		return source.Texture
	end
	return ""
end
function Image.Number(source: Instance, name: string, fallback: number, maximum: number): number
	local value = source:GetAttribute(name)
	return if type(value) == "number" and value == value then math.clamp(value, 1, maximum) else fallback
end
function Image.Mount(context: Types.PreviewContext)
	local source = context.source
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	local function scale()
		label.ScaleType = if context.options.scaleMode == "Fill" then Enum.ScaleType.Crop else Enum.ScaleType.Fit
	end
	scale()
	local scaling = RunService.Heartbeat:Connect(scale)
	context.onCleanup(function()
		scaling:Disconnect()
	end)
	label.Image = Image.Asset(source)
	if source:IsA("Decal") then
		label.ImageColor3 = source.Color3
		label.ImageTransparency = source.Transparency
	end
	if source:IsA("ImageLabel") or source:IsA("ImageButton") then
		label.ImageRectOffset = source.ImageRectOffset
		label.ImageRectSize = source.ImageRectSize
		label.ImageColor3 = source.ImageColor3
		label.ImageTransparency = source.ImageTransparency
	end
	label.Parent = context.host
	context.onCleanup(function()
		label:Destroy()
	end)
	if source:GetAttribute("Preview_FlipbookColumns") then
		local columns = math.floor(Image.Number(source, "Preview_FlipbookColumns", 1, 64))
		local rows = math.floor(Image.Number(source, "Preview_FlipbookRows", 1, 64))
		local width = Image.Number(source, "Preview_FrameWidth", 256, 8192)
		local height = Image.Number(source, "Preview_FrameHeight", 256, 8192)
		local fps = Image.Number(source, "Preview_FPS", 24, 120)
		label.ImageRectSize = Vector2.new(width, height)
		local elapsed = 0
		local connection = RunService.Heartbeat:Connect(function(dt)
			if context.options.playing then
				elapsed += dt
			end
			local frame = math.floor(elapsed * fps) % (columns * rows)
			label.ImageRectOffset = Vector2.new((frame % columns) * width, math.floor(frame / columns) * height)
		end)
		context.onCleanup(function()
			connection:Disconnect()
		end)
		context.report(`Flipbook · {columns * rows} frames · {fps} FPS`)
	end
end
return Image
