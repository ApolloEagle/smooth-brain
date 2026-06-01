#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";

const write = process.argv.includes("--write");
const bumpRank = { none: 0, patch: 1, minor: 2, major: 3 };
const rankBump = ["none", "patch", "minor", "major"];

function git(args) {
  return execFileSync("git", args, { encoding: "utf8" }).trim();
}

function parseVersion(value) {
  const match = String(value).trim().replace(/^v/, "").match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) {
    throw new Error(`Invalid semver: ${value}`);
  }
  return match.slice(1).map(Number);
}

function compareVersions(a, b) {
  const left = parseVersion(a);
  const right = parseVersion(b);
  for (let i = 0; i < 3; i += 1) {
    if (left[i] !== right[i]) return left[i] - right[i];
  }
  return 0;
}

function incrementVersion(version, bump) {
  const [major, minor, patch] = parseVersion(version);
  if (bump === "major") return `${major + 1}.0.0`;
  if (bump === "minor") return `${major}.${minor + 1}.0`;
  if (bump === "patch") return `${major}.${minor}.${patch + 1}`;
  return version;
}

function latestTag() {
  const tags = git(["tag", "--list", "v[0-9]*", "--sort=-v:refname"]);
  return tags.split("\n").find(Boolean) || null;
}

function currentVersion() {
  if (existsSync("VERSION")) {
    return readFileSync("VERSION", "utf8").trim();
  }
  const tag = latestTag();
  return tag ? tag.replace(/^v/, "") : "0.0.0";
}

function commitsSince(ref) {
  const range = ref ? `${ref}..HEAD` : "HEAD";
  const output = git(["log", "--format=%H%x1f%s%x1f%b%x1e", range]);
  if (!output) return [];
  return output
    .split("\x1e")
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => {
      const [sha, subject, body = ""] = entry.split("\x1f");
      return { sha, subject, body };
    })
    .filter((commit) => !/^chore(\(release\))?: plan next release/i.test(commit.subject));
}

function deterministicBump(commits) {
  let bump = "none";
  for (const commit of commits) {
    const text = `${commit.subject}\n${commit.body}`;
    if (/BREAKING CHANGE:|^[a-z]+(?:\([^)]+\))?!:/i.test(text)) {
      bump = "major";
    } else if (/^feat(?:\([^)]+\))?:/i.test(commit.subject) && bumpRank[bump] < bumpRank.minor) {
      bump = "minor";
    } else if (
      /^(fix|perf|refactor|docs)(?:\([^)]+\))?:/i.test(commit.subject) &&
      bumpRank[bump] < bumpRank.patch
    ) {
      bump = "patch";
    }
  }
  return bump;
}

function changedFiles(ref) {
  const range = ref ? `${ref}..HEAD` : "HEAD";
  const output = git(["diff", "--name-only", range]);
  return output ? output.split("\n").filter(Boolean) : [];
}

function defaultReadmeBlock(version) {
  return [
    `Current stable version: \`v${version}\`.`,
    "",
    "- A release-plan workflow checks pushes to `main`.",
    "- It opens a PR with the proposed version, changelog, and README updates.",
    "- A separate release workflow creates the git tag after that PR is merged and tests pass.",
    "- Re-run the installer to update an existing install.",
  ].join("\n");
}

function defaultChangelogEntry(commits) {
  return commits.map((commit) => `- ${commit.subject}`).join("\n");
}

function buildPrompt({ baseVersion, nextVersion, bump, commits, files }) {
  return [
    "You are planning a release for smooth-brain, an open source Claude Code plugin.",
    "Return only structured JSON matching the schema.",
    "Use semantic versioning. Do not propose a bump lower than the deterministic bump.",
    "Keep README text short and factual.",
    "",
    `Base version: ${baseVersion}`,
    `Deterministic bump: ${bump}`,
    `Expected next version if the deterministic bump is accepted: ${nextVersion}`,
    "",
    "Changed files:",
    files.map((file) => `- ${file}`).join("\n") || "- none",
    "",
    "Commits since latest tag:",
    commits.map((commit) => `- ${commit.sha.slice(0, 7)} ${commit.subject}`).join("\n") || "- none",
  ].join("\n");
}

async function askOpenAI(context) {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return null;

  const model = process.env.OPENAI_MODEL;
  if (!model) {
    console.warn("[smooth-brain] OPENAI_API_KEY is set but OPENAI_MODEL is missing; using deterministic plan.");
    return null;
  }

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      instructions:
        "You are a conservative release manager. Prefer small version bumps. Never invent changes not present in the commits.",
      input: buildPrompt(context),
      max_output_tokens: 1200,
      text: {
        format: {
          type: "json_schema",
          name: "release_plan",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            required: ["bump", "rationale", "readmeNeedsUpdate", "readmeBlock", "changelogEntry"],
            properties: {
              bump: { type: "string", enum: ["none", "patch", "minor", "major"] },
              rationale: { type: "string" },
              readmeNeedsUpdate: { type: "boolean" },
              readmeBlock: { type: "string" },
              changelogEntry: { type: "string" },
            },
          },
        },
      },
    }),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`OpenAI release plan failed: ${response.status} ${details}`);
  }

  const payload = await response.json();
  const text =
    payload.output_text ??
    payload.output
      ?.flatMap((item) => item.content ?? [])
      .filter((item) => item.type === "output_text")
      .map((item) => item.text)
      .join("\n");

  if (!text) {
    throw new Error("OpenAI release plan did not include text output");
  }
  return JSON.parse(text);
}

