# Design: settings-auto-sync v0.0.1

**Feature**: Claude Code 전역 설정 자동 동기화
**Created**: 2026-03-26
**Status**: Draft
**Plan**: `docs/01-plan/features/settings-auto-sync.plan-v0.0.1.md`

---

## 1. Architecture Overview

### 1.1 스크립트 실행 흐름

```
┌─────────────────────────────────────────────────────────┐
│                    sync.sh / sync.ps1                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────┐   │
│  │ 1. Init  │───▶│ 2. Lock  │───▶│ 3. Load Config   │   │
│  │ parse    │    │ acquire  │    │ (sync.conf)      │   │
│  │ flags    │    │          │    │                  │   │
│  └──────────┘    └──────────┘    └────────┬─────────┘   │
│                                           │             │
│  ┌──────────────────────────────────────┐ │             │
│  │ 4. Diff & Copy                      │◀┘             │
│  │                                      │               │
│  │  for each SYNC_TARGET:               │               │
│  │    ~/.claude/{target}                │               │
│  │         ↓ diff                       │               │
│  │    project/{target}                  │               │
│  │         ↓ changed? → cp             │               │
│  └──────────────┬───────────────────────┘               │
│                 │                                       │
│  ┌──────────────▼───────────────────────┐               │
│  │ 5. Git Operations                    │               │
│  │                                      │               │
│  │  changes? ─No──▶ "No changes" exit  │               │
│  │    │Yes                              │               │
│  │    ├─▶ git add -A                   │               │
│  │    ├─▶ git commit -m "..."          │               │
│  │    └─▶ git push origin {branch}     │               │
│  └──────────────┬───────────────────────┘               │
│                 │                                       │
│  ┌──────────────▼──────┐                                │
│  │ 6. Cleanup          │                                │
│  │  release lock       │                                │
│  │  print summary      │                                │
│  └─────────────────────┘                                │
└─────────────────────────────────────────────────────────┘
```

### 1.2 파일 구조

```
my_claude_set/
├── sync.sh          # Bash 동기화 스크립트 (Mac/Linux)
├── sync.ps1         # PowerShell 동기화 스크립트 (Windows)
├── sync.conf        # 동기화 설정 파일
└── .gitignore       # (수정) 제외 패턴 추가
```

---

## 2. sync.conf 명세

### 2.1 포맷

`KEY=VALUE` 형식. 리스트는 공백 구분. `#`으로 시작하는 줄은 주석.

### 2.2 전체 설정

```conf
# ── Sync Targets ──────────────────────────────────────
# ~/.claude/ 아래의 동기화 대상 (공백 구분)
SYNC_TARGETS="CLAUDE.md settings.json statusline-command.sh commands skills dev-pipeline"

# ── Exclude Patterns ──────────────────────────────────
# rsync/diff 제외 패턴 (공백 구분, glob 지원)
SYNC_EXCLUDES="__pycache__ *.bak *.tmp .DS_Store"

# ── Git Settings ──────────────────────────────────────
REMOTE_BRANCH="main"
COMMIT_PREFIX="sync"

# ── Source Directory ──────────────────────────────────
# 동기화 소스 디렉토리 (기본값: ~/.claude)
SOURCE_DIR="$HOME/.claude"
```

### 2.3 필드 설명

| Key | Type | Default | 설명 |
|-----|------|---------|------|
| `SYNC_TARGETS` | space-separated list | (필수) | `SOURCE_DIR` 하위 동기화 대상 경로 |
| `SYNC_EXCLUDES` | space-separated list | `""` | 제외할 glob 패턴 |
| `REMOTE_BRANCH` | string | `"main"` | git push 대상 브랜치 |
| `COMMIT_PREFIX` | string | `"sync"` | 커밋 메시지 접두사. `sync: update settings` 형태 |
| `SOURCE_DIR` | path | `"$HOME/.claude"` | 동기화 소스 디렉토리 |

---

## 3. sync.sh 상세 설계

### 3.1 함수 목록

| 함수 | 역할 |
|------|------|
| `main` | 엔트리포인트. 플래그 파싱 → lock → load_config → sync → git → unlock |
| `parse_args` | `--dry-run`, `--install-cron`, `--help` 플래그 처리 |
| `acquire_lock` | `.sync.lock` 파일 생성. PID 기록. 기존 lock이 있으면 PID 활성 여부 확인 |
| `release_lock` | `.sync.lock` 파일 삭제. trap으로 비정상 종료 시에도 실행 |
| `load_config` | `sync.conf` 파싱. 미존재 시 에러 종료 |
| `sync_targets` | 각 타겟에 대해 diff 비교 → 변경 시 복사. 변경 파일 수 반환 |
| `diff_and_copy` | 단일 타겟의 diff 비교 및 복사. 파일/디렉토리 자동 판별 |
| `is_excluded` | 경로가 SYNC_EXCLUDES 패턴에 매칭되는지 확인 |
| `git_commit_push` | git add → commit → push. 변경 없으면 스킵 |
| `install_cron` | crontab에 30분 주기 엔트리 추가 |
| `log_info` / `log_warn` / `log_error` | 로그 출력 유틸리티 (타임스탬프 포함) |

