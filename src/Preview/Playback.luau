--!strict
local Types = require(script.Parent.Parent.Shared.Types)
local Playback = {}
function Playback.Sound(selection: { Instance }, first: number, last: number, preferred: Instance?): Instance?
	local firstSound: Instance? = nil
	for index = first, last do
		local source = selection[index]
		if source and source:IsA("Sound") then
			firstSound = firstSound or source
			if source == preferred then
				return source
			end
		end
	end
	return firstSound
end
function Playback.Audible(options: Types.PreviewOptions): boolean
	return options.playing and options.audioEnabled ~= false
end
function Playback.HasControls(source: Instance): boolean
	return source:IsA("Sound")
		or source:IsA("Animation")
		or source:IsA("AnimationClip")
		or source:IsA("ParticleEmitter")
		or source:IsA("Beam")
		or source:IsA("Trail")
		or source:GetAttribute("Preview_FlipbookColumns") ~= nil
end
return Playback
