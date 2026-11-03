--!strict
-- Engine-only: verifies real BillboardGui layout, camera projection and teardown.
local Source = script.Parent.Parent.Source
local Capture = require(Source.Organizer.Capture)
local Bridge = require(Source.Organizer.Bridge)
local Database = require(Source.Organizer.Database)
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

return function(): number
	assert(not RunService:IsRunning(), "Run capture tests in edit mode")
	local camera = workspace.CurrentCamera
	assert(camera, "No Studio camera")
	local originalFrame, originalFocus = camera.CFrame, camera.Focus
	local originalMode, originalFov = camera.FieldOfViewMode, camera.FieldOfView
	local count = 0
	local function check(condition: boolean, message: string)
		assert(condition, message)
		count += 1
	end
	local root = Instance.new("Folder")
	root.Name, root.Archivable = "_AssetToolsCaptureTests", false
	root:SetAttribute("_AssetToolsPreview", true)
	root.Parent = game:GetService("ServerStorage")
	local part = Instance.new("Part")
	part.Name, part.Parent = "Subject", root
	local sourceFrame, sourceSize = part.CFrame, part.Size
	local controller = Capture.new()
	local expiring = Capture.new(0.1)
	local stopBridge: (() -> ())? = nil
	local function waitReady(id: string): Capture.Info
		local deadline = os.clock() + 15
		local info = controller.Status(id)
		while info.status == "loading" and os.clock() < deadline do
			task.wait()
			info = controller.Status(id)
		end
		check(info.status == "ready", "Capture not ready: " .. info.message)
		return info
	end
	local function absent(id: string): boolean
		local name = "_AssetToolsCapture_" .. id
		return workspace:FindFirstChild(name) == nil and game:GetService("CoreGui"):FindFirstChild(name) == nil
	end
	local ok, message = pcall(function(): string?
		local info = waitReady(controller.Begin(part).id)
		local stage = workspace:FindFirstChild("_AssetToolsCapture_" .. info.id) :: Part
		local gui = game:GetService("CoreGui"):FindFirstChild(stage.Name) :: BillboardGui
		check(gui.Adornee == stage and not gui.AlwaysOnTop, "Billboard is not in the screenshot render pass")
		local host = gui:FindFirstChild("PreviewContent") :: Frame
		check(not host.ClipsDescendants, "Clipped host hides the ViewportFrame in Studio screenshots")
		check(not stage.Archivable and not gui.Archivable, "Temporary capture can be saved")
		check(not stage.CanQuery and not stage.CanCollide and not stage.CanTouch, "Stage affects world queries")
		for _, mode in Enum.FieldOfViewMode:GetEnumItems() do
			camera.FieldOfViewMode = mode
			camera.FieldOfView = 52
			camera.CFrame = originalFrame * CFrame.Angles(0.1, 0.2, 0.03)
			task.wait(0.1)
			local pixels = camera.ViewportSize
			check((gui.AbsoluteSize - pixels).Magnitude < 2, "Billboard no longer fills the viewport")
			local topLeft = camera:WorldToViewportPoint(
				stage.CFrame:PointToWorldSpace(Vector3.new(-stage.Size.X / 2, stage.Size.Y / 2, 0))
			)
			local bottomRight = camera:WorldToViewportPoint(
				stage.CFrame:PointToWorldSpace(Vector3.new(stage.Size.X / 2, -stage.Size.Y / 2, 0))
			)
			check(Vector2.new(topLeft.X, topLeft.Y).Magnitude < 2, "Stage top-left is not at viewport origin")
			check(
				(Vector2.new(bottomRight.X, bottomRight.Y) - pixels).Magnitude < 2,
				"Stage bottom-right misses viewport"
			)
		end
		check(not pcall(controller.Begin, part), "Concurrent capture replaced the current session")
		check(not pcall(controller.Finish, "stale") and not absent(info.id), "Stale id removed an active capture")
		check(controller.Finish(info.id).status == "finished" and absent(info.id), "Finish leaked capture objects")
		check(controller.Finish(info.id).status == "finished", "Finish is not idempotent")
		part.Archivable = false
		local failed = controller.Begin(part)
		task.wait()
		check(
			controller.Status(failed.id).status == "error" and absent(failed.id),
			"Mount failure leaked capture objects"
		)
		part.Archivable = true
		local timed = expiring.Begin(part)
		task.wait(0.2)
		check(expiring.Status(timed.id).status == "expired" and absent(timed.id), "Timeout leaked capture objects")
		local pending = controller.Begin(part)
		controller.Destroy()
		task.wait()
		check(absent(pending.id), "Destroy during loading leaked objects")
		check(not pcall(controller.Begin, part), "Closed controller restarted")
		local database = Database.new(root, root, false)
		-- The fixture root is internal; clear that marker only for bridge resolution.
		root:SetAttribute("_AssetToolsPreview", nil)
		stopBridge = Bridge.Start(database, { preview = function() end, propose = function() end }, root)
		local endpoint = root:FindFirstChild("AssetToolsMCP") :: BindableFunction
		local function invoke(request: unknown): { ok: boolean, result: unknown }
			return HttpService:JSONDecode(endpoint:Invoke(HttpService:JSONEncode(request)))
		end
		check(not invoke({ action = "capture", path = "game" }).ok, "Bridge accepted a root capture")
		local response = invoke({ action = "capture", path = "game/Subject" })
		check(response.ok, "Bridge did not start capture")
		local result = response.result :: { capture: Capture.Info }
		local id = result.capture.id
		check(not invoke({ action = "finishCapture", id = 123 }).ok, "Bridge accepted an invalid session id")
		check(invoke({ action = "captureStatus", id = id }).ok, "Bridge did not expose capture status")
		endpoint:Destroy()
		task.wait()
		check(absent(id), "Endpoint removal leaked capture objects")
		check(part.Parent == root and part.CFrame == sourceFrame and part.Size == sourceSize, "Capture changed source")
		return nil
	end)
	controller.Destroy()
	expiring.Destroy()
	if stopBridge then
		stopBridge()
	end
	root:Destroy()
	camera.FieldOfViewMode, camera.FieldOfView = originalMode, originalFov
	camera.CFrame, camera.Focus = originalFrame, originalFocus
	assert(ok, tostring(message))
	return count
end
