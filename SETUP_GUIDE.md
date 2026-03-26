# Claude Code 설정 이식 가이드

새 컴퓨터(Mac / Windows)에 Claude Code 전역 설정을 그대로 옮기는 방법입니다.

---

## 포함된 파일 구조

```
my_claude_set/
├── CLAUDE.md                      # 전역 AI 행동 지침 (PDCA 규칙, 코드 품질 기준)
├── settings.json                  # Claude Code 전역 설정
├── statusline-command.sh          # 상태 표시줄 스크립트 (ctx%, 토큰, 모델)
├── commands/
│   └── develop.md                 # /develop — 계층적 자동화 개발 파이프라인
├── dev-pipeline/                  # 자동화 개발 파이프라인 엔진 (Python)
│   ├── agents/prompts/            # 역할별 에이전트 시스템 프롬프트
│   └── pipeline/                  # 파이프라인 상태 관리 모듈
├── skills/
│   ├── context-check/             # 컨텍스트 윈도우 진단 스킬
│   ├── git-commit-push/           # Git add→commit→push 자동화 스킬
│   ├── lokuma/                    # Lokuma 디자인 인텔리전스 스킬
│   └── subagent-creator/          # Claude Agent SDK 서브에이전트 생성기
├── setup_mac.sh                   # macOS 자동 설치 스크립트
├── setup_windows.ps1              # Windows 자동 설치 스크립트
└── archive/                       # 구버전 파일 보관
```

---

## 사전 요구사항

| 항목 | 버전 | 용도 |
|------|------|------|
| Node.js | 18+ | Claude Code CLI 실행 |
| Python | 3.8+ | dev-pipeline 엔진 |
| Claude Code CLI | 최신 | `npm install -g @anthropic-ai/claude-code` |

---

## 빠른 설치 (권장)

### macOS

```bash
bash setup_mac.sh
```

### Windows (PowerShell, 관리자 권한)

```powershell
.\setup_windows.ps1
```

스크립트가 자동으로 처리하는 것들:
- Node.js / Python 설치 확인
- Claude Code CLI 설치
- 설정 파일 전체 복사 (`~/.claude/`)
- MCP 서버 등록 (context7, shadcn-ui)

---

## 수동 설치

### macOS / Linux

```bash
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR/commands" "$CLAUDE_DIR/skills"

cp CLAUDE.md "$CLAUDE_DIR/CLAUDE.md"
cp settings.json "$CLAUDE_DIR/settings.json"
cp statusline-command.sh "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"

cp -r commands/. "$CLAUDE_DIR/commands/"
cp -r dev-pipeline "$CLAUDE_DIR/dev-pipeline"
cp -r skills/. "$CLAUDE_DIR/skills/"

claude mcp add context7 -s user -- npx -y @upstash/context7-mcp
claude mcp add shadcn-ui -s user -- npx -y shadcn@canary mcp
```

### Windows (PowerShell)

```powershell
$ClaudeDir = "$env:USERPROFILE\.claude"
New-Item -ItemType Directory -Force -Path "$ClaudeDir\commands", "$ClaudeDir\skills" | Out-Null

Copy-Item "CLAUDE.md" "$ClaudeDir\CLAUDE.md" -Force
Copy-Item "settings.json" "$ClaudeDir\settings.json" -Force
Copy-Item "statusline-command.sh" "$ClaudeDir\statusline-command.sh" -Force
Copy-Item "commands\*" "$ClaudeDir\commands\" -Force -Recurse
Copy-Item "dev-pipeline" "$ClaudeDir\dev-pipeline" -Recurse -Force
Copy-Item "skills\*" "$ClaudeDir\skills\" -Force -Recurse

claude mcp add context7 -s user -- npx -y @upstash/context7-mcp
claude mcp add shadcn-ui -s user -- npx -y shadcn@canary mcp
```

---

## 설치 후 확인

```bash
claude                       # Claude Code 실행
/develop 테스트 요구사항     # 파이프라인 동작 확인
claude mcp list              # MCP 서버 목록 확인
```

---

## 설정 상세 설명

### settings.json 주요 항목

| 항목 | 값 | 설명 |
|------|-----|------|
| `model` | `sonnet` | 기본 모델 |
| `autoUpdatesChannel` | `latest` | 자동 업데이트 채널 |
| `skipDangerousModePermissionPrompt` | `true` | 위험 모드 승인 생략 |
| `statusLine` | command | 상태 표시줄 (ctx%, 토큰, 모델) |
| `enabledPlugins` | bkit, telegram | 활성 플러그인 |
| `mcpServers` | playwright, sequential-thinking | 자동 로드 MCP |

### 플러그인

| 플러그인 | 기능 |
|---------|------|
| `bkit` | AI Native 개발 방법론 (PDCA, 에이전트팀) |
| `telegram` | Telegram 채널 연동 → `/telegram:configure` |

### MCP 서버

| MCP | 용도 | 등록 방법 |
|-----|------|---------|
| `context7` | 최신 라이브러리 문서 | setup 스크립트 자동 등록 |
| `shadcn-ui` | shadcn/ui 컴포넌트 레지스트리 | setup 스크립트 자동 등록 |
| `playwright` | E2E 브라우저 자동화 | settings.json 자동 로드 |
| `sequential-thinking` | 단계별 사고 보조 | settings.json 자동 로드 |

### 상태 표시줄

Claude Code 실행 시 상단에 표시:

```
my_project | claude-sonnet-4-6 | ctx:12% | tokens:45.2k
```

> Windows에서 상태 표시줄을 사용하려면 Git Bash가 PATH에 있어야 합니다.
> WSL2 환경에서는 별도 설정 없이 동작합니다.

---

## 커스텀 스킬 사용법

| 스킬 | 트리거 키워드 | 설명 |
|------|-------------|------|
| `context-check` | "컨텍스트 확인해줘" | 세션 컨텍스트 사용량 진단 |
| `git-commit-push` | "커밋해줘", "푸시해줘" | add → commit → push 자동화 |
| `lokuma` | UI/UX 작업 시 자동 | 디자인 인텔리전스 |
| `subagent-creator` | "서브에이전트 만들어줘" | Claude Agent SDK 에이전트 생성 |

---

## /develop 파이프라인 사용법

| 명령어 | 실행 단계 |
|--------|---------|
| `/develop 요구사항` | Git분석 → 계획 → 구현 → 테스트 → 리뷰 |
| `/develop :hotfix 요구사항` | 구현 → 테스트 |
| `/develop :refactor 요구사항` | Git분석 → 계획 → 구현 → 리뷰 |
| `/develop :plan 요구사항` | 설계 → Git분석 → 계획 → 구현 → 테스트 → 리뷰 |

---

## 설정 업데이트 방법

```bash
git pull
bash setup_mac.sh       # macOS
.\setup_windows.ps1     # Windows
```

기존 설정은 `.bak` 파일로 자동 백업됩니다.

---

## 체크리스트

- [ ] Node.js 18+ 설치
- [ ] Python 3.8+ 설치
- [ ] `bash setup_mac.sh` 또는 `.\setup_windows.ps1` 실행
- [ ] `claude` 실행 확인
- [ ] `claude mcp list`로 MCP 서버 확인
- [ ] `/develop 테스트` 동작 확인
- [ ] (선택) Telegram 연동: `/telegram:configure`
- [ ] (선택) bkit 사용: `/bkit`
- [ ] (선택) Lokuma 사용 시 `LOKUMA_API_KEY` 환경변수 설정
