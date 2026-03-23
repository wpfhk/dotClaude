# Failure Pattern — 실패 학습 메모리 운영 규칙

coder-lead, tester-lead가 **작업 시작 전 반드시** 읽는 파일입니다.

---

## 1. failure-patterns.json 읽기 조건

```
D:\.claude\dev-pipeline\failure-patterns.json 파일이 존재하는 경우에만 읽습니다.
파일이 없으면 이 단계를 완전히 스킵합니다. 오류를 발생시키지 마세요.
```

읽기 타이밍:
- **coder-lead:** Stage 2 시작 직후, core-developer에게 태스크를 할당하기 전
- **tester-lead:** Stage 3a 시작 직후, qa-validator 실행 전

---

## 2. 패턴 매칭 방법

현재 작업과 관련된 과거 실패 패턴을 식별합니다:

```
1. plan.json(또는 code_result.json)에서 현재 작업의 target_files 목록 추출
2. failure-patterns.json의 각 패턴의 affected_files와 교집합 확인
3. 교집합이 1개 이상인 패턴 = 관련 패턴
4. 관련 패턴을 에이전트에게 "사전 경고"로 전달
```

**매칭 예시:**
```
현재 target_files: ["pipeline/state.py", "pipeline/runner.py"]
패턴 affected_files: ["pipeline/state.py", "pipeline/orchestrator.py"]
교집합: ["pipeline/state.py"] → 관련 패턴으로 판정
```

---

## 3. 사전 경고 전달 형식

관련 패턴이 있으면 에이전트에게 다음 형식으로 전달하세요:

```
⚠️ 과거 실패 패턴 경고:
- [FP001] {description}
  근본 원인: {root_cause}
  해결 방법: {solution}
  관련 파일: {affected_files}
```

관련 패턴이 없으면 아무것도 전달하지 않습니다 (빈 섹션 표시 불필요).

---

## 4. record-failure 호출 조건

다음 조건이 **모두** 충족될 때만 호출합니다:

```
조건 1: test_result.json.status == "fail"
조건 2: 오케스트레이터가 iteration 카운터를 증가시키는 시점 (Stage 2 재진입 직전)
```

호출 명령:
```
python3 $CLAUDE_CONFIG_DIR/dev-pipeline/pipeline/runner.py record-failure {run_id}
```

> test가 pass인데 record-failure를 호출하거나, 매 반복마다 중복 호출하지 마세요.

---

## 5. failure-patterns.json 항목 스키마

```json
{
  "pattern_id": "FP0001",
  "description": "실패 상황 요약 (1~2문장)",
  "affected_files": ["관련 파일 경로"],
  "root_cause": "근본 원인 (기술적으로 명확하게)",
  "solution": "검증된 해결 방법",
  "stage": "coding|testing",
  "error_type": "syntax_error|import_error|test_failure|type_error|...",
  "occurrence_count": 1,
  "tags": ["python", "import", "circular"]
}
```

---

## 6. 동일 패턴 중복 기록 방지

`runner.py record-failure`는 내부적으로 중복을 처리하지만, 직접 JSON을 수정하는 경우:

```
1. 기존 패턴과 root_cause + error_type이 동일하면 → occurrence_count 증가 + last_seen 업데이트
2. 새로운 패턴이면 → 신규 항목 추가 (pattern_id는 FP + 4자리 순번)
3. pattern_id를 임의로 변경하거나 재사용하지 마세요.
```
