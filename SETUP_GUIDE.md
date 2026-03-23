# Claude Code 설정 이식 가이드

새 컴퓨터(Mac / Windows)에 현재 Claude Code 설정을 그대로 옮기는 방법입니다.

---

## 포함된 설정 파일

```
my_claude_set/
├── settings.json          # 전역 설정 (권한, 테마, 환경변수 등)
├── commands/
│   └── develop.md         # /develop 커스텀 슬래시 커맨드
└── SETUP_GUIDE.md         # 이 파일
```

---

## 사전 요구사항

- Node.js 18+ 설치
- Claude Code CLI 설치: `npm install -g @anthropic-ai/claude-code`
- locky-agent 레포지토리 클론 (develop.md의 파이프라인 사용 시 필요)

---

## Mac 설정 방법

### 1. Claude Code 설치

```bash
npm install -g @anthropic-ai/claude-code
claude --version   # 설치 확인
```

### 2. 설정 파일 복사

```bash
# ~/.claude 디렉토리 생성 (없는 경우)
mkdir -p ~/.claude/commands

# 설정 파일 복사
cp /path/to/my_claude_set/settings.json ~/.claude/settings.json
cp /path/to/my_claude_set/commands/develop.md ~/.claude/commands/develop.md
```

### 3. develop.md 경로 수정

`~/.claude/commands/develop.md` 파일 내 하드코딩된 경로를 새 컴퓨터의 locky-agent 경로로 변경합니다.

```bash
# 파일에서 기존 경로 확인
grep -n "youngsang.kwon" ~/.claude/commands/develop.md

# sed로 일괄 치환 (경로를 실제 경로로 수정)
sed -i '' 's|/Users/youngsang.kwon/01_private/locky-agent|/Users/YOUR_USERNAME/path/to/locky-agent|g' \
  ~/.claude/commands/develop.md
```

### 4. 설정 확인

```bash
claude                     # Claude Code 실행
/settings                  # 설정 확인
/develop 테스트 요구사항    # 커스텀 커맨드 동작 확인
```

---

## Windows 설정 방법

### 1. Claude Code 설치

PowerShell (관리자 권한)에서 실행:

```powershell
npm install -g @anthropic-ai/claude-code
claude --version
```

### 2. 설정 디렉토리 확인

Windows에서 Claude Code 설정 디렉토리는 다음 위치입니다:

```
%USERPROFILE%\.claude\
# 예: C:\Users\YourName\.claude\
```

### 3. 설정 파일 복사

PowerShell에서 실행:

```powershell
# 디렉토리 생성
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\commands"

# 파일 복사 (my_claude_set 경로를 실제 경로로 수정)
Copy-Item "C:\path\to\my_claude_set\settings.json" "$env:USERPROFILE\.claude\settings.json"
Copy-Item "C:\path\to\my_claude_set\commands\develop.md" "$env:USERPROFILE\.claude\commands\develop.md"
```

### 4. develop.md 경로 수정

`develop.md` 내 경로는 Mac 스타일(`/Users/...`)로 되어 있습니다.
Windows 경로(`C:\Users\...`) 또는 WSL 경로(`/home/...`)로 수정하세요.

메모장이나 VS Code로 `%USERPROFILE%\.claude\commands\develop.md`를 열어
`/Users/youngsang.kwon/01_private/locky-agent` 를
본인 경로(예: `C:/Users/YourName/locky-agent`)로 전체 치환합니다.

> **WSL 사용 시**: WSL 내부 경로(`/home/username/locky-agent`)로 치환하고,
> Claude Code도 WSL 터미널에서 실행하면 Mac과 동일하게 동작합니다.

### 5. 설정 확인

```powershell
claude
# /settings 로 설정 확인
# /develop 테스트 요구사항
```

---

## develop.md 경로 치환 빠른 참조

| 항목 | 원본 경로 |
|------|-----------|
| locky-agent 루트 | `/Users/youngsang.kwon/01_private/locky-agent` |
| runner.py | `/Users/youngsang.kwon/01_private/locky-agent/pipeline/runner.py` |
| 프롬프트 파일들 | `/Users/youngsang.kwon/01_private/locky-agent/agents/prompts/` |

새 컴퓨터에서 locky-agent를 클론한 경로로 위 경로들을 전부 교체하면 됩니다.

---

## 프로젝트별 CLAUDE.md

`locky-agent/CLAUDE.md` 는 레포지토리에 체크인되어 있으므로,
`git clone` 만 해도 자동으로 적용됩니다. 별도 복사 불필요.

---

## 요약 체크리스트

- [ ] Node.js 18+ 설치
- [ ] `npm install -g @anthropic-ai/claude-code`
- [ ] `~/.claude/settings.json` 복사
- [ ] `~/.claude/commands/develop.md` 복사
- [ ] `develop.md` 내 하드코딩 경로를 새 컴퓨터 경로로 수정
- [ ] locky-agent 레포 클론
- [ ] `claude` 실행 후 `/develop` 동작 확인
