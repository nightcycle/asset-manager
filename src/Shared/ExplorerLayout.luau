--!strict
local ExplorerLayout = {}
export type Layout = { columns: number, rows: number, width: number, height: number, gap: number, scale: number }

function ExplorerLayout.Fit(count: number, width: number, height: number, grid: boolean): Layout
	count = math.max(1, math.floor(count))
	width, height = math.max(width, 1), math.max(height, 1)
	local baseWidth = 144
	local baseHeight = if grid then baseWidth else 56
	local minimumColumns = if grid then 4 else 1
	local bestColumns, bestRows, bestScale = minimumColumns, math.ceil(count / minimumColumns), 0
	for columns = minimumColumns, if grid then math.max(minimumColumns, count) else 1 do
		local rows = math.ceil(count / columns)
		local scale = math.min(
			1,
			width / (columns * baseWidth + (columns - 1) * 8),
			height / (rows * baseHeight + (rows - 1) * 8)
		)
		if
			scale > bestScale + 0.000001
			or (
				math.abs(scale - bestScale) < 0.000001
				and (
					columns * rows < bestColumns * bestRows
					or (columns * rows == bestColumns * bestRows and columns > bestColumns)
				)
			)
		then
			bestColumns, bestRows, bestScale = columns, rows, scale
		end
	end
	local gap = 8 * bestScale
	local cellHeight = baseHeight * bestScale
	if grid then
		-- Fractional offsets can round up in Studio and wrap a nominal four-column row into three.
		cellHeight = if cellHeight >= 1 then math.floor(cellHeight) else cellHeight
		bestScale = cellHeight / baseHeight
		gap = math.floor(8 * bestScale)
	end
	return {
		columns = bestColumns,
		rows = bestRows,
		width = if grid then cellHeight else width,
		height = cellHeight,
		gap = gap,
		scale = bestScale,
	}
end
return ExplorerLayout
