<p align="center">
  <img src="cover.png" alt="pretty-claude-hud cover" width="100%">
</p>

# pretty-claude-hud

A Claude Code statusline that makes the working state readable without turning the bottom of the terminal into a dashboard.

> **English** | [한국어](README-Ko-KR.md)

## What It Shows

- **Short model tag** — `Opus 4.8 (1M context)` becomes `O4.8`, leaving room for the gauges.
- **Context meter** — Compact token usage bar with the current context window size.
- **Compact worktree tail** — Branch, dirty count, and upstream arrows stay at the end instead of crowding the gauges.
- **Rate-limit meters** — 5-hour and weekly usage bars when Claude Code OAuth usage data is available.
- **Last-message recall** — A subtle second line with your latest prompt, trimmed to match the HUD width.
- **Terminal-native shape** — Built for Nerd Fonts, Powerlevel10k-style prompts, and dark terminal themes.

## Design Stance

**Thesis:** a Claude Code HUD should behave like a good shell prompt: compact, glanceable, and quiet until a number matters.

**Antithesis:** a pretty HUD can become noise when it chases badges, gradients, and labels that do not help the next action.

**Synthesis:** this repo keeps one dense statusline plus one intent line. Context and rate-limit gauges get the prime space; worktree state becomes a short tail.

## Quick Start

### Using an LLM

Paste this into Claude Code, Codex, or another coding assistant:

#### Detailed LLM Agent Prompt

```text
You are setting up pretty-claude-hud on my machine. Please perform the setup end to end, but be careful with my existing Claude Code configuration.

Goal:
- Install pretty-claude-hud from https://github.com/wjgoarxiv/pretty-claude-hud.
- Configure Claude Code's statusLine command to run the installed HUD script.
- Verify that the script and settings are valid.
- Report exactly what changed and tell me when to restart Claude Code.

Rules:
- Do not delete or rewrite unrelated settings in ~/.claude/settings.json.
- If ~/.claude/settings.json already has a statusLine command that does not look like pretty-claude-hud or ~/.claude/hud/context-bar.sh, stop and show me the existing command before changing it.
- Keep any settings.json.bak.* backup made by the installer.
- Stop on any command failure and show me the command plus the error.
- Use $HOME instead of assuming a specific username.

Steps:
1. Check the required tools:
   command -v bash
   command -v git
   command -v jq
   command -v curl
   If any tool is missing, stop and tell me what to install.

2. Clone or update the repository:
   if [ -d "$HOME/pretty-claude-hud/.git" ]; then
     git -C "$HOME/pretty-claude-hud" pull --ff-only
   else
     git clone https://github.com/wjgoarxiv/pretty-claude-hud.git "$HOME/pretty-claude-hud"
   fi

3. Inspect the installer before writing files:
   bash "$HOME/pretty-claude-hud/install.sh" --dry-run
   Confirm that it targets:
   - $HOME/.claude/hud/context-bar.sh
   - $HOME/.claude/settings.json

4. Install:
   bash "$HOME/pretty-claude-hud/install.sh"

5. Verify the installed files:
   test -x "$HOME/.claude/hud/context-bar.sh"
   bash -n "$HOME/.claude/hud/context-bar.sh"
   jq -e . "$HOME/.claude/settings.json"
   jq -r '.statusLine.command' "$HOME/.claude/settings.json"
   The statusLine command should be:
   bash "$HOME/.claude/hud/context-bar.sh"

6. Render a sample HUD without touching my real transcript:
   tmpdir="$(mktemp -d)"
   transcript="$tmpdir/transcript.jsonl"
   status="$tmpdir/status.json"
   cat > "$transcript" <<'JSONL'
{"type":"user","message":{"content":"Check that the HUD is readable."}}
{"type":"assistant","message":{"usage":{"input_tokens":420000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":0}}}
JSONL
   cat > "$status" <<JSON
{"model":{"display_name":"Opus 4.8 (1M context)"},"cwd":"$HOME/pretty-claude-hud","transcript_path":"$transcript","context_window":{"context_window_size":1000000}}
JSON
   CLAUDE_HUD_TEST_USAGE='5h=42,1w=63' bash "$HOME/.claude/hud/context-bar.sh" < "$status" | sed -E 's/\x1b\[[0-9;]*m//g'

7. Final report:
   - Tell me whether install succeeded.
   - List the files changed.
   - Show the statusLine command from jq -r '.statusLine.command' "$HOME/.claude/settings.json".
   - Tell me: Restart Claude Code or open a new Claude Code session to see the HUD.
```

### Manual Install

```bash
git clone https://github.com/wjgoarxiv/pretty-claude-hud.git ~/pretty-claude-hud
bash ~/pretty-claude-hud/install.sh
```

Restart Claude Code or open a new session after installation.

## Installer Behavior

1. Copies `context-bar.sh` to `~/.claude/hud/context-bar.sh`.
2. Backs up `~/.claude/settings.json` when it already exists.
3. Writes this statusline command:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/hud/context-bar.sh\""
  }
}
```

Preview the plan without writing files:

```bash
bash install.sh --dry-run
```

## Requirements

- Claude Code with `statusLine` command support.
- `bash`, `jq`, `git`, and `curl`.
- A Nerd Font is recommended. JetBrainsMono Nerd Font, Hack Nerd Font, Meslo Nerd Font, and D2CodingLigature Nerd Font all work well.

## Themes

Set a theme with an environment variable before launching Claude Code:

```bash
export CLAUDE_HUD_THEME=cyan
```

Available themes:

| Theme | Mood |
| --- | --- |
| `blue` | calm default |
| `cyan` | crisp terminal glow |
| `teal` | muted productivity |
| `green` | classic shell |
| `gold` | warm focus |
| `rose` | soft contrast |
| `lavender` | quiet purple |
| `orange` | high energy |
| `slate` | low saturation |
| `gray` | monochrome |

Disable color:

```bash
export CLAUDE_HUD_NO_COLOR=1
```

## Verify

```bash
bash -n context-bar.sh
bash -n install.sh
tests/run-tests.sh
```

## Uninstall

Remove the installed script and restore your previous `settings.json` backup manually:

```bash
rm -f ~/.claude/hud/context-bar.sh
ls -t ~/.claude/settings.json.bak.* 2>/dev/null | head -1
```

Then copy the backup you want back to `~/.claude/settings.json`.

## Design Note

The goal is not decoration for decoration's sake. The HUD should make Claude Code easier to drive: model, folder, git state, context pressure, rate-limit pressure, and the last user intent should be visible in one glance.

## License

MIT License — see `LICENSE`.
