[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$NoOpen,
    [string]$PluginDirectory,
    [string]$StudioPath
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
    if (-not $SkipBuild) { & (Join-Path $PSScriptRoot 'check.ps1') }
    $demoPath = Join-Path $repoRoot 'build/AssetToolsDemo.rbxl'
    if (-not (Test-Path -LiteralPath $demoPath -PathType Leaf)) { throw 'Build the demo first with scripts/check.ps1.' }

    if (-not $PluginDirectory) {
        $localData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
        $PluginDirectory = Join-Path $localData 'Roblox/Plugins'
    }
    $PluginDirectory = [IO.Path]::GetFullPath($PluginDirectory)
    New-Item -ItemType Directory -Path $PluginDirectory -Force | Out-Null
    $backupDirectory = Join-Path $repoRoot ('build/plugin-backups/' + (Get-Date -Format 'yyyyMMdd-HHmmss-ffff'))
    foreach ($name in @('AssetPreviewer', 'AssetOrganizer')) {
        $sourcePath = Join-Path $repoRoot "build/$name.rbxm"
        $destinationPath = Join-Path $PluginDirectory "$name.rbxm"
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Missing plugin build: $sourcePath" }
        if (Test-Path -LiteralPath $destinationPath) {
            if ((Get-FileHash -LiteralPath $sourcePath).Hash -eq (Get-FileHash -LiteralPath $destinationPath).Hash) { continue }
            New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
            Copy-Item -LiteralPath $destinationPath -Destination (Join-Path $backupDirectory "$name.rbxm")
        }
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
        if ((Get-FileHash -LiteralPath $sourcePath).Hash -ne (Get-FileHash -LiteralPath $destinationPath).Hash) { throw "Plugin copy verification failed: $name" }
        Write-Host "Installed $destinationPath"
    }
    if (-not $NoOpen) {
        if (-not $StudioPath) {
            $association = (Get-ItemProperty -LiteralPath 'Registry::HKEY_CLASSES_ROOT\Roblox.Place\shell\Open\command' -ErrorAction SilentlyContinue).'(default)'
            if ($association -match '^"([^"]+RobloxStudioBeta\.exe)"') { $StudioPath = $Matches[1] }
        }
        if (-not $StudioPath -or -not (Test-Path -LiteralPath $StudioPath -PathType Leaf)) {
            throw "Studio executable not found. Pass -StudioPath or open $demoPath manually. Plugins are installed."
        }
        # This is the interactive Studio window requested for testing, not a background helper.
        Start-Process -FilePath $StudioPath -ArgumentList ('"' + $demoPath + '"')
        Write-Host "Opened $demoPath"
    }
    Write-Host 'Use Plugins > Asset Tools to open both widgets. If Studio was already open, reopen this demo to reload local plugins.'
} finally {
    Pop-Location
}
