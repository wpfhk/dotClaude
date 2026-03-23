# /develop — 계층적 자동화 개발 파이프라인

당신은 **오케스트레이터(Orchestrator)**입니다. 아래 요구사항을 받아 Planner → Coder → Tester 팀 순으로 파이프라인을 실행하세요.

## 요구사항 (CMD)
$ARGUMENTS

---

## Bash 명령어 실행 규칙

Bash 명령어를 실행할 때 `cd`와 `git` 등 여러 명령어를 `&&`로 묶는 Compound command를 사용하지 마세요.
대신 작업 디렉토리로 먼저 이동하거나, 각 명령어를 개별적으로 실행하세요.
이렇게 해야 사용자의 승인 요청 없이 파이프라인이 중단 없이 진행됩니다.

```
# 금지
cd /path/to/project && git status

# 허용
cd /path/to/project
git status
```

---

## 실행 전 준비

1. `python3 $CLAUDE_CONFIG_DIR/dev-pipeline/pipeline/runner.py init "$ARGUMENTS"` 를 실행하여 실행 ID(run_id)와 초기 상태 파일을 생성하세요.
2. 출력된 `run_id`를 기억하고 이후 모든 단계에서 사용하세요.
3. `.pipeline/runs/{run_id}/` 디렉토리는 **현재 작업 중인 프로젝트 디렉토리**에 생성됩니다.

---

## Stage 1: Planner Team

**목표:** 요구사항을 분석하고 구체적인 작업 지시서(Plan Document)를 생성합니다.

Agent 도구로 `planner-lead` 에이전트를 다음 설정으로 실행하세요:

```
description: "요구사항 전체를 분석하고 개발 마일스톤을 수립하는 수석 플래너"
allowed_tools: ["Read", "Glob", "Grep", "Write", "Bash", "Agent"]
subagents:
  - context-analyzer: 코드베이스 구조·의존성·파일 관계를 분석
  - task-breaker: 기능을 원자 단위 작업 지시서로 분할
```

플래너 에이전트에게 다음 지시를 전달하세요:
- `$CLAUDE_CONFIG_DIR/dev-pipeline/agents/prompts/planner_lead.md` 파일의 시스템 프롬프트를 읽어 역할 파악
- `context-analyzer` 서브에이전트를 호출하여 현재 프로젝트 코드베이스 분석 수행
- `task-breaker` 서브에이전트를 호출하여 작업 분할 수행
- 결과를 `.pipeline/runs/{run_id}/plan.json` 에 저장

Plan 완료 후 `python3 $CLAUDE_CONFIG_DIR/dev-pipeline/pipeline/runner.py advance {run_id} planning` 실행.

---

## Stage 2: Coder Team

**목표:** Plan Document를 바탕으로 실제 코드 변경을 수행합니다.

`.pipeline/runs/{run_id}/plan.json` 을 읽어 Agent 도구로 `coder-lead` 에이전트를 실행:

```
description: "플래너 지시서를 받아 코드 구현을 총괄하는 수석 개발자"
allowed_tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent"]
subagents:
  - core-developer: 핵심 비즈니스 로직 작성·파일 수정
  - refactor-formatter: 컨벤션 적용·주석·코드 최적화
```

코더 에이전트에게 다음 지시를 전달하세요:
- `$CLAUDE_CONFIG_DIR/dev-pipeline/agents/prompts/coder_lead.md` 파일의 시스템 프롬프트를 읽어 역할 파악
- plan.json의 각 태스크를 `core-developer`에게 병렬 할당
- 구현 완료 후 `refactor-formatter`로 코드 정리
- 변경된 파일 목록과 요약을 `.pipeline/runs/{run_id}/code_result.json` 에 저장

Code 완료 후 `python3 $CLAUDE_CONFIG_DIR/dev-pipeline/pipeline/runner.py advance {run_id} coding` 실행.

---

## Stage 3: Tester Team

**목표:** 구현된 코드의 품질과 안정성을 검증합니다.

`.pipeline/runs/{run_id}/code_result.json` 을 읽어 Agent 도구로 `tester-lead` 에이전트를 실행:

```
description: "코드 품질·테스트·보안을 책임지는 수석 QA 엔지니어"
allowed_tools: ["Read", "Bash", "Glob", "Grep", "Write", "Agent"]
subagents:
  - qa-validator: 단위 테스트 작성 및 로컬 테스트 스크립트 실행
  - security-auditor: 보안 취약점·하드코딩 시크릿 정적 분석
```

테스터 에이전트에게 다음 지시를 전달하세요:
- `$CLAUDE_CONFIG_DIR/dev-pipeline/agents/prompts/tester_lead.md` 파일의 시스템 프롬프트를 읽어 역할 파악
- `qa-validator`와 `security-auditor`를 병렬로 실행
- 결과를 `.pipeline/runs/{run_id}/test_result.json` 에 저장 (status: "pass" | "fail")

Test 완료 후 `python3 $CLAUDE_CONFIG_DIR/dev-pipeline/pipeline/runner.py advance {run_id} testing` 실행.

---

## 피드백 루프

`test_result.json`의 `status`를 확인하세요:

- **"pass"** → `python3 $CLAUDE_CONFIG_DIR/dev-pipeline/pipeline/runner.py complete {run_id}` 실행 후 최종 결과 보고
- **"fail"** →
  1. `iteration` 카운터를 확인하세요 (최대 3회)
  2. 3회 미만이면: `.pipeline/runs/{run_id}/test_result.json`의 `feedback`을 Coder Lead에게 전달하여 **Stage 2**부터 재실행
  3. 3회 초과이면: `python3 $CLAUDE_CONFIG_DIR/dev-pipeline/pipeline/runner.py fail {run_id}` 실행 후 실패 보고

---

## 최종 보고

파이프라인 완료 시 다음 형식으로 사용자에게 보고하세요:

```
## ✅ 개발 파이프라인 완료

**Run ID:** {run_id}
**요구사항:** {requirements}
**반복 횟수:** {iteration}

### Planner 결과
- 분석된 태스크 수: N개
- 주요 마일스톤: ...

### Coder 결과
- 수정된 파일: ...
- 주요 변경사항: ...

### Tester 결과
- 테스트 통과: N/M
- 보안 이슈: 없음 / N건
```
