# One command to play the current code: build a demo place (canonical world + current src),
# open it in Roblox Studio on the primary monitor, and press Play.
#   .\tools\play.ps1            # build + launch + play
#   .\tools\play.ps1 -NoPlay    # just open it in Studio
# Never touches build\NeonArcana.rbxl (the canonical place); output is build\NeonArcana.demo.rbxl.
param(
    [switch]$NoPlay
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
$env:Path = "$env:USERPROFILE\.rokit\bin;" + $env:Path

Write-Host "==> Building demo place from canonical world + src/" -ForegroundColor Cyan
lune run tools/build_demo
if ($LASTEXITCODE -ne 0) { throw "demo build failed" }
$place = Join-Path $root "build\NeonArcana.demo.rbxl"

# Close any Studio instance that already has the demo open, so the fresh build loads.
Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -like "*NeonArcana.demo*" } |
    ForEach-Object {
        $_.CloseMainWindow() | Out-Null
        if (-not $_.WaitForExit(8000)) { Stop-Process -Id $_.Id -Force }  # stuck in Play or behind a dialog
    }
Start-Sleep 2

Write-Host "==> Opening in Roblox Studio" -ForegroundColor Cyan
$before = @(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
Start-Process $place

$studio = $null
for ($i = 0; $i -lt 90 -and -not $studio; $i++) {
    Start-Sleep 1
    $studio = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue |
        Where-Object { $before -notcontains $_.Id -and $_.MainWindowTitle -like "*NeonArcana.demo*" } |
        Select-Object -First 1
}
if (-not $studio) { throw "Studio window did not appear" }

Add-Type @"
using System; using System.Runtime.InteropServices;
public class NeonWin {
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
"@
Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
Start-Sleep 4   # let Studio finish loading the place before we move/focus it
$studio.Refresh()
$h = $studio.MainWindowHandle
[NeonWin]::ShowWindow($h, 9) | Out-Null
[NeonWin]::SetWindowPos($h, [IntPtr]::Zero, $screen.X, $screen.Y, $screen.Width, $screen.Height, 0x0040) | Out-Null
[NeonWin]::ShowWindow($h, 3) | Out-Null
[NeonWin]::SetForegroundWindow($h) | Out-Null

if (-not $NoPlay) {
    Start-Sleep 2
    [System.Windows.Forms.SendKeys]::SendWait("{F5}")
    Write-Host "==> Sent F5 (Play). Server builds the city on boot; pick a school when the screen appears." -ForegroundColor Green
}
Write-Host "Studio pid $($studio.Id) on primary monitor: $place"
