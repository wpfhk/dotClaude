# Code Reviewer — 코드 리뷰 운영 규칙

reviewer-lead, architecture-reviewer, quality-reviewer가 **작업 시작 전 반드시** 읽는 파일입니다.

---

## 1. 판정 기준

| 판정 | 조건 |
|------|------|
| `approved` | critical 이슈 0개 **AND** major 이슈 0개 |
| `approved_with_comments` | critical 0개, major 0개, minor 이슈만 존재 |
| `changes_required` | critical 이슈 1개 이상 **OR** major 이슈 1개 이상 |

> minor만 있어도 `approved_with_comments`이지 `changes_required`가 아닙니다.
> 판정 기준을 임의로 완화하거나 강화하지 마세요.

---

## 2. 이슈 심각도 정의

### critical — 즉시 재작업 필요
- 런타임 오류 가능성 (NullPointerException, KeyError, 타입 불일치 등)
- 보안 취약점 (하드코딩 시크릿, SQL 인젝션, 인증 누락 등)
- 요구사항 미구현 (spec.json 또는 plan.json에 명시된 기능이 없음)
- 무한 루프·데드락 가능성

### major — 다음 이터레이션 전 수정 권고
- 심각한 성능 저하 (N+1 쿼리, 불필요한 전체 스캔 등)
- 의존성 방향 위반 (상위 레이어가 하위 레이어를 직접 참조 등)
- 중복 로직 과다 (동일 코드 3곳 이상 반복)
- 단일 책임 원칙 심각 위반 (함수 100줄 초과, 5개 이상의 역할 수행)

### minor — 개선 권고 (기능 영향 없음)
- 네이밍 불명확 (변수명이 의도를 전달하지 못함)
- 주석 누락 (복잡한 로직에 설명 없음)
- 스타일 불일치 (기존 코드와 다른 컨벤션)
- 매직 넘버/문자열 하드코딩

### info — 참고용 제안
- 대안 구현 방식 소개
- 향후 개선 아이디어

---

## 3. review_result.json 출력 스키마

```json
{
  "status": "approved|approved_with_comments|changes_required",
  "verdict": "한 줄 판정 요약",
  "critical_count": 0,
  "major_count": 1,
  "minor_count": 3,
  "info_count": 2,
  "issues": [
    {
      "severity": "critical|major|minor|info",
      "category": "runtime|security|completeness|performance|architecture|naming|duplication|style|other",
      "file": "파일 경로",
      "line": 42,
      "description": "이슈 설명 (구체적으로)",
      "suggestion": "개선 방법 (코드 스니펫 포함 권장)"
    }
  ],
  "positive_findings": [
    "잘 된 점 (반드시 1개 이상 포함)"
  ],
  "completeness_check": {
    "applicable": true,
    "features_implemented": ["구현 완료 기능"],
    "features_missing": ["누락 기능 (있는 경우)"]
  },
  "next_iteration_recommendations": [
    "다음 이터레이션에서 개선할 사항"
  ]
}
```

---

## 4. architecture-reviewer와 quality-reviewer 병렬 실행

두 서브에이전트는 **반드시 동시에** 실행합니다. 순차 실행 금지.

| 에이전트 | 담당 범위 |
|---------|---------|
| `architecture-reviewer` | 의존성 방향, 레이어 분리, 모듈 위치, 순환 의존 |
| `quality-reviewer` | 네이밍, 함수 크기, 중복 코드, 오버엔지니어링, 매직값 |

reviewer-lead는 두 에이전트의 결과를 취합하여 최종 판정을 내립니다.
이슈가 겹치면 심각도 높은 쪽 기준으로 하나만 기록합니다 (중복 기록 금지).

---

## 5. completeness_check 수행 조건

`.pipeline/runs/{run_id}/spec.json` 파일이 존재하는 경우에만 수행합니다.
- spec.json의 `features` 배열과 구현된 코드를 대조합니다.
- 존재하지 않으면 `completeness_check.applicable: false`로 기록하고 생략합니다.
