# ==============================
# Favorite Directories Manager
# ==============================

$favFile = Join-Path $HOME "Documents\WindowsPowerShell\.favdirs.json"

if (-not (Test-Path $favFile)) {
    "{}" | Set-Content $favFile -Encoding UTF8
}

# ------------------------------
# Storage helpers
# ------------------------------

function Get-FavDirs {
    try {
        $json = Get-Content $favFile -Raw | ConvertFrom-Json
    } catch {
        $json = $null
    }

    $dirs = @{}
    if ($json) {
        foreach ($p in $json.PSObject.Properties) {
            if ($p.Value -is [string]) {
                $dirs[$p.Name] = @{
                    path  = $p.Value
                    count = 0
                }
            } else {
                $dirs[$p.Name] = @{
                    path  = $p.Value.path
                    count = [int]$p.Value.count
                }
            }
        }
    }
    return $dirs
}

function Save-FavDirs($dirs) {
    $tmp = "$favFile.tmp"
    $dirs | ConvertTo-Json -Depth 5 | Set-Content $tmp -Encoding UTF8
    Move-Item $tmp $favFile -Force
}

# ------------------------------
# Git helpers
# ------------------------------

function Get-GitRoot {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        return $null
    }

    try {
        $root = git rev-parse --show-toplevel 2>$null
        if ($root) { return $root.Trim() }
    } catch {}

    return $null
}

# ------------------------------
# Core commands
# ------------------------------

function Add-FavDir {
    param(
        [Parameter(Mandatory)][string]$Alias,
        [string]$Path = (Get-Location).Path
    )

    $Alias = $Alias.ToLower().Trim()
    $Dirs  = Get-FavDirs

    if (-not (Test-Path $Path)) {
        Write-Host "[ERROR] Path does not exist: $Path" -ForegroundColor Red
        return
    }

    $Resolved = (Resolve-Path $Path).Path

    $count = if ($Dirs.ContainsKey($Alias)) {
        Write-Host "[WARN] Updated existing alias: $Alias (count preserved)" -ForegroundColor Yellow
        $Dirs[$Alias].count
    } else {
        Write-Host "[OK] Added new favorite: $Alias" -ForegroundColor Green
        0
    }

    $Dirs[$Alias] = @{
        path  = $Resolved
        count = $count
    }

    Save-FavDirs $Dirs
}

function Remove-FavDir {
    param([Parameter(Mandatory)][string]$Alias)

    $Alias = $Alias.ToLower().Trim()
    $Dirs = Get-FavDirs

    if ($Dirs.ContainsKey($Alias)) {
        $Dirs.Remove($Alias)
        Save-FavDirs $Dirs
        Write-Host "[OK] Removed: $Alias" -ForegroundColor Yellow
    } else {
        Write-Host "[ERROR] Alias not found: $Alias" -ForegroundColor Red
    }
}

function Go-FavDir {
    param([Parameter(Mandatory)][string]$Alias)

    $Alias = $Alias.ToLower().Trim()
    $Dirs = Get-FavDirs

    if (-not $Dirs.ContainsKey($Alias)) {
        Write-Host "[ERROR] Alias not found: $Alias" -ForegroundColor Red
        return
    }

    $target = $Dirs[$Alias].path

    if (-not (Test-Path $target)) {
        Write-Host "[ERROR] Path missing: $target" -ForegroundColor Red
        return
    }

    $Dirs[$Alias].count++
    Save-FavDirs $Dirs

    if (Test-Path $target -PathType Container) {
        Set-Location $target
        Write-Host "[OK] Moved to $target" -ForegroundColor Cyan
    } else {
        $parent = Split-Path $target -Parent
        Set-Location $parent
        Write-Host "[OK] Moved to $parent (file: $(Split-Path $target -Leaf))" -ForegroundColor Cyan
    }
}

function List-FavDirs {
    $Dirs = Get-FavDirs
    Write-Host "=== Favorite Directories ===" -ForegroundColor Cyan

    if ($Dirs.Count -eq 0) {
        Write-Host "(none)" -ForegroundColor DarkGray
        return
    }

    $Dirs.GetEnumerator() |
        Sort-Object { $_.Value.count } -Descending |
        ForEach-Object {
            $path = $_.Value.path
            $tag = if (Test-Path $path -PathType Leaf) { "[file]" } else { "[dir]" }
            Write-Host "$($_.Key) $tag -> $path (used $($_.Value.count))"
        }
}

# ------------------------------
# Interactive jump (x)
# ------------------------------

