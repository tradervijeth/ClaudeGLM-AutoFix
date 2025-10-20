"use strict";

const path = require("path");
const { readFile, fileExists } = require("../utils/file_system");
const logger = require("../utils/logger");
const { runPipeline } = require("./pipeline");

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case "--repo":
        args.repoName = argv[++i];
        break;
      case "--attempts":
        {
          const value = parseInt(argv[++i], 10);
          if (!Number.isNaN(value)) {
            args.maxAttempts = value;
          }
        }
        break;
      case "--diagnostics-limit":
        {
          const value = parseInt(argv[++i], 10);
          if (!Number.isNaN(value)) {
            args.diagnosticsLimit = value;
          }
        }
        break;
      case "--attempt-start":
        {
          const value = parseInt(argv[++i], 10);
          if (!Number.isNaN(value)) {
            args.attemptStart = value;
          }
        }
        break;
      case "--claude-model":
        args.claudeModel = argv[++i];
        break;
      case "--glm-model":
        args.glmModel = argv[++i];
        break;
      case "--build-command":
        if (!args.buildCommands) {
          args.buildCommands = [];
        }
        args.buildCommands.push(argv[++i]);
        break;
      case "--artifacts-dir":
        args.artifactsDir = argv[++i];
        break;
      default:
        break;
    }
  }
  return args;
}

async function loadConfig(cwd) {
  const configPath = path.join(cwd, "auto-fix.config.json");
  const exists = await fileExists(configPath);
  if (!exists) {
    return {};
  }
  const raw = await readFile(configPath, "utf8");
  try {
    return JSON.parse(raw);
  } catch (error) {
    logger.warn(`Failed to parse auto-fix.config.json: ${error.message}`);
    return {};
  }
}

function defaultBuildCommand(repoName) {
  return `xcodebuild -scheme ${repoName || "<REPLACE_ME>"} build`;
}

async function main() {
  const cwd = process.cwd();
  const config = await loadConfig(cwd);
  const args = parseArgs(process.argv.slice(2));

  const repoName = args.repoName || config.repoName || path.basename(cwd);
  const buildCommands = args.buildCommands || config.buildCommands || [defaultBuildCommand(repoName)];

  const options = {
    repoName,
    buildCommands,
    claudeModel: args.claudeModel || config.claudeModel,
    glmModel: args.glmModel || config.glmModel,
    diagnosticsLimit: args.diagnosticsLimit || config.diagnosticsLimit,
    maxAttempts: args.maxAttempts || config.maxAttempts,
    attemptStart: args.attemptStart || config.attemptStart,
    artifactsDir: args.artifactsDir || config.artifactsDir || "artifacts"
  };

  try {
    const result = await runPipeline(options);
    if (result.success) {
      console.log(
        `✅ Auto-fix succeeded on attempt ${result.attempt}. Artifacts: ${path.resolve(result.artifactsDir)}`
      );
      process.exit(0);
    }
    console.log(
      `❌ Auto-fix failed after attempt ${result.attempt} (reason: ${result.reason}). Artifacts: ${path.resolve(result.artifactsDir)}`
    );
    process.exit(1);
  } catch (error) {
    console.error(`Auto-fix pipeline encountered an error: ${error.message}`);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

module.exports = {
  main
};
