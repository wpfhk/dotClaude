# Claude Code 설정 이식 가이드

새 컴퓨터(Mac / Windows)에 현재 Claude Code 설정을 그대로 옮기는 방법입니다.

---

## 포함된 파일

```
dotClaude/
├── settings.json                  # 전역 설정 (모델, 권한, 마켓플레이스 등)
├── commands/
│   └── develop.md                 # /develop 커스텀 슬래시 커맨드
├── dev-pipeline/                  # 자동화 개발 파이프라인 엔진
│   ├── agents/prompts/            # 각 역할 에이전트 시스템 프롬프트
│   │   ├── planner_lead.md
│   │   ├── coder_lead.md
│   │   ├── tester_lead.md
│   │   ├── architect_lead.md
│   │   ├── reviewer_lead.md
│   │   └── git_preanalyzer.md
│   ├── pipeline/                  # 파이프라인 상태 관리 Python 모듈
│   │   ├── __init__.py
│   │   ├── runner.py
│   │   ├── state.py
│   │   └── failure_memory.py
│   └── skills/                    # 에이전트별 운영 규칙
│       ├── code-reviewer/
│       ├── context-analyzer/
│       ├── failure-pattern/
│       ├── pipeline-orchestrator/
│       └── task-breaker/
├── skills/
│   ├── lokuma/                    # Lokuma 디자인 인텔리전스 스킬
│   │   ├── SKILL.md
│   │   └── scripts/design.py
│   └── subagent-creator/          # 서브에이전트 생성기 스킬
│       ├── SKILL.md
│       └── references/
├── setup_mac.sh                   # macOS 자동 설치 스크립트
├── setup_windows.ps1              # Windows 자동 설치 스크립트
└── SETUP_GUIDE.md                 # 이 파일
```

---

## 사전 요구사항

- **Node.js 18+** — Claude Code CLI 실행에 필요
- **Python 3.8+** — dev-pipeline 엔진 실행에 필요
- **Claude Code CLI** — `npm install -g @anthropic-ai/claude-code`

---

## 빠른 설치 (권장)

설치 스크립트가 Node.js / Python 확인 → Claude Code 설치 → 파일 복사 → 경로 치환을 자동으로 처리합니다.

### macOS

```bash
bash setup_mac.sh
```

### Windows (PowerShell, 관리자 권한)

```powershell
.\setup_windows.ps1
```

---

## 수동 설치

스크립트 없이 직접 설정하려면 아래 단계를 따르세요.

### macOS

```bash
mkdir -p ~/.claude/commands ~/.claude/skills

# 파일 복사
cp settings.json ~/.claude/settings.json
cp -r commands/. ~/.claude/commands/
cp -r dev-pipeline ~/.claude/dev-pipeline
cp -r skills/. ~/.claude/skills/

# Lokuma SKILL.md 경로 치환 (원본 경로를 현재 경로로)
sed -i '' 's|C:/Users/SMILE/.claude|~/.claude|g' ~/.claude/skills/lokuma/SKILL.md
```

### Windows (PowerShell)

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\commands"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills"

# 파일 복사
Copy-Item "settings.json" "$env:USERPROFILE\.claude\settings.json"
Copy-Item "commands\*" "$env:USERPROFILE\.claude\commands\" -Recurse -Force
Copy-Item "dev-pipeline" "$env:USERPROFILE\.claude\dev-pipeline" -Recurse -Force
Copy-Item "skills\*" "$env:USERPROFILE\.claude\skills\" -Recurse -Force

# Lokuma SKILL.md 경로 치환
$f = "$env:USERPROFILE\.claude\skills\lokuma\SKILL.md"
(Get-Content $f -Raw) -replace 'C:/Users/SMILE/.claude', "$env:USERPROFILE\.claude" |
  Set-Content $f -Encoding UTF8
```

---

## 설치 후 확인

```bash
claude          # Claude Code 실행
/develop 테스트  # 개발 파이프라인 동작 확인
```

Lokuma 스킬 사용 시 `LOKUMA_API_KEY` 환경변수가 필요합니다.

---

## /develop 파이프라인 템플릿

| 명령어 | 템플릿 | 스테이지 |
|--------|--------|---------|
| `/develop 요구사항` | standard | Git분석 → 계획 → 구현 → 테스트 → 리뷰 |
| `/develop :hotfix 요구사항` | hotfix | 구현 → 테스트 |
| `/develop :refactor 요구사항` | refactor | Git분석 → 계획 → 구현 → 리뷰 |
| `/develop :plan 요구사항` | plan | 설계 → Git분석 → 계획 → 구현 → 테스트 → 리뷰 |

---

## 요약 체크리스트

- [ ] `bash setup_mac.sh` 또는 `.\setup_windows.ps1` 실행
- [ ] `claude` 실행 확인
- [ ] `/develop 테스트 요구사항` 동작 확인
- [ ] (선택) Lokuma 사용 시 `LOKUMA_API_KEY` 환경변수 설정
