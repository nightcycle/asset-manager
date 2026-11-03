--!strict
local AssetFilter = {}
local infrastructure: { [string]: boolean } = {
	BindableEvent = true,
	BindableFunction = true,
	RemoteEvent = true,
	RemoteFunction = true,
	UnreliableRemoteEvent = true,
	Camera = true,
	Terrain = true,
	PackageLink = true,
}
function AssetFilter.IsNonAsset(instance: Instance): boolean
	return instance:IsA("LuaSourceContainer") or instance:IsA("ValueBase") or infrastructure[instance.ClassName] == true
end
return AssetFilter
