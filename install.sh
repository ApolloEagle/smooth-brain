#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNINSTALL=false

for arg in "$@"; do
  [[ "$arg" == "--uninstall" ]] && UNINSTALL=true
done

# ── helpers ────────────────────────────────────────────────────────────────────

log()  { echo "[smooth-brain] $*"; }
ok()   { echo "[smooth-brain] ✓ $*"; }
warn() { echo "[smooth-brain] ! $*"; }

add_hook() {
  local settings="$1"
  python3 - "$settings" <<'PYEOF'
import json, sys

path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

hook_entry = {
    "matcher": "",
    "hooks": [
        {
            "type": "command",
            "command": "cat \"$HOME/.claude/smooth-brain-active\" 2>/dev/null || true"
        }
    ]
}

hooks = data.setdefault("hooks", {})
submit_hooks = hooks.setdefault("UserPromptSubmit", [])

# idempotent — only add if not already present
for h in submit_hooks:
    for hh in h.get("hooks", []):
        if "smooth-brain" in hh.get("command", ""):
            print("[smooth-brain] hook already present, skipping")
            sys.exit(0)

submit_hooks.append(hook_entry)

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("[smooth-brain] ✓ hook added to " + path)
PYEOF
}

remove_hook() {
  local settings="$1"
  python3 - "$settings" <<'PYEOF'
import json, sys

path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    print("[smooth-brain] no settings file found, nothing to remove")
    sys.exit(0)

hooks = data.get("hooks", {})
submit = hooks.get("UserPromptSubmit", [])
filtered = [
    h for h in submit
    if not any("smooth-brain" in hh.get("command", "") for hh in h.get("hooks", []))
]
hooks["UserPromptSubmit"] = filtered
if not filtered:
    del hooks["UserPromptSubmit"]
if not hooks:
    del data["hooks"]

with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("[smooth-brain] ✓ hook removed from " + path)
PYEOF
}

# ── Claude Code ────────────────────────────────────────────────────────────────

CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CLAUDE_ACTIVE="$HOME/.claude/smooth-brain-active"
SKILL_SRC="$REPO_ROOT/skills/smooth-brain/SKILL.md"
CMD_SRC="$REPO_ROOT/.claude/commands/smooth-brain.md"

install_claude() {
  if [[ ! -d "$HOME/.claude" ]]; then
    warn "Claude Code not detected (~/.claude missing). Skipping."
    return
  fi

  mkdir -p "$CLAUDE_COMMANDS_DIR"

  if [[ "$UNINSTALL" == true ]]; then
    rm -f "$CLAUDE_COMMANDS_DIR/smooth-brain.md"
    rm -f "$CLAUDE_ACTIVE"
    remove_hook "$CLAUDE_SETTINGS"
    ok "Claude Code uninstalled"
    return
  fi

  cp "$CMD_SRC" "$CLAUDE_COMMANDS_DIR/smooth-brain.md"
  ok "Slash command → $CLAUDE_COMMANDS_DIR/smooth-brain.md"

  # Write default active preset file (bumpy)
  cat "$SKILL_SRC" > "$CLAUDE_ACTIVE"
  printf '\n\nActive preset: bumpy\n' >> "$CLAUDE_ACTIVE"
  ok "Default preset (bumpy) → $CLAUDE_ACTIVE"

  add_hook "$CLAUDE_SETTINGS"
  ok "Session-start hook configured in $CLAUDE_SETTINGS"
}

# ── main ───────────────────────────────────────────────────────────────────────

log "smooth-brain installer"
[[ "$UNINSTALL" == true ]] && log "mode: uninstall" || log "mode: install"
echo ""

install_claude

echo ""
if [[ "$UNINSTALL" == true ]]; then
  log "Uninstall complete."
else
  log "Install complete. Run /smooth-brain in Claude Code to activate."
fi
