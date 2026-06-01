#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function readJson(relativePath) {
  return JSON.parse(readFileSync(path.join(root, relativePath), "utf8"));
}

function run(command, args, options = {}) {
  return execFileSync(command, args, {
    cwd: root,
    encoding: "utf8",
    stdio: options.stdio ?? "pipe",
    env: { ...process.env, ...(options.env ?? {}) },
  });
}

const version = readFileSync(path.join(root, "VERSION"), "utf8").trim();
const manifest = readJson(".claude-plugin/plugin.json");
const hooks = readJson("hooks/hooks.json");

assert(manifest.name === "smooth-brain", "plugin name should be smooth-brain");
assert(manifest.version === version, "plugin manifest version should match VERSION");
assert(manifest.commands === "./commands/", "plugin should load root commands directory");
assert(manifest.skills === "./skills/", "plugin should load root skills directory");
assert(manifest.hooks === "./hooks/hooks.json", "plugin should load hooks/hooks.json");
assert(existsSync(path.join(root, "commands", "smooth-brain.md")), "plugin command should exist");
assert(existsSync(path.join(root, "skills", "smooth-brain", "SKILL.md")), "plugin skill should exist");
assert(existsSync(path.join(root, "bin", "smooth-brain-active.js")), "hook helper should exist");

const hookCommand = hooks.hooks?.UserPromptSubmit?.[0]?.hooks?.[0]?.command ?? "";
assert(
  hookCommand.includes("${CLAUDE_PLUGIN_ROOT}/bin/smooth-brain-active.js"),
  "hook should read active preset through the plugin helper",
);

const home = mkdtempSync(path.join(tmpdir(), "smooth-brain-plugin-"));
try {
  const claudeDir = path.join(home, ".claude");
  run("mkdir", ["-p", claudeDir]);
  const activeText = "# smooth-brain\n\nActive preset: smooth\n";
  writeFileSync(path.join(claudeDir, "smooth-brain-active"), activeText);
  const output = run("node", ["bin/smooth-brain-active.js"], { env: { HOME: home } });
  assert(output === activeText, "hook helper should print the active preset file");
} finally {
  rmSync(home, { recursive: true, force: true });
}

console.log("[smooth-brain] plugin layout tests passed");
