# Pipeline Orchestrator — 오케스트레이터 운영 규칙

develop.md를 실행하는 오케스트레이터가 **작업 시작 전 반드시** 읽는 파일입니다.

---

## 1. 템플릿 분기 판단 기준

| 템플릿 | 트리거 키워드 | 스테이지 |
|--------|-------------|---------|
| `hotfix` | `:hotfix`, "버그 수정", "빠른 수정", "긴급 패치" | Coder → Tester |
| `refactor` | `:refactor`, "리팩토링", "코드 정리", "구조 개선" | Git-Analyzer → Planner → Coder → Reviewer |
| `plan` | `:plan`, "새 기능 설계", "신규 프로젝트", "처음부터", "아키텍처 설계" | Architect → Git-Analyzer → Planner → Coder → Tester → Reviewer |
| `standard` | 위 키워드 없음 (기본값) | Git-Analyzer → Planner → Coder → Tester → Reviewer |

> 키워드가 여러 개 감지되면 **더 구체적인 템플릿 우선** (hotfix > refactor > plan > standard)

---

## 2. runner.py advance 호출 타이밍

- **각 stage 완료 직후에만** 호출합니다.
- 에이전트가 결과 파일을 저장한 것을 확인한 뒤 호출하세요.
- 호출 형식: `python3 $CLAUDE_CONFIG_DIR/dev-pipeline/pipeline/runner.py advance {run_id} {stage_name}`

| stage_name | 호출 시점 |
|-----------|---------|
| `architecting` | spec.json 저장 완료 후 |
| `git_analyzing` | git_context.json 저장 완료 후 |
| `planning` | plan.json 저장 완료 후 |
| `coding` | code_result.json 저장 완료 후 |
| `testing` | test_result.json 저장 완료 후 |
| `reviewing` | review_result.json 저장 완료 후 |

---

## 3. run_id 규칙

- `runner.py init` 명령의 **stdout 출력값을 그대로** 사용합니다.
- **절대 임의 생성 금지.** 추측하거나 날짜를 직접 조합하지 마세요.
- run_id를 잃어버린 경우: `runner.py list` 로 최근 실행 목록에서 확인하세요.

---

## 4. 피드백 루프 재진입 조건

```
test_result.json.status == "fail"
  └─ state.iteration < 3  → Stage 2(Coder) 재실행 + record-failure 호출
  └─ state.iteration >= 3 → runner.py fail {run_id} 호출 후 중단

review_result.json.status == "changes_required"
  └─ critical 이슈 목록을 Coder Lead에게 전달 → Stage 2 재실행
  └─ iteration 카운터는 test fail 시에만 증가 (review 재실행은 별도 카운트 없음)

test == "pass" AND review == "approved" 또는 "approved_with_comments"
  └─ runner.py complete {run_id} 호출 후 최종 보고
```

---

## 5. Stage 3a/3b 병렬 실행 (standard, plan 템플릿)

- `standard`, `plan` 템플릿에서 **Tester(3a)와 Reviewer(3b)는 반드시 동시에** Agent로 실행합니다.
- 단일 메시지에서 두 Agent 호출을 함께 발행하세요.
- 둘 다 완료된 뒤 결과를 취합하여 피드백 루프 판단을 수행합니다.

---

## 6. 각 Stage 시작 전 입력 파일 확인

Stage를 시작하기 전 해당 stage가 필요로 하는 입력 파일의 존재 여부를 확인하세요.
파일이 없으면 이전 stage가 완료되지 않은 것이므로 **진행을 중단**하고 사용자에게 보고합니다.

| Stage | 필수 입력 파일 |
|-------|-------------|
| git_analyzing | (없음 — git repo 여부만 확인) |
| planning | git_context.json (없으면 경고만, 진행은 가능) |
| coding | plan.json |
| testing | code_result.json |
| reviewing | code_result.json |
| 피드백 루프 | test_result.json, review_result.json |

---

## 7. 에이전트 모델 자동 할당

에이전트를 생성할 때 **작업 난이도와 양**에 따라 아래 기준으로 모델을 자동 선택합니다.
각 Stage 시작 시 사용된 모델과 선택 이유를 **반드시 사용자에게 보고**합니다.

### 모델 선택 기준

| 모델 | 사용 조건 |
|------|---------|
| `opus` | 전체 아키텍처 설계 / 복잡한 다중 의존성 플래닝 / 10개 이상 파일 수정 / `plan` 템플릿의 Architect Lead · Planner Lead |
| `sonnet` | 표준 기능 구현 / 단위 테스트 작성 / 코드 리뷰 리드 / 3~9개 파일 수정 / `hotfix` · `standard` · `refactor` 템플릿의 Lead 에이전트 |
| `haiku` | 단순 탐색·검색 / 코드 포맷팅 / 정적 분석 패턴 매칭 / 1~2개 파일 수정 / 모든 서브에이전트 (context-analyzer, refactor-formatter, security-auditor, qa-validator, task-breaker 등) |

> **원칙:** Lead 에이전트는 sonnet 이상, 서브에이전트는 haiku 우선.
> plan 템플릿의 설계·기획 단계 Lead만 opus로 승격.

### 보고 형식 (각 Stage 시작 시 출력)

```
## Stage N: {stage명} [{현재}/{전체} 스테이지]
├─ {lead-에이전트명} — 모델: {opus|sonnet} | 이유: {선택 근거}
├─ {서브에이전트명} — 모델: {haiku|sonnet} | 이유: {선택 근거}
└─ {서브에이전트명} — 모델: {haiku|sonnet} | 이유: {선택 근거}
```

예시:
```
## Stage -1: Architect [1/6 스테이지]
├─ architect-lead     — 모델: opus   | 이유: 전체 시스템 아키텍처 설계 (plan 템플릿, 신규 프로젝트)
├─ context-analyzer   — 모델: haiku  | 이유: 읽기 전용 코드베이스 탐색, 단순 분석
└─ task-breaker       — 모델: haiku  | 이유: 태스크 구조화, 단순 분해 작업

## Stage 2: Coder [3/5 스테이지]
├─ coder-lead         — 모델: sonnet | 이유: 표준 기능 구현 총괄, 5개 파일 수정 예상
├─ core-developer #1  — 모델: haiku  | 이유: 단일 파일 수정 (API 라우터)
└─ refactor-formatter — 모델: haiku  | 이유: 코드 포맷팅·컨벤션 적용
```

### 최종 보고에 모델 사용 현황 포함

최종 보고의 각 Stage 결과 섹션에 사용된 모델을 아래 형식으로 명시합니다:
```
- 사용 모델: architect-lead(opus), context-analyzer(haiku), task-breaker(haiku)
```
