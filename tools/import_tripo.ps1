# Pulls Tripo GLB exports from Downloads into the pipeline and imports them into the
# running Roblox Studio (edit mode, demo place focused):
#   Downloads\<name>.glb -> assets\raw\<name>.glb -> Blender -> assets\export\<name>.fbx
#   -> Studio 3D Importer (Ctrl+M), Anchored, Import -> Workspace.<name>
#   .\tools\import_tripo.ps1                # everything new in Downloads
#   .\tools\import_tripo.ps1 -Names a,b     # only these
#   .\tools\import_tripo.ps1 -NoStudio      # convert only
param(
    [string[]]$Names,
    [switch]$NoStudio,
    [int]$Tris = 8000
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
if ($env:BLENDER_PATH) { $blender = $env:BLENDER_PATH }
New-Item -ItemType Directory -Force "assets\raw", "assets\export" | Out-Null

Add-Type @"
using System; using System.Runtime.InteropServices;
public class TripoWin {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
"@
Add-Type -AssemblyName System.Windows.Forms
function Click($x, $y) { [TripoWin]::SetCursorPos($x, $y); Start-Sleep -Milliseconds 300; [TripoWin]::mouse_event(2,0,0,0,[UIntPtr]::Zero); [TripoWin]::mouse_event(4,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 600 }

$glbs = @(Get-ChildItem "$env:USERPROFILE\Downloads\*.glb" | Where-Object { -not $Names -or $Names -contains $_.BaseName })
# a name already moved into assets\raw (e.g. an interrupted run) is picked up from there
foreach ($n in $Names) {
    if (-not ($glbs | Where-Object { $_.BaseName -eq $n }) -and (Test-Path "assets\raw\$n.glb")) { $glbs += Get-Item "assets\raw\$n.glb" }
}
if (-not $glbs) { Write-Host "nothing to import"; exit 0 }

$imported = @()
foreach ($glb in $glbs) {
    $name = $glb.BaseName
    $raw = Join-Path $root "assets\raw\$name.glb"
    if ($glb.FullName -ne (Get-Item $raw -ErrorAction SilentlyContinue).FullName) { Move-Item $glb.FullName $raw -Force }
    $fbx = Join-Path $root "assets\export\$name.fbx"
    Write-Host "==> $name : Blender convert" -ForegroundColor Cyan
    $ErrorActionPreference = "Continue"
    & $blender --background --python (Join-Path $PSScriptRoot "tripo_to_roblox.py") -- $raw $fbx $Tris 2>&1 |
        Where-Object { "$_" -match "^\[pipeline\]|Error|Traceback" } | ForEach-Object { Write-Host "    $_" }
    $exit = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($exit -ne 0 -or -not (Test-Path $fbx)) { Write-Host "    FAILED" -ForegroundColor Red; continue }

    if ($NoStudio) { continue }
    $studio = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*NeonArcana*" } | Select-Object -First 1
    if (-not $studio) { Write-Host "    no Studio window; skipping import" -ForegroundColor Yellow; continue }
    Write-Host "==> $name : Studio import" -ForegroundColor Cyan
    [TripoWin]::SetForegroundWindow($studio.MainWindowHandle) | Out-Null; Start-Sleep 1
    Click 189 61                                    # Stop, in case the demo is in Play mode (no-op in edit mode)
    Start-Sleep 5
    Click 1000 500                                  # focus viewport
    [System.Windows.Forms.SendKeys]::SendWait("^m"); Start-Sleep 4
    Click 460 495                                   # file name box
    [System.Windows.Forms.SendKeys]::SendWait("$fbx{ENTER}"); Start-Sleep 12
    Click 1148 626                                  # Anchored
    Click 1275 876                                  # Import
    Start-Sleep 25
    $imported += $name
}
Write-Host ("Imported into Studio: " + ($imported -join ", "))
