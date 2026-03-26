# Plan: settings-auto-sync v0.0.1

**Feature**: Claude Code 전역 설정 자동 동기화
**Created**: 2026-03-26
**Status**: Draft

---

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | settings-auto-sync |
| Created | 2026-03-26 |
| Duration | 1 session |

| 관점 | 내용 |
|------|------|
| **Problem** | 글로벌 Claude Code 설정 변경 시 수동으로 프로젝트에 복사·커밋·푸시해야 함 |
| **Solution** | diff 기반 변경 감지 → 선택적 복사 → 자동 커밋·푸시 스크립트 |
| **Function UX Effect** | 한 줄 명령 또는 30분 주기 자동 실행으로 설정 동기화 완료 |
| **Core Value** | 여러 컴퓨터 간 설정 일관성 유지, 수동 작업 제거 |

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 글로벌 설정 변경이 프로젝트에 자동 반영되지 않아 수동 동기화 필요 |
| **WHO** | Claude Code를 여러 컴퓨터에서 사용하는 개발자 |
| **RISK** | 런타임 파일(캐시, 세션) 혼입, 불필요한 빈 커밋, 경로 하드코딩 |
| **SUCCESS** | 변경 감지 → 동기화 → 커밋 → 푸시가 무인으로 동작 |
| **SCOPE** | sync 스크립트 (bash+ps1), 수동/자동 실행, .gitignore 업데이트 |

---

## 1. Requirements

### 1.1 Functional Requirements

| ID | 요구사항 | 우선순위 |
|----|---------|---------|
| FR-01 | `~/.claude/` 내 대상 파일과 프로젝트 파일의 diff를 감지 | Must |
| FR-02 | 변경된 파일만 프로젝트에 복사 (덮어쓰기) | Must |
| FR-03 | 복사 후 git add → commit → push 자동 실행 | Must |
| FR-04 | 수동 실행: `bash sync.sh` 또는 `.\sync.ps1` | Must |
| FR-05 | 자동 실행: 30분 주기 cron/Task Scheduler 등록 가능 | Should |
| FR-06 | 동기화 대상/제외 패턴을 설정 파일로 관리 | Should |
| FR-07 | 변경 없을 시 커밋 생략 (빈 커밋 방지) | Must |
| FR-08 | 동기화 로그 출력 (어떤 파일이 변경되었는지) | Should |

### 1.2 Non-Functional Requirements

| ID | 요구사항 |
|----|---------|
| NFR-01 | Mac/Windows 크로스플랫폼 지원 (bash + PowerShell) |
| NFR-02 | 외부 의존성 없음 (bash, git, diff만 사용) |
| NFR-03 | 실행 시간 10초 이내 |

### 1.3 Sync Target Files

| 대상 | 소스 경로 (글로벌) | 프로젝트 경로 |
|------|-------------------|-------------|
| CLAUDE.md | `~/.claude/CLAUDE.md` | `CLAUDE.md` |
| settings.json | `~/.claude/settings.json` | `settings.json` |
| statusline-command.sh | `~/.claude/statusline-command.sh` | `statusline-command.sh` |
| commands/ | `~/.claude/commands/` | `commands/` |
| skills/ | `~/.claude/skills/` | `skills/` |
| dev-pipeline/ | `~/.claude/dev-pipeline/` | `dev-pipeline/` |

### 1.4 Exclusion Patterns

| 제외 대상 | 이유 |
|----------|------|
| `~/.claude/cache/` | 런타임 캐시 |
| `~/.claude/sessions/` | 세션 상태 |
| `~/.claude/history.jsonl` | 대화 히스토리 |
| `~/.claude/plugins/` | 플러그인 런타임 (마켓에서 자동 설치) |
| `~/.claude/projects/` | 프로젝트별 설정 |
| `~/.claude/agent-memory/` | 에이전트 메모리 |
| `~/.claude/shell-snapshots/` | 셸 스냅샷 |
| `~/.claude/ide/` | IDE 설정 |
| `~/.claude/file-history/` | 파일 히스토리 |
| `~/.claude/tasks/` | 태스크 상태 |
| `~/.claude/teams/` | 팀 상태 |
| `~/.claude/backups/` | 백업 |
| `*/__pycache__/` | Python 캐시 |
| `*.bak` | 백업 파일 |

---

## 2. Success Criteria

| ID | 기준 | 측정 방법 |
|----|------|---------|
| SC-01 | 글로벌 설정 변경 후 sync 실행 시 프로젝트에 반영 | diff 결과 0 |
| SC-02 | 변경 없을 때 빈 커밋 생성 안 됨 | git log 확인 |
| SC-03 | Mac에서 `bash sync.sh` 정상 동작 | 실행 테스트 |
| SC-04 | Windows에서 `.\sync.ps1` 정상 동작 | 실행 테스트 |
| SC-05 | 제외 대상 파일이 프로젝트에 복사되지 않음 | 파일 존재 확인 |

---

## 3. Risks

| Risk | 영향 | 완화 |
|------|------|------|
| 런타임 파일 혼입 | 불필요한 대용량 파일 커밋 | 제외 패턴 명확히 정의 |
| 원격 충돌 | push 실패 | pull --rebase 후 재시도 |
| 경로 하드코딩 | 다른 사용자 환경에서 실패 | $HOME 변수 사용 |
| cron 중복 실행 | 동시 커밋 충돌 | lock 파일 메커니즘 |

---

## 4. Implementation Scope

### 4.1 New Files

| 파일 | 용도 |
|------|------|
| `sync.sh` | Mac/Linux 동기화 스크립트 |
| `sync.ps1` | Windows 동기화 스크립트 |
| `sync.conf` | 동기화 대상/제외 설정 파일 |

### 4.2 Modified Files

| 파일 | 변경 내용 |
|------|---------|
| `.gitignore` | `.bkit/`, `__pycache__/` 등 제외 패턴 추가 |
| `README.md` | sync 스크립트 사용법 추가 |
| `SETUP_GUIDE.md` | 자동 동기화 설정 가이드 추가 |
