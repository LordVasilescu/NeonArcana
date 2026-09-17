# Converts a Tripo AI export into a Roblox-ready FBX.
# Usage:  .\tools\Convert-TripoAsset.ps1 -Input "assets\raw\hoverboard.glb" [-Tris 8000]
# Output lands in assets\export\<name>.fbx — import that via Studio's 3D Importer.
param(
    [Parameter(Mandatory = $true)][string]$Input,
    [int]$Tris = 8000
)

$blender = "C:\Program Files (x86)\Steam\steamapps\common\Blender\blender.exe"
if (-not (Test-Path $blender)) {
    Write-Error "Blender not found at $blender — update the path in this script."
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