function normalizePlan(plan, context) {
  const aiBump = bumpRank[plan?.bump] == null ? context.bump : plan.bump;
  const bump = rankBump[Math.max(bumpRank[context.bump], bumpRank[aiBump])];
  const nextVersion = incrementVersion(context.baseVersion, bump);
  const readmeBlock = String(plan?.readmeBlock || defaultReadmeBlock(nextVersion)).trim();
  const changelogEntry = String(plan?.changelogEntry || defaultChangelogEntry(context.commits)).trim();
  const rationale = String(plan?.rationale || `Detected a ${bump} release from commits since latest tag.`).trim();

  return {
    bump,
    nextVersion,
    rationale,
    readmeNeedsUpdate: Boolean(plan?.readmeNeedsUpdate),
    readmeBlock: readmeBlock.slice(0, 2000),
    changelogEntry: changelogEntry.slice(0, 4000),
  };
}

function upsertReadmeBlock(version, block) {
  const start = "<!-- release-readme:start -->";
  const end = "<!-- release-readme:end -->";
  const wrapped = `${start}\n## Updates\n\n${block.trim()}\n${end}`;
  const readme = readFileSync("README.md", "utf8");

  if (readme.includes(start) && readme.includes(end)) {
    return readme.replace(new RegExp(`${start}[\\s\\S]*?${end}`), wrapped);
  }

  const anchor = "Re-run to update. Safe to run multiple times.\n";
  if (readme.includes(anchor)) {
    return readme.replace(anchor, `${anchor}\n${wrapped}\n`);
  }

  return `${readme.trimEnd()}\n\n${wrapped}\n`;
}

function upsertChangelog(version, entry) {
  const date = new Date().toISOString().slice(0, 10);
  const section = `## [${version}] - ${date}\n\n${entry.trim()}\n`;
  if (!existsSync("CHANGELOG.md")) {
    return `# Changelog\n\n${section}`;
  }

  const changelog = readFileSync("CHANGELOG.md", "utf8");
  if (changelog.includes(`## [${version}]`)) {
    return changelog.replace(new RegExp(`## \\[${version}\\][\\s\\S]*?(?=\\n## \\[|\\n?$)`), section.trimEnd());
  }

  return changelog.replace(/^# Changelog\s*/, `# Changelog\n\n${section}\n`);
}

function writeReleasePlan(plan, context) {
  const body = [
    `# Release Plan: v${plan.nextVersion}`,
    "",
    `Proposed bump: \`${plan.bump}\``,
    "",
    "## Rationale",
    "",
    plan.rationale,
    "",
    "## Changelog Entry",
    "",
    plan.changelogEntry,
    "",
    "## Changed Files",
    "",
    context.files.map((file) => `- \`${file}\``).join("\n") || "- none",
    "",
    "## Commits",
    "",
    context.commits.map((commit) => `- \`${commit.sha.slice(0, 7)}\` ${commit.subject}`).join("\n") || "- none",
    "",
  ].join("\n");

  writeFileSync("RELEASE_PLAN.md", body);
}

async function main() {
  const tag = latestTag();
  const tagVersion = tag ? tag.replace(/^v/, "") : "0.0.0";
  const fileVersion = currentVersion();
  const baseVersion = compareVersions(fileVersion, tagVersion) < 0 ? tagVersion : fileVersion;

  if (compareVersions(baseVersion, tagVersion) > 0) {
    console.log(`[smooth-brain] VERSION ${baseVersion} is already ahead of latest tag v${tagVersion}; skipping.`);
    return;
  }

  const commits = commitsSince(tag);
  if (commits.length === 0) {
    console.log("[smooth-brain] no commits since latest tag; skipping.");
    return;
  }

  const bump = deterministicBump(commits);

  const context = {
    tag,
    baseVersion,
    bump,
    nextVersion: incrementVersion(baseVersion, bump),
    commits,
    files: changedFiles(tag),
  };

  const aiPlan = await askOpenAI(context);
  const plan = normalizePlan(aiPlan, context);

  if (plan.bump === "none") {
    console.log("[smooth-brain] no releasable commits detected; skipping.");
    return;
  }

  if (!write) {
    console.log(JSON.stringify(plan, null, 2));
    return;
  }

  writeFileSync("VERSION", `${plan.nextVersion}\n`);
  writeFileSync("CHANGELOG.md", upsertChangelog(plan.nextVersion, plan.changelogEntry));
  writeFileSync("README.md", upsertReadmeBlock(plan.nextVersion, plan.readmeBlock));
  writeReleasePlan(plan, context);
  console.log(`[smooth-brain] planned release v${plan.nextVersion}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
