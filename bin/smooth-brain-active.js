#!/usr/bin/env node
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const activeFile = path.join(os.homedir(), ".claude", "smooth-brain-active");

try {
  if (fs.existsSync(activeFile)) {
    process.stdout.write(fs.readFileSync(activeFile, "utf8"));
  }
} catch {
  // Hooks should never block a prompt because this optional style file is unreadable.
}
