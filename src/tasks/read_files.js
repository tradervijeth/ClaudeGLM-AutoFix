"use strict";

const { readFile, fileExists } = require("../utils/file_system");
const logger = require("../utils/logger");

async function readFilesForPlan(plan) {
  if (!plan || !Array.isArray(plan.tasks)) {
    throw new Error("readFilesForPlan expects a FixPlan with tasks.");
  }

  const paths = new Set();

  for (const task of plan.tasks) {
    if (!task || !Array.isArray(task.files)) {
      continue;
    }

    for (const file of task.files) {
      if (!file || typeof file.path !== "string") {
        continue;
      }
      paths.add(file.path);

      if (Array.isArray(file.context_files)) {
        for (const contextPath of file.context_files) {
          if (typeof contextPath === "string") {
            paths.add(contextPath);
          }
        }
      }
    }
  }

  const results = [];

  for (const filePath of paths) {
    const exists = await fileExists(filePath);
    if (!exists) {
      logger.warn(`Context file not found: ${filePath}`);
      continue;
    }

    try {
      const content = await readFile(filePath, "utf8");
      results.push({ path: filePath, content });
    } catch (error) {
      logger.error(`Failed to read file ${filePath}: ${error.message}`);
    }
  }

  return results;
}

module.exports = {
  readFilesForPlan
};
