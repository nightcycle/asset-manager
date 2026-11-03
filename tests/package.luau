--!strict
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
for _, name in { "Previewer", "Organizer" } do
	local roots = roblox.deserializeModel(fs.readFile(`build/Asset{name}.rbxm`))
	assert(#roots == 1 and roots[1]:IsA("Model"), "Invalid plugin artifact root")
	local root = roots[1]
	assert(root:FindFirstChild("Main") and root.Main:IsA("Script"), "Missing executable plugin entry")
	assert(root:FindFirstChild("Packages") and root:FindFirstChild("Source"), "Missing runtime files")
	assert(root:FindFirstChild("ThirdPartyNotices"), "Missing runtime dependency license notices")
	for _, instance in root:GetDescendants() do
		assert(
			instance.Name ~= "DevPackages" and instance.Name ~= "UILabs" and instance.Name ~= "Tests",
			"Development dependency leaked into plugin"
		)
		assert(not instance.Name:match("%.story$"), "A UI Labs story leaked into a production plugin")
	end
	print(`Verified {name} plugin artifact`)
end
