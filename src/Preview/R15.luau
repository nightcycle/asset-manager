--!strict
local Types = require(script.Parent.Parent.Shared.Types)
local World = require(script.Parent.World)
local R15 = {}
local parents: { [string]: string } = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	LeftHand = "LeftLowerArm",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	RightHand = "RightLowerArm",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
	LeftFoot = "LeftLowerLeg",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	RightFoot = "RightLowerLeg",
}
function R15.Matches(channels: { [string]: (number) -> CFrame }): boolean
	for name in parents do
		if channels[name] then
			return true
		end
	end
	return false
end
function R15.EnsureMotors(rig: Model)
	local connected: { [BasePart]: boolean } = {}
	for _, item in rig:GetDescendants() do
		if item:IsA("Motor6D") and item.Part1 then
			connected[item.Part1] = true
		end
	end
	for childName, parentName in parents do
		local child, parent = rig:FindFirstChild(childName), rig:FindFirstChild(parentName)
		if not child or not child:IsA("BasePart") or not parent or not parent:IsA("BasePart") or connected[child] then
			continue
		end
		for _, attachment in child:GetChildren() do
			if not attachment:IsA("Attachment") or not attachment.Name:match("RigAttachment$") then
				continue
			end
			local other = parent:FindFirstChild(attachment.Name)
			if other and other:IsA("Attachment") then
				local motor = Instance.new("Motor6D")
				motor.Name, motor.Part0, motor.Part1 = childName .. "PreviewJoint", parent, child
				motor.C0, motor.C1, motor.Parent = other.CFrame, attachment.CFrame, child
				break
			end
		end
	end
end
function R15.Create(context: Types.PreviewContext): Model?
	local description = Instance.new("HumanoidDescription")
	context.onCleanup(function()
		description:Destroy()
	end)
	local rig = game:GetService("Players")
		:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	context.onCleanup(function()
		rig:Destroy()
	end)
	if not context.isAlive() then
		return nil
	end
	World.Sanitize(rig)
	for _, instance in rig:GetDescendants() do
		if instance:IsA("Animator") or instance:IsA("Clothing") or instance:IsA("ShirtGraphic") then
			instance:Destroy()
		end
	end
	return rig
end
return R15
