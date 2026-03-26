# dotClaude

Claude Code 전역 설정 및 커스텀 도구 모음입니다.

## 포함 항목

| 항목 | 설명 |
|------|------|
| `settings.json` | Claude Code 전역 설정 (모델: Sonnet, 마켓플레이스 등) |
| `commands/develop.md` | `/develop` — 계층적 자동화 개발 파이프라인 커맨드 |
| `dev-pipeline/` | Planner → Coder → Tester → Reviewer 파이프라인 엔진 |
| `skills/lokuma/` | Lokuma 디자인 인텔리전스 스킬 |
| `skills/subagent-creator/` | Claude Agent SDK 서브에이전트 생성기 스킬 |

## 빠른 설치

```bash
# macOS
bash setup_mac.sh

# Windows (PowerShell, 관리자 권한)
.\setup_windows.ps1
```

자세한 내용은 [SETUP_GUIDE.md](SETUP_GUIDE.md)를 참고하세요.

## /develop 사용법

프로젝트 디렉토리에서 Claude Code를 실행한 뒤:

```
/develop 로그인 기능을 추가해줘
/develop :hotfix 결제 버그 수정
/develop :plan 새로운 대시보드 설계
```

파이프라인은 Git 분석 → 기획 → 구현 → 테스트 → 리뷰 단계를 자동으로 진행하며,
테스트 실패 시 최대 3회까지 자동으로 재시도합니다.

## 요구사항

- Node.js 18+
- Python 3.8+
- Claude Code CLI (`npm install -g @anthropic-ai/claude-code`)
