# to_set_path_initially.ps1
# Adds fav_dir.ps1 to PowerShell profile dynamically

$profilePath = $PROFILE

# Path to fav_dir.ps1 relative to this installer
$favScriptPath = Join-Path $PSScriptRoot "fav_dir.ps1"

if (-not (Test-Path $favScriptPath)) {
    Write-Host "[ERROR] fav_dir.ps1 not found next to installer" -ForegroundColor Red
    return
}

# Line to add into profile (escaped correctly)
$line = ". `"$favScriptPath`""

# Ensure profile file exists
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

# Read existing profile
$content = Get-Content $profilePath -ErrorAction SilentlyContinue

if ($content -contains $line) {
    Write-Host "[INFO] fav_dir already registered in profile" -ForegroundColor Yellow
} else {
    Add-Content $profilePath "`n$line"
    Write-Host "[OK] fav_dir added to PowerShell profile" -ForegroundColor Green
}

Write-Host "Restart PowerShell to apply changes."
