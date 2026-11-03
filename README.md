# Asset Tools for Roblox Studio

Two independent Studio plugins built with strict Luau, React 17, and [StudioComponents](https://github.com/sircfenner/StudioComponents). Wally manages runtime dependencies, including `MaterialIcons = "nightcycle/material-icons@1.0.3"`, and the UI Labs development dependency. Folder, navigation, menu, and fallback asset icons use MaterialIcons sprite sheets and Studio theme colors.

- **Previewer** follows Explorer selection, expands services, Folders, and Configurations recursively into their children, divides the viewer into 1, 4, or 9 tiles per page, and dispatches each instance to a class-specific renderer. Models, Tools, and Accessories stay intact; overlapping selections are deduplicated. Adding or removing children updates the previews. CoreGui is excluded.
- **Organizer** browses folders and asset files with thumbnails, defines a place-local metadata schema, filters assets by hierarchy, tags, and attributes, and applies undoable batch edits.

## Develop and install

For a ready-made test place, run `pwsh -File scripts/launch-demo.ps1`. It builds and checks the project, installs both local plugins (backing up changed existing versions), and opens `build/AssetToolsDemo.rbxl` in Studio. The demo includes your complete asset library at `ReplicatedStorage.lib`, a labelled gallery at `Workspace.AssetGallery`, an example Organizer schema, eight media fixtures, and the UI Labs development tree. Plugin builds are also embedded under `ServerStorage.PluginBuilds` for inspection.

The source library is vendored at `demo/assets/lib.rbxm`; the original file in `local-package` is not changed. Gallery copies are uniformly resized and positioned, while the imported library remains intact. Use `-SkipBuild` to reopen an existing build, `-NoOpen` to install without launching Studio, or `-PluginDirectory` / `-StudioPath` for a custom Studio installation. The launcher runs on Windows. Local plugins remain installed across places; opening an RBXL alone does not install or execute plugins. See `demo/README.txt` for the test walkthrough.

Install [Rokit](https://github.com/rojo-rbx/rokit), then run from this repository:

```powershell
rokit install
wally install
pwsh -File scripts/check.ps1
rojo serve default.project.json
```

Connect Rojo in Studio. The development tree appears at `ReplicatedStorage.AssetTools`. With the **UI Labs Studio plugin installed**, open the **Asset Tools** storybook. The Wally UI Labs package supplies story utilities; it does not install the Studio plugin itself.

The check command emits:

| File | Purpose |
| --- | --- |
| `build/AssetPreviewer.rbxm` | Standalone Previewer plugin |
| `build/AssetOrganizer.rbxm` | Standalone Organizer plugin |
| `build/development.rbxl` | Development place containing the complete source, dependencies, stories, and tests |
| `build/AssetToolsDemo.rbxl` | Interactive test place with the supplied asset library, labelled gallery, media fixtures, schema, and embedded plugin builds |

To install local plugin builds:

```powershell
rojo build previewer.project.json --plugin AssetPreviewer.rbxm
rojo build organizer.project.json --plugin AssetOrganizer.rbxm
```

Enable each plugin from the **Asset Tools** toolbar. Their stable widget IDs and `overridePreviousState=false` let Studio restore docking, size, and open/closed state across sessions. Closing a widget unmounts its UI and releases preview resources; the bridge is also stopped. Plugin settings remember background, Fit/Fill, autoplay, page limits, and Organizer's List/Grid preference.

## Preview behavior

| Selection | Renderer |
| --- | --- |
| Service, Folder, Configuration | Expand into children; nested containers expand recursively |
| BasePart, Model, Accessory, Tool, SpecialMesh | Sanitized clone in a WorldModel/ViewportFrame; drag to orbit and scroll to zoom |
| Animation, KeyframeSequence, CurveAnimation | R15 animation when body joints match; otherwise an animated bone stand-in |
| Keyframe | Its authored pose on the R15 rig or bone stand-in |
| Shirt, Pants, ShirtGraphic (T-shirt) | Clothing clone applied to an R15 mannequin |
| Decal, Texture | ImageLabel preserving tint and transparency |
| Images with flipbook metadata | Animated sprite-sheet frames |
| ParticleEmitter | Animated 2D approximation with color/size/transparency sequences, velocity, acceleration, drag, rotation, and standard flipbook layouts |
| GuiObject or LayerCollector, including ImageLabel/ImageButton | GUI clone with child hierarchy preserved; root Visible/Enabled is forced true; scripts are removed |
| Sound | Widget-local audio with autoplay/Play/Pause, live PlaybackLoudness history, progress, and elapsed/total track time |
| Other classes | Class and child/descendant counts |

The interface follows Studio's theme live through StudioComponents. Previewer fills the widget with previews and shows pagination only when there are multiple pages. Hover the viewer to reveal the top-right **⋯** button for a dismissible options drawer: **Studio**, **Dark**, or **Light** backgrounds, **Fit/Fill**, playback, page size, and place lighting. Fit shows the whole asset; Fill enlarges it to cover the preview and crops overflow. GUI canvases retain their proportions, image sheets use fit/crop, and 3D previews adjust camera framing. Changing Fit/Fill preserves playback. Balanced panels use a grid; panels at least twice as tall as wide use a vertical list, and panels at least twice as wide as tall use a horizontal list. Tile headers and informational footers are hidden; loading and error messages overlay the preview when needed. Only the visible page mounts renderers. Selected-source edits are debounced; descendant property watching is capped at 1,000 nodes per tile. Larger assets can be refreshed by reselecting them.

Page size adapts to the widget dimensions, within the minimum and maximum configured in the options drawer. Previewer defaults to 1–25 items and supports limits up to 64. Assets auto-play by default; turn off **Auto-play assets** to start new selections/pages paused, then use playback controls to start them manually. The settings persist across Studio sessions. Camera framing solves the horizontal and vertical frustum constraints using visible part bounding-box corners, excludes invisible helper parts, and leaves a small border. Animated rigs use a sampled motion envelope to keep the camera stable.

Cloning does not change the original asset. Non-Archivable selections report an error; Roblox may omit non-Archivable descendants. Scripts and embedded sounds are stripped from cloned geometry/GUI. Downloaded animations still require asset access. Each tile reports its own loading or renderer errors.

Animations load through [AnimationClipProvider](https://create.roblox.com/docs/reference/engine/classes/AnimationClipProvider) and sample KeyframeSequence poses or CurveAnimation position/rotation curves. A custom solver positions anchored R15 parts from joint offsets and sampled transforms; playback does not depend on a live Humanoid or Animator. When no R15 body joints match, a colored bone-and-joint stand-in shows the animation hierarchy and movement. Channel paths distinguish repeated bone names on separate branches. If the selected clip is inside its original rig Model, available Bone/Motor6D rest offsets are used; without those offsets, the stand-in is schematic rather than a reconstruction of the original mesh. Facial channels are not rendered. Local clips and individual Keyframes can be selected without uploading them; a lone Keyframe displays its static pose. R15 mannequins are created through Roblox's avatar service.

Audio is cloned into the plugin widget for edit-mode playback, detached from the source SoundGroup, and capped at 50% volume (zero-volume sources use 50% for preview). It auto-plays unless disabled in settings, loops, respects the global playback pause, and stops when the tile unmounts. Play can also start it manually when autoplay is disabled. The graph displays actual [PlaybackLoudness](https://create.roblox.com/docs/reference/engine/classes/Sound/PlaybackLoudness) samples, not a frequency spectrum. Loading failures remain visible; private audio still requires access in the current Studio session. Track length appears after loading. Organizer's sound thumbnails remain silent icons; opening the selected asset preview uses its autoplay preference.

### Lighting and FX limitations

Place matching approximates ambient light, sun direction, brightness, and color shift; a Sky clone supplies viewport reflections. Roblox's [ViewportFrame limitations](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame) still apply: no scene shadows or post-processing, and some materials differ from Workspace. This is not a pixel-identical scene render.

Particle FX use an explicitly labelled 2D approximation because native emitters do not render in ViewportFrames. The approximation is capped at 128 sprites per tile, emits even for disabled emitters, and uses the X/Y projection of motion. It does not reproduce emitter shapes, world collisions, Z motion, lighting/occlusion, beam/trail effects, or all envelope/flipbook behaviors. Select an emitter inside a model to view its FX. Beam, Trail, Fire, Smoke, and unsupported classes use fallback details until dedicated renderers are added.

For sprite sheets, set these numeric attributes on the selected image instance:

| Attribute | Meaning | Default |
| --- | --- | --- |
| `Preview_FlipbookColumns` | Enables flipbook mode; number of columns | 1 |
| `Preview_FlipbookRows` | Rows in the sheet | 1 |
| `Preview_FrameWidth` | Pixel width of one frame | 256 |
| `Preview_FrameHeight` | Pixel height of one frame | 256 |
| `Preview_FPS` | Playback rate | 24 |

ParticleEmitter flipbooks use their native layout/mode properties. `Preview_TextureSize` specifies square sheet dimensions when different from the 1024-pixel default.

### Add a renderer

Add a strict module under `src/Preview`, then register it in `Registry.luau`. A renderer has `id`, `label`, `supports(instance)`, and `mount(context)` functions, typed by `Shared.Types.Renderer`. Registering after initialization inserts before the fallback; an explicit priority can override a broader renderer.

`context.host` is a disposable Frame. Use `context.onCleanup` for every instance, connection, and track. Register cleanup before yielding; check `context.isAlive()` after async work. `context.options.playing`, `scaleMode`, and background update without remounting, so pause and framing changes preserve playback position. `context.palette` provides live theme colors for native renderer visuals. Send status/errors through `context.report`. Add a UI Labs story and a dispatch assertion in `tests/studio/Core.spec.luau`.

## Organizer

1. Open the **☰ drawer → Tag and attribute schema** and create tags or attributes. Every definition requires a description. Existing names from the current scope are offered in dropdowns; new definitions can still be typed.
2. Numbers require finite inclusive minimum/maximum bounds; enums require an explicit list of allowed strings; booleans accept exactly `true` and `false`. Freeform string attributes are deliberately excluded.
3. Start at the place root and click a service folder, then click Folders or Configurations to open the next layer. Back, Forward, Up, and clickable breadcrumbs navigate between locations. **Menu → Filters and scope** also offers a canonical path field with **Open location**, and **Open selected folder or containing folder** for Studio's current selection. Folder-view rows show names and asset types; search/filter results also show the instance's `GetFullName()`, derived from its current hierarchy, never stored as an attribute.
4. Toggle tag chips at the foot of the list, or choose tags and an attribute/value from the drawer dropdowns. Tag filters require every selected tag; attribute filtering preserves the value's type (`false`, `"false"`, `0`, and `"0"` are different values).
5. Click an asset file to select it while keeping the list visible. Open **Menu → Selected instances** for its preview and metadata editor. Add/remove managed tags or set an attribute on the current Explorer selection, up to 200 targets per batch.

The ordinary folder view shows only immediate children, with folders first. Empty services, Folders, and Configurations are hidden, including branches containing only other empty folders. Services (direct children of the DataModel) are represented internally as virtual Folder records; the actual services are never cloned, renamed, or replaced. They are navigation targets only and cannot be selected as assets, annotated, or submitted for MCP preview/classification. Models, Tools, and other non-container instances are files; their internal descendants do not appear as separate browser entries.

Open **Menu → View and playback settings** to switch between List and Grid. Grid places wrapped instance names below larger previews; full paths appear in search/filter results. The same panel configures autoplay and automatic page-size limits (8–100 by default, configurable up to 200). Resizing adapts the page size and retains the page containing the previous first item.

Typing in search or enabling a tag/attribute filter searches recursively through the current location's folders. Search covers names, classes, and full paths. Opening a new location clears those filters. Thumbnails mount only for visible file rows, are released on scrolling away, and do not intercept row selection or scrolling. Audio and nonvisual classes use MaterialIcons fallback glyphs; visual classes reuse the shared preview renderers.

The footer shows the 12 most populous tags under the current folder, sorted by instance count, plus any other active tag filters. Scroll the chip strip horizontally for more. Counts and dropdown suggestions include the folder's browsable contents recursively before search, filters, and pagination; services and file internals do not contribute metadata. Filters can use existing metadata without a schema definition; edits still require described tags and bounded attributes. The drawer also contains schema editing, MCP controls, and proposal review.

CoreGui and its entire subtree are excluded from results, counts, and suggestions, including explicit scopes inside CoreGui. Direct metadata/preview/edit requests against that subtree are rejected. A user-created Folder named `CoreGui` is unaffected.

The schema is JSON in `ServerStorage.AssetToolsSchema` (StringValue, version 1), saved with the place. Values are native instance attributes; tags are native CollectionService tags. No external database is needed. Existing tags and attributes outside the edited fields are preserved. Schemas do not automatically migrate existing values when definitions change.

Edits validate the full batch first, record a Studio undo operation, and roll back on write failure. Studio Undo/Redo and opening the drawer refresh the list. Use **Refresh instances and suggestions** in the drawer after changes made elsewhere, including Team Create changes. The query engine traverses the current hierarchy in sorted order and yields in batches; it does not maintain a stale index. The UI page size adapts within the configured limits; the API allows up to 200.

Paths use `game/Service/Folder/Name`, with percent-escaped segments, rather than executable Luau expressions. Dots, slashes, percent signs, and Unicode names round-trip safely. Duplicate sibling names are rejected as ambiguous, and affected query entries are counted and skipped. Rename duplicate siblings before using them as query scopes or annotation targets. Renames/moves are reflected on the next query. Corrupt or newer schema versions are reported and never silently overwritten.

## Studio MCP integration

Organizer includes an **opt-in adapter for the existing Studio MCP server**, not a second MCP server or an embedded vision model. Click **Enable Studio MCP bridge** under **☰ → Filters and scope** while the Organizer widget is open. This creates a non-Archivable `BindableFunction` at `ServerStorage.AssetToolsMCP` and removes it when disabled/unloaded.

A client with Studio's `execute_luau` tool can invoke the adapter:

```lua
local HttpService = game:GetService("HttpService")
local bridge = game:GetService("ServerStorage"):FindFirstChild("AssetToolsMCP")
assert(bridge and bridge:IsA("BindableFunction"), "Enable the Organizer MCP bridge")
return bridge:Invoke(HttpService:JSONEncode({ action = "schema" }))
```

The JSON response is `{ok=true,result=...}` or `{ok=false,error=...}`. Requests are limited to 256 KiB.

| Action | Input | Output / behavior |
| --- | --- | --- |
| `schema` | No additional fields | Versioned definitions, descriptions, and bounds |
| `query` | `scope`; optional `search`, `className`, `tags`, `attributes`, `offset`, `limit`, `browse`, `recursive` | `records`, total count, ambiguous-path count, scope `catalog` of tag counts and observed attribute values |
| `preview` | `path` | Opens that asset in Organizer's selection drawer; returns its metadata |
| `propose` | `annotations = [{path,tags,attributes}, ...]` | Validates and queues a batch for review without applying it |

Queries default to recursive instance search, excluding service objects. Set `browse=true, recursive=false` for a direct-child directory listing; `browse=true, recursive=true` searches through nested directory containers without descending into files. Both browser modes omit completely empty directory branches. Records include `kind` (`folder` or `asset`), `selectable`, and `sourceClassName`; service navigation records use `className="Folder"` with `selectable=false`. CoreGui remains excluded in every mode.

For example, a proposal body is:

```json
{
  "action": "propose",
  "annotations": [
    {"path": "game/Workspace/Assets/Rock", "tags": ["Nature"], "attributes": {"Complexity": 2}}
  ]
}
```

A vision-capable MCP client can read the schema, query candidate paths, request a preview, **capture the visible widget using a screenshot capability**, and propose classifications. Rendering is asynchronous, so capture after the preview finishes loading. The adapter itself returns metadata, not image bytes. Some Studio screenshot tools capture only the main 3D viewport; those cannot see dock widgets and require a separate desktop/widget capture tool. This screenshot-dependent vision workflow has not been verified end-to-end here.

Review lists every proposed tag and value before **Apply proposals**. It revalidates against the latest schema, verifies the same instances still occupy the proposed paths, and applies one undoable batch. Dismiss clears the batch. Only one batch can be pending. There is no arbitrary-code or direct-apply action in the adapter.

## UI Labs

Stories include **Full stack**, **Previewer**, **Organizer**, **Organizer drawer**, **Asset thumbnails**, **Material icons**, **Popular tag chips**, **Preview card**, **Preview menu**, **Images, audio, and R15**, **GUI mounting**, **Bone stand-in**, **Classic clothing**, **Schema editor**, **Metadata editor**, and **Core controls**. Every story has a light/dark theme control. Previewer controls cover Folder and Configuration selection, a single preview, and an empty selection. Organizer stories include List/Grid views, nested Folders/Configurations, a Model file, navigation, thumbnail visibility, filters, metadata/schema drawers, and dropdowns. Full stack shares selection between both screens. Media controls accept image, animation, and sound IDs and include a local animation clip. GUI mounting covers hidden roots, disabled screens, and Fit/Fill; Previewer includes tall/wide panel controls. Bone stand-in covers non-R15 motion and single Keyframes. Classic clothing accepts Shirt/Pants templates and a T-shirt image. The fixture hierarchy is isolated from the actual place, and its edits do not use Studio's undo history.

Production Rojo projects exclude DevPackages, this project's stories/tests, and dependency-supplied story files. Artifact tests enforce that separation. Only the development project includes UI Labs.

## CI/CD

`ci.yml` installs Wally packages, checks the committed lockfile, runs strict Luau analysis and formatting, runs core and publishing-tool tests, builds both plugins and the UI Labs development place, and checks production contents.

`publish.yml` runs that validation first and publishes its exact artifacts on a `v*` tag or a manual dispatch (Previewer, Organizer, or both). Configure the GitHub environment **roblox-production** with:

| Setting | Type | Meaning |
| --- | --- | --- |
| `ROBLOX_OPEN_CLOUD_API_KEY` | Secret | API key for the publishing creator and execution universe |
| `PREVIEWER_PLUGIN_ID` | Variable | Existing Previewer plugin asset ID |
| `ORGANIZER_PLUGIN_ID` | Variable | Existing Organizer plugin asset ID |
| `ROBLOX_CREATOR_ID` | Variable | Owning user or group ID |
| `ROBLOX_CREATOR_TYPE` | Variable | `User` or `Group` |
| `PUBLISH_UNIVERSE_ID` | Variable | Dedicated publishing experience universe ID |
| `PUBLISH_PLACE_ID` | Variable | Published place within that experience |

Create each plugin once in Studio to obtain its ID. Use a dedicated empty publishing place owned by the creator. Enable the appropriate Open Cloud Luau execution read/write permissions and asset write permissions for that creator; see [API scopes](https://create.roblox.com/docs/cloud/reference/scopes). Configure environment protection if releases should require approval.

Publishing uploads the RBXM as a binary input, runs [Open Cloud Luau execution](https://create.roblox.com/docs/cloud/reference/features/luau-execution), deserializes the plugin, and calls `AssetService:CreateAssetVersionAsync` with `Enum.AssetType.Plugin`. It does not run the plugin, save the publishing place, or use an account cookie. This follows the route used by [Rojo's plugin release workflow](https://github.com/rojo-rbx/rojo/blob/master/.lune/upload-plugin.luau).

Both selected artifacts/configurations are preflighted before publishing either. A publish is not atomic across two asset IDs; if the second fails, inspect the task/version logs before retrying. Task creation is never retried automatically. A successful response must contain the expected plugin ID and new version. Timeouts and ambiguous results fail the workflow rather than claiming success.

With the variables set locally, `python scripts/publish.py previewer --dry-run` validates configuration and the built artifact without network access. **No plugin has been published by this implementation; real IDs, credentials, and a live publishing run are still required.**

## Verification status

Local checks cover strict typing of application code, stories, Studio tests, plugin entrypoints, and the cloud publishing script; formatting; core behavior in Lune using Roblox instances; publishing-client unit tests; and all three builds. The core test module can also be run in Studio:

```lua
print(require(game.ReplicatedStorage.AssetTools.Tests["Core.spec"])())
```

No Studio session was connected during implementation. Visual layout, docking restoration, native animation playback, permission prompts, and screenshot-driven classification need an in-Studio smoke test. Lune service adapters do not simulate Studio rendering or ChangeHistoryService.
