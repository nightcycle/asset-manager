$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed ($LASTEXITCODE)" }
}
New-Item -ItemType Directory -Path build,.tools -Force | Out-Null
if (-not (Test-Path .tools/roblox.d.luau)) {
    Invoke-WebRequest 'https://luau-lsp.pages.dev/type-definitions/globalTypes.PluginSecurity.d.luau' -OutFile .tools/roblox.d.luau
}
Invoke-Checked rojo @('sourcemap', 'default.project.json', '--output', 'sourcemap.json')
if ((Get-Content Packages/React.lua -Raw) -notmatch 'local REQUIRED_MODULE') {
    Invoke-Checked wally-package-types @('--sourcemap', 'sourcemap.json', 'Packages')
}
if ((Get-Content DevPackages/UILabs.lua -Raw) -notmatch 'local REQUIRED_MODULE') {
    Invoke-Checked wally-package-types @('--sourcemap', 'sourcemap.json', 'DevPackages')
}
Invoke-Checked luau-lsp @('analyze', '--definitions=@roblox=.tools/roblox.d.luau', '--sourcemap=sourcemap.json', '--platform=roblox', '--ignore=Packages/**', '--ignore=DevPackages/**', 'src', 'stories', 'tests/studio')
Invoke-Checked luau-lsp @('analyze', '--definitions=@roblox=.tools/roblox.d.luau', '--platform=roblox', 'scripts/publish-engine.luau', 'scripts/build-demo.luau', 'tests/demo.luau')
foreach ($pluginName in @('previewer', 'organizer')) {
    Invoke-Checked rojo @('sourcemap', "$pluginName.project.json", '--output', "build/$pluginName-sourcemap.json")
    $entryName = if ($pluginName -eq 'previewer') { 'Previewer' } else { 'Organizer' }
    Invoke-Checked luau-lsp @('analyze', '--definitions=@roblox=.tools/roblox.d.luau', "--sourcemap=build/$pluginName-sourcemap.json", '--platform=roblox', '--ignore=Packages/**', "entry/$entryName.server.luau")
    Invoke-Checked rojo @('build', "$pluginName.project.json", '--output', "build/Asset$entryName.rbxm")
}
Invoke-Checked stylua @('--check', 'src', 'entry', 'stories', 'tests', 'scripts/publish-engine.luau', 'scripts/build-demo.luau')
Invoke-Checked rojo @('build', 'default.project.json', '--output', 'build/development.rbxl')
Invoke-Checked lune @('run', 'tests/run.luau')
Invoke-Checked lune @('run', 'tests/package.luau')
Invoke-Checked lune @('run', 'scripts/build-demo.luau')
Invoke-Checked lune @('run', 'tests/demo.luau')
Invoke-Checked python @('-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py')
