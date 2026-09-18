# Full local quality gate for Neon Arcana. Run from anywhere:
#   .\tools\check.ps1          # format check, lint, type check, build, Studio smoke test
#   .\tools\check.ps1 -Fast    # skip the Studio smoke test (used by the pre-commit hook)
#   .\tools\check.ps1 -Fix     # auto-format with StyLua before checking
param(
    [switch]$Fast,
    [switch]$Fix
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

# Make sure Rokit-managed tools are reachable even in shells opened before install.
$env:Path = "$env:USERPROFILE\.rokit\bin;" + $env:Path

$failed = @()
function Step([string]$name, [scriptblock]$body) {
    Write-Host "==> $name" -ForegroundColor Cyan
    & $body
    if ($LASTEXITCODE -ne 0) {
        $script:failed += $name
        Write-Host "    FAILED" -ForegroundColor Red
    } else {
        Write-Host "    ok" -ForegroundColor Green
    }
}

if ($Fix) {
    Step "StyLua format" { stylua src tests }
}
Step "StyLua check" { stylua --check src tests }
Step "Selene lint" { selene src tests }
Step "Rojo sourcemap" { rojo sourcemap default.project.json -o sourcemap.json }

if (-not (Test-Path "globalTypes.d.luau")) {
    Write-Host "==> Downloading Roblox type definitions" -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau" -OutFile "globalTypes.d.luau"
}
Step "luau-lsp type check" {
    luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json --ignore="Packages/**" src tests
}

# Build to a scratch file. build\NeonArcana.rbxl is the canonical Studio-saved place
# (it holds the imported models) and must never be overwritten by rojo build.
New-Item -ItemType Directory -Force "build" | Out-Null
Step "Rojo build" { rojo build -o build\NeonArcana.ci.rbxl }

if (-not $Fast) {
    Step "Studio smoke test" {
        run-in-roblox --place build\NeonArcana.rbxl --script tests\smoke.server.luau | Tee-Object -Variable smoke
        if (-not ($smoke -match "SMOKE_RESULT: ALL PASS")) { $global:LASTEXITCODE = 1 }
    }
}

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host ("FAILED: " + ($failed -join ", ")) -ForegroundColor Red
    exit 1
}
