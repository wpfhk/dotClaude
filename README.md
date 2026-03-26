# my_claude_set

Claude Code 전역 설정 및 커스텀 도구 모음입니다. 새 컴퓨터에서 그대로 복원할 수 있습니다.

## 포함 항목

| 항목 | 설명 |
|------|------|
| `CLAUDE.md` | 전역 AI 행동 지침 — PDCA 규칙, 코드 품질 기준 |
| `settings.json` | Claude Code 전역 설정 — 모델, 플러그인, MCP, 상태 표시줄 |
| `statusline-command.sh` | 상태 표시줄 스크립트 (ctx%, 토큰, 모델명) |
| `commands/develop.md` | `/develop` — 계층적 자동화 개발 파이프라인 |
| `dev-pipeline/` | Planner → Coder → Tester → Reviewer 파이프라인 엔진 |
| `skills/context-check/` | 컨텍스트 윈도우 진단 스킬 |
| `skills/git-commit-push/` | Git add→commit→push 자동화 스킬 |
| `skills/lokuma/` | Lokuma 디자인 인텔리전스 스킬 |
| `skills/subagent-creator/` | Claude Agent SDK 서브에이전트 생성기 스킬 |
| `sync.sh` / `sync.ps1` | 글로벌 설정 자동 동기화 스크립트 |
| `sync.conf` | 동기화 대상/제외 설정 |

## 설정 동기화

글로벌 Claude Code 설정(`~/.claude/`)을 이 프로젝트에 자동 동기화합니다.

```bash
bash sync.sh              # 동기화 실행
bash sync.sh --dry-run    # 변경사항만 확인
bash sync.sh --install-cron  # 30분 자동 실행 등록
```

## 빠른 설치

```bash
# macOS
bash setup_mac.sh

# Windows (PowerShell, 관리자 권한)
.\setup_windows.ps1
```

자세한 내용은 [SETUP_GUIDE.md](SETUP_GUIDE.md)를 참고하세요.

## /develop 사용법

```
/develop 로그인 기능을 추가해줘
/develop :hotfix 결제 버그 수정
/develop :plan 새로운 대시보드 설계
```

Git 분석 → 계획 → 구현 → 테스트 → 리뷰 단계를 자동으로 진행합니다.

## 요구사항

- Node.js 18+
- Python 3.8+
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
