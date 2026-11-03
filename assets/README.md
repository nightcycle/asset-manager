# Plugin icons

Previewer combines Google's **view_in_ar** and **visibility** Material icons. Organizer combines **folder** and **label**. The SVG compositions are transparent, use a matching badge style, and work on Studio's light and dark surfaces.

The unmodified source SVGs are in `material/`, pinned to the commit in `material/REVISION` from [google/material-design-icons](https://github.com/google/material-design-icons). Their Apache 2.0 license is in `material/LICENSE`. `scripts/build-icons.py` composes the final SVGs in `plugins/`; edit the composition script rather than the generated SVGs.

[Asphalt 2.0.2](https://github.com/jackTabsCode/asphalt/tree/v2.0.2) owns rasterization, alpha bleeding, local installation, uploads, hashing and the generated Luau asset references. Its creator is group **4181328**.

- `./scripts/sync-icons.ps1 -Target studio` installs both images into the current Studio version's content folder and generates local `rbxasset://` references. Run it again after a Studio upgrade or icon edit, then rebuild/reinstall the plugins.
- `./scripts/sync-icons.ps1 -Target debug` renders into `.asphalt-debug/` for inspection without changing the active Luau references.
- `./scripts/sync-icons.ps1 -Target cloud` uploads with `ASPHALT_API_KEY` (asset:read and asset:write for this group) and generates portable `rbxassetid://` references. Commit `asphalt.lock.toml` and `src/Generated/PluginIcons.luau` together with the source SVGs. Keep the key in the environment, never in the repository.

The **Sync plugin icons** workflow performs cloud sync using the `ASPHALT_API_KEY` Actions secret and returns the lockfile and generated references as a downloadable artifact for review/commit. It does not publish plugins. Plugin publishing requires cloud references; local content paths only work on machines where Asphalt installed the images.

The generated module now uses cloud references: Previewer `90992575777610` and Organizer `76034680482836`. The asset hashes and IDs are recorded in `asphalt.lock.toml`. Studio exposes the widget's opening icon through its toolbar button; both buttons use one shared **Asset Tools** toolbar, including after either plugin reloads.
