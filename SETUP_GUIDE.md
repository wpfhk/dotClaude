# Claude Code 설정 이식 가이드

새 컴퓨터(Mac / Windows)에 현재 Claude Code 설정을 그대로 옮기는 방법입니다.

---

## 포함된 파일

```
my_claude_set/
├── settings.json          # 전역 설정 (권한, 테마, 환경변수 등)
├── commands/
│   └── develop.md         # /develop 커스텀 슬래시 커맨드
├── setup_mac.sh           # macOS 자동 설치 스크립트
├── setup_windows.ps1      # Windows 자동 설치 스크립트
└── SETUP_GUIDE.md         # 이 파일
```

---

## 빠른 설치 (권장)

설치 스크립트가 Node.js 확인 → Claude Code 설치 → 파일 복사 → 경로 치환을 자동으로 처리합니다.

### macOS

```bash
bash setup_mac.sh
```

### Windows (PowerShell, 관리자 권한)

```powershell
.\setup_windows.ps1
```

스크립트 실행 중 locky-agent 경로를 물어봅니다. 입력하면 `develop.md` 내 경로가 자동 치환됩니다.
스킵하면 수동으로 수정해야 합니다 ([아래 참조](#developmd-경로-치환-빠른-참조)).

---

## 수동 설치

스크립트 없이 직접 설정하려면 아래 단계를 따르세요.

### 사전 요구사항

- Node.js 18+ 설치
- Claude Code CLI: `npm install -g @anthropic-ai/claude-code`
- locky-agent 레포지토리 클론 (`/develop` 커맨드 사용 시)

### macOS

```bash
mkdir -p ~/.claude/commands

cp settings.json ~/.claude/settings.json
cp commands/develop.md ~/.claude/commands/develop.md

# develop.md 경로 치환
sed -i '' 's|/Users/youngsang.kwon/01_private/locky-agent|/Users/YOUR_NAME/path/to/locky-agent|g' \
  ~/.claude/commands/develop.md
```

### Windows (PowerShell)

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\commands"

Copy-Item "settings.json" "$env:USERPROFILE\.claude\settings.json"
Copy-Item "commands\develop.md" "$env:USERPROFILE\.claude\commands\develop.md"

# develop.md 경로 치환
$f = "$env:USERPROFILE\.claude\commands\develop.md"
(Get-Content $f -Raw) -replace '/Users/youngsang.kwon/01_private/locky-agent', 'C:/Users/YOUR_NAME/path/to/locky-agent' |
  Set-Content $f -Encoding UTF8
```

> **WSL 사용 시**: WSL 내부 경로(`/home/username/locky-agent`)로 치환하고,
> Claude Code도 WSL 터미널에서 실행하면 Mac과 동일하게 동작합니다.

---

## develop.md 경로 치환 빠른 참조

`develop.md` 안에 하드코딩된 원본 경로:

| 항목 | 원본 경로 |
|------|-----------|
| locky-agent 루트 | `/Users/youngsang.kwon/01_private/locky-agent` |
| runner.py | `/Users/youngsang.kwon/01_private/locky-agent/pipeline/runner.py` |
| 프롬프트 파일들 | `/Users/youngsang.kwon/01_private/locky-agent/agents/prompts/` |

모두 같은 prefix이므로 루트 경로 하나만 치환하면 전부 적용됩니다.

---

## 프로젝트별 CLAUDE.md

`locky-agent/CLAUDE.md`는 레포지토리에 체크인되어 있으므로
`git clone`만 해도 자동으로 적용됩니다. 별도 복사 불필요.

---

## 요약 체크리스트

- [ ] `bash setup_mac.sh` 또는 `.\setup_windows.ps1` 실행
- [ ] locky-agent 레포 클론 (없는 경우)
- [ ] locky-agent 경로를 스크립트에서 입력 (또는 수동 치환)
- [ ] `claude` 실행 후 `/develop` 동작 확인
