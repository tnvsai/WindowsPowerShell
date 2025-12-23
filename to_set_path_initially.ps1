$profilePath = $PROFILE

$line = '. "$HOME\Documents\WindowsPowerShell\fav_dir.ps1""'

if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$content = Get-Content $profilePath -ErrorAction SilentlyContinue

if ($content -notcontains $line) {
    Add-Content $profilePath "`n$line"
    Write-Host "[OK] favdirs added to PowerShell profile"
} else {
    Write-Host "[INFO] favdirs already present in profile"
}
