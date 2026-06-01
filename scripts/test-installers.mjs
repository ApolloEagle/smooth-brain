#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");

function run(command, args, options = {}) {
  return execFileSync(command, args, {
    cwd: root,
    encoding: "utf8",
    stdio: options.stdio ?? "pipe",
    env: { ...process.env, ...(options.env ?? {}) },
    input: options.input,
  });
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function readJson(file) {
  return JSON.parse(readFileSync(file, "utf8"));
}

function countSmoothBrainHooks(settings) {
  const entries = settings.hooks?.UserPromptSubmit ?? [];
  return entries.filter((entry) =>
    (entry.hooks ?? []).some((hook) => String(hook.command ?? "").includes("smooth-brain")),
  ).length;
}

function makeHome(name) {
  const dir = mkdtempSync(path.join(tmpdir(), `smooth-brain-${name}-`));
  return {
    dir,
    claude: path.join(dir, ".claude"),
    cleanup: () => rmSync(dir, { recursive: true, force: true }),
  };
}

run("bash", ["-n", "install.sh"]);

const home = makeHome("install");
try {
  run("mkdir", ["-p", home.claude]);
  const settingsPath = path.join(home.claude, "settings.json");
  writeFileSync(
    settingsPath,
    `${JSON.stringify(
      {
        model: "test-model",
        hooks: {
          UserPromptSubmit: [
            {
              matcher: "existing",
              hooks: [{ type: "command", command: "echo existing" }],
            },
          ],
        },
      },
      null,
      2,
    )}\n`,
  );

  run("bash", ["install.sh"], { env: { HOME: home.dir } });

  assert(
    existsSync(path.join(home.claude, "commands", "smooth-brain.md")),
    "install should copy the slash command",
  );
  assert(
    existsSync(path.join(home.claude, "smooth-brain-active")),
    "install should write the active preset file",
  );

  let settings = readJson(settingsPath);
  assert(settings.model === "test-model", "install should preserve existing settings");
  assert(countSmoothBrainHooks(settings) === 1, "install should add exactly one hook");
  assert(
    settings.hooks.UserPromptSubmit.some((entry) => entry.matcher === "existing"),
    "install should preserve unrelated hooks",
  );

  run("bash", ["install.sh"], { env: { HOME: home.dir } });
  settings = readJson(settingsPath);
  assert(countSmoothBrainHooks(settings) === 1, "reinstall should not duplicate hooks");

  run("bash", ["install.sh", "--uninstall"], { env: { HOME: home.dir } });
  settings = readJson(settingsPath);
  assert(countSmoothBrainHooks(settings) === 0, "uninstall should remove smooth-brain hooks");
  assert(
    settings.hooks.UserPromptSubmit.some((entry) => entry.matcher === "existing"),
    "uninstall should preserve unrelated hooks",
  );
  assert(
    !existsSync(path.join(home.claude, "commands", "smooth-brain.md")),
    "uninstall should remove the slash command",
  );
  assert(
    !existsSync(path.join(home.claude, "smooth-brain-active")),
    "uninstall should remove the active preset file",
  );
} finally {
  home.cleanup();
}

const noClaudeHome = makeHome("no-claude");
try {
  run("bash", ["install.sh"], { env: { HOME: noClaudeHome.dir } });
  assert(!existsSync(path.join(noClaudeHome.dir, ".claude")), "missing .claude should be skipped");
} finally {
  noClaudeHome.cleanup();
}

const badJsonHome = makeHome("bad-json");
try {
  run("mkdir", ["-p", badJsonHome.claude]);
  const badSettings = path.join(badJsonHome.claude, "settings.json");
  const original = '{\n  "model": "broken",\n';
  writeFileSync(badSettings, original);

  let failed = false;
  try {
    run("bash", ["install.sh"], { env: { HOME: badJsonHome.dir } });
  } catch {
    failed = true;
  }

  assert(failed, "install should fail on invalid settings JSON");
  assert(readFileSync(badSettings, "utf8") === original, "invalid settings JSON should not be overwritten");
} finally {
  badJsonHome.cleanup();
}

const pipedHome = makeHome("piped");
try {
  run("mkdir", ["-p", pipedHome.claude]);
  run("bash", [], {
    env: {
      HOME: pipedHome.dir,
      SMOOTH_BRAIN_RAW_BASE: `file://${root}`,
    },
    input: readFileSync(path.join(root, "install.sh")),
  });

  assert(
    existsSync(path.join(pipedHome.claude, "commands", "smooth-brain.md")),
    "piped install should fetch and copy the slash command",
  );
  assert(
    existsSync(path.join(pipedHome.claude, "smooth-brain-active")),
    "piped install should fetch and write the active preset file",
  );
} finally {
  pipedHome.cleanup();
}

console.log("[smooth-brain] installer tests passed");
