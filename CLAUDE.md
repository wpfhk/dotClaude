# Global Claude Code Rules (bkit v2.0.5)

> 이 파일은 모든 프로젝트에서 전역으로 적용되는 bkit 핵심 지침입니다.
> 프로젝트별 CLAUDE.md가 있으면 해당 규칙이 우선합니다.

---

## 0. 컨텍스트 절약 규칙 (최우선 적용)

### 파일 읽기 최소화
- 이미 읽은 파일은 재읽지 않는다. 내용을 기억하고 재활용한다.
- 파일 탐색 시 `Glob` → `Grep` → `Read` 순서로 범위를 좁힌 후 읽는다.
- 1000줄 이상 파일은 `offset`/`limit`으로 필요한 구간만 읽는다.
- 확인 목적의 `cat`/`ls` 대신 `Glob`·`Grep` 전용 도구를 사용한다.

### 응답 간결화
- 완료된 작업은 결과만 요약한다. 과정을 재서술하지 않는다.
- 코드 블록은 변경된 부분만 표시한다. 전체 파일을 출력하지 않는다.
- 사용자가 이미 알고 있는 내용(이전 답변에서 설명한 것)을 반복하지 않는다.
- 에러 메시지는 핵심 1~2줄만 인용한다.

### 도구 호출 최적화
- 독립적인 작업은 병렬 도구 호출로 처리한다 (Read + Glob 동시 실행 등).
- 결과를 예측할 수 있는 단순 작업은 확인 없이 즉시 실행한다.
- 에이전트(Agent)는 컨텍스트를 별도 격리하므로, 대형 탐색 작업에 적극 활용한다.

### 컴팩션 유도
- 대화 turns이 30회 이상이거나 대형 파일을 3회 이상 읽었으면 `/compact`를 제안한다.
- 새 피처 작업 시작 전 컨텍스트가 무거우면 새 세션 시작을 먼저 권장한다.

---

## 1. PDCA 자동 적용 규칙

**No Guessing**: 확신 없으면 docs 확인 → docs에 없으면 사용자에게 질문
**SoR 우선순위**: 코드 > CLAUDE.md > docs/ 설계 문서

| 요청 유형 | 동작 |
|----------|------|
| 새 기능 | `docs/02-design/` 확인 → 없으면 설계 먼저 |
| 버그 수정 | 코드 + 설계 비교 → 수정 |
| 리팩토링 | 현황 분석 → 계획 → 설계 업데이트 → 실행 |
| 구현 완료 | Gap 분석 제안 (`/pdca analyze`) |

---

## 2. 레벨 자동 감지

| 레벨 | 감지 조건 |
|------|----------|
| **Starter** | 위 조건 없음 (정적 웹/입문) |
| **Dynamic** | supabase/ 폴더 또는 .mcp.json bkend 설정 |
| **Enterprise** | services/ + infra/ + docker-compose.yml |

레벨별 응답 스타일: Starter → 친근/상세, Dynamic → 기술적/명확, Enterprise → 간결/아키텍처

---

## 3. 코드 품질 기준

### 코딩 전 체크
1. 유사 기능 이미 존재하는가? 먼저 검색
2. `utils/`, `hooks/`, `components/ui/` 확인
3. 존재하면 재사용, 없으면 생성

### 핵심 원칙
- **DRY**: 2번째 사용 시 공통 함수로 추출
- **SRP**: 함수 하나당 책임 하나
- **No Hardcoding**: 의미 있는 상수 사용
- **확장성**: 일반화된 패턴으로 작성

### 리팩토링 시점
- 같은 코드 2번 등장
- 함수가 20줄 초과
- if-else 3단계 이상 중첩
- 동일 파라미터를 여러 함수에 전달

---

## 4. 작업 분류

| 분류 | 내용 크기 | PDCA 수준 | 동작 |
|------|---------|----------|------|
| Quick Fix | < 50자 | 없음 | 즉시 실행 |
| Minor Change | 50~200자 | Lite | 요약 후 진행 |
| Feature | 200~1000자 | Standard | 설계 문서 확인/생성 |
| Major Feature | > 1000자 | Strict | 설계 필수, 사용자 확인 |

---

## 5. 에이전트 자동 트리거

