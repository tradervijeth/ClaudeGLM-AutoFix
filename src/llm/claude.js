"use strict";

const path = require("path");
const { spawn } = require("child_process");
const { readFile } = require("../utils/file_system");
const logger = require("../utils/logger");
const { validateFixPlan } = require("../validators/fixplan_validator");

let promptCache = null;

async function loadPromptTemplate() {
  if (promptCache) {
    return promptCache;
  }
  const templatePath = path.join(__dirname, "..", "..", "prompts", "claude_fixplan.txt");
  promptCache = await readFile(templatePath, "utf8");
  return promptCache;
}

function renderTemplate(template, variables) {
  return template.replace(/{{\s*([a-zA-Z0-9_]+)\s*}}/g, (match, key) => {
    if (Object.prototype.hasOwnProperty.call(variables, key)) {
      const value = variables[key];
      if (value === null || value === undefined) {
        return "";
      }
      return typeof value === "string" ? value : JSON.stringify(value, null, 2);
    }
    return "";
  });
}

function normalizeBuildCommands(buildCommands) {
  if (Array.isArray(buildCommands)) {
    return buildCommands.join(" && ");
  }
  if (typeof buildCommands === "string") {
    return buildCommands;
  }
  return "";
}

function serializeContextSnippets(snippets) {
  if (!Array.isArray(snippets)) {
    return JSON.stringify([], null, 2);
  }
  return JSON.stringify(snippets, null, 2);
}

async function generateFixPlan(options = {}) {
  const {
    repoName = "unknown-repo",
    attempt = 1,
    buildCommands = [],
    diagnostics = "",
    diagnosticsLimit = diagnostics.length,
    contextSnippets = [],
    previousSummary = "",
    model: modelOverride
  } = options;

  const model = modelOverride || process.env.CLAUDE_MODEL || "claude-3-5-sonnet";
  const template = await loadPromptTemplate();

  const replacements = {
    repo_name: repoName,
    attempt: String(attempt),
    build_commands: normalizeBuildCommands(buildCommands),
    diagnostics_limit: String(diagnosticsLimit),
    diagnostics,
    context_snippets: serializeContextSnippets(contextSnippets),
    previous_summary: previousSummary || "None",
    timestamp: new Date().toISOString(),
    model
  };

  const prompt = renderTemplate(template, replacements);
  logger.debug("Generated FixPlan prompt");

  const response = await callClaudeAPI(prompt, model);
  const plan = response;

  const validation = await validateFixPlan(plan);
  if (validation.valid) {
    return plan;
  }

  logger.warn("FixPlan failed schema validation", { errors: validation.errors });
  return {
    valid: false,
    errors: validation.errors || []
  };
}

const { debug, info, warn, error } = require("../utils/logger");

function extractJSON(raw) {
  const s = raw
    .replace(/^\s*```(?:json)?/i, "")
    .replace(/```\s*$/i, "")
    .trim();

  try {
    return JSON.parse(s);
  } catch (_) {}

  const start = s.indexOf("{");
  if (start === -1) throw new Error("No JSON object start found in Claude output.");
  let depth = 0;
  for (let i = start; i < s.length; i++) {
    const ch = s[i];
    if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) {
        const candidate = s.slice(start, i + 1);
        try {
          return JSON.parse(candidate);
        } catch (_) {}
      }
    }
  }
  throw new Error("Could not parse JSON from Claude output.");
}

async function callClaudeAPI(prompt, modelFromCaller) {
  const bin = process.env.CLAUDE_CLI || "claude";
  const model = process.env.CLAUDE_MODEL || modelFromCaller || "claude-3-5-sonnet";
  debug(`Calling Claude CLI "${bin}" with model "${model}"`);

  return new Promise((resolve, reject) => {
    const args = ["--model", model];
    const child = spawn(bin, args, { stdio: ["pipe", "pipe", "pipe"] });

    let out = "";
    let err = "";

    child.stdout.on("data", (d) => (out += d.toString()));
    child.stderr.on("data", (d) => (err += d.toString()));

    child.on("error", (e) => {
      reject(new Error(`Failed to start "${bin}": ${e.message}`));
    });

    child.on("close", (code) => {
      if (code !== 0) {
        return reject(
          new Error(
            `Claude CLI exited ${code}. stderr: ${err || "(empty)"} stdout: ${out.slice(0, 500)}`
          )
        );
      }
      try {
        const json = extractJSON(out);
        resolve(json);
      } catch (e) {
        reject(
          new Error(
            `Claude output was not valid JSON: ${e.message}\nRaw (first 800 chars):\n${out.slice(0, 800)}`
          )
        );
      }
    });

    child.stdin.write(prompt);
    child.stdin.end();
  });
}

module.exports = {
  generateFixPlan,
  callClaudeAPI
};
