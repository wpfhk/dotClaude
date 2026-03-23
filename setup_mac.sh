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

# ── 5. settings.json 복사 ────────────────────────────────
info "settings.json 복사 중..."
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak"
    warn "기존 settings.json을 settings.json.bak으로 백업했습니다."
fi
cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
info "settings.json 복사 완료"

# ── 6. commands 복사 ─────────────────────────────────────
info "commands 복사 중..."
cp -r "$SCRIPT_DIR/commands/." "$CLAUDE_DIR/commands/"
info "commands 복사 완료"

# ── 7. dev-pipeline 복사 ─────────────────────────────────
info "dev-pipeline 복사 중..."
if [ -d "$CLAUDE_DIR/dev-pipeline" ]; then
    warn "기존 dev-pipeline을 dev-pipeline.bak으로 백업합니다."
    rm -rf "$CLAUDE_DIR/dev-pipeline.bak"
    mv "$CLAUDE_DIR/dev-pipeline" "$CLAUDE_DIR/dev-pipeline.bak"
fi
cp -r "$SCRIPT_DIR/dev-pipeline" "$CLAUDE_DIR/dev-pipeline"
info "dev-pipeline 복사 완료"

# ── 8. skills 복사 ───────────────────────────────────────
info "skills 복사 중..."
cp -r "$SCRIPT_DIR/skills/." "$CLAUDE_DIR/skills/"
info "skills 복사 완료"

# ── 9. Lokuma 경로 치환 (SKILL.md 내 Windows 절대경로) ──
LOKUMA_SKILL="$CLAUDE_DIR/skills/lokuma/SKILL.md"
if [ -f "$LOKUMA_SKILL" ]; then
    sed -i '' "s|C:\\\\Users\\\\SMILE\\\\.claude|$CLAUDE_DIR|g" "$LOKUMA_SKILL"
    sed -i '' "s|C:/Users/SMILE/.claude|$CLAUDE_DIR|g" "$LOKUMA_SKILL"
    info "SKILL.md 경로 치환 완료"
fi

# ── 10. 완료 ──────────────────────────────────────────────
echo ""
echo "=============================================="
echo -e "  ${GREEN}설치 완료!${NC}"
echo "=============================================="
echo ""
echo "  설정 위치: $CLAUDE_DIR"
echo ""
echo "  설치된 항목:"
echo "    settings.json            — Claude Code 전역 설정"
echo "    commands/develop.md      — /develop 커스텀 커맨드"
echo "    dev-pipeline/            — 자동화 파이프라인 엔진"
echo "    skills/lokuma/           — Lokuma 디자인 인텔리전스"
echo "    skills/subagent-creator/ — 서브에이전트 생성기"
echo ""
echo "  확인 방법:"
echo "    claude                    # Claude Code 실행"
echo "    /develop 테스트 요구사항  # 개발 파이프라인 실행"
echo ""
