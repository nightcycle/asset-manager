--!strict
local Pagination = {}
function Pagination.Capacity(
	width: number,
	height: number,
	itemWidth: number,
	itemHeight: number,
	minimum: number,
	maximum: number
): number
	local columns = math.max(1, math.floor(math.max(width, 1) / math.max(itemWidth, 1)))
	local rows = math.max(1, math.floor(math.max(height, 1) / math.max(itemHeight, 1)))
	return math.clamp(columns * rows, minimum, maximum)
end
function Pagination.Page(count: number, requested: number, capacity: number): (number, number, number, number)
	capacity = math.max(1, math.floor(capacity))
	local pages = math.max(1, math.ceil(count / capacity))
	local page = math.clamp(math.floor(requested), 1, pages)
	return page, pages, (page - 1) * capacity + 1, math.min(count, page * capacity)
end
function Pagination.Grid(count: number, width: number, height: number): (number, number)
	count = math.max(1, count)
	local aspect = math.max(width, 1) / math.max(height, 1)
	-- Extreme panels use a list along their long axis.
	if aspect <= 0.5 then
		return 1, count
	end
	if aspect >= 2 then
		return count, 1
	end
	local bestColumns, bestRows, bestScore = 1, count, math.huge
	for columns = 1, count do
		local rows = math.ceil(count / columns)
		local score = math.abs(math.log(aspect * rows / columns)) + (columns * rows - count) / count
		if score < bestScore then
			bestColumns, bestRows, bestScore = columns, rows, score
		end
	end
	return bestColumns, bestRows
end
return Pagination
