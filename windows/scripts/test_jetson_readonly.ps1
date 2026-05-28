param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\ground_station.json")
)

$config = Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json
$target = "{0}@{1}" -f $config.jetson.user, $config.jetson.host
$projectPath = $config.jetson.projectPath

$remote = @"
cd '$projectPath' &&
printf 'HOSTNAME=' && hostname &&
printf 'PWD=' && pwd &&
printf '\nDASHBOARD_SERVICE\n' &&
systemctl --user --no-pager --plain status vision-dashboard | sed -n '1,12p' &&
printf '\nLANDING_SERVICE\n' &&
systemctl --user --no-pager --plain status vision-landing | sed -n '1,12p' &&
printf '\nCONFIG_MAVLINK\n' &&
grep -n 'enabled:' configs/aruco_live.yaml &&
printf '\nRECENT_LOG\n' &&
tail -n 3 logs/dashboard_status.jsonl
"@

ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=8 $target $remote
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "SSH read-only test did not complete."
    Write-Host "If the error is 'Permission denied', run .\scripts\open_ssh_jetson.ps1 and log in with the Jetson password, or configure an SSH key."
    exit $LASTEXITCODE
}
