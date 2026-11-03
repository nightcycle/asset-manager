--!strict
local Pagination = {}
function Pagination.Page(count: number, requested: number, capacity: number): (number, number, number, number)
	capacity = math.max(1, math.floor(capacity))
	local pages = math.max(1, math.ceil(count / capacity))
	local page = math.clamp(math.floor(requested), 1, pages)
	return page, pages, (page - 1) * capacity + 1, math.min(count, page * capacity)
end
function Pagination.Grid(count: number, width: number, height: number): (number, number)
	local columns =
		math.clamp(math.ceil(math.sqrt(count * math.max(width, 1) / math.max(height, 1))), 1, math.max(count, 1))
	return columns, math.max(1, math.ceil(count / columns))
end
return Pagination
