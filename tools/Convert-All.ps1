# Converts every downloaded model that has no up-to-date Roblox export yet.
#   .\tools\Convert-All.ps1            # convert anything new
#   .\tools\Convert-All.ps1 -Force     # reconvert everything
#   .\tools\Convert-All.ps1 -Tris 6000 # lower triangle budget
#
# Drop files here and run this:
#   assets\raw\<name>.glb|.fbx|.obj   static models  -> assets\export\<name>.fbx
#   assets\animated\<name>.fbx         rigged/animated -> assets\export_animated\<name>.fbx
# Works with downloads from any source (Tripo, Meshy, Sketchfab, Poly Pizza, Kenney...).
# Then import the FBX in Studio: Home -> Import 3D, or upload with tools\roblox_upload.py.
param(
    [switch]$Force,
    [int]$Tris = 8000
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent

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

function Convert-Batch([string]$inDir, [string[]]$patterns, [string]$outDir, [string]$script) {
    if (-not (Test-Path $inDir)) { return }
    New-Item -ItemType Directory -Force $outDir | Out-Null
    $files = Get-ChildItem $inDir -File | Where-Object { $patterns -contains $_.Extension.ToLower() }
    foreach ($file in $files) {
        $out = Join-Path $outDir ($file.BaseName + ".fbx")
        if (-not $Force -and (Test-Path $out) -and (Get-Item $out).LastWriteTime -ge $file.LastWriteTime) {
            Write-Host "  up to date: $($file.Name)" -ForegroundColor DarkGray
            continue
        }
        Write-Host "==> $($file.Name) -> $out" -ForegroundColor Cyan
        & $blender --background --python (Join-Path $PSScriptRoot $script) -- $file.FullName $out $Tris 2>&1 |
            Where-Object { $_ -match "^\[(pipeline|anim-pipeline)\]|Error|Traceback" }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
            $script:failures += $file.Name
        } else {
            Write-Host "    ok" -ForegroundColor Green
            $script:converted += $file.Name
        }
    }
}

$converted = @()
$failures = @()
Write-Host "Static models (assets\raw):"
Convert-Batch (Join-Path $root "assets\raw") @(".glb", ".gltf", ".fbx", ".obj") (Join-Path $root "assets\export") "tripo_to_roblox.py"
Write-Host "Animated models (assets\animated):"
Convert-Batch (Join-Path $root "assets\animated") @(".fbx") (Join-Path $root "assets\export_animated") "animated_to_roblox.py"

Write-Host ""
Write-Host ("Converted: {0}   Failed: {1}" -f $converted.Count, $failures.Count)
if ($failures.Count -gt 0) {
    Write-Host ("Failed: " + ($failures -join ", ")) -ForegroundColor Red
    exit 1
}
