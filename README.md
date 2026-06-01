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
| `wrinkled` | No jargon, no filler openers ("Certainly!", "Great question!"), shorter responses |
| `bumpy` | + Short sentences, common words, bullets over paragraphs, no unsolicited context |
| `smooth` | + Explain like never coded before, single steps only, one sentence where possible |

All presets automatically suspend for destructive operation warnings (deleting files, dropping databases, etc.) and resume after.

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

## Validate before submitting

```bash
node scripts/test-plugin-layout.mjs
node scripts/test-installers.mjs
claude plugin validate
```

Submit for community review at:

- https://claude.ai/settings/plugins/submit
- https://platform.claude.com/plugins/submit

## Release automation

Pushes to `main` run installer tests and create or update a `release/next` PR when releasable changes are detected. The planner uses conventional commits first:

| Commit type | Bump |
|-------------|------|
| `feat:` | minor |
| `fix:`, `perf:`, `refactor:`, `docs:` | patch |
| `BREAKING CHANGE:` or `type!:` | major |

If `OPENAI_API_KEY` and `OPENAI_MODEL` are set, the planner asks OpenAI for a structured release plan and README/changelog wording. Without both values, the deterministic plan is used.

After the release PR is merged, the release workflow reads `VERSION`, extracts the matching `CHANGELOG.md` entry, creates the `vX.Y.Z` tag, and publishes a GitHub Release.

## Platforms

- Claude Code

## License

MIT
