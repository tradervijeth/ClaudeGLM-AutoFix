"use strict";

const path = require("path");
const logger = require("../utils/logger");
const { readFile, fileExists } = require("../utils/file_system");
const {
  applyUnifiedPatch,
  writeFullFile,
  deleteFile,
  renameFile
} = require("../utils/patch");
const { applyTask } = require("../llm/glm");

function resolvePath(cwd, targetPath) {
  return path.isAbsolute(targetPath) ? targetPath : path.join(cwd, targetPath);
}

async function collectSourceBlobs(task, cwd) {
  const filePaths = new Set();
  if (Array.isArray(task.files)) {
    for (const file of task.files) {
      if (file && typeof file.path === "string") {
        filePaths.add(file.path);
      }
      if (file && Array.isArray(file.context_files)) {
        for (const contextPath of file.context_files) {
          if (typeof contextPath === "string") {
            filePaths.add(contextPath);
          }
        }
      }
    }
  }

  const blobs = [];
  for (const filePath of filePaths) {
    const resolved = resolvePath(cwd, filePath);
    const exists = await fileExists(resolved);
    if (!exists) {
      logger.warn(`Source blob missing for task: ${filePath}`);
      continue;
    }

    try {
      const content = await readFile(resolved, "utf8");
      blobs.push({ path: filePath, content });
    } catch (error) {
      logger.error(`Failed to read source blob ${filePath}: ${error.message}`);
    }
  }

  return blobs;
}

function dependenciesMet(task, statusMap) {
  if (!Array.isArray(task.dependencies) || task.dependencies.length === 0) {
    return true;
  }
  return task.dependencies.every(
    (dep) => statusMap.has(dep) && statusMap.get(dep) === true
  );
}

async function applyPlan(options = {}) {
  const { plan, glmModel = "glm-4.6", cwd = process.cwd() } = options;

  if (!plan || !Array.isArray(plan.tasks)) {
    throw new Error("applyPlan requires a FixPlan with tasks.");
  }

  const summaries = [];
  const taskStatus = new Map();

  for (const task of plan.tasks) {
    const summary = {
      taskId: task.id || "unknown",
      title: task.title || "",
      success: false,
      editResults: [],
      notes: []
    };

    if (!dependenciesMet(task, taskStatus)) {
      summary.status = "skipped: unmet dependencies";
      logger.warn(
        `Skipping task ${summary.taskId} due to unmet dependencies: ${JSON.stringify(
          task.dependencies
        )}`
      );
      summaries.push(summary);
      taskStatus.set(task.id, false);
      continue;
    }

    logger.info(`Applying task ${summary.taskId} – ${summary.title}`);

    let sourceBlobs;
    try {
      sourceBlobs = await collectSourceBlobs(task, cwd);
    } catch (error) {
      logger.error(`Failed to collect source blobs for ${summary.taskId}: ${error.message}`);
      summary.status = `failed: source blob error`;
      summaries.push(summary);
      taskStatus.set(task.id, false);
      continue;
    }

    let glmResult;
    try {
      glmResult = await applyTask({
        task,
        sourceBlobs,
        globalConstraints: plan.overview?.constraints || [],
        model: glmModel
      });
    } catch (error) {
      logger.error(`GLM applyTask failed for ${summary.taskId}: ${error.message}`);
      summary.status = `failed: glm error`;
      summaries.push(summary);
      taskStatus.set(task.id, false);
      continue;
    }

    if (!glmResult || glmResult.task_id !== task.id || !Array.isArray(glmResult.edits)) {
      logger.error(`GLM returned invalid response for ${summary.taskId}`);
      summary.status = "failed: bad GLM response";
      summaries.push(summary);
      taskStatus.set(task.id, false);
      continue;
    }

    logger.debug(`GLM returned ${glmResult.edits.length} edits for ${summary.taskId}`);

    const editResults = [];
    let taskSuccess = true;

    for (const edit of glmResult.edits) {
      const editSummary = {
        path: edit.path || "",
        action: edit.action || "",
        ok: false,
        details: {}
      };

      try {
        switch (edit.action) {
          case "modify_file":
            if (edit.strategy === "unified_patch") {
              if (typeof edit.patch !== "string") {
                editSummary.details = { reason: "missing patch" };
                taskSuccess = false;
                break;
              }
              const result = await applyUnifiedPatch(edit.patch, { cwd });
              editSummary.ok = result.applied;
              editSummary.details = result;
              if (!result.applied) {
                taskSuccess = false;
              }
            } else if (edit.strategy === "file_rewrite") {
              if (typeof edit.content !== "string") {
                editSummary.details = { reason: "missing content" };
                taskSuccess = false;
                break;
              }
              const result = await writeFullFile(edit.path, edit.content, { cwd });
              editSummary.ok = result.written === true;
              editSummary.details = result;
              if (!editSummary.ok) {
                taskSuccess = false;
              }
            } else {
              editSummary.details = { reason: "unknown strategy" };
              taskSuccess = false;
            }
            break;

          case "create_file":
            if (typeof edit.content !== "string") {
              editSummary.details = { reason: "missing content" };
              taskSuccess = false;
              break;
            }
            {
              const result = await writeFullFile(edit.path, edit.content, { cwd });
              editSummary.ok = result.written === true;
              editSummary.details = result;
              if (!editSummary.ok) {
                taskSuccess = false;
              }
            }
            break;

          case "delete_file": {
            const result = await deleteFile(edit.path, { cwd });
            editSummary.ok = result.deleted === true;
            editSummary.details = result;
            if (!editSummary.ok && result.reason !== "missing") {
              taskSuccess = false;
            }
            break;
          }

          case "rename_file":
            if (typeof edit.target_path !== "string") {
              editSummary.details = { reason: "missing target_path" };
              taskSuccess = false;
              break;
            }
            {
              const result = await renameFile(edit.path, edit.target_path, { cwd });
              editSummary.ok = result.renamed === true;
              editSummary.details = result;
              if (!editSummary.ok) {
                taskSuccess = false;
              }
            }
            break;

          default:
            editSummary.details = { reason: "unknown action" };
            taskSuccess = false;
            break;
        }
      } catch (error) {
        logger.error(`Failed to apply edit for ${summary.taskId}: ${error.message}`);
        editSummary.details = { error: error.message };
        taskSuccess = false;
      }

      if (editSummary.ok) {
        logger.info(`Applied edit: ${editSummary.action} ${editSummary.path}`);
      } else {
        logger.warn(
          `Edit failed: ${editSummary.action} ${editSummary.path} ${JSON.stringify(editSummary.details)}`
        );
      }

      editResults.push(editSummary);
    }

    summary.success = taskSuccess;
    summary.editResults = editResults;
    summary.notes = Array.isArray(glmResult.notes) ? glmResult.notes : [];
    summary.status = taskSuccess ? "completed" : summary.status || "failed";

    summaries.push(summary);
    taskStatus.set(task.id, taskSuccess);
  }

  const allSuccessful = summaries.every((taskSummary) => taskSummary.success);

  return {
    tasks: summaries,
    allSuccessful
  };
}

module.exports = {
  applyPlan
};
