#!/usr/bin/env node
// Validates every skill in skills/: frontmatter shape, name/dir agreement,
// plugin.json coverage, and that relative markdown links resolve.
import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { join, dirname, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const skillsDir = join(root, "skills");
const errors = [];
const fail = (where, msg) => errors.push(`${where}: ${msg}`);

const skills = readdirSync(skillsDir).filter((n) =>
  statSync(join(skillsDir, n)).isDirectory(),
);

if (skills.length === 0) fail("skills/", "no skills found");

for (const name of skills) {
  const skillMd = join(skillsDir, name, "SKILL.md");
  if (!existsSync(skillMd)) {
    fail(`skills/${name}`, "missing SKILL.md");
    continue;
  }

  const source = readFileSync(skillMd, "utf8");
  const frontmatter = source.match(/^---\n([\s\S]*?)\n---\n/);
  if (!frontmatter) {
    fail(`skills/${name}/SKILL.md`, "missing YAML frontmatter");
    continue;
  }

  const fields = Object.fromEntries(
    frontmatter[1]
      .split("\n")
      .map((line) => line.match(/^([a-z-]+):\s*(.*)$/))
      .filter(Boolean)
      .map((m) => [m[1], m[2].replace(/^["']|["']$/g, "")]),
  );

  if (!fields.name) fail(`skills/${name}/SKILL.md`, "frontmatter has no name");
  else if (fields.name !== name)
    fail(`skills/${name}/SKILL.md`, `name "${fields.name}" does not match directory`);
  if (!fields.description)
    fail(`skills/${name}/SKILL.md`, "frontmatter has no description");
  else if (fields.description.length > 1024)
    fail(`skills/${name}/SKILL.md`, "description exceeds 1024 characters");

  // Relative links, in SKILL.md and every reference file.
  const files = [skillMd];
  const refs = join(skillsDir, name, "references");
  if (existsSync(refs))
    for (const f of readdirSync(refs).filter((f) => f.endsWith(".md")))
      files.push(join(refs, f));

  for (const file of files) {
    const text = readFileSync(file, "utf8");
    const rel = file.slice(root.length + 1);
    for (const [, target] of text.matchAll(/\]\((?!https?:|#|mailto:)([^)]+)\)/g)) {
      const [path, anchor] = target.split("#");
      const resolved = join(dirname(file), path);
      if (!existsSync(resolved)) {
        fail(rel, `broken link: ${target}`);
        continue;
      }
      if (!anchor) continue;
      const slugs = readFileSync(resolved, "utf8")
        .split("\n")
        .filter((l) => l.startsWith("#"))
        .map((l) =>
          l
            .replace(/^#+\s*/, "")
            .toLowerCase()
            .replace(/[^a-z0-9 -]/g, "")
            .trim()
            .replace(/\s+/g, "-"),
        );
      if (!slugs.includes(anchor)) fail(rel, `broken anchor: ${target}`);
    }
  }
}

// Every skill must be listed in the plugin manifest, and vice versa.
const plugin = JSON.parse(
  readFileSync(join(root, ".claude-plugin", "plugin.json"), "utf8"),
);
const listed = new Set((plugin.skills ?? []).map((p) => p.replace("./skills/", "")));
for (const name of skills)
  if (!listed.has(name)) fail(".claude-plugin/plugin.json", `does not list ${name}`);
for (const name of listed)
  if (!skills.includes(name))
    fail(".claude-plugin/plugin.json", `lists missing skill ${name}`);

if (errors.length) {
  console.error(`✗ ${errors.length} problem(s):\n${errors.map((e) => `  ${e}`).join("\n")}`);
  process.exit(1);
}
console.log(`✓ ${skills.length} skill(s) valid: ${skills.join(", ")}`);
