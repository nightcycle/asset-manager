--!strict
local React = require(script.Parent.Parent.Packages.React)
local App = require(script.Parent.Parent.Source.Preview.App)
local Story = require(script.Parent.Story)
return Story.Create(
	"Bone stand-in",
	{ LightTheme = false, SingleKeyframe = false, SinglePose = false },
	function(fixture, props)
		local clip = React.useMemo(function()
			local sequence = Instance.new("KeyframeSequence")
			sequence.Name, sequence.Parent = "Unmatched rig animation", fixture.root
			for _, time in { 0, 0.5, 1 } do
				local key = Instance.new("Keyframe")
				key.Time, key.Parent = time, sequence
				local root = Instance.new("Pose")
				root.Name, root.Parent, root.Weight = "CreatureRoot", key, 1
				for index = 1, 3 do
					local limb = Instance.new("Pose")
					limb.Name, limb.Parent, limb.Weight = "Limb" .. tostring(index), root, 1
					limb.CFrame = CFrame.Angles(0, 0, if time == 0.5 then (index - 2) * math.pi / 3 else 0)
					limb.EasingStyle = Enum.PoseEasingStyle.Linear
					local tip = Instance.new("Pose")
					tip.Name, tip.Parent, tip.Weight = "Tip", limb, 1
				end
			end
			return sequence
		end, {})
		local selection: { Instance } = {
			if props.controls.SinglePose == true
				then clip:GetChildren()[2]:GetChildren()[1]
				elseif props.controls.SingleKeyframe == true then clip:GetChildren()[2]
				else clip,
		}
		return React.createElement(App, { selection = selection })
	end
)