### 3.2 실행 흐름 의사코드

```bash
main() {
    parse_args "$@"

    # --install-cron 처리 후 종료
    if [[ "$INSTALL_CRON" == true ]]; then
        install_cron
        exit 0
    fi

    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    cd "$SCRIPT_DIR"

    acquire_lock
    trap release_lock EXIT

    load_config

    changed_count=0
    changed_files=()

    for target in $SYNC_TARGETS; do
        diff_and_copy "$SOURCE_DIR/$target" "$SCRIPT_DIR/$target"
    done

    if [[ $changed_count -eq 0 ]]; then
        log_info "No changes detected. Skipping commit."
        exit 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would commit ${changed_count} file(s)"
        exit 0
    fi

    git_commit_push
}
```

### 3.3 핵심 함수 상세

#### `diff_and_copy(source, dest)`

```
1. source 존재 확인 → 없으면 warn 후 skip
2. source가 디렉토리인 경우:
   a. source 내 모든 파일을 재귀 순회
   b. 각 파일에 대해 is_excluded 확인
   c. diff -q로 비교 → 다르면 cp (디렉토리 구조 유지)
   d. dest에만 있는 파일은 유지 (삭제하지 않음)
3. source가 파일인 경우:
   a. is_excluded 확인
   b. diff -q로 비교 → 다르면 cp
4. 변경된 파일 경로를 changed_files에 추가
```

#### `acquire_lock()`

```
LOCK_FILE="$SCRIPT_DIR/.sync.lock"
1. LOCK_FILE 존재 확인
2. 존재 시 → 기록된 PID로 kill -0 확인
   a. 프로세스 살아있으면 → "Already running (PID: xxx)" 에러 종료
   b. 프로세스 없으면 → stale lock, 삭제 후 계속
3. 현재 PID를 LOCK_FILE에 기록
```

#### `install_cron()`

```
1. 기존 crontab에서 sync.sh 엔트리 검색
2. 이미 있으면 → "Already installed" 메시지 후 종료
3. 없으면 → 아래 엔트리 추가:
   */30 * * * * cd {SCRIPT_DIR} && bash sync.sh >> /tmp/claude-sync.log 2>&1
4. 등록 확인 메시지 출력
```

#### `git_commit_push()`

```
1. git add -A
2. git status --porcelain 확인 → 비어있으면 스킵
3. 변경된 파일 목록으로 커밋 메시지 생성:
   "{COMMIT_PREFIX}: update {파일목록_요약}"
   예: "sync: update CLAUDE.md, settings.json"
4. git commit -m "{message}"
5. git pull --rebase origin {REMOTE_BRANCH}  (충돌 방지)
6. git push origin {REMOTE_BRANCH}
7. push 실패 시 → 에러 로그 출력, exit 1
```

---

## 4. sync.ps1 상세 설계

### 4.1 함수 목록

| 함수 | 역할 |
|------|------|
| `Main` | 엔트리포인트 |
| `Get-Lock` / `Remove-Lock` | 뮤텍스 기반 lock 관리 |
| `Import-SyncConfig` | sync.conf 파싱 |
| `Sync-Targets` | 각 타겟 diff & copy |
| `Compare-And-Copy` | 단일 타겟 비교 및 복사 |
| `Test-Excluded` | 제외 패턴 매칭 |
| `Invoke-GitCommitPush` | git 자동화 |
| `Install-TaskScheduler` | Windows 작업 스케줄러 등록 |
| `Write-Log` | 로그 출력 유틸리티 |

### 4.2 PowerShell 매개변수

```powershell
param(
    [switch]$DryRun,
    [switch]$InstallTask,    # --install-cron에 대응
    [switch]$Help
)
```

### 4.3 핵심 차이점 (Bash와의 분기)

