#!/bin/bash
# Claude /team skill installer
# - copies the /team skill to ~/.claude/skills/team/
# - seeds ~/agent-team/ (roster + claude-ask bridge + state dirs)
# - never overwrites an existing team.json (your roster is yours)

set -euo pipefail
cd "$(dirname "$0")"

SKILL_DIR="$HOME/.claude/skills/team"
TEAM_DIR="$HOME/agent-team"

mkdir -p "$SKILL_DIR" "$TEAM_DIR/bin" "$TEAM_DIR/channels" "$TEAM_DIR/logs" "$TEAM_DIR/wt"

cp skill/SKILL.md "$SKILL_DIR/SKILL.md"
echo "installed skill  -> $SKILL_DIR/SKILL.md"

cp bin/claude-ask "$TEAM_DIR/bin/claude-ask"
chmod +x "$TEAM_DIR/bin/claude-ask"
echo "installed bridge -> $TEAM_DIR/bin/claude-ask"

if [[ -f "$TEAM_DIR/team.json" ]]; then
  echo "kept existing    -> $TEAM_DIR/team.json (template not applied)"
else
  cp team.json "$TEAM_DIR/team.json"
  echo "installed roster -> $TEAM_DIR/team.json"
fi

if [[ -x "$HOME/grok-bridge/bin/grok-ask" ]] || command -v grok-ask >/dev/null 2>&1; then
  echo "found grok-ask   -> Grok audit/verify ready"
else
  echo
  echo "NOTE: grok-ask not found. The shipped roster uses Grok 4.5 (Grok Build CLI)"
  echo "as the independent plan auditor/verifier. To enable it:"
  echo "  1. Grok Build CLI (SuperGrok or X Premium+ subscription):"
  echo "       curl -fsSL https://x.ai/cli/install.sh | bash && grok login"
  echo "  2. Bridge: https://github.com/BlinkingSun/claude-grok-bridge  (./install.sh)"
  echo "Until then, /team falls back to a different Claude model for audit/verify."
fi

echo
echo "Done. In any Claude Code session, try:  /team <your task>"
echo "Edit $TEAM_DIR/team.json to add models or rewire roles."
