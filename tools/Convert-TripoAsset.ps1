# Converts a Tripo AI export into a Roblox-ready FBX.
# Usage:  .\tools\Convert-TripoAsset.ps1 -Input "assets\raw\hoverboard.glb" [-Tris 8000]
# Output lands in assets\export\<name>.fbx — import that via Studio's 3D Importer.
param(
    [Parameter(Mandatory = $true)][string]$Input,
    [int]$Tris = 8000
)

# Blender lookup: BLENDER_PATH env var, then the standard installer location, then Steam.
$candidates = @(
    $env:BLENDER_PATH,
    (Get-ChildItem "C:\Program Files\Blender Foundation" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName "blender.exe" } | Select-Object -First 1),
    "C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe"
) | Where-Object { $_ -and (Test-Path $_) }
$blender = $candidates | Select-Object -First 1
if (-not $blender) {
    Write-Error "Blender not found. Install it (winget install BlenderFoundation.Blender) or set BLENDER_PATH."
    exit 1
}

$projectRoot = Split-Path $PSScriptRoot -Parent
$name = [IO.Path]::GetFileNameWithoutExtension($Input)
$out = Join-Path $projectRoot "assets\export\$name.fbx"

& $blender --background --python (Join-Path $PSScriptRoot "tripo_to_roblox.py") -- $Input $out $Tris
if ($LASTEXITCODE -eq 0) {
    Write-Host "DONE -> $out" -ForegroundColor Green
} else {
    Write-Error "Conversion failed (exit $LASTEXITCODE)"
}
