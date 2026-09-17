# Runs the full Tripo asset queue sequentially. Detached-friendly; logs to assets\queue.log.
Set-Location (Split-Path $PSScriptRoot -Parent)
$log = "assets\queue.log"
"=== queue started $(Get-Date -Format o) ===" | Out-File $log -Encoding utf8

$queue = @(
    @("low-poly stylized giant rat fused with cables and circuit boards, game monster, purple neon accents, clean silhouette", "wire_rat"),
    @("low-poly stylized chrome-armored cyberpunk gang enforcer, full body game character, blue neon accents, clean silhouette", "chrome_ganger"),
    @("low-poly stylized ghostly hooded figure made of glitching data fragments, game monster, grey-green neon accents", "data_wraith"),
    @("low-poly stylized boxy armored security robot, game character, blue neon accents, clean silhouette", "sentinel_unit"),
    @("low-poly stylized corrupted digital king on floating throne, imposing game boss, gold neon accents, clean silhouette", "glitch_king"),
    @("low-poly stylized armored cyber knight with energy shield, game character, tan and bronze neon accents", "proxy_knight"),
    @("low-poly stylized cyberpunk stalker creature, lean and predatory, grey neon accents, game monster", "grid_stalker"),
    @("low-poly stylized massive floating AI overseer core with mechanical tendrils, game boss, purple lightning accents", "overseer_prime"),
    @("low-poly stylized hanging neon shop sign with kanji and circuitry, cyberpunk street prop", "neon_sign_1"),
    @("low-poly stylized cyberpunk vending machine with glowing front panel, street prop", "vending_machine"),
    @("low-poly stylized cyberpunk hoverboard, teal neon underglow, game vehicle, clean silhouette", "hoverboard_basic"),
    @("low-poly stylized cute companion drone, round body, single glowing eye, game pet", "drone_pet")
)

foreach ($item in $queue) {
    $name = $item[1]
    if (Test-Path "assets\export\$name.fbx") {
        "SKIP (exists): $name" | Out-File $log -Append -Encoding utf8
        continue
    }
    "STARTING: $name  $(Get-Date -Format HH:mm:ss)" | Out-File $log -Append -Encoding utf8
    python tools\tripo_generate.py $item[0] $name *>> $log
    if ($LASTEXITCODE -eq 0) {
        "OK: $name" | Out-File $log -Append -Encoding utf8
    } else {
        "FAILED: $name (exit $LASTEXITCODE)" | Out-File $log -Append -Encoding utf8
    }
}
"=== queue finished $(Get-Date -Format o) ===" | Out-File $log -Append -Encoding utf8
