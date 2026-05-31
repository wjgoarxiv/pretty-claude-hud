<p align="center">
  <img src="cover.png" alt="pretty-claude-hud cover" width="100%">
</p>

# pretty-claude-hud

Claude Code의 현재 상태를 조용하게 보여주는 statusline HUD입니다. 터미널 프롬프트처럼 짧고, 읽히고, 필요한 순간에만 숫자가 튀어나오게 합니다.

> [English](README.md) | **한국어**

## 표시 항목

- **짧은 모델 태그** — `Opus 4.8 (1M context)`를 `O4.8`처럼 줄여 게이지 공간을 확보합니다.
- **컨텍스트 미터** — 현재 context window 기준 토큰 사용량을 짧은 바와 퍼센트로 표시합니다.
- **축약형 worktree tail** — 브랜치, 변경 수, upstream 화살표를 맨 뒤에 짧게 둡니다.
- **Rate-limit 미터** — Claude Code OAuth 사용량을 읽을 수 있으면 5시간/주간 사용률을 표시합니다.
- **마지막 메시지 리마인더** — 두 번째 줄에 마지막 사용자 메시지를 짧게 보여줍니다.
- **터미널형 형태** — Nerd Font, Powerlevel10k 계열 프롬프트, 어두운 터미널 테마를 기준으로 맞췄습니다.

## 디자인 입장

**정립:** Claude Code HUD는 좋은 셸 프롬프트처럼 작아야 합니다. 읽기 쉽고, 한 번에 들어오며, 숫자가 중요해질 때만 눈에 띄어야 합니다.

**반정립:** 예쁜 HUD는 쉽게 소음이 됩니다. 배지, 장식, 과한 라벨이 다음 행동을 돕지 않으면 방해물입니다.

**종합:** 이 repo는 한 줄의 밀도 높은 statusline과 한 줄의 의도 리마인더만 남깁니다. Context와 rate-limit 게이지가 가장 좋은 자리를 차지하고, worktree 상태는 짧은 꼬리로 물러납니다.

## 빠른 시작

### LLM에게 맡기기

Claude Code, Codex 또는 다른 코딩 어시스턴트에 아래 내용을 붙여넣으세요:

```text
https://github.com/wjgoarxiv/pretty-claude-hud 를 홈 디렉토리에 클론하고 install.sh를 실행해줘. 단, ~/.claude/settings.json에 특이한 statusLine 설정이 있으면 변경 전에 멈춰줘.
```

### 직접 설치

```bash
git clone https://github.com/wjgoarxiv/pretty-claude-hud.git ~/pretty-claude-hud
bash ~/pretty-claude-hud/install.sh
```

설치 후 Claude Code를 재시작하거나 새 세션을 여세요.

## 설치 동작

1. `context-bar.sh`를 `~/.claude/hud/context-bar.sh`로 복사합니다.
2. 기존 `~/.claude/settings.json`이 있으면 백업합니다.
3. 아래 statusline 명령을 설정합니다.

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/hud/context-bar.sh\""
  }
}
```

실제 파일을 쓰기 전에 설치 계획만 확인할 수 있습니다:

```bash
bash install.sh --dry-run
```

## 요구 사항

- `statusLine` command를 지원하는 Claude Code.
- `bash`, `jq`, `git`, `curl`.
- Nerd Font 권장. JetBrainsMono Nerd Font, Hack Nerd Font, Meslo Nerd Font, D2CodingLigature Nerd Font에서 잘 보입니다.

## 테마

Claude Code를 실행하기 전에 환경변수로 테마를 지정할 수 있습니다:

```bash
export CLAUDE_HUD_THEME=cyan
```

지원 테마:

| Theme | 느낌 |
| --- | --- |
| `blue` | 차분한 기본값 |
| `cyan` | 선명한 터미널 글로우 |
| `teal` | 조용한 생산성 |
| `green` | 클래식 셸 |
| `gold` | 따뜻한 집중감 |
| `rose` | 부드러운 대비 |
| `lavender` | 낮은 채도의 보라 |
| `orange` | 높은 에너지 |
| `slate` | 절제된 색감 |
| `gray` | 단색 모드 |

색상을 끄려면:

```bash
export CLAUDE_HUD_NO_COLOR=1
```

## 검증

```bash
bash -n context-bar.sh
bash -n install.sh
tests/run-tests.sh
```

## 제거

설치된 스크립트를 지우고 원하는 `settings.json` 백업을 직접 복원하세요:

```bash
rm -f ~/.claude/hud/context-bar.sh
ls -t ~/.claude/settings.json.bak.* 2>/dev/null | head -1
```

선택한 백업을 `~/.claude/settings.json`으로 복사하면 됩니다.

## 디자인 철학

이 HUD의 목적은 장식이 아니라 즉시 이해입니다. 모델, 폴더, Git 상태, context pressure, rate-limit pressure, 마지막 사용자 의도가 한 번에 들어와야 합니다.

## 라이선스

MIT License — `LICENSE`를 참고하세요.
