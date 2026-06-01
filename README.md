# smooth-brain

> stop AI from being so wordy

A plugin that tells AI agents to respond with fewer words and simpler language. Three presets from "slightly less annoying" to "explain like I'm five."

## Install from Claude Code

After marketplace approval:

```text
/plugin marketplace update claude-plugins-official
/plugin install smooth-brain@claude-plugins-official
```

If Claude Code does not have the official marketplace yet:

```text
/plugin marketplace add anthropics/claude-plugins-official
```

Until then, test the plugin locally from this repo:

```bash
claude --plugin-dir .
```

Then run:

```text
/smooth-brain:smooth-brain
/smooth-brain:smooth-brain wrinkled
/smooth-brain:smooth-brain bumpy
/smooth-brain:smooth-brain smooth
```

## Legacy Installer

```bash
# macOS / Linux
curl -fsSL https://raw.githubusercontent.com/ApolloEagle/smooth-brain/main/install.sh | bash

# Windows PowerShell
irm https://raw.githubusercontent.com/ApolloEagle/smooth-brain/main/install.ps1 | iex
```

Re-run to update. Safe to run multiple times.

<!-- release-readme:start -->
## Updates

Current stable version: `v0.3.0`.

- Release updates are proposed by the release-plan workflow after pushes to `main`.
- Tags are created only after the release PR is merged and tests pass.
- Re-run the installer to update an existing install.
<!-- release-readme:end -->

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/ApolloEagle/smooth-brain/main/install.sh | bash -s -- --uninstall
```

## Usage

Marketplace/plugin command:

```text
/smooth-brain:smooth-brain              # bumpy - default
/smooth-brain:smooth-brain wrinkled     # mild: plain English, no filler
/smooth-brain:smooth-brain bumpy        # moderate: short sentences, common words, bullets
/smooth-brain:smooth-brain smooth       # maximum: one sentence answers, analogies only
```

Legacy installer command:

```text
/smooth-brain              # bumpy - default
/smooth-brain wrinkled     # mild: plain English, no filler
/smooth-brain bumpy        # moderate: short sentences, common words, bullets
/smooth-brain smooth       # maximum: one sentence answers, analogies only
```

## Presets

| Preset | What changes |
|--------|-------------|
| `wrinkled` | Plain English, no filler openers, full multi-step checklist at once |
| `bumpy` | + Short sentences, common words, grouped phases for multi-step tasks |
| `smooth` | + Beginner-friendly language, one user action at a time, waits for confirmation |

All presets automatically suspend for destructive operation warnings (deleting files, dropping databases, etc.) and resume after. If the user asks for all steps, a checklist, a quick reference, or a summary, smooth-brain gives the full list.

## How it works

The slash command carries the full preset rules and writes the active preset to `~/.claude/smooth-brain-active`. A prompt-submit hook reads that file so the chosen preset stays active across prompts.

Marketplace plugin files live in the Claude Code plugin layout:

```text
.claude-plugin/plugin.json
commands/smooth-brain.md
skills/smooth-brain/SKILL.md
hooks/hooks.json
```

The legacy installer still copies the same command into `~/.claude/commands` for users who are not using plugins yet.

## Platforms

- Claude Code

## License

MIT
