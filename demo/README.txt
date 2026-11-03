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
4. Hover the viewer and open the top-right ellipsis menu for automatic page
   limits, autoplay, background, Fit/Fill, playback, and lighting. Pagination appears only when
   more than one page is needed. Switch the Studio theme; adjust Lighting.
5. In Organizer, open Workspace > AssetGallery > a category folder. Services,
   Folders, and Configurations navigate like directories; asset files have
   small previews. Use Back, Forward, Up, and the breadcrumbs to navigate.
6. Toggle the popular DemoAsset or Geometry chips at the foot of the list.
   Search and filters include subfolders. In the drawer, choose Category and
   vegetation from the dropdowns. Opening another folder clears the filters.
7. Select some assets, open Selected instances in the drawer, choose
   Reviewed = true, apply, and test Studio Undo/Redo. CoreGui is excluded.
8. Select items in ReplicatedStorage.PreviewExamples for images, FX,
   animation, GUI, audio, and unsupported-class handling.
9. GUI_Label is hidden and GUI_DisabledScreen is disabled in the source;
   both should appear in the viewer. Compare Fit/Fill on these rectangular UIs.
10. Select Animation_LocalR15Wave to test the custom solver with a local clip.
    Select Audio_ElectronicPing to hear autoplay and see loudness and track time.
    Pause playback from the menu, then resume without resetting the position.
11. Resize the previewer tall/narrow or wide/short with several assets selected
    to switch between vertical and horizontal lists; balanced sizes use a grid.
12. Select Animation_BoneStandIn for a non-R15 animation, or
    Keyframe_StandalonePose for its authored static pose.
13. Select Clothing_TShirt to preview a graphic on R15. Set ShirtTemplate or
    PantsTemplate on the other clothing fixtures to test your clothing textures.
14. Organizer > Menu > View and playback settings offers Grid with wrapped
    labels, autoplay, and minimum/maximum page limits. Resize to test capacity.

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
