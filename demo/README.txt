ASSET TOOLS DEMO

Run scripts/launch-demo.ps1 from PowerShell. It builds the place, installs
AssetPreviewer.rbxm and AssetOrganizer.rbxm into your Studio local Plugins
folder, then opens build/AssetToolsDemo.rbxl in Roblox Studio.

Plugin installation is separate from the place file. Opening this place
alone does not grant its scripts plugin permissions. Use the launcher once,
or install both build/Asset*.rbxm files into Studio's local Plugins folder.
Existing versions of these two files are backed up in build/plugin-backups.
The plugins remain installed for other Studio places until you remove them.

TEST IN EDIT MODE (no Play button required):
1. Open Asset Previewer and Asset Organizer from Plugins > Asset Tools.
2. Select an asset in Workspace.AssetGallery; drag/scroll its 3D preview.
3. Select AssetGallery or a category folder to preview its children; nested
   Folders and Configurations expand recursively, while Models stay intact.
4. Hover the viewer and open the top-right ellipsis menu for 1 / 4 / 9 tiles,
   background, playback, and lighting options. Pagination appears only when
   more than one page is needed. Switch the Studio theme; adjust Lighting.
5. In Organizer, select AssetGallery and click Scope to selection.
6. Filter by DemoAsset or Geometry; try Category = vegetation.
7. Select some assets, set Reviewed = true, and test Studio Undo/Redo.
8. Select items in ReplicatedStorage.PreviewExamples for images, FX,
   animation, GUI, audio, and unsupported-class handling.

ReplicatedStorage.lib preserves all supplied library assets, names, tags,
attributes, meshes, and textures. Workspace.AssetGallery contains separate
display copies, uniformly resized and positioned on labelled stands.

The flipbook fixture demonstrates crop stepping using the built-in sparkle
image. Replace Image with a real 4x4 sprite sheet and set frame dimensions
for a meaningful animation. The R15 example uses Roblox's default idle ID;
asset loading still depends on your Studio session's network/permissions.

ServerStorage.PluginBuilds contains the two packaged plugins for inspection
or manual Save as Local Plugin. They do not run from ServerStorage.
ServerStorage.AssetToolsSchema contains a described, bounded example schema.
ReplicatedStorage.AssetTools contains the original UI Labs development tree.

The Studio MCP adapter is opt-in. Enable it inside Organizer, then use its
schema/query/preview/propose requests as documented in the repository README.
