--!strict
local Pagination = {}
function Pagination.PreviewCapacity(width: number, height: number, minimum: number, maximum: number): number
	-- Roughly 100 px square slots; a normal dock can comfortably render sixteen.
	return math.clamp(math.floor(math.max(width, 1) * math.max(height, 1) / 10000 + 0.5), minimum, maximum)
end
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
	count = math.max(1, math.floor(count))
	local aspect = math.max(width, 1) / math.max(height, 1)
	local bestColumns, bestRows, bestScore = 1, count, math.huge
	for columns = 1, count do
		-- Only consider complete rows; choose the closest-to-square cells within those layouts.
		if count % columns ~= 0 then
			continue
		end
		local rows = count / columns
		local score = math.abs(math.log(aspect * rows / columns))
		if score < bestScore - 0.000001 then
			bestColumns, bestRows, bestScore = columns, rows, score
		end
	end
	return bestColumns, bestRows
end
return Pagination