function x {
    param([string]$Filter)

    $Dirs = Get-FavDirs
    if ($Dirs.Count -eq 0) {
        Write-Host "No favorites saved." -ForegroundColor Yellow
        return
    }

    $items = $Dirs.GetEnumerator()

    if ($Filter -match '^\d+$') {
        $list = @(
            $items |
            Sort-Object { $_.Value.count } -Descending |
            Select-Object -ExpandProperty Key
        )

        $index = [int]$Filter - 1
        if ($index -lt 0 -or $index -ge $list.Count) {
            Write-Host "[ERROR] Invalid index: $Filter" -ForegroundColor Red
            return
        }

        Go-FavDir $list[$index]
        return
    }

    if ($Filter) {
        $Filter = $Filter.ToLower()
        $items = $items | Where-Object { $_.Key -like "*$Filter*" }
    }

    $list = @(
        $items |
        Sort-Object { $_.Value.count } -Descending |
        Select-Object -ExpandProperty Key
    )

    if ($list.Count -eq 0) {
        Write-Host "No matches." -ForegroundColor Yellow
        return
    }

    for ($i = 0; $i -lt $list.Count; $i++) {
        $k = $list[$i]
        $path = $Dirs[$k].path
        $tag = if (Test-Path $path -PathType Leaf) { "[file]" } else { "[dir]" }
        Write-Host "$($i+1)) $k $tag -> $path (used $($Dirs[$k].count))"
    }

    $choice = Read-Host "Select number"
    if ($choice -match '^\d+$' -and
        $choice -ge 1 -and
        $choice -le $list.Count) {

        Go-FavDir $list[$choice - 1]
    }
}

# ------------------------------
# Open helpers
# ------------------------------

function Open-FavDir {
    param([Parameter(Mandatory)][string]$Alias)

    $Dirs = Get-FavDirs
    $path = $Dirs[$Alias].path

    if (-not (Test-Path $path)) {
        Write-Host "[ERROR] Path does not exist: $path" -ForegroundColor Red
        return
    }

    if (Test-Path $path -PathType Container) {
        # Directory → open in Explorer
        Start-Process explorer.exe $path
    }
    else {
        # File → open with default application
        Start-Process $path
    }
}

function xop {
    param([Parameter(Mandatory)][string]$Target)

    $Dirs = Get-FavDirs

    $list = @(
        $Dirs.GetEnumerator() |
        Sort-Object { $_.Value.count } -Descending |
        Select-Object -ExpandProperty Key
    )

    if ($Target -match '^\d+$') {
        $index = [int]$Target - 1
        if ($index -lt 0 -or $index -ge $list.Count) {
            Write-Host "[ERROR] Invalid index: $Target" -ForegroundColor Red
            return
        }
        $alias = $list[$index]
    } else {
        $alias = $Target.ToLower().Trim()
        if (-not $Dirs.ContainsKey($alias)) {
            Write-Host "[ERROR] Alias not found: $alias" -ForegroundColor Red
            return
        }
    }

    Open-FavDir $alias
    Write-Host "[OK] Opened: $alias" -ForegroundColor Cyan
}

# ------------------------------
# Utilities
# ------------------------------

function Clean-FavDirs {
    $Dirs = Get-FavDirs
    foreach ($k in @($Dirs.Keys)) {
        if (-not (Test-Path $Dirs[$k].path)) {
            $Dirs.Remove($k)
        }
    }
    Save-FavDirs $Dirs
}

function xgit {
    $root = Get-GitRoot
    if (-not $root) {
        Write-Host "[ERROR] Not inside a Git repository" -ForegroundColor Red
        return
    }
    Set-Location $root
    Write-Host "[OK] Moved to Git repo root: $root" -ForegroundColor Cyan
}

function xnew($path) {
    if (-not (Test-Path $path)) {
        "" | Out-File -FilePath $path -Encoding UTF8
        Write-Host "Created new file: $path (UTF-8)"
    } else {
        Write-Host "File already exists: $path"
    }
}

# ------------------------------
# Tab completion
# ------------------------------

Register-ArgumentCompleter -CommandName x,xgo,xrm,xop -ScriptBlock {
    param($cmd, $param, $word)
    foreach ($k in (Get-FavDirs).Keys) {
        if ($k -like "$word*") {
            [System.Management.Automation.CompletionResult]::new($k,$k,'ParameterValue',$k)
        }
    }
}

# ------------------------------
# Aliases
# ------------------------------

Set-Alias xadd  Add-FavDir
Set-Alias xrm   Remove-FavDir
Set-Alias xgo   Go-FavDir
Set-Alias xls   List-FavDirs
Set-Alias xcl   Clean-FavDirs
Set-Alias gitroot xgit
Set-Alias xn    xnew
