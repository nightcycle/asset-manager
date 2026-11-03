--!strict
local Cleanup = require(script.Parent.Parent.Shared.Cleanup)
local Registry = require(script.Parent.Parent.Preview.Registry)

local Capture = {}
export type Status = "loading" | "ready" | "error" | "finished" | "expired"
export type Info = {
	id: string,
	status: Status,
	renderer: string,
	message: string,
	viewportWidth: number,
	viewportHeight: number,
	expiresIn: number,
}
export type Controller = {
	Begin: (Instance) -> Info,
	Status: (string) -> Info,
	Finish: (string) -> Info,
	Destroy: () -> (),
}
type Session = { info: Info, cleanup: Cleanup.Cleanup, alive: boolean, deadline: number }

-- Each bridge owns one session. The caller takes the MCP screenshot between
-- Begin/ready and Finish; the plugin cannot call an external MCP tool itself.
function Capture.new(lifetime: number?): Controller
	local maxAge = lifetime or 120
	assert(maxAge > 0 and maxAge <= 120, "Capture lifetime must be in (0, 120] seconds")
	local current: Session? = nil
	local destroyed = false

	local function snapshot(session: Session): Info
		local info = table.clone(session.info)
		info.expiresIn = if session.alive then math.max(0, session.deadline - os.clock()) else 0
		return info
	end
	local function stop(session: Session, status: Status, message: string)
		if not session.alive then
			return
		end
		session.alive = false
		session.info.status, session.info.message = status, message
		session.cleanup:Destroy()
	end
	local function find(id: string): Session
		local session = current
		assert(session and session.info.id == id, "Unknown or stale capture id")
		return session
	end
	return {
		Begin = function(source)
			assert(not destroyed, "Capture controller is closed")
			assert(not current or not current.alive, "Finish the active capture before starting another")
			local runService = game:GetService("RunService")
			local workspace = game:GetService("Workspace")
			assert(not runService:IsRunning(), "Capture requires Studio edit mode")
			local camera = workspace.CurrentCamera
			assert(camera and camera.ViewportSize.X > 0 and camera.ViewportSize.Y > 0, "No active Studio viewport")
			local renderer = Registry.Resolve(source)
			assert(renderer.id ~= "fallback", "No preview renderer for " .. source.ClassName)
			local session: Session = {
				info = {
					id = game:GetService("HttpService"):GenerateGUID(false),
					status = "loading",
					renderer = renderer.id,
					message = "Preparing preview",
					viewportWidth = 0,
					viewportHeight = 0,
					expiresIn = maxAge,
				},
				cleanup = Cleanup.new(),
				alive = true,
				deadline = os.clock() + maxAge,
			}
			current = session
			local timer: thread? = nil
			session.cleanup:Add(function()
				if timer then
					task.cancel(timer)
					timer = nil
				end
			end)
			timer = task.delay(maxAge, function()
				timer = nil
				stop(session, "expired", "Capture timed out; temporary preview removed")
			end)
			task.spawn(function()
				local ok, message = pcall(function(): string?
					local part = Instance.new("Part")
					session.cleanup:Add(function()
						part:Destroy()
					end)
					part.Name, part.Archivable = "_AssetToolsCapture_" .. session.info.id, false
					part:SetAttribute("_AssetToolsPreview", true)
					part.Anchored, part.Transparency = true, 1
					part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false

					local gui = Instance.new("BillboardGui")
					session.cleanup:Add(function()
						gui:Destroy()
					end)
					gui.Name, gui.Archivable = part.Name, false
					gui:SetAttribute("_AssetToolsPreview", true)
					gui.Adornee = part
					-- Studio's MCP screenshot omits AlwaysOnTop UI. A CoreGui parent
					-- also avoids blank/cached ViewportFrames under Workspace parts.
					gui.AlwaysOnTop, gui.LightInfluence = false, 0
					gui.Brightness = 1
					local host = Instance.new("Frame")
					host.Name = "PreviewContent"
					host.Size = UDim2.fromScale(1, 1)
					host.BackgroundColor3 = Color3.fromRGB(28, 30, 34)
					host.BorderSizePixel = 0
					-- Clipping this host suppresses its ViewportFrame in Studio's
					-- world-space screenshot pass, even though layout reports ready.
					host.ClipsDescendants = false
					host.Parent = gui

					local function fit()
						local activeCamera = workspace.CurrentCamera
						if not activeCamera or runService:IsRunning() or source.Parent == nil then
							stop(session, "error", "Capture lost its camera, source, or edit session")
							return
						end
						local pixels = activeCamera.ViewportSize
						if pixels.X <= 0 or pixels.Y <= 0 then
							stop(session, "error", "Studio viewport is unavailable")
							return
						end
						local distance = math.max(2, -activeCamera.NearPlaneZ + 0.5)
						-- FieldOfView is the current vertical FOV in every FieldOfViewMode.
						local height = 2 * distance * math.tan(math.rad(activeCamera.FieldOfView / 2))
						local width = height * pixels.X / pixels.Y
						part.Size = Vector3.new(width, height, 0.05)
						part.CFrame = activeCamera.CFrame * CFrame.new(0, 0, -distance)
						gui.Size = UDim2.fromScale(width, height)
						session.info.viewportWidth, session.info.viewportHeight = pixels.X, pixels.Y
					end
					fit()
					if not session.alive then
						return nil
					end
					part.Parent = workspace
					gui.Parent = game:GetService("CoreGui")
					local connection = runService.Heartbeat:Connect(function()
						local fitted, failure = pcall(function(): string?
							fit()
							return nil
						end)
						if not fitted then
							stop(session, "error", tostring(failure))
						end
					end)
					session.cleanup:Add(function()
						connection:Disconnect()
					end)
					renderer.mount({
						host = host,
						source = source,
						options = {
							background = "Dark",
							playing = false,
							audioEnabled = false,
							mirrorLighting = false,
							scaleMode = "Fit",
						},
						report = function(status, kind)
							if session.alive then
								session.info.message = status
								if kind == "error" then
									stop(session, "error", status)
								end
							end
						end,
						onCleanup = function(callback)
							session.cleanup:Add(callback)
						end,
						isAlive = function()
							return session.alive
						end,
					})
					if not session.alive then
						return nil
					end
					local failed = 0
					game:GetService("ContentProvider"):PreloadAsync(host:GetDescendants(), function(_, status)
						if status ~= Enum.AssetFetchStatus.Success then
							failed += 1
						end
					end)
					assert(failed == 0, `{failed} preview assets failed to load`)
					-- Wait for layout/camera fitting and a rendered frame after loading.
					for _ = 1, 3 do
						runService.Heartbeat:Wait()
						if not session.alive then
							return nil
						end
					end
					assert(host.AbsoluteSize.X > 0 and host.AbsoluteSize.Y > 0, "Preview did not lay out")
					session.info.status = "ready"
					return nil
				end)
				if not ok then
					stop(session, "error", tostring(message))
				end
			end)
			return snapshot(session)
		end,
		Status = function(id)
			return snapshot(find(id))
		end,
		Finish = function(id)
			local session = find(id)
			stop(session, "finished", "Temporary preview removed")
			return snapshot(session)
		end,
		Destroy = function()
			destroyed = true
			if current then
				stop(current, "finished", "Bridge closed; temporary preview removed")
			end
		end,
	}
end

return Capture
