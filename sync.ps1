# ============================================================
# Claude Code Settings Sync Script — Windows (PowerShell)
# Usage:
#   .\sync.ps1                # 동기화 실행
#   .\sync.ps1 -DryRun       # 변경사항만 확인 (실제 반영 안 함)
#   .\sync.ps1 -InstallTask  # 30분 주기 Task Scheduler 등록
# ============================================================

param(
    [switch]$DryRun,
    [switch]$InstallTask,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LockFile = Join-Path $ScriptDir ".sync.lock"
$ConfFile = Join-Path $ScriptDir "sync.conf"

$script:ChangedCount = 0
$script:ChangedFiles = @()

# ── Logging ───────────────────────────────────────────────

function Write-Log {
    param($msg, $Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    switch ($Level) {
        "INFO"  { Write-Host "[$ts] $msg" -ForegroundColor Green }
        "WARN"  { Write-Host "[$ts] WARN $msg" -ForegroundColor Yellow }
        "ERROR" { Write-Host "[$ts] ERROR $msg" -ForegroundColor Red }
    }
}

# ── Help ──────────────────────────────────────────────────

if ($Help) {
    Write-Host "Usage: .\sync.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -DryRun        변경사항만 확인 (실제 반영 안 함)"
    Write-Host "  -InstallTask   30분 주기 Task Scheduler 등록"
    Write-Host "  -Help          이 도움말 표시"
    exit 0
}

# ── Lock Management ───────────────────────────────────────

function Get-Lock {
    if (Test-Path $LockFile) {
        $pid = Get-Content $LockFile -ErrorAction SilentlyContinue
        if ($pid) {
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Log "Already running (PID: $pid)" "ERROR"
                exit 2
            }
        }
        Write-Log "Stale lock found (PID: $pid). Removing." "WARN"
        Remove-Item $LockFile -Force
    }
    $PID | Out-File $LockFile -Encoding UTF8 -NoNewline
}

function Remove-Lock {
    if (Test-Path $LockFile) {
        Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
    }
}

# ── Config Loading ────────────────────────────────────────

function Import-SyncConfig {
    if (-not (Test-Path $ConfFile)) {
        Write-Log "sync.conf not found: $ConfFile" "ERROR"
        exit 1
    }

    $script:SyncTargets = ""
    $script:SyncExcludes = ""
    $script:RemoteBranch = "main"
    $script:CommitPrefix = "sync"
    $script:SourceDir = Join-Path $env:USERPROFILE ".claude"

    Get-Content $ConfFile | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }

        if ($line -match '^(\w+)\s*=\s*"?(.+?)"?\s*$') {
            $key = $Matches[1]
            $value = $Matches[2]
            $value = $value -replace '\$HOME', $env:USERPROFILE
            $value = $value -replace '\$env:USERPROFILE', $env:USERPROFILE

            switch ($key) {
                "SYNC_TARGETS"  { $script:SyncTargets = $value }
                "SYNC_EXCLUDES" { $script:SyncExcludes = $value }
                "REMOTE_BRANCH" { $script:RemoteBranch = $value }
                "COMMIT_PREFIX" { $script:CommitPrefix = $value }
                "SOURCE_DIR"    { $script:SourceDir = $value }
            }
        }
    }

    if (-not $script:SyncTargets) {
        Write-Log "SYNC_TARGETS is empty in sync.conf" "ERROR"
        exit 1
    }

    if (-not (Test-Path $script:SourceDir)) {
        Write-Log "Source directory not found: $($script:SourceDir)" "ERROR"
        exit 1
    }
}

# ── Exclude Check ─────────────────────────────────────────

function Test-Excluded {
    param($FilePath)

    $basename = Split-Path $FilePath -Leaf
    $patterns = $script:SyncExcludes -split '\s+'

    foreach ($pattern in $patterns) {
        if (-not $pattern) { continue }
        if ($basename -like $pattern) { return $true }
        if ($FilePath -like "*\$pattern\*") { return $true }
        if ($FilePath -like "*\$pattern") { return $true }
        if ($FilePath -like "*/$pattern/*") { return $true }
        if ($FilePath -like "*/$pattern") { return $true }
    }
    return $false
}

# ── Compare & Copy ────────────────────────────────────────

