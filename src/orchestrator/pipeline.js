"use strict";

const path = require("path");
const { ensureDir, writeFile } = require("../utils/file_system");
const logger = require("../utils/logger");
const { runBuild } = require("../tasks/run_build");
const { generateFixPlan } = require("../llm/claude");
const { applyPlan } = require("../tasks/apply_plan");

async function saveArtifact(baseDir, name, contents) {
  const resolvedDir = path.resolve(baseDir);
  await ensureDir(resolvedDir);
  const filePath = path.join(resolvedDir, name);
  await writeFile(filePath, contents, "utf8");
  logger.debug(`Saved artifact: ${filePath}`);
}

function normalizeCommands(buildCommands) {
  if (!buildCommands) {
    return [];
  }
  if (Array.isArray(buildCommands)) {
    return buildCommands;
  }
  return [String(buildCommands)];
}

async function runPipeline(options = {}) {
  const {
    repoName = path.basename(process.cwd()),
    buildCommands,
    claudeModel = "claude-3-sonnet",
    glmModel = "glm-4.6",
    diagnosticsLimit = 20000,
    attemptStart = 1,
    maxAttempts = 2,
    artifactsDir = "artifacts",
    previousSummary = null
  } = options;

  await ensureDir(artifactsDir);
  let priorSummary = previousSummary;

  const commandList = normalizeCommands(buildCommands);
  if (commandList.length === 0) {
    throw new Error("runPipeline requires at least one build command.");
  }

  for (let attempt = attemptStart; attempt < attemptStart + maxAttempts; attempt += 1) {
    logger.info(`[Attempt ${attempt}] Running build/tests…`);
    const build1 = await runBuild(commandList);
    await saveArtifact(
      artifactsDir,
      `attempt-${attempt}-prebuild.log`,
      build1.output || ""
    );

    if (build1.success) {
      logger.info(`[Attempt ${attempt}] Build already successful. Nothing to fix.`);
      return {
        attempt,
        success: true,
        reason: "already_builds",
        artifactsDir
      };
    }

    const diagnostics = (build1.output || "").slice(0, diagnosticsLimit);

    let plan;
    try {
      plan = await generateFixPlan({
        repoName,
        attempt,
        buildCommands: commandList.join(" && "),
        diagnostics,
        diagnosticsLimit,
        contextSnippets: [],
        previousSummary: priorSummary ? JSON.stringify(priorSummary) : "",
        model: claudeModel
      });
    } catch (error) {
      logger.error(`[Attempt ${attempt}] Failed to generate FixPlan: ${error.message}`);
      return {
        attempt,
        success: false,
        reason: "plan_generation_failed",
        error: error.message,
        artifactsDir
      };
    }

    await saveArtifact(
      artifactsDir,
      `attempt-${attempt}-fixplan.json`,
      JSON.stringify(plan, null, 2)
    );

    if (plan && plan.valid === false) {
      logger.warn(`[Attempt ${attempt}] FixPlan validation failed; stopping.`);
      return {
        attempt,
        success: false,
        reason: "invalid_plan",
        errors: plan.errors,
        artifactsDir
      };
    }

    if (!plan.tasks || plan.tasks.length === 0) {
      logger.warn(`[Attempt ${attempt}] FixPlan has no tasks; stopping.`);
      return {
        attempt,
        success: false,
        reason: "empty_plan",
        artifactsDir
      };
    }

    let applyResult;
    try {
      applyResult = await applyPlan({ plan, glmModel, cwd: process.cwd() });
    } catch (error) {
      logger.error(`[Attempt ${attempt}] Failed while applying FixPlan: ${error.message}`);
      return {
        attempt,
        success: false,
        reason: "apply_failed",
        error: error.message,
        artifactsDir
      };
    }
    await saveArtifact(
      artifactsDir,
      `attempt-${attempt}-apply-summary.json`,
      JSON.stringify(applyResult, null, 2)
    );

    if (!applyResult.allSuccessful) {
      logger.warn(`[Attempt ${attempt}] Not all edits applied cleanly.`);
    }

    const build2 = await runBuild(commandList);
    await saveArtifact(
      artifactsDir,
      `attempt-${attempt}-postbuild.log`,
      build2.output || ""
    );

    if (build2.success) {
      logger.info(`[Attempt ${attempt}] Build fixed ✅`);
      return {
        attempt,
        success: true,
        reason: "fixed",
        applySummary: applyResult,
        artifactsDir
      };
    }

    priorSummary = {
      attempt,
      applySummary: applyResult
    };
  }

  const finalAttempt = attemptStart + maxAttempts - 1;
  logger.warn(`[Attempt ${finalAttempt}] Max attempts reached without success.`);
  return {
    attempt: finalAttempt,
    success: false,
    reason: "max_attempts_reached",
    artifactsDir
  };
}

module.exports = {
  runPipeline
};
