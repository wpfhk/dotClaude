# Context Analyzer — 코드베이스 분석 규칙

context-analyzer 서브에이전트가 **작업 시작 전 반드시** 읽는 파일입니다.

---

## 1. 탐색 순서

다음 순서를 지키세요. 각 단계 완료 후 다음 단계로 진행합니다.

```
Step 1. 루트 구조 파악
  → Glob("**/*", maxDepth=2) 로 전체 디렉토리 레이아웃 파악
  → 프로젝트 타입 식별 (Python/Node/Java/Go 등)

Step 2. 진입점 파일 식별
  → main.py / index.ts / app.py / server.js / main.go 등 탐색
  → package.json / pyproject.toml / requirements.txt / go.mod 등 설정 파일 읽기

Step 3. 핵심 모듈 파악
  → 진입점에서 import/require 추적
  → src/, lib/, app/, internal/ 등 주요 디렉토리 구조 확인

Step 4. 의존성 추적
  → 직접 의존(depth=1): 전부 추적
  → 간접 의존(depth=2): 핵심 모듈에서 한 단계 더 추적
  → depth=3 이상은 생략 (시간 대비 효과 낮음)

Step 5. 위험 파일 식별
  → 다수 모듈이 import하는 공통 파일
  → 설정/환경 파일 (config.py, settings.ts 등)
  → DB 스키마·마이그레이션 파일
```

---

## 2. 도구 사용 원칙

- **Glob 우선:** 파일 목록 탐색은 항상 Glob을 사용합니다.
- **Grep은 심볼 추적 시에만:** 특정 함수명·클래스명·변수명을 찾을 때만 Grep을 사용합니다.
- **Read는 핵심 파일만:** 모든 파일을 읽지 말고, 진입점·설정 파일·위험 파일로 범위를 한정합니다.
- 탐색이 끝없이 깊어지면 **depth 2에서 강제 중단**하고 현재까지의 결과를 출력합니다.

---

## 3. 출력 포맷

분석 결과를 다음 JSON 스키마로 출력하세요:

```json
{
  "project_type": "python|node|go|java|other",
  "entry_points": [
    {
      "path": "파일 경로",
      "role": "main|server|cli|library",
      "description": "역할 설명"
    }
  ],
  "dependency_graph": {
    "파일A.py": ["파일B.py", "파일C.py"],
    "파일B.py": ["파일D.py"]
  },
  "patterns": [
    {
      "name": "패턴 이름 (예: Repository Pattern)",
      "description": "설명",
      "example_files": ["해당 패턴을 쓰는 파일"]
    }
  ],
  "risk_files": [
    {
      "path": "파일 경로",
      "risk_reason": "왜 위험한지 (예: 15개 모듈이 import)",
      "dependent_count": 15
    }
  ],
  "tech_stack": {
    "language": "Python 3.11",
    "framework": "FastAPI",
    "test_framework": "pytest",
    "other": ["sqlalchemy", "pydantic"]
  },
  "conventions": {
    "naming": "snake_case / camelCase / PascalCase",
    "file_structure": "기존 파일 구조 패턴 설명",
    "notes": "주목할 만한 컨벤션"
  }
}
```

---

## 4. 분석 깊이 기준 요약

| 의존 depth | 처리 방법 |
|-----------|---------|
| depth 1 (직접 의존) | 전부 추적 |
| depth 2 (간접 의존) | 핵심 모듈만 추적 |
| depth 3+ | 생략 (위험 파일 여부만 메모) |
