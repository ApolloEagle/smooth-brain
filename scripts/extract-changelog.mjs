#!/usr/bin/env node
import { readFileSync } from "node:fs";

const version = process.argv[2] || readFileSync("VERSION", "utf8").trim();
const changelog = readFileSync("CHANGELOG.md", "utf8");
const escaped = version.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const match = changelog.match(new RegExp(`## \\[${escaped}\\][^\\n]*\\n([\\s\\S]*?)(?=\\n## \\[|\\n?$)`));

if (!match) {
  throw new Error(`No changelog entry found for ${version}`);
}

console.log(match[1].trim());
