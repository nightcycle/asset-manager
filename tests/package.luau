--!strict
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
for _, name in { "Previewer", "Organizer" } do
	local roots = roblox.deserializeModel(fs.readFile(`build/Asset{name}.rbxm`))
	assert(#roots == 1 and roots[1]:IsA("Model"), "Invalid plugin artifact root")
	local root = roots[1]
	assert(root:FindFirstChild("Main") and root.Main:IsA("Script"), "Missing executable plugin entry")
	assert(root:FindFirstChild("Packages") and root:FindFirstChild("Source"), "Missing runtime files")
	assert(root:FindFirstChild("ThirdPartyNotices"), "Missing runtime dependency license notices")
	assert(root.Packages:FindFirstChild("MaterialIcons"), "MaterialIcons missing from runtime packages")
	local icons = luau.load(root.Source.Generated.PluginIcons.Source)()
	assert(
		type(icons.Previewer) == "string" and type(icons.Organizer) == "string" and icons.Previewer ~= icons.Organizer,
		"Missing distinct Asphalt plugin icons"
	)
	for _, icon in { icons.Previewer, icons.Organizer } do
		assert(
			icon:match("^rbxassetid://%d+$") or icon:match("^rbxasset://%.asphalt%-"),
			"Invalid Asphalt asset reference"
		)
	end
	assert(root.Source.Shared:FindFirstChild("PluginToolbar"), "Missing shared toolbar host")
	local iconPackage = root.Packages._Index["nightcycle_material-icons@1.0.3"]["material-icons"]
	local glyphs = luau.load(
		iconPackage.Default_24_2.Source,
		{ environment = { Vector2 = roblox.Vector2 }, injectGlobals = true }
	)()
	for _, icon in
		{
			"folder",
			"arrow_back",
			"arrow_forward",
			"arrow_upward",
			"menu",
			"close",
			"more_horiz",
			"chevron_left",
			"chevron_right",
			"insert_drive_file",
			"view_in_ar",
			"movie",
			"image",
			"volume_up",
		}
	do
		local glyph = glyphs[icon]
		assert(
			glyph and glyph.Image:match("^rbxassetid://") and glyph.ImageRectSize == roblox.Vector2.new(48, 48),
			"Missing or invalid MaterialIcons glyph: " .. icon
		)
	end
	for _, instance in root:GetDescendants() do
		assert(
			instance.Name ~= "DevPackages" and instance.Name ~= "UILabs" and instance.Name ~= "Tests",
			"Development dependency leaked into plugin"
		)
		assert(not instance.Name:match("%.story$"), "A UI Labs story leaked into a production plugin")
	end
	print(`Verified {name} plugin artifact`)
end
