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
}
export type Record = {
	path: string,
	name: string,
	fullName: string,
	className: string,
	tags: { string },
	attributes: { [string]: Value },
}
export type Annotation = { path: string, tags: { string }, attributes: { [string]: Value } }
export type TagCount = { name: string, count: number }
export type Catalog = { tags: { TagCount }, attributes: { [string]: { Value } } }
export type Background = "Studio" | "Dark" | "Light"
export type PreviewOptions = { background: Background, playing: boolean, mirrorLighting: boolean }
export type PreviewStatusKind = "info" | "loading" | "error"
export type PreviewContext = {
	host: Frame,
	source: Instance,
	options: PreviewOptions,
	report: (string, PreviewStatusKind?) -> (),
	onCleanup: (() -> ()) -> (),
	isAlive: () -> boolean,
}
export type Renderer = { id: string, label: string, supports: (Instance) -> boolean, mount: (PreviewContext) -> () }
return {}
