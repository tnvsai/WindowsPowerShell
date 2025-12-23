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
                # migrate old format
                $dirs[$p.Name] = @{
                    path  = $p.Value
                    count = 0
                    type  = "dir"
                }
            } else {
                $dirs[$p.Name] = @{
                    path  = $p.Value.path
                    count = [int]$p.Value.count
                    type  = $p.Value.type
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
        if ($root) {
            return $root.Trim()
        }
    } catch {}

    return $null
}

# ------------------------------
# Core commands
# ------------------------------

function Add-FavDir {
    param(
        [Parameter(Mandatory)]
        [string]$Alias,

        [string]$Path = (Get-Location).Path
    )

    $Alias = $Alias.ToLower().Trim()
    $Dirs  = Get-FavDirs

    $gitRoot = Get-GitRoot
    if ($gitRoot) {
        $Resolved = $gitRoot
        $Type = "git"
    } else {
        if (-not (Test-Path $Path)) {
            Write-Host "[ERROR] Path does not exist: $Path" -ForegroundColor Red
            return
        }
        $Resolved = (Resolve-Path $Path).Path
        $Type = "dir"
    }

    if ($Dirs.ContainsKey($Alias)) {
        $count = $Dirs[$Alias].count
        Write-Host "[WARN] Updated existing alias: $Alias (count preserved)" -ForegroundColor Yellow
    } else {
        $count = 0
        Write-Host "[OK] Added new favorite: $Alias" -ForegroundColor Green
    }

    $Dirs[$Alias] = @{
        path  = $Resolved
        count = $count
        type  = $Type
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

    $Target = $Dirs[$Alias].path

    if (-not (Test-Path $Target)) {
        Write-Host "[ERROR] Directory missing: $Target" -ForegroundColor Red
        return
    }

    $Dirs[$Alias].count++
    Save-FavDirs $Dirs

    Set-Location $Target
    Write-Host "[OK] Moved to $Target" -ForegroundColor Cyan
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
            $tag = if ($_.Value.type -eq "git") { "[git]" } else { "[dir]" }
            Write-Host "$($_.Key) $tag -> $($_.Value.path) (used $($_.Value.count))"
        }
}

function x {
    param([string]$Filter)

    $Dirs = Get-FavDirs
    if ($Dirs.Count -eq 0) {
        Write-Host "No favorites saved." -ForegroundColor Yellow
        return
    }

    $items = $Dirs.GetEnumerator()

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
        $tag = if ($Dirs[$k].type -eq "git") { "[git]" } else { "[dir]" }
        Write-Host "$($i+1)) $k $tag -> $($Dirs[$k].path) (used $($Dirs[$k].count))"
    }

    $choice = Read-Host "Select number"
    if ($choice -match '^\d+$' -and
        $choice -ge 1 -and
        $choice -le $list.Count) {

        Go-FavDir $list[$choice - 1]
    }
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

function Open-FavDir {
    param([Parameter(Mandatory)][string]$Alias)

    $Alias = $Alias.ToLower().Trim()
    $Dirs = Get-FavDirs

    if ($Dirs.ContainsKey($Alias)) {
        Start-Process explorer.exe $Dirs[$Alias].path
    } else {
        Write-Host "[ERROR] Alias not found: $Alias" -ForegroundColor Red
    }
}

function Clean-FavDirs {
    $Dirs = Get-FavDirs
    foreach ($k in @($Dirs.Keys)) {
        if (-not (Test-Path $Dirs[$k].path)) {
            $Dirs.Remove($k)
        }
    }
    Save-FavDirs $Dirs
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
Set-Alias xop   Open-FavDir
Set-Alias xcl   Clean-FavDirs
Set-Alias gitroot xgit
Set-Alias xn    xnew
