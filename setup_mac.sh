#!/usr/bin/env bash
# ============================================================
# Claude Code 설정 설치 스크립트 — macOS
# 사용법: bash setup_mac.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "=============================================="
echo "  Claude Code 설정 설치 스크립트 (macOS)"
echo "=============================================="
echo ""

# ── 1. Node.js 확인 ──────────────────────────────────────
info "Node.js 확인 중..."
if ! command -v node &>/dev/null; then
    warn "Node.js가 설치되어 있지 않습니다."
    echo ""
    echo "  설치 방법 (둘 중 하나 선택):"
    echo "    [Homebrew]  brew install node"
    echo "    [공식 사이트] https://nodejs.org"
    echo ""
    read -rp "Node.js를 설치한 후 계속하려면 Enter를 누르세요..."
    command -v node &>/dev/null || error "Node.js를 찾을 수 없습니다. 설치 후 다시 실행하세요."
fi
NODE_VER=$(node --version)
info "Node.js $NODE_VER 감지됨"

# ── 2. Python3 확인 ───────────────────────────────────────
info "Python3 확인 중..."
if ! command -v python3 &>/dev/null; then
    warn "Python3가 설치되어 있지 않습니다."
    echo ""
    echo "  설치 방법:"
    echo "    [Homebrew]  brew install python3"
    echo "    [공식 사이트] https://python.org"
    echo ""
    read -rp "Python3를 설치한 후 계속하려면 Enter를 누르세요..."
    command -v python3 &>/dev/null || error "Python3를 찾을 수 없습니다. 설치 후 다시 실행하세요."
fi
PY_VER=$(python3 --version)
info "$PY_VER 감지됨"

# ── 3. Claude Code CLI 설치 ───────────────────────────────
info "Claude Code CLI 확인 중..."
if ! command -v claude &>/dev/null; then
    info "Claude Code CLI 설치 중..."
    npm install -g @anthropic-ai/claude-code
else
    CLAUDE_VER=$(claude --version 2>/dev/null || echo "unknown")
    info "Claude Code 이미 설치됨: $CLAUDE_VER"
fi

# ── 4. ~/.claude 디렉토리 생성 ───────────────────────────
info "~/.claude 디렉토리 준비 중..."
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/skills"

# ── 5. CLAUDE.md 복사 ────────────────────────────────────
info "CLAUDE.md 복사 중..."
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
    cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.bak"
    warn "기존 CLAUDE.md를 CLAUDE.md.bak으로 백업했습니다."
fi
cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
info "CLAUDE.md 복사 완료"

# ── 6. settings.json 복사 ────────────────────────────────
info "settings.json 복사 중..."
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak"
    warn "기존 settings.json을 settings.json.bak으로 백업했습니다."
fi
cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
info "settings.json 복사 완료"

# ── 7. statusline-command.sh 복사 ────────────────────────
info "statusline-command.sh 복사 중..."
cp "$SCRIPT_DIR/statusline-command.sh" "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"
info "statusline-command.sh 복사 완료"

# ── 8. commands 복사 ─────────────────────────────────────
info "commands 복사 중..."
cp -r "$SCRIPT_DIR/commands/." "$CLAUDE_DIR/commands/"
info "commands 복사 완료"

# ── 9. dev-pipeline 복사 ─────────────────────────────────
info "dev-pipeline 복사 중..."
if [ -d "$CLAUDE_DIR/dev-pipeline" ]; then
    warn "기존 dev-pipeline을 dev-pipeline.bak으로 백업합니다."
    rm -rf "$CLAUDE_DIR/dev-pipeline.bak"
    mv "$CLAUDE_DIR/dev-pipeline" "$CLAUDE_DIR/dev-pipeline.bak"
fi
cp -r "$SCRIPT_DIR/dev-pipeline" "$CLAUDE_DIR/dev-pipeline"
info "dev-pipeline 복사 완료"

# ── 10. skills 복사 ───────────────────────────────────────
info "skills 복사 중..."
cp -r "$SCRIPT_DIR/skills/." "$CLAUDE_DIR/skills/"
info "skills 복사 완료"

# ── 11. MCP 서버 등록 ────────────────────────────────────
info "MCP 서버 등록 중..."

# context7 (최신 라이브러리 문서)
if ! claude mcp list 2>/dev/null | grep -q "context7"; then
    claude mcp add context7 -s user -- npx -y @upstash/context7-mcp 2>/dev/null && \
        info "context7 MCP 등록 완료" || \
        warn "context7 MCP 등록 실패 — 수동 등록: claude mcp add context7 -s user -- npx -y @upstash/context7-mcp"
else
    info "context7 MCP 이미 등록됨"
fi

# shadcn-ui (UI 컴포넌트 레지스트리)
if ! claude mcp list 2>/dev/null | grep -q "shadcn"; then
    claude mcp add shadcn-ui -s user -- npx -y shadcn@canary mcp 2>/dev/null && \
        info "shadcn-ui MCP 등록 완료" || \
        warn "shadcn-ui MCP 등록 실패 — 수동 등록: claude mcp add shadcn-ui -s user -- npx -y shadcn@canary mcp"
else
    info "shadcn-ui MCP 이미 등록됨"
fi

info "MCP 서버 등록 완료 (playwright, sequential-thinking은 settings.json에서 자동 로드)"

# ── 12. 완료 ──────────────────────────────────────────────
echo ""
echo "=============================================="
echo -e "  ${GREEN}설치 완료!${NC}"
echo "=============================================="
echo ""
echo "  설정 위치: $CLAUDE_DIR"
echo ""
echo "  설치된 항목:"
echo "    CLAUDE.md                — 전역 AI 행동 지침"
echo "    settings.json            — Claude Code 전역 설정"
echo "    statusline-command.sh    — 상태 표시줄 스크립트"
echo "    commands/develop.md      — /develop 커스텀 커맨드"
echo "    dev-pipeline/            — 자동화 파이프라인 엔진"
echo "    skills/context-check/    — 컨텍스트 진단 스킬"
echo "    skills/git-commit-push/  — Git 커밋/푸시 스킬"
echo "    skills/lokuma/           — Lokuma 디자인 인텔리전스"
echo "    skills/subagent-creator/ — 서브에이전트 생성기"
echo ""
echo "  확인 방법:"
echo "    claude                    # Claude Code 실행"
echo "    /develop 테스트 요구사항  # 개발 파이프라인 실행"
echo ""
echo "  다음 단계 (선택):"
echo "    Telegram 연동: /telegram:configure"
echo "    bkit 플러그인: /bkit"
echo ""
