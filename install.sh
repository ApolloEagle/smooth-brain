#!/usr/bin/env bash
set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_SOURCE" && -f "$SCRIPT_SOURCE" ]]; then
  REPO_ROOT="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
else
  REPO_ROOT=""
fi
SMOOTH_BRAIN_REF="${SMOOTH_BRAIN_REF:-main}"
SMOOTH_BRAIN_RAW_BASE="${SMOOTH_BRAIN_RAW_BASE:-https://raw.githubusercontent.com/ApolloEagle/smooth-brain/$SMOOTH_BRAIN_REF}"
SMOOTH_BRAIN_RAW_BASE="${SMOOTH_BRAIN_RAW_BASE%/}"
UNINSTALL=false

for arg in "$@"; do
  [[ "$arg" == "--uninstall" ]] && UNINSTALL=true
done

# ── helpers ────────────────────────────────────────────────────────────────────

log()  { echo "[smooth-brain] $*"; }
ok()   { echo "[smooth-brain] ✓ $*"; }
warn() { echo "[smooth-brain] ! $*"; }

command -v python3 >/dev/null 2>&1 || { warn "python3 is required but not found. Please install it."; exit 1; }

copy_source_file() {
  local local_path="$1"
  local raw_path="$2"
  local dest="$3"

  if [[ -n "$local_path" && -f "$local_path" ]]; then
    cp "$local_path" "$dest"
    return
  fi

  command -v curl >/dev/null 2>&1 || { warn "curl is required for remote install but not found. Please install it."; exit 1; }
  curl -fsSL "$SMOOTH_BRAIN_RAW_BASE/$raw_path" -o "$dest"
}

write_active_preset() {
  if [[ -n "$SKILL_SRC" && -f "$SKILL_SRC" ]]; then
    cat "$SKILL_SRC" > "$CLAUDE_ACTIVE"
  else
    command -v curl >/dev/null 2>&1 || { warn "curl is required for remote install but not found. Please install it."; exit 1; }
    curl -fsSL "$SMOOTH_BRAIN_RAW_BASE/skills/smooth-brain/SKILL.md" -o "$CLAUDE_ACTIVE"
  fi
  printf '\n\nActive preset: bumpy\n' >> "$CLAUDE_ACTIVE"
}

add_hook() {
  local settings="$1"
  python3 - "$settings" <<'PYEOF'
import json, os, shutil, sys

path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    data = {}
except json.JSONDecodeError as exc:
    print(f"[smooth-brain] invalid JSON in {path}: {exc}", file=sys.stderr)
    print("[smooth-brain] fix the file before installing so existing settings are not overwritten", file=sys.stderr)
    sys.exit(1)

# $HOME is intentionally a literal string — it expands at hook execution time, not install time
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

import tempfile
dir_ = os.path.dirname(os.path.abspath(path))
fd, tmp = tempfile.mkstemp(dir=dir_)
try:
    if os.path.exists(path):
        shutil.copy2(path, path + ".smooth-brain.bak")
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
except:
    os.unlink(tmp)
    raise

print("[smooth-brain] ✓ hook added to " + path)
PYEOF
}

remove_hook() {
  local settings="$1"
  python3 - "$settings" <<'PYEOF'
import json, os, shutil, sys

path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except FileNotFoundError:
    print("[smooth-brain] no settings file found, nothing to remove")
    sys.exit(0)
except json.JSONDecodeError as exc:
    print(f"[smooth-brain] invalid JSON in {path}: {exc}", file=sys.stderr)
    print("[smooth-brain] fix the file before uninstalling so existing settings are not overwritten", file=sys.stderr)
    sys.exit(1)

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

import tempfile
dir_ = os.path.dirname(os.path.abspath(path))
fd, tmp = tempfile.mkstemp(dir=dir_)
try:
    if os.path.exists(path):
        shutil.copy2(path, path + ".smooth-brain.bak")
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
except:
    os.unlink(tmp)
    raise

print("[smooth-brain] ✓ hook removed from " + path)
PYEOF
}

# ── Claude Code ────────────────────────────────────────────────────────────────

CLAUDE_COMMANDS_DIR="$HOME/.claude/commands"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
CLAUDE_ACTIVE="$HOME/.claude/smooth-brain-active"
SKILL_SRC="${REPO_ROOT:+$REPO_ROOT/skills/smooth-brain/SKILL.md}"
CMD_SRC="${REPO_ROOT:+$REPO_ROOT/.claude/commands/smooth-brain.md}"

install_claude() {
  if [[ ! -d "$HOME/.claude" ]]; then
    warn "Claude Code not detected (~/.claude missing). Skipping."
    return
  fi

  if [[ "$UNINSTALL" == true ]]; then
    rm -f "$CLAUDE_COMMANDS_DIR/smooth-brain.md"
    rm -f "$CLAUDE_ACTIVE"
    remove_hook "$CLAUDE_SETTINGS"
    ok "Claude Code uninstalled"
    return
  fi

  mkdir -p "$CLAUDE_COMMANDS_DIR"

  copy_source_file "$CMD_SRC" ".claude/commands/smooth-brain.md" "$CLAUDE_COMMANDS_DIR/smooth-brain.md"
  ok "Slash command → $CLAUDE_COMMANDS_DIR/smooth-brain.md"

  # Write default active preset file (bumpy)
  write_active_preset
  ok "Default preset (bumpy) → $CLAUDE_ACTIVE"

  add_hook "$CLAUDE_SETTINGS"
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
