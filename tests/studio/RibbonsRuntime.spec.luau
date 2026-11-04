--!strict
-- Engine-only; detached GUI fixtures do not modify the open place.
local Source = script.Parent.Parent.Source
local Ribbons = require(Source.Preview.Ribbons)
local Types = require(Source.Shared.Types)

return function(): number
	local count = 0
	local function check(condition: boolean, message: string)
		assert(condition, message)
		count += 1
	end
	local beam, trail = Instance.new("Beam"), Instance.new("Trail")
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureSpeed, beam.Width0, beam.Width1, beam.Segments = 0.7, 1, 0.5, 64
	trail.Texture, trail.Lifetime, trail.MinLength = beam.Texture, 1, 0
	local effects: { Beam | Trail } = { beam, trail }
	for _, source in effects do
		local host = Instance.new("Frame")
		host.Size = UDim2.fromOffset(400, 300)
		local cleanups: { () -> () } = {}
		local options: Types.PreviewOptions = {
			background = "Dark",
			playing = false,
			mirrorLighting = false,
			scaleMode = "Fit",
			thumbnail = true,
		}
		beam.Enabled, trail.Enabled = false, false
		beam.Texture, trail.Texture =
			"rbxasset://textures/particles/sparkles_main.dds", "rbxasset://textures/particles/sparkles_main.dds"
		local ok, message = pcall(function()
			Ribbons.Mount({
				host = host,
				source = source,
				options = options,
				report = function() end,
				onCleanup = function(callback)
					table.insert(cleanups, callback)
				end,
				isAlive = function()
					return true
				end,
			})
			local layer = host:FindFirstChild("RibbonPreview")
			check(layer ~= nil and #layer:GetChildren() > 0, "Paused FX did not mount visible content")
			assert(layer and layer:IsA("Frame"))
			local first = layer:GetChildren()[1] :: ImageLabel
			check(
				first.Visible and first.Size.Y.Offset > 0 and first.Image == source.Texture,
				"FX lost its texture or width"
			)
			local position = first.Position
			task.wait(0.1)
			check(first.Position == position, "Paused FX moved")
			options.playing = true
			task.wait(0.15)
			check(first.Position ~= position, "Playing FX did not advance")
			options.playing = false
			position = first.Position
			task.wait(0.1)
			check(first.Position == position, "Pause did not freeze FX")
			local size = first.Size
			options.scaleMode = "Fill"
			host.Size = UDim2.fromOffset(600, 100)
			task.wait(0.1)
			check(first.Size ~= size, "Resize/Fit/Fill did not reframe paused FX")
			for _, mode in Enum.TextureMode:GetEnumItems() do
				beam.TextureMode, trail.TextureMode = mode, mode
				beam.TextureLength, trail.TextureLength = 0, 0
				task.wait(0.05)
				check(#layer:GetChildren() <= 128, "Texture repetition exceeded the slice budget")
			end
			beam.Texture, trail.Texture = "", ""
			task.wait(0.05)
			check(first.Image == "" and first.BackgroundTransparency < 1, "Untextured FX is invisible")
			check(not source.Enabled and source.Parent == nil, "Mount changed source state")
		end)
		for index = #cleanups, 1, -1 do
			cleanups[index]()
		end
		check(#host:GetChildren() == 0, "Unmount leaked ribbon GUI")
		host:Destroy()
		if not ok then
			beam:Destroy()
			trail:Destroy()
			error(tostring(message))
		end
	end
	beam:Destroy()
	trail:Destroy()
	return count
end
