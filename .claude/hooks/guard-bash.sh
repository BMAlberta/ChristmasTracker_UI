#!/bin/bash
CMD=$(cat | jq -r '.tool_input.command // ""')
block() { echo "Blocked: $1" >&2; exit 2; }
printf '%s' "$CMD" | grep -Eq '\.claude|\.env|\.p12|\.mobileprovision' && block "shell commands may not touch .claude/, .env, or signing files."
if printf '%s' "$CMD" | grep -Eq 'gh pr create' && ! printf '%s' "$CMD" | grep -Eq -- '--base[ =]master'; then
  block "gh pr create must pass --base master."
fi
printf '%s' "$CMD" | grep -Eq 'git push.* (master|main)( |$)' && block "do not push to master or main."
exit 0