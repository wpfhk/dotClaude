---
name: git-commit-push
description: >
  현재 프로젝트의 git 작업(add, commit, push, 브랜치 관리 등)을 한 번에 처리하는 스킬.
  사용자가 "커밋해줘", "푸시해줘", "git 올려줘", "변경사항 저장해줘", "commit push",
  "git commit", "git push", "코드 올려줘", "작업 내용 커밋", "브랜치 만들어줘",
  "새 브랜치", "git 작업해줘" 등 git 관련 작업을 언급하면 반드시 이 스킬을 사용할 것.
  add → commit → push는 확인 없이 바로 실행하고, 브랜치 생성/삭제·rebase·force push 등
  되돌리기 어려운 작업은 실행 전 사용자 확인을 받는다.
---

# Git Commit & Push Skill

변경사항을 분석해 커밋 메시지를 자동 생성하고, add → commit → push를 즉시 실행한다.
브랜치 생성 등 복잡한 작업은 확인 후 실행한다.

---

## 실행 원칙

| 작업 유형 | 예시 | 확인 필요 여부 |
|-----------|------|--------------|
| 기본 흐름 | `git add`, `git commit`, `git push` | ❌ 즉시 실행 |
| 브랜치 전환 | `git checkout <기존 브랜치>` | ❌ 즉시 실행 |
| 브랜치 생성 | `git checkout -b <new>` | ✅ 확인 후 실행 |
| 브랜치 삭제 | `git branch -d / -D` | ✅ 확인 후 실행 |
| Force push | `git push --force` | ✅ 확인 후 실행 |
| Rebase | `git rebase` | ✅ 확인 후 실행 |
| Reset / Revert | `git reset`, `git revert` | ✅ 확인 후 실행 |

---

## 기본 흐름: add → commit → push

### 1단계: 상태 파악

```bash
git status
git branch --show-current
git diff --stat HEAD
```

### 2단계: 커밋 메시지 생성

```bash
git diff HEAD
git diff --cached
```

변경 내용을 분석해 **Conventional Commits** 형식으로 자동 생성한다:

```
<type>(<scope>): <subject>

[optional body]
```

**type 선택:**

| type | 상황 |
|------|------|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `refactor` | 동작 변경 없는 코드 개선 |
| `docs` | 문서 |
| `style` | 포맷/공백 |
| `test` | 테스트 |
| `chore` | 빌드, 설정, 의존성 |
| `perf` | 성능 개선 |

- **scope**: 변경된 주요 모듈/파일명 (생략 가능)
- **subject**: 현재형 동사로 시작, 50자 이내, 영어 또는 한국어 모두 허용
- 여러 성격의 변경이 섞이면 가장 중요한 type을 선택하고 body에 나머지를 요약

**예시:**
```
feat(auth): add JWT refresh token logic
fix(api): handle null response from user endpoint
chore: update dependencies to latest versions
```

### 3단계: 즉시 실행

확인 없이 순서대로 실행한다:

```bash
git add .
git commit -m "<generated-message>"
git push origin <branch>
```

각 명령 실행 후 출력을 확인하고, 오류가 있으면 즉시 멈추고 원인을 알린다.

### 4단계: 결과 보고

```
## ✅ 완료

브랜치: <branch>
커밋: <hash> — <message>
푸시: origin/<branch>
```

---

## 브랜치 작업 (확인 후 실행)

### 브랜치 생성 요청 시

현재 브랜치와 새 브랜치명을 보여주고 확인을 받는다:

```
새 브랜치를 생성합니다:
  현재: <current-branch>
  생성: <new-branch>
  명령: git checkout -b <new-branch>

진행할까요?
```

승인 후 브랜치를 생성하고, 이어서 작업이 있으면 기본 흐름(add → commit → push)을 즉시 실행한다.

### 브랜치 삭제 요청 시

```
브랜치를 삭제합니다:
  대상: <branch-name>
  명령: git branch -d <branch-name>

⚠️ 이 작업은 되돌리기 어렵습니다. 진행할까요?
```

---

## 엣지 케이스 처리

**변경사항이 없을 때**
```
현재 커밋할 변경사항이 없습니다. (git status: clean)
```

**push가 rejected될 때 (원격이 앞서 있는 경우)**
```
⚠️ push가 거절되었습니다. 원격 브랜치에 새로운 커밋이 있습니다.
git pull --rebase 후 다시 push하시겠습니까?
```
→ 확인 후 `git pull --rebase && git push origin <branch>` 실행

**`.env`, 빌드 산출물 등 민감/불필요 파일 감지 시**
`git add .` 실행 전에 스테이징될 파일 목록을 빠르게 확인해,
`.env`, `node_modules/`, `__pycache__/`, `dist/`, `*.log` 등이 포함될 것 같으면 사용자에게 먼저 알린다:
```
⚠️ 스테이징에 포함될 민감한 파일이 감지되었습니다: .env
계속 진행하면 이 파일이 커밋에 포함됩니다. 진행할까요?
```

**커밋 메시지를 사용자가 직접 지정한 경우**
자동 생성 없이 해당 메시지를 그대로 사용한다.
Conventional Commits 형식이 아니어도 강요하지 않는다.
