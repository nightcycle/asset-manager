--!strict
local Packages = script.Parent.Parent.Parent.Packages
local React = require(Packages.React)
local Studio = require(Packages.StudioComponents)
local MaterialIcons = require(Packages.MaterialIcons)
local e = React.createElement
local Icons = {}
export type Name =
	"folder"
	| "folder_open"
	| "arrow_back"
	| "arrow_forward"
	| "arrow_upward"
	| "home"
	| "search"
	| "menu"
	| "close"
	| "more_horiz"
	| "chevron_left"
	| "chevron_right"
	| "description"
	| "movie"
	| "volume_up"
	| "image"
	| "refresh"
	| "insert_drive_file"
	| "view_in_ar"
	| "play_arrow"
	| "pause"
	| "grid_view"
	| "view_list"
	| "broken_image"
export type Glyph = { Image: string, ImageRectOffset: Vector2, ImageRectSize: Vector2 }
-- Keep the package's generated thousands-of-icons type behind this small adapter.
local glyphs = (MaterialIcons.default.dp_24.scale_2 :: unknown) :: { [string]: Glyph }
function Icons.Get(name: Name): Glyph
	return assert(glyphs[name], "Missing Material icon: " .. name)
end
function Icons.Image(
	props: { name: Name, size: UDim2?, position: UDim2?, color: Color3?, zIndex: number? }
): React.ReactElement
	local theme = Studio.useTheme()
	local glyph = Icons.Get(props.name)
	return e("ImageLabel", {
		Size = props.size or UDim2.fromOffset(24, 24),
		Position = props.position,
		BackgroundTransparency = 1,
		Image = glyph.Image,
		ImageRectOffset = glyph.ImageRectOffset,
		ImageRectSize = glyph.ImageRectSize,
		ImageColor3 = props.color or theme:GetColor(Enum.StudioStyleGuideColor.MainText),
		ZIndex = props.zIndex,
	})
end
function Icons.Button(props: {
	name: Name,
	text: string?,
	click: () -> (),
	position: UDim2?,
	size: UDim2?,
	anchorPoint: Vector2?,
	disabled: boolean?,
	order: number?,
	zIndex: number?,
}): React.ReactElement
	local glyph = Icons.Get(props.name)
	return e(Studio.Button, {
		Text = props.text,
		Icon = {
			Image = glyph.Image,
			RectOffset = glyph.ImageRectOffset,
			RectSize = glyph.ImageRectSize,
			Size = Vector2.new(20, 20),
			UseThemeColor = true,
		},
		OnActivated = props.click,
		Position = props.position,
		Size = props.size or UDim2.fromOffset(28, 28),
		AnchorPoint = props.anchorPoint,
		Disabled = props.disabled,
		LayoutOrder = props.order,
		ZIndex = props.zIndex,
	})
end
return Icons
