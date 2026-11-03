--!strict
export type Cleanup = { Add: (self: Cleanup, callback: () -> ()) -> (), Destroy: (self: Cleanup) -> () }
local Cleanup = {}
function Cleanup.new(): Cleanup
	local callbacks: { () -> () } = {}
	local destroyed = false
	return {
		Add = function(_, callback)
			if destroyed then
				callback()
			else
				table.insert(callbacks, callback)
			end
		end,
		Destroy = function(_)
			if destroyed then
				return
			end
			destroyed = true
			for index = #callbacks, 1, -1 do
				local ok, message = pcall(function(): string?
					callbacks[index]()
					return nil
				end)
				if not ok then
					warn(message)
				end
			end
			table.clear(callbacks)
		end,
	}
end
return Cleanup
