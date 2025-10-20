"use strict";

const { spawn } = require("child_process");
const logger = require("../utils/logger");

async function executeCommand(command) {
  return new Promise((resolve) => {
    const child = spawn("bash", ["-lc", command], {
      stdio: ["ignore", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("close", (code) => {
      resolve({
        code,
        stdout,
        stderr
      });
    });
  });
}

async function runBuild(commands) {
  const commandList = Array.isArray(commands) ? commands : [commands];
  const combinedOutput = [];

  for (const command of commandList) {
    if (!command || typeof command !== "string") {
      continue;
    }

    logger.info(`Running command: ${command}`);
    const result = await executeCommand(command);

    combinedOutput.push(result.stdout);
    combinedOutput.push(result.stderr);

    if (result.code !== 0) {
      return {
        success: false,
        output: combinedOutput.join("\n")
      };
    }
  }

  return {
    success: true,
    output: combinedOutput.join("\n")
  };
}

module.exports = {
  runBuild
};
