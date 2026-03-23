#!/usr/bin/env bash
# ============================================================
# Claude Code 설정 설치 스크립트 — macOS
# 사용법: bash setup_mac.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
ORIGINAL_LOCKY_PATH="/Users/youngsang.kwon/01_private/locky-agent"

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

# ── 2. Claude Code CLI 설치 ───────────────────────────────
info "Claude Code CLI 확인 중..."
if ! command -v claude &>/dev/null; then
    info "Claude Code CLI 설치 중..."
    npm install -g @anthropic-ai/claude-code
else
    CLAUDE_VER=$(claude --version 2>/dev/null || echo "unknown")
    info "Claude Code 이미 설치됨: $CLAUDE_VER"
fi

# ── 3. locky-agent 경로 입력 ─────────────────────────────
echo ""
echo "locky-agent 레포지토리 경로를 입력하세요."
echo "  (git clone 한 경로, 예: /Users/yourname/projects/locky-agent)"
read -rp "locky-agent 경로 [Enter로 스킵]: " LOCKY_PATH

# ── 4. ~/.claude 디렉토리 생성 ───────────────────────────
info "~/.claude 디렉토리 준비 중..."
mkdir -p "$CLAUDE_DIR/commands"

# ── 5. settings.json 복사 ────────────────────────────────
info "settings.json 복사 중..."
if [ -f "$CLAUDE_DIR/settings.json" ]; then
    cp "$CLAUDE_DIR/settings.json" "$CLAUDE_DIR/settings.json.bak"
    warn "기존 settings.json을 settings.json.bak으로 백업했습니다."
fi
cp "$SCRIPT_DIR/settings.json" "$CLAUDE_DIR/settings.json"
info "settings.json 복사 완료"

# ── 6. develop.md 복사 및 경로 치환 ──────────────────────
info "develop.md 복사 중..."
if [ -f "$CLAUDE_DIR/commands/develop.md" ]; then
    cp "$CLAUDE_DIR/commands/develop.md" "$CLAUDE_DIR/commands/develop.md.bak"
    warn "기존 develop.md를 develop.md.bak으로 백업했습니다."
fi
cp "$SCRIPT_DIR/commands/develop.md" "$CLAUDE_DIR/commands/develop.md"

if [ -n "$LOCKY_PATH" ]; then
    # 경로 끝 슬래시 제거
    LOCKY_PATH="${LOCKY_PATH%/}"
    sed -i '' "s|$ORIGINAL_LOCKY_PATH|$LOCKY_PATH|g" "$CLAUDE_DIR/commands/develop.md"
    info "develop.md 경로 치환 완료: $LOCKY_PATH"
else
    warn "경로 입력을 스킵했습니다. develop.md의 경로를 수동으로 수정해 주세요:"
    warn "  파일: $CLAUDE_DIR/commands/develop.md"
    warn "  치환: $ORIGINAL_LOCKY_PATH → 실제 locky-agent 경로"
fi

# ── 7. 완료 ───────────────────────────────────────────────
echo ""
echo "=============================================="
echo -e "  ${GREEN}설치 완료!${NC}"
echo "=============================================="
echo ""
echo "  설정 위치: $CLAUDE_DIR"
echo "  커맨드:    $CLAUDE_DIR/commands/develop.md"
echo ""
echo "  확인 방법:"
echo "    claude                  # Claude Code 실행"
echo "    /develop 테스트 요구사항 # 커스텀 커맨드 확인"
echo ""
