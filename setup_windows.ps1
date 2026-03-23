# ============================================================
# Claude Code 설정 설치 스크립트 — Windows (PowerShell)
# 사용법: 관리자 권한 PowerShell에서 실행
#   .\setup_windows.ps1
# ============================================================

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = "$env:USERPROFILE\.claude"
$OriginalLockyPath = "/Users/youngsang.kwon/01_private/locky-agent"

function Write-Info  { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  Claude Code 설정 설치 스크립트 (Windows)"   -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Node.js 확인 ──────────────────────────────────────
Write-Info "Node.js 확인 중..."
try {
    $nodeVer = node --version 2>&1
    Write-Info "Node.js $nodeVer 감지됨"
} catch {
    Write-Warn "Node.js가 설치되어 있지 않습니다."
    Write-Host ""
    Write-Host "  설치 방법 (둘 중 하나 선택):" -ForegroundColor Yellow
    Write-Host "    [winget]     winget install OpenJS.NodeJS"
    Write-Host "    [공식 사이트] https://nodejs.org"
    Write-Host ""
    Read-Host "Node.js를 설치한 후 계속하려면 Enter를 누르세요"
    try {
        node --version | Out-Null
    } catch {
        Write-Err "Node.js를 찾을 수 없습니다. 설치 후 다시 실행하세요."
    }
}

# ── 2. Claude Code CLI 설치 ───────────────────────────────
Write-Info "Claude Code CLI 확인 중..."
$claudeExists = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeExists) {
    Write-Info "Claude Code CLI 설치 중..."
    npm install -g @anthropic-ai/claude-code
} else {
    $claudeVer = claude --version 2>&1
    Write-Info "Claude Code 이미 설치됨: $claudeVer"
}

# ── 3. locky-agent 경로 입력 ─────────────────────────────
Write-Host ""
Write-Host "locky-agent 레포지토리 경로를 입력하세요." -ForegroundColor Cyan
Write-Host "  Windows 예시: C:\Users\yourname\projects\locky-agent"
Write-Host "  WSL 예시:     /home/yourname/locky-agent"
Write-Host "  (스킵하려면 그냥 Enter)"
$LockyPath = Read-Host "locky-agent 경로"

# Windows 백슬래시를 슬래시로 통일 (develop.md는 슬래시 사용)
if ($LockyPath) {
    $LockyPath = $LockyPath.TrimEnd('\').TrimEnd('/')
    $LockyPathForMd = $LockyPath -replace '\\', '/'
    # 드라이브 문자 앞 슬래시 추가 (C:/... → /C:/... 는 불필요, 그대로 유지)
}

# ── 4. ~/.claude 디렉토리 생성 ───────────────────────────
Write-Info "~\.claude 디렉토리 준비 중..."
New-Item -ItemType Directory -Force -Path "$ClaudeDir\commands" | Out-Null

# ── 5. settings.json 복사 ────────────────────────────────
Write-Info "settings.json 복사 중..."
$settingsDest = "$ClaudeDir\settings.json"
if (Test-Path $settingsDest) {
    Copy-Item $settingsDest "$settingsDest.bak" -Force
    Write-Warn "기존 settings.json을 settings.json.bak으로 백업했습니다."
}
Copy-Item "$ScriptDir\settings.json" $settingsDest -Force
Write-Info "settings.json 복사 완료"

# ── 6. develop.md 복사 및 경로 치환 ──────────────────────
Write-Info "develop.md 복사 중..."
$developDest = "$ClaudeDir\commands\develop.md"
if (Test-Path $developDest) {
    Copy-Item $developDest "$developDest.bak" -Force
    Write-Warn "기존 develop.md를 develop.md.bak으로 백업했습니다."
}
Copy-Item "$ScriptDir\commands\develop.md" $developDest -Force

if ($LockyPath) {
    $content = Get-Content $developDest -Raw -Encoding UTF8
    $content = $content -replace [regex]::Escape($OriginalLockyPath), $LockyPathForMd
    Set-Content $developDest -Value $content -Encoding UTF8 -NoNewline
    Write-Info "develop.md 경로 치환 완료: $LockyPathForMd"
} else {
    Write-Warn "경로 입력을 스킵했습니다. develop.md의 경로를 수동으로 수정해 주세요:"
    Write-Warn "  파일: $developDest"
    Write-Warn "  치환: $OriginalLockyPath → 실제 locky-agent 경로"
}

# ── 7. 완료 ───────────────────────────────────────────────
Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  설치 완료!" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  설정 위치: $ClaudeDir"
Write-Host "  커맨드:    $ClaudeDir\commands\develop.md"
Write-Host ""
Write-Host "  확인 방법:" -ForegroundColor Cyan
Write-Host "    claude                   # Claude Code 실행"
Write-Host "    /develop 테스트 요구사항  # 커스텀 커맨드 확인"
Write-Host ""