function Compare-And-Copy {
    param($Source, $Dest, $RelPath)

    if (-not (Test-Path $Source)) {
        Write-Log "Source not found, skipping: $RelPath" "WARN"
        return
    }

    if (Test-Path $Source -PathType Container) {
        if (-not (Test-Path $Dest)) {
            New-Item -ItemType Directory -Force -Path $Dest | Out-Null
        }

        Get-ChildItem $Source -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($Source.Length + 1)
            $destFile = Join-Path $Dest $rel

            if (Test-Excluded $rel) { return }

            $needsCopy = $false
            if (-not (Test-Path $destFile)) {
                $needsCopy = $true
            } else {
                $srcHash = (Get-FileHash $_.FullName -Algorithm MD5).Hash
                $dstHash = (Get-FileHash $destFile -Algorithm MD5).Hash
                if ($srcHash -ne $dstHash) { $needsCopy = $true }
            }

            if ($needsCopy) {
                if ($DryRun) {
                    Write-Log "[DRY-RUN] Would copy: $RelPath/$rel"
                } else {
                    $destDir = Split-Path $destFile -Parent
                    if (-not (Test-Path $destDir)) {
                        New-Item -ItemType Directory -Force -Path $destDir | Out-Null
                    }
                    Copy-Item $_.FullName $destFile -Force
                    Write-Log "Copied: $RelPath/$rel"
                }
                $script:ChangedCount++
                $script:ChangedFiles += "$RelPath/$rel"
            }
        }
    } else {
        if (Test-Excluded $RelPath) { return }

        $needsCopy = $false
        if (-not (Test-Path $Dest)) {
            $needsCopy = $true
        } else {
            $srcHash = (Get-FileHash $Source -Algorithm MD5).Hash
            $dstHash = (Get-FileHash $Dest -Algorithm MD5).Hash
            if ($srcHash -ne $dstHash) { $needsCopy = $true }
        }

        if ($needsCopy) {
            if ($DryRun) {
                Write-Log "[DRY-RUN] Would copy: $RelPath"
            } else {
                Copy-Item $Source $Dest -Force
                Write-Log "Copied: $RelPath"
            }
            $script:ChangedCount++
            $script:ChangedFiles += $RelPath
        }
    }
}

# ── Sync Targets ──────────────────────────────────────────

function Sync-Targets {
    $targets = $script:SyncTargets -split '\s+'
    foreach ($target in $targets) {
        if (-not $target) { continue }
        $src = Join-Path $script:SourceDir $target
        $dst = Join-Path $ScriptDir $target
        Compare-And-Copy $src $dst $target
    }
}

# ── Git Operations ────────────────────────────────────────

function Invoke-GitCommitPush {
    Set-Location $ScriptDir

    $gitExists = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitExists) {
        Write-Log "git is not installed" "ERROR"
        exit 1
    }

    $isRepo = git rev-parse --is-inside-work-tree 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Not a git repository: $ScriptDir" "ERROR"
        exit 1
    }

    git add -A

    $status = git status --porcelain
    if (-not $status) {
        Write-Log "No git changes after sync. Skipping commit."
        return
    }

    if ($script:ChangedFiles.Count -le 3) {
        $fileSummary = $script:ChangedFiles -join ", "
    } else {
        $fileSummary = "$($script:ChangedFiles[0]), $($script:ChangedFiles[1]) and $($script:ChangedFiles.Count - 2) more"
    }

    $message = "$($script:CommitPrefix): update $fileSummary"
    git commit -m $message
    Write-Log "Committed: $message"

    $pushResult = git push origin $script:RemoteBranch 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Push failed. Trying pull --rebase..." "WARN"
        git pull --rebase origin $script:RemoteBranch 2>&1
        if ($LASTEXITCODE -ne 0) {
            git rebase --abort 2>&1 | Out-Null
            Write-Log "Rebase conflict. Manual resolution required." "ERROR"
            exit 3
        }
        git push origin $script:RemoteBranch
        Write-Log "Push succeeded after rebase."
    } else {
        Write-Log "Pushed to origin/$($script:RemoteBranch)"
    }
}

# ── Task Scheduler Installation ───────────────────────────

function Install-TaskScheduler {
    $taskName = "ClaudeSettingsSync"

    $existing = schtasks /Query /TN $taskName 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Task already exists: $taskName" "WARN"
        Write-Host ""
        Write-Host "To remove: schtasks /Delete /TN `"$taskName`" /F"
        return
    }

    $syncScript = Join-Path $ScriptDir "sync.ps1"
    schtasks /Create /SC MINUTE /MO 30 /TN $taskName `
        /TR "powershell -ExecutionPolicy Bypass -File `"$syncScript`"" `
        /F

    Write-Log "Task Scheduler registered: every 30 minutes"
    Write-Host ""
    Write-Host "To remove: schtasks /Delete /TN `"$taskName`" /F"
}

# ── Main ──────────────────────────────────────────────────

function Main {
    if ($InstallTask) {
        Install-TaskScheduler
        return
    }

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "  Claude Code Settings Sync"                   -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""

    Set-Location $ScriptDir

    Get-Lock
    try {
        Import-SyncConfig
        Write-Log "Source: $($script:SourceDir)"
        Write-Log "Targets: $($script:SyncTargets)"
        if ($DryRun) { Write-Log "DRY-RUN mode enabled" "WARN" }

        Sync-Targets

        if ($script:ChangedCount -eq 0) {
            Write-Log "No changes detected. Everything is up to date."
            Write-Host ""
            return
        }

        Write-Log "$($script:ChangedCount) file(s) changed."

        if ($DryRun) {
            Write-Log "[DRY-RUN] No actual changes made."
            Write-Host ""
            return
        }

        Invoke-GitCommitPush

        Write-Host ""
        Write-Host "==============================================" -ForegroundColor Cyan
        Write-Host "  Sync complete! ($($script:ChangedCount) file(s))" -ForegroundColor Green
        Write-Host "==============================================" -ForegroundColor Cyan
        Write-Host ""
    }
    finally {
        Remove-Lock
    }
}

Main