| 항목 | sync.sh (Bash) | sync.ps1 (PowerShell) |
|------|---------------|----------------------|
| Diff 도구 | `diff -q` | `Compare-Object` + `Get-FileHash` |
| Lock | PID 파일 + `kill -0` | .lock 파일 + `Get-Process` |
| Cron 등록 | `crontab -e` | `schtasks /Create` |
| 경로 구분자 | `/` | `Join-Path` (자동 `\`) |
| 소스 경로 | `$HOME/.claude` | `$env:USERPROFILE\.claude` |
| Exclude 매칭 | bash glob (`[[ $f == $pattern ]]`) | `-like` 연산자 |

### 4.4 Install-TaskScheduler 설계

```
1. schtasks /Query로 기존 태스크 확인 (이름: "ClaudeSettingsSync")
2. 이미 있으면 → 메시지 후 종료
3. 없으면:
   schtasks /Create /SC MINUTE /MO 30 /TN "ClaudeSettingsSync" `
     /TR "powershell -ExecutionPolicy Bypass -File {ScriptPath}\sync.ps1" `
     /F
4. 등록 확인 메시지 출력
```

---

## 5. 에러 처리 전략

### 5.1 에러 분류 및 대응

| 에러 유형 | 감지 방법 | 대응 |
|----------|----------|------|
| sync.conf 없음 | 파일 존재 확인 | 에러 메시지 출력 후 exit 1 |
| SOURCE_DIR 없음 | 디렉토리 존재 확인 | 에러 메시지 출력 후 exit 1 |
| 타겟 파일 없음 | 파일 존재 확인 | warn 출력, 해당 타겟 skip |
| git 미설치 | `command -v git` | 에러 메시지 출력 후 exit 1 |
| git repo 아님 | `git rev-parse` | 에러 메시지 출력 후 exit 1 |
| Lock 충돌 | PID 활성 확인 | 에러 메시지 출력 후 exit 1 |
| Stale lock | PID 비활성 확인 | lock 삭제 후 계속 |
| push 실패 | exit code 확인 | pull --rebase 후 재시도 1회 |
| rebase 충돌 | exit code 확인 | rebase --abort, 에러 로그 출력 후 exit 1 |

### 5.2 Exit Codes

| Code | 의미 |
|------|------|
| 0 | 성공 (동기화 완료 또는 변경 없음) |
| 1 | 일반 에러 (설정 오류, 필수 도구 없음) |
| 2 | Lock 충돌 (다른 인스턴스 실행 중) |
| 3 | Git 에러 (push/rebase 실패) |

### 5.3 Trap 및 정리

```bash
# sync.sh
trap 'release_lock; log_error "Interrupted"; exit 1' INT TERM
trap 'release_lock' EXIT
```

```powershell
# sync.ps1
try { ... }
finally { Remove-Lock }
```

---

## 6. Cron / Task Scheduler 통합

### 6.1 Mac/Linux (cron)

```
명령: sync.sh --install-cron
등록: */30 * * * * cd /path/to/my_claude_set && bash sync.sh >> /tmp/claude-sync.log 2>&1
해제: crontab에서 수동 삭제 (안내 메시지 출력)
로그: /tmp/claude-sync.log (append 모드)
```

### 6.2 Windows (Task Scheduler)

```
명령: .\sync.ps1 -InstallTask
태스크명: ClaudeSettingsSync
주기: 30분
실행: powershell -ExecutionPolicy Bypass -File {path}\sync.ps1
해제: schtasks /Delete /TN "ClaudeSettingsSync" /F
```

---

## 7. 구현 가이드

### 7.1 구현 파일 및 순서

| 순서 | 파일 | 작업 | 예상 규모 |
|------|------|------|----------|
| 1 | `sync.conf` | 설정 파일 생성 | ~15줄 |
| 2 | `sync.sh` | Bash 동기화 스크립트 | ~200줄 |
| 3 | `sync.ps1` | PowerShell 동기화 스크립트 | ~200줄 |
| 4 | `.gitignore` | `.sync.lock`, `.bkit/` 등 추가 | 수정 |

### 7.2 sync.sh 구현 순서

1. 스크립트 헤더 (`set -euo pipefail`, 상수 정의)
2. 로그 유틸리티 (`log_info`, `log_warn`, `log_error`)
3. `parse_args` → `--dry-run`, `--install-cron`, `--help`
4. `acquire_lock` / `release_lock` + trap 설정
5. `load_config` (sync.conf 파싱)
6. `is_excluded` (패턴 매칭)
7. `diff_and_copy` (단일 타겟 비교 및 복사)
8. `sync_targets` (전체 타겟 순회)
9. `git_commit_push` (git 자동화)
10. `install_cron` (cron 등록)
11. `main` (조합)

### 7.3 sync.ps1 구현 순서

sync.sh와 동일한 순서. PowerShell 관용구로 변환:
- `diff` → `Compare-Object` + `Get-FileHash`
- glob 매칭 → `-like` 연산자
- trap → `try/finally`
- crontab → `schtasks`

### 7.4 테스트 체크리스트

| # | 테스트 | 방법 |
|---|--------|------|
| 1 | 변경 파일 감지 및 복사 | 글로벌 설정 수정 후 `bash sync.sh --dry-run` |
| 2 | 변경 없을 때 스킵 | 동기화 후 재실행, "No changes" 확인 |
| 3 | 제외 패턴 동작 | `__pycache__/` 생성 후 동기화, 복사 안 됨 확인 |
| 4 | Lock 충돌 방지 | 두 터미널에서 동시 실행, 하나 거부 확인 |
| 5 | --dry-run | 실행 후 git log 변화 없음 확인 |
| 6 | --install-cron | `crontab -l`로 등록 확인 |
| 7 | Commit 메시지 형식 | `git log -1`으로 `sync: update ...` 확인 |
| 8 | Push 실패 복구 | 원격 변경 후 sync 실행, rebase 동작 확인 |
