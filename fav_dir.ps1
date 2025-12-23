# ==============================
# Favorite Directories Manager 
# ==============================

$favFile = "$HOME\Documents\WindowsPowerShell\.favdirs.json"

if (-not (Test-Path $favFile)) {
    "{}" | Set-Content $favFile -Encoding UTF8
}

function Get-FavDirs {
    try {
        $json = Get-Content $favFile -Raw | ConvertFrom-Json
    } catch {
        $json = $null
    }

    $dirs = @{}
    if ($json) {
        foreach ($p in $json.PSObject.Properties) {

            # Auto-migrate old format
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
    $dirs | ConvertTo-Json -Depth 5 | Set-Content $favFile -Encoding UTF8
}

function Get-GitRoot {
    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) {
            return $gitRoot.Trim()
        }
    } catch {}
    return $null
}

function In-GitRepo {
    return [bool](Get-GitRoot)
}


function Add-FavDir {
    param(
        [Parameter(Mandatory)]
        [string]$Alias,

        [string]$Path = (Get-Location).Path
    )

    $Alias = $Alias.ToLower()
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
        $existingCount = $Dirs[$Alias].count
        Write-Host "[WARN] Updated existing alias: $Alias (count preserved)" -ForegroundColor Yellow
    } else {
        $existingCount = 0
        Write-Host "[OK] Added new favorite: $Alias" -ForegroundColor Green
    }

    $Dirs[$Alias] = @{
        path  = $Resolved
        count = $existingCount
        type  = $Type
    }

    Save-FavDirs $Dirs
}


function Remove-FavDir {
    param([Parameter(Mandatory)][string]$Alias)

    $Alias = $Alias.ToLower()
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

    $Alias = $Alias.ToLower()
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
            $typeTag = if ($_.Value.type -eq "git") { "[git]" } else { "[dir]" }
			Write-Host "$($_.Key) $typeTag -> $($_.Value.path) (used $($_.Value.count))"

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

    $list = $items |
        Sort-Object { $_.Value.count } -Descending |
        Select-Object -ExpandProperty Key

    if ($list.Count -eq 0) {
        Write-Host "No matches." -ForegroundColor Yellow
        return
    }

    for ($i = 0; $i -lt $list.Count; $i++) {
        $k = $list[$i]
        Write-Host "$($i+1)) $k -> $($Dirs[$k].path) (used $($Dirs[$k].count))"
    }

    $choice = Read-Host "Select number"
    if ($choice -match '^\d+$' -and
        $choice -ge 1 -and
        $choice -le $list.Count) {

        Go-FavDir $list[$choice - 1]
    }
}

function Open-FavDir {
    param([Parameter(Mandatory)][string]$Alias)

    $Alias = $Alias.ToLower()
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

function xgit {
    $gitRoot = Get-GitRoot
    if (-not $gitRoot) {
        Write-Host "[ERROR] Not inside a Git repository" -ForegroundColor Red
        return
    }

    Set-Location $gitRoot
    Write-Host "[OK] Moved to Git repo root: $gitRoot" -ForegroundColor Cyan
}


Register-ArgumentCompleter -CommandName fav,favgo,favrm,favopen -ScriptBlock {
    param($cmd, $param, $word)
    foreach ($k in (Get-FavDirs).Keys) {
        if ($k -like "$word*") {
            [System.Management.Automation.CompletionResult]::new($k,$k,'ParameterValue',$k)
        }
    }
}

Set-Alias xadd  Add-FavDir
Set-Alias xrm   Remove-FavDir
Set-Alias xgo   Go-FavDir
Set-Alias xls   List-FavDirs
Set-Alias xop Open-FavDir
Set-Alias xcl Clean-FavDirs
Set-Alias gitroot xgit

