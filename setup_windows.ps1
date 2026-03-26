# ============================================================
# Claude Code 설정 설치 스크립트 — Windows (PowerShell)
# 사용법: 관리자 권한 PowerShell에서 실행
#   .\setup_windows.ps1
# ============================================================

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = "$env:USERPROFILE\.claude"

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
    try { node --version | Out-Null } catch { Write-Err "Node.js를 찾을 수 없습니다. 설치 후 다시 실행하세요." }
}

# ── 2. Python3 확인 ───────────────────────────────────────
Write-Info "Python3 확인 중..."
try {
    $pyVer = python --version 2>&1
    Write-Info "$pyVer 감지됨"
} catch {
    Write-Warn "Python이 설치되어 있지 않습니다."
    Write-Host ""
    Write-Host "  설치 방법:" -ForegroundColor Yellow
    Write-Host "    [winget]     winget install Python.Python.3"
    Write-Host "    [공식 사이트] https://python.org"
    Write-Host ""
    Read-Host "Python을 설치한 후 계속하려면 Enter를 누르세요"
    try { python --version | Out-Null } catch { Write-Err "Python을 찾을 수 없습니다. 설치 후 다시 실행하세요." }
}

# ── 3. Claude Code CLI 설치 ───────────────────────────────
Write-Info "Claude Code CLI 확인 중..."
$claudeExists = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeExists) {
    Write-Info "Claude Code CLI 설치 중..."
    npm install -g @anthropic-ai/claude-code
} else {
    $claudeVer = claude --version 2>&1
    Write-Info "Claude Code 이미 설치됨: $claudeVer"
}

# ── 4. 디렉토리 생성 ─────────────────────────────────────
Write-Info "디렉토리 준비 중..."
New-Item -ItemType Directory -Force -Path "$ClaudeDir\commands" | Out-Null
New-Item -ItemType Directory -Force -Path "$ClaudeDir\skills"   | Out-Null

# ── 5. CLAUDE.md 복사 ────────────────────────────────────
Write-Info "CLAUDE.md 복사 중..."
$claudeMdDest = "$ClaudeDir\CLAUDE.md"
if (Test-Path $claudeMdDest) {
    Copy-Item $claudeMdDest "$claudeMdDest.bak" -Force
    Write-Warn "기존 CLAUDE.md를 CLAUDE.md.bak으로 백업했습니다."
}
Copy-Item "$ScriptDir\CLAUDE.md" $claudeMdDest -Force
Write-Info "CLAUDE.md 복사 완료"

# ── 6. settings.json 복사 ────────────────────────────────
Write-Info "settings.json 복사 중..."
$settingsDest = "$ClaudeDir\settings.json"
if (Test-Path $settingsDest) {
    Copy-Item $settingsDest "$settingsDest.bak" -Force
    Write-Warn "기존 settings.json을 settings.json.bak으로 백업했습니다."
}
Copy-Item "$ScriptDir\settings.json" $settingsDest -Force
Write-Info "settings.json 복사 완료"

# ── 7. statusline-command.sh 복사 (WSL/Git Bash용) ───────
Write-Info "statusline-command.sh 복사 중..."
Copy-Item "$ScriptDir\statusline-command.sh" "$ClaudeDir\statusline-command.sh" -Force
Write-Info "statusline-command.sh 복사 완료 (Git Bash/WSL 환경에서 사용)"

# ── 8. commands 복사 ─────────────────────────────────────
Write-Info "commands 복사 중..."
Copy-Item "$ScriptDir\commands\*" "$ClaudeDir\commands\" -Force -Recurse
Write-Info "commands 복사 완료"

# ── 9. dev-pipeline 복사 ─────────────────────────────────
Write-Info "dev-pipeline 복사 중..."
$devPipelineDest = "$ClaudeDir\dev-pipeline"
if (Test-Path $devPipelineDest) {
    $backupPath = "$ClaudeDir\dev-pipeline.bak"
    if (Test-Path $backupPath) { Remove-Item $backupPath -Recurse -Force }
    Rename-Item $devPipelineDest "dev-pipeline.bak"
    Write-Warn "기존 dev-pipeline을 dev-pipeline.bak으로 백업했습니다."
}
Copy-Item "$ScriptDir\dev-pipeline" "$ClaudeDir\dev-pipeline" -Recurse -Force
Write-Info "dev-pipeline 복사 완료"

# ── 10. skills 복사 ───────────────────────────────────────
Write-Info "skills 복사 중..."
Copy-Item "$ScriptDir\skills\*" "$ClaudeDir\skills\" -Force -Recurse
Write-Info "skills 복사 완료"

# ── 11. MCP 서버 등록 ────────────────────────────────────
Write-Info "MCP 서버 등록 중 (context7, shadcn-ui)..."

$mcpList = claude mcp list 2>&1

if ($mcpList -notmatch "context7") {
    try {
        claude mcp add context7 -s user -- npx -y @upstash/context7-mcp 2>&1 | Out-Null
        Write-Info "context7 MCP 등록 완료"
    } catch {
        Write-Warn "context7 MCP 등록 실패 — 수동 등록: claude mcp add context7 -s user -- npx -y @upstash/context7-mcp"
    }
} else {
    Write-Info "context7 MCP 이미 등록됨"
}

if ($mcpList -notmatch "shadcn") {
    try {
        claude mcp add shadcn-ui -s user -- npx -y shadcn@canary mcp 2>&1 | Out-Null
        Write-Info "shadcn-ui MCP 등록 완료"
    } catch {
        Write-Warn "shadcn-ui MCP 등록 실패 — 수동 등록: claude mcp add shadcn-ui -s user -- npx -y shadcn@canary mcp"
    }
} else {
    Write-Info "shadcn-ui MCP 이미 등록됨"
}

Write-Info "MCP 설정 완료 (playwright, sequential-thinking은 settings.json에서 자동 로드)"

# ── 12. 완료 ──────────────────────────────────────────────
Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  설치 완료!" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  설정 위치: $ClaudeDir"
Write-Host ""
Write-Host "  설치된 항목:" -ForegroundColor Cyan
Write-Host "    CLAUDE.md                - 전역 AI 행동 지침"
Write-Host "    settings.json            - Claude Code 전역 설정"
Write-Host "    statusline-command.sh    - 상태 표시줄 스크립트"
Write-Host "    commands\develop.md      - /develop 커스텀 커맨드"
Write-Host "    dev-pipeline\            - 자동화 파이프라인 엔진"
Write-Host "    skills\context-check\    - 컨텍스트 진단 스킬"
Write-Host "    skills\git-commit-push\  - Git 커밋/푸시 스킬"
Write-Host "    skills\lokuma\           - Lokuma 디자인 인텔리전스"
Write-Host "    skills\subagent-creator\ - 서브에이전트 생성기"
Write-Host ""
Write-Host "  확인 방법:" -ForegroundColor Cyan
Write-Host "    claude                    # Claude Code 실행"
Write-Host "    /develop 테스트 요구사항  # 개발 파이프라인 실행"
Write-Host ""
Write-Host "  다음 단계 (선택):" -ForegroundColor Cyan
Write-Host "    Telegram 연동: /telegram:configure"
Write-Host "    bkit 플러그인: /bkit"
Write-Host ""
