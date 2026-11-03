--!strict
local ViewSettings = {}
export type Settings = {
	minItems: number,
	maxItems: number,
	autoPlay: boolean,
	viewMode: "List" | "Grid",
	listPageSize: number?,
	gridPageSize: number?,
}
function ViewSettings.Default(organizer: boolean): Settings
	return {
		minItems = if organizer then 8 else 1,
		maxItems = if organizer then 100 else 16,
		autoPlay = true,
		viewMode = "List",
	}
end
function ViewSettings.Decode(raw: unknown, organizer: boolean): Settings
	local result = ViewSettings.Default(organizer)
	if type(raw) ~= "table" then
		return result
	end
	local data = raw :: { [string]: unknown }
	local cap = if organizer then 200 else 64
	for _, field in { "minItems", "maxItems" } do
		local value = data[field]
		if type(value) == "number" and value == value and math.abs(value) < math.huge then
			if field == "minItems" then
				result.minItems = math.clamp(math.floor(value), 1, cap)
			else
				result.maxItems = math.clamp(math.floor(value), 1, cap)
			end
		end
	end
	result.minItems = math.min(result.minItems, result.maxItems)
	if type(data.autoPlay) == "boolean" then
		result.autoPlay = data.autoPlay
	end
	if data.viewMode == "List" or data.viewMode == "Grid" then
		result.viewMode = data.viewMode
	end
	if organizer then
		for _, field in { "listPageSize", "gridPageSize" } do
			local value = data[field]
			if type(value) == "number" and value == value and value >= 1 and value < math.huge then
				if field == "listPageSize" then
					result.listPageSize = math.clamp(math.floor(value), 1, 200)
				else
					result.gridPageSize = math.clamp(math.floor(value), 1, 200)
				end
			end
		end
	end
	return result
end
function ViewSettings.PageSize(value: Settings): number?
	return if value.viewMode == "Grid" then value.gridPageSize else value.listPageSize
end
function ViewSettings.WithPageSize(value: Settings, pageSize: number?): Settings
	local updated = table.clone(value)
	if value.viewMode == "Grid" then
		updated.gridPageSize = pageSize
	else
		updated.listPageSize = pageSize
	end
	return updated
end
function ViewSettings.ExplorerCapacity(value: Settings, fittingItems: number): number
	local fixed = ViewSettings.PageSize(value)
	if fixed then
		return math.clamp(math.floor(fixed), 1, 200)
	end
	local fitted = math.clamp(fittingItems, value.minItems, value.maxItems)
	return math.clamp(fitted * (if value.viewMode == "Grid" then 3 else 1), value.minItems, value.maxItems)
end
function ViewSettings.Read(pluginInstance: Plugin, key: string, organizer: boolean): Settings
	local ok, raw = pcall(function(): unknown
		return pluginInstance:GetSetting(key)
	end)
	return ViewSettings.Decode(if ok then raw else nil, organizer)
end
function ViewSettings.Save(pluginInstance: Plugin, key: string, value: Settings)
	local ok, message = pcall(function(): string?
		pluginInstance:SetSetting(key, value)
		return nil
	end)
	if not ok then
		warn("Unable to save viewer settings: " .. tostring(message))
	end
end
return ViewSettings
