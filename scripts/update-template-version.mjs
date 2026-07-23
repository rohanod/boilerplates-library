#!/usr/bin/env node

import { readdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { createInterface } from "node:readline/promises";
import { fileURLToPath } from "node:url";

const VERSION_PATTERN = /^v?\d+(?:\.\d+)+(?:[-+][0-9A-Za-z.-]+)?$/;

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function latestRelease(repo, current) {
  const response = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, {
    headers: {
      Accept: "application/vnd.github+json",
      "User-Agent": "boilerplates-version-updater",
    },
  });
  if (!response.ok) throw new Error(`GitHub returned HTTP ${response.status}`);
  const tag = String((await response.json()).tag_name ?? "").trim();
  if (!tag) throw new Error(`GitHub returned no release tag for ${repo}`);
  const bare = tag.replace(/^v/, "");
  return current.startsWith("v") ? `v${bare}` : bare;
}

function validateVersion(version) {
  const trimmed = version.trim();
  if (!VERSION_PATTERN.test(trimmed)) throw new Error(`invalid version: ${JSON.stringify(trimmed)}`);
  return trimmed;
}

async function filesUnder(directory) {
  const result = [];
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const child = path.join(directory, entry.name);
    if (entry.isDirectory()) result.push(...(await filesUnder(child)));
    else if (entry.isFile()) result.push(child);
  }
  return result.sort();
}

async function prepareChanges(templateDir, newVersion) {
  const templatePath = path.join(templateDir, "template.json");
  const data = JSON.parse(await readFile(templatePath, "utf8"));
  const version = data.metadata.version;
  const current = String(version.source_dep_version).trim();
  const sourceDep = String(version.source_dep_name).trim();

  if (newVersion === current) return { current, changes: new Map() };

  const pattern = new RegExp(
    `^(\\s*image:\\s*${escapeRegex(sourceDep)}:)${escapeRegex(current)}(\\s*(?:#.*)?)$`,
    "gm",
  );
  const changes = new Map();
  let replacements = 0;
  for (const file of await filesUnder(path.join(templateDir, "files"))) {
    const original = await readFile(file, "utf8");
    const updated = original.replace(pattern, (...match) => {
      replacements += 1;
      return `${match[1]}${newVersion}${match[2]}`;
    });
    if (updated !== original) changes.set(file, updated);
  }

  if (!replacements) {
    throw new Error(`no ${sourceDep}:${current} image reference found under ${path.join(templateDir, "files")}`);
  }

  version.name = newVersion;
  version.source_dep_version = newVersion;
  const updatedTemplate = `${JSON.stringify(data, null, 2)}\n`;
  JSON.parse(updatedTemplate);
  changes.set(templatePath, updatedTemplate);
  return { current, changes };
}

async function writeChanges(changes) {
  const temporary = new Map();
  try {
    for (const [file, content] of changes) {
      const temp = `${file}.${process.pid}.tmp`;
      await writeFile(temp, content, "utf8");
      temporary.set(file, temp);
    }
    for (const [file, temp] of temporary) await rename(temp, file);
  } finally {
    await Promise.all([...temporary.values()].map((temp) => rm(temp, { force: true })));
  }
}

function usage() {
  console.error("Usage: scripts/update-template-version.mjs TEMPLATE [VERSION]");
}

async function main() {
  const [template, explicitVersion, ...extra] = process.argv.slice(2);
  if (!template || extra.length) {
    usage();
    return 1;
  }

  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const templateDir = path.join(root, "compose", template);
  const templatePath = path.join(templateDir, "template.json");
  let data;
  try {
    data = JSON.parse(await readFile(templatePath, "utf8"));
  } catch {
    console.error(`Template not found or invalid: ${template}`);
    return 1;
  }

  const metadata = data?.metadata?.version ?? {};
  const current = String(metadata.source_dep_version ?? "").trim();
  if (!current) {
    console.error("Template has no source_dep_version");
    return 1;
  }

  let prompt;
  const ask = async (question) => {
    prompt ??= createInterface({ input: process.stdin, output: process.stdout });
    return prompt.question(question);
  };
  try {
    let proposed = explicitVersion;
    if (!proposed) {
      const sourceRepo = String(metadata.source_repo ?? "").trim();
      try {
        if (!sourceRepo) throw new Error("template has no metadata.version.source_repo");
        proposed = await latestRelease(sourceRepo, current);
        console.log(`Latest release from ${sourceRepo}: ${proposed}`);
      } catch (error) {
        console.error(`Automatic detection failed: ${error.message}`);
        proposed = await ask("Enter the newest version manually: ");
      }
    }

    proposed = validateVersion(proposed);
    const prepared = await prepareChanges(templateDir, proposed);
    if (!prepared.changes.size) {
      console.log(`${template} is already at ${prepared.current}`);
      return 0;
    }

    console.log(`Update ${template}: ${prepared.current} -> ${proposed}`);
    const confirmation = (await ask("Apply this update? [y/N] ")).trim().toLowerCase();
    if (confirmation !== "y" && confirmation !== "yes") {
      console.log("No changes made");
      return 0;
    }

    await writeChanges(prepared.changes);
    console.log("Updated:");
    for (const file of [...prepared.changes.keys()].sort()) {
      console.log(`  ${path.relative(root, file)}`);
    }
    return 0;
  } catch (error) {
    console.error(`Cannot update ${template}: ${error.message}`);
    return 1;
  } finally {
    prompt?.close();
  }
}

process.exitCode = await main();
