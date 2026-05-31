#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/claude-hud-tests.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  printf 'FAIL %s: %s\n' "$1" "$2" >&2
  exit 1
}

strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*m//g'
}

write_transcript() {
  local transcript="$1"
  cat > "$transcript" <<'JSONL'
{"type":"user","message":{"content":"Make the HUD beautiful but still readable."}}
{"type":"assistant","message":{"usage":{"input_tokens":500000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0,"output_tokens":0}}}
JSONL
}

write_status() {
  local status_file="$1" transcript="$2" cwd="$3"
  cat > "$status_file" <<JSON
{"model":{"display_name":"Opus 4.8 (1M context)"},"cwd":"$cwd","transcript_path":"$transcript","context_window":{"context_window_size":1000000}}
JSON
}

hud_happy_path_renders_compact_sections() {
  local id="hud_happy_path_renders_compact_sections"
  local transcript="$TMP_DIR/transcript.jsonl"
  local status="$TMP_DIR/status.json"
  local folder_name
  folder_name="$(basename "$ROOT")"
  write_transcript "$transcript"
  write_status "$status" "$transcript" "$ROOT"

  local output
  output="$(CLAUDE_HUD_TEST_USAGE='5h=42,1w=63,reset5=2027-01-01T01:00:00Z,reset1=2027-01-05T01:00:00Z' "$ROOT/context-bar.sh" < "$status" | strip_ansi)"

  [[ "$output" == *"O4.8"* ]] || fail "$id" "missing abbreviated model label"
  [[ "$output" != *"Opus 4.8 (1M context)"* ]] || fail "$id" "model label is too long"
  [[ "$output" != *"$folder_name"* ]] || fail "$id" "folder segment should not render"
  [[ "$output" != *"󰉋"* ]] || fail "$id" "folder icon should not render"
  [[ "$output" == *"ctx "* ]] || fail "$id" "missing context label"
  [[ "$output" == *"50%/1000k"* ]] || fail "$id" "missing compact context ratio"
  [[ "$output" == *"5h ["* && "$output" == *"1w ["* ]] || fail "$id" "missing labeled rate-limit meters"
  [[ "$output" == *"git main"* ]] || fail "$id" "missing compact git segment"
  [[ "$output" != *"uncommitted"* && "$output" != *"no upstream"* ]] || fail "$id" "git segment is too verbose"
  [[ "$output" == *"└─ 💬 Make the HUD beautiful"* ]] || fail "$id" "missing second-line last message"
  pass "$id"
}

hud_missing_transcript_and_minimal_json_still_renders() {
  local id="hud_missing_transcript_and_minimal_json_still_renders"
  local output
  output="$(printf '{}\n' | "$ROOT/context-bar.sh" | strip_ansi)"

  [[ "$output" == *"?"* ]] || fail "$id" "missing fallback model"
  [[ "$output" != *"󰉋"* ]] || fail "$id" "folder icon should not render in fallback"
  [[ "$output" == *"ctx "* ]] || fail "$id" "missing fallback context label"
  [[ "$output" == *"~10%/200k"* ]] || fail "$id" "missing fallback baseline context"
  pass "$id"
}

install_dry_run_writes_expected_command_and_no_live_mutation() {
  local id="install_dry_run_writes_expected_command_and_no_live_mutation"
  local fake_home="$TMP_DIR/fake-home"
  mkdir -p "$fake_home"

  local output
  output="$("$ROOT/install.sh" --dry-run --home-dir "$fake_home")"

  [[ "$output" == *"DRY RUN"* ]] || fail "$id" "dry-run banner missing"
  [[ "$output" == *"$fake_home/.claude/hud/context-bar.sh"* ]] || fail "$id" "target HUD path missing"
  [[ "$output" == *"$fake_home/.claude/settings.json"* ]] || fail "$id" "target settings path missing"
  [[ ! -e "$fake_home/.claude/hud/context-bar.sh" ]] || fail "$id" "dry-run wrote HUD file"
  [[ ! -e "$fake_home/.claude/settings.json" ]] || fail "$id" "dry-run wrote settings file"
  pass "$id"
}

docs_reference_cover_install_and_bilingual_links() {
  local id="docs_reference_cover_install_and_bilingual_links"

  [[ -s "$ROOT/cover.png" ]] || fail "$id" "cover.png missing or empty"
  grep -q 'README-Ko-KR.md' "$ROOT/README.md" || fail "$id" "English README missing Korean link"
  grep -q 'install.sh' "$ROOT/README.md" || fail "$id" "English README missing installer"
  grep -q 'Claude Code' "$ROOT/README-Ko-KR.md" || fail "$id" "Korean README missing product name"
  grep -q 'context-bar.sh' "$ROOT/README-Ko-KR.md" || fail "$id" "Korean README missing script reference"
  pass "$id"
}

docs_avoid_ai_slop_and_include_design_stance() {
  local id="docs_avoid_ai_slop_and_include_design_stance"
  local combined="$TMP_DIR/readme-combined.md"
  cat "$ROOT/README.md" "$ROOT/README-Ko-KR.md" > "$combined"

  for phrase in \
    "polished" \
    "at a glance" \
    "instant situational awareness" \
    "works well" \
    "What You Get" \
    "What The Installer Does"
  do
    if grep -qi "$phrase" "$combined"; then
      fail "$id" "generic phrase remains: $phrase"
    fi
  done

  grep -q 'Thesis' "$ROOT/README.md" || fail "$id" "missing English thesis stance"
  grep -q 'Antithesis' "$ROOT/README.md" || fail "$id" "missing English antithesis stance"
  grep -q 'Synthesis' "$ROOT/README.md" || fail "$id" "missing English synthesis stance"
  grep -q '정립' "$ROOT/README-Ko-KR.md" || fail "$id" "missing Korean thesis stance"
  grep -q '반정립' "$ROOT/README-Ko-KR.md" || fail "$id" "missing Korean antithesis stance"
  grep -q '종합' "$ROOT/README-Ko-KR.md" || fail "$id" "missing Korean synthesis stance"
  pass "$id"
}

main() {
  hud_happy_path_renders_compact_sections
  hud_missing_transcript_and_minimal_json_still_renders
  install_dry_run_writes_expected_command_and_no_live_mutation
  docs_reference_cover_install_and_bilingual_links
  docs_avoid_ai_slop_and_include_design_stance
}

main "$@"
