--!strict
export type Value = string | number | boolean
export type TagDefinition = { name: string, description: string }
export type AttributeDefinition = {
	name: string,
	description: string,
	kind: "number" | "enum" | "boolean",
	min: number?,
	max: number?,
	values: { string }?,
}
export type Schema = { version: number, tags: { TagDefinition }, attributes: { AttributeDefinition } }
export type Query = {
	scope: string,
	search: string?,
	className: string?,
	tags: { string }?,
	attributes: { [string]: Value }?,
	offset: number?,
	limit: number?,
	-- Browse treats containers as directories and never descends into asset internals.
	browse: boolean?,
	recursive: boolean?,
}
export type Record = {
	path: string,
	name: string,
	fullName: string,
	className: string,
	sourceClassName: string,
	kind: "folder" | "asset",
	selectable: boolean,
	tags: { string },
	attributes: { [string]: Value },
}
export type Annotation = { path: string, tags: { string }, attributes: { [string]: Value } }
export type TagCount = { name: string, count: number }
export type Catalog = { tags: { TagCount }, attributes: { [string]: { Value } } }
export type Background = "Studio" | "Dark" | "Light"
export type ScaleMode = "Fit" | "Fill"
export type PreviewOptions = {
	background: Background,
	playing: boolean,
	mirrorLighting: boolean,
	thumbnail: boolean?,
	scaleMode: ScaleMode?,
	autoPlay: boolean?,
	audioEnabled: boolean?,
}
export type PreviewStatusKind = "info" | "loading" | "error"
export type PreviewPalette = { text: Color3, accent: Color3, button: Color3, buttonText: Color3 }
export type PreviewContext = {
	host: Frame,
	source: Instance,
	options: PreviewOptions,
	palette: PreviewPalette?,
	report: (string, PreviewStatusKind?) -> (),
	onCleanup: (() -> ()) -> (),
	isAlive: () -> boolean,
}
export type Renderer = { id: string, label: string, supports: (Instance) -> boolean, mount: (PreviewContext) -> () }
return {}
