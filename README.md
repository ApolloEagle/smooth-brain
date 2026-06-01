# smooth-brain

> stop AI from being so wordy

A plugin that tells AI agents to respond with fewer words and simpler language. Three presets from "slightly less annoying" to "explain like I'm five."

## Install

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/ApolloEagle/smooth-brain/main/install.sh | bash

# Windows PowerShell
irm https://raw.githubusercontent.com/ApolloEagle/smooth-brain/main/install.ps1 | iex
```

Re-run to update. Safe to run multiple times.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/ApolloEagle/smooth-brain/main/install.sh | bash -s -- --uninstall
```

## Usage (Claude Code)

```
/smooth-brain              # bumpy — default
/smooth-brain wrinkled     # mild: plain English, no filler
/smooth-brain bumpy        # moderate: short sentences, common words, bullets
/smooth-brain smooth       # maximum: one sentence answers, analogies only
```

## Presets

| Preset | What changes |
|--------|-------------|
| `wrinkled` | No jargon, no filler openers ("Certainly!", "Great question!"), shorter responses |
| `bumpy` | + Short sentences, common words, bullets over paragraphs, no unsolicited context |
| `smooth` | + Explain like never coded before, single steps only, one sentence where possible |

All presets automatically suspend for destructive operation warnings (deleting files, dropping databases, etc.) and resume after.

## How it works

The `/smooth-brain` slash command carries the full preset rules and writes the active preset to `~/.claude/smooth-brain-active`. A session-start hook reads that file so the chosen preset stays active across prompts.

## Platforms

- Claude Code ✓
- Codex — coming soon
- Cursor — coming soon

## License

MIT
