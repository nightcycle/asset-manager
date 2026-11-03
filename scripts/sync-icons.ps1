[CmdletBinding()]
param([ValidateSet('studio', 'cloud', 'debug')][string]$Target = 'studio')
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
    if ($Target -eq 'cloud' -and -not $env:ASPHALT_API_KEY) {
        throw 'Set ASPHALT_API_KEY with asset:read and asset:write for group 4181328 before cloud sync.'
    }
    python scripts/build-icons.py
    if ($LASTEXITCODE -ne 0) { throw 'Icon composition failed.' }
    asphalt sync $Target
    if ($LASTEXITCODE -ne 0) { throw "Asphalt $Target sync failed." }
    if ($Target -ne 'debug') {
        $modulePath = Join-Path $repoRoot 'src/Generated/PluginIcons.luau'
        $generated = Get-Content -LiteralPath $modulePath -Raw
        # Keep generated references strictly typed without hand-editing Asphalt output.
        if (-not $generated.StartsWith('--!strict')) {
            [IO.File]::WriteAllText($modulePath, "--!strict`n" + $generated)
        }
    }
} finally {
    Pop-Location
}
