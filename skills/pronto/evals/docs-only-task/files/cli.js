#!/usr/bin/env node
// notes: append a line to today's note file.
const fs = require("fs");
const path = require("path");
const os = require("os");

const dir = process.env.NOTES_DIR || path.join(os.homedir(), "notes");
const text = process.argv.slice(2).join(" ");
if (!text) {
  console.error("usage: notes <text>");
  process.exit(1);
}
fs.mkdirSync(dir, { recursive: true });
const file = path.join(dir, new Date().toISOString().slice(0, 10) + ".md");
fs.appendFileSync(file, "- " + text + "\n");
console.log("saved to " + file);
