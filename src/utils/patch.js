"use strict";

const fs = require("fs");
const path = require("path");
const { spawn } = require("child_process");
const logger = require("./logger");
const { ensureDir, writeFile, fileExists } = require("./file_system");

function resolvePath(targetPath, cwd = process.cwd()) {
  return path.isAbsolute(targetPath) ? targetPath : path.join(cwd, targetPath);
}

async function recordPatchArtifact(patchText, cwd) {
  const artifactsDir = path.join(cwd, "artifacts");
  await ensureDir(artifactsDir);
  const fileName = `patch-${Date.now()}.diff`;
  const artifactPath = path.join(artifactsDir, fileName);
  await writeFile(artifactPath, patchText, "utf8");
  logger.debug(`Stored patch artifact at ${artifactPath}`);
}

async function applyUnifiedPatch(patchText, opts = {}) {
  const cwd = opts.cwd || process.cwd();
  await recordPatchArtifact(patchText, cwd);

  return new Promise((resolve) => {
    const child = spawn("git", ["apply", "--whitespace=nowarn", "--reject", "--unsafe-paths", "-"], {
      cwd,
      stdio: ["pipe", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", (error) => {
      logger.error(`git apply failed: ${error.message}`);
      resolve({
        applied: false,
        stdout,
        stderr: `${stderr}${stderr ? "\n" : ""}${error.message}`
      });
    });

    child.on("close", (code) => {
      const applied = code === 0;
      if (!applied) {
        logger.warn(
          `git apply returned non-zero exit code ${code}: ${stderr || "no stderr"}`
        );
      } else {
        logger.info("git apply succeeded");
      }
      resolve({
        applied,
        stdout,
        stderr
      });
    });

    child.stdin.end(patchText);
  });
}

async function writeFullFile(filePath, content, opts = {}) {
  const cwd = opts.cwd || process.cwd();
  const targetPath = resolvePath(filePath, cwd);
  await ensureDir(path.dirname(targetPath));
  await writeFile(targetPath, content, "utf8");
  logger.info(`Wrote file ${targetPath}`);
  return { written: true };
}

async function deleteFile(filePath, opts = {}) {
  const cwd = opts.cwd || process.cwd();
  const targetPath = resolvePath(filePath, cwd);
  const exists = await fileExists(targetPath);
  if (!exists) {
    logger.warn(`File not found for deletion: ${targetPath}`);
    return { deleted: false, reason: "missing" };
  }

  await fs.promises.unlink(targetPath);
  logger.info(`Deleted file ${targetPath}`);
  return { deleted: true };
}

async function renameFile(fromPath, toPath, opts = {}) {
  const cwd = opts.cwd || process.cwd();
  const source = resolvePath(fromPath, cwd);
  const target = resolvePath(toPath, cwd);
  await ensureDir(path.dirname(target));

  try {
    await fs.promises.rename(source, target);
  } catch (error) {
    if (error.code === "EXDEV") {
      const data = await fs.promises.readFile(source);
      await fs.promises.writeFile(target, data);
      await fs.promises.unlink(source);
    } else {
      logger.error(`Failed to rename ${source} to ${target}: ${error.message}`);
      throw error;
    }
  }

  logger.info(`Renamed file ${source} -> ${target}`);
  return { renamed: true };
}

module.exports = {
  applyUnifiedPatch,
  writeFullFile,
  deleteFile,
  renameFile
};