| 사용자 의도 | 자동 호출 에이전트 |
|------------|-----------------|
| 코드 리뷰, 보안 스캔 | `bkit:code-analyzer` |
| 설계 검토, 스펙 확인 | `bkit:design-validator` |
| 갭 분석 | `bkit:gap-detector` |
| 보고서, 요약 | `bkit:report-generator` |
| QA, 로그 분석 | `bkit:qa-monitor` |
| 파이프라인, 단계 안내 | `bkit:pipeline-guide` |

---

## 6. PDCA 문서 경로 규칙

```
docs/
├── 00-pm/           {feature}.prd.md
├── 01-plan/
│   └── features/    {feature}.plan-v{version}.md
├── 02-design/
│   └── features/    {feature}.design-v{version}.md
├── 03-analysis/     {feature}.analysis-v{version}.md
├── 04-report/
│   └── features/    {feature}.report-v{version}.md
└── archive/         {project}/{sprint}/
```

버전 시작: `v0.0.1`, 버전 네이밍: `v{major}.{minor}.{patch}`

---

## 7. 응답 언어 규칙

- 사용자 언어에 맞춰 응답 (기본: 한국어 프로젝트는 한국어)
- 코드 주석: 프로젝트 CLAUDE.md 언어 규칙 따름
- 커밋 메시지: Conventional Commits 형식 (영어)

---

## 8. PDCA 단계별 MCP 활용 규칙

### 필수 MCP 서버 (전역 등록)
| MCP | 설치 명령 | 용도 |
|-----|---------|------|
| `context7` | `claude mcp add context7 -s user -- npx -y @upstash/context7-mcp` | 최신 라이브러리 문서 조회 |
| `shadcn-ui` | `claude mcp add shadcn-ui -s user -- npx -y shadcn@canary mcp` | shadcn/ui 컴포넌트 레지스트리 |
| `playwright` | `claude mcp add playwright -s user -- npx -y @playwright/mcp@latest` | E2E 테스트 자동화 |

### MCP 미설치 시 자동 안내
작업 중 필요한 MCP가 없다면(`claude mcp list`로 확인):
1. 위 표의 설치 명령을 사용자에게 제시한다.
2. 설치 전까지 공식 문서 URL 참조로 대체한다.

### PDCA 단계별 MCP 사용

#### Plan 단계 (기획/계획)
- **Context7 필수**: 사용할 라이브러리의 최신 API를 `mcp__context7__resolve-library-id` → `mcp__context7__query-docs` 순으로 조회한 뒤 계획에 반영한다.
- 버전 종속적인 코드 패턴(예: Next.js App Router, React 19 훅 등)은 반드시 Context7로 최신 버전 확인 후 설계한다.

#### Design 단계 (설계/UI)
- **shadcn-ui 필수**: UI 컴포넌트 설계 시 `mcp__shadcn-ui__*` 도구로 컴포넌트 목록·API·예제를 조회한다.
- shadcn/ui에 없는 컴포넌트만 커스텀 구현한다. 있는 것은 반드시 shadcn/ui를 우선 사용한다.
- 컴포넌트 선택 근거를 설계 문서(`docs/02-design/`)에 명시한다.
- **Context7 병행**: 사용할 UI 라이브러리(Tailwind, Radix 등) 최신 사용법을 Context7로 확인한다.

#### Do 단계 (구현)
- **Context7 필수**: 구현 전 사용 라이브러리의 최신 문서를 조회하여 deprecated API 사용을 방지한다.
- 외부 패키지 함수 시그니처가 불확실하면 추측하지 말고 Context7로 조회한 뒤 코딩한다.

#### Check 단계 (갭 분석/검증)
- **Playwright 활용**: UI 렌더링·인터랙션 검증이 필요할 때 `mcp__playwright__*`로 브라우저 자동화 테스트를 실행한다.
- 스크린샷(`browser_take_screenshot`) → 콘솔 에러 확인(`browser_console_messages`) → 네트워크 요청 검증(`browser_network_requests`) 순으로 진행한다.
- **Playwright 사용 시 CTO팀 필수**: Playwright 기반 QA/검증 작업은 반드시 `/pdca team {feature}`로 CTO팀을 구성하여 **전문 서브에이전트 최소 3명**(developer, frontend, qa)이 병렬로 작업한다. 단독 세션에서 Playwright를 수동으로 돌리지 않는다.

#### Report 단계 (완료 보고)
- MCP 조회 불필요. 기존 코드·문서만으로 보고서를 작성한다.

#### PM 단계 (기획 분석)
- **Context7 선택적**: 경쟁 라이브러리·프레임워크 트렌드 파악이 필요하면 조회한다. PRD 작성 자체에는 불필요.
