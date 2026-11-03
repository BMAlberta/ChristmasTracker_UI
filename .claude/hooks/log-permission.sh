#!/bin/bash
INPUT=$(cat)
DIR="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/logs"
mkdir -p "$DIR"
printf '%s\n' "$INPUT" >> "$DIR/permission-requests.jsonl"

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // "tool"')
DETAIL=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // .tool_input.file_path // ""' | tr '\n' ' ' | cut -c1-80)

osascript -e 'on run argv' \
          -e 'display notification (item 1 of argv) with title "Claude Code needs permission"' \
          -e 'end run' -- "$TOOL: $DETAIL" >/dev/null 2>&1 &
afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 &
exit 0