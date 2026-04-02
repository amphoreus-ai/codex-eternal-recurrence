#!/usr/bin/env node

import { mkdir, readFile, writeFile, copyFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, resolve, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = resolve(__dirname, "..");
const sourceDir = join(rootDir, ".codex");
const targetDir = join(process.cwd(), ".codex");

const hookScriptPath = join(targetDir, "hooks", "eternal-recurrence.sh");
const configPath = join(targetDir, "config.toml");
const hooksJsonPath = join(targetDir, "hooks.json");

const sourceHookScriptPath = join(sourceDir, "hooks", "eternal-recurrence.sh");
const sourceConfigPath = join(sourceDir, "config.toml");
const sourceHooksJsonPath = join(sourceDir, "hooks.json");

const hookCommand = "sh .codex/hooks/eternal-recurrence.sh";

async function exists(filePath) {
  try {
    await readFile(filePath);
    return true;
  } catch {
    return false;
  }
}

function hasHookCommand(value) {
  if (!value || typeof value !== "object") return false;
  if (value.command === hookCommand) return true;
  return Object.values(value).some(hasHookCommand);
}

async function isInstalled() {
  if (!(await exists(hookScriptPath)) || !(await exists(configPath)) || !(await exists(hooksJsonPath))) {
    return false;
  }

  const [sourceConfig, targetConfig, targetHooksJson] = await Promise.all([
    readFile(sourceConfigPath, "utf8"),
    readFile(configPath, "utf8"),
    readFile(hooksJsonPath, "utf8"),
  ]);

  return targetConfig.includes(sourceConfig.trim()) && hasHookCommand(JSON.parse(targetHooksJson));
}

async function install() {
  if (await isInstalled()) {
    process.exit(0);
  }

  await mkdir(join(targetDir, "hooks"), { recursive: true });
  await copyFile(sourceHookScriptPath, hookScriptPath);

  const sourceConfig = await readFile(sourceConfigPath, "utf8");
  if (await exists(configPath)) {
    const targetConfig = await readFile(configPath, "utf8");
    if (!targetConfig.includes(sourceConfig.trim())) {
      await writeFile(configPath, `${targetConfig.replace(/\s*$/, "\n\n")}${sourceConfig}`);
    }
  } else {
    await copyFile(sourceConfigPath, configPath);
  }

  const sourceHooksJson = JSON.parse(await readFile(sourceHooksJsonPath, "utf8"));
  if (await exists(hooksJsonPath)) {
    const targetHooksJson = JSON.parse(await readFile(hooksJsonPath, "utf8"));
    targetHooksJson.hooks ??= {};

    for (const [eventName, sourceEntries] of Object.entries(sourceHooksJson.hooks ?? {})) {
      targetHooksJson.hooks[eventName] ??= [];
      for (const sourceEntry of sourceEntries) {
        if (!targetHooksJson.hooks[eventName].some((targetEntry) => JSON.stringify(targetEntry) === JSON.stringify(sourceEntry))) {
          targetHooksJson.hooks[eventName].push(sourceEntry);
        }
      }
    }

    await writeFile(hooksJsonPath, `${JSON.stringify(targetHooksJson, null, 2)}\n`);
  } else {
    await copyFile(sourceHooksJsonPath, hooksJsonPath);
  }

  process.exit(0);
}

install();
