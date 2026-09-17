# Commons (Neon Plaza) asset queue. Logs to assets\commons_queue.log.
Set-Location (Split-Path $PSScriptRoot -Parent)
$log = "assets\commons_queue.log"
"=== commons queue started $(Get-Date -Format o) ===" | Out-File $log -Encoding utf8

$queue = @(
    @("low-poly stylized cyberpunk data fountain, three tiered dark metal basins with glowing teal holographic beam rising from center, game environment prop, clean silhouette", "commons_fountain"),
    @("low-poly stylized cyberpunk neon tree, dark trunk with fiber optic branches glowing teal and magenta, game environment prop", "cyber_tree"),
    @("low-poly stylized cyberpunk holographic billboard screen on dark metal pole, game street prop", "holo_billboard"),
    @("low-poly stylized cyberpunk metal bench with neon underglow strip, game environment prop", "plaza_bench"),
    @("low-poly stylized cyberpunk noodle food stall with glowing hanging sign and steam, game environment prop", "food_stall"),
    @("low-poly stylized elderly cyberpunk hacker sage with glowing cybernetic eye, long tech coat and staff, wise mentor, full body game character, clean silhouette", "chief_codewright"),
    @("low-poly stylized cyberpunk arcade storefront facade with big neon sign frame and glowing windows, game building piece", "shop_facade"),
    @("low-poly stylized holographic crown statue on dark pedestal, gold neon glow, cyberpunk game prop", "crown_statue")
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
"=== commons queue finished $(Get-Date -Format o) ===" | Out-File $log -Append -Encoding utf8
