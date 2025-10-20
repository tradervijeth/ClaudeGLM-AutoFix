"use strict";

const path = require("path");
const { spawn } = require("child_process");
const { readFile } = require("../utils/file_system");
const logger = require("../utils/logger");
const { debug } = logger;

let promptCache = null;

async function loadPromptTemplate() {
  if (promptCache) {
    return promptCache;
  }
  const templatePath = path.join(__dirname, "..", "..", "prompts", "glm_apply.txt");
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

function formatAcceptance(acceptance) {
  if (!Array.isArray(acceptance) || acceptance.length === 0) {
    return "-";
  }
  return acceptance.map((line) => `- ${line}`).join("\n");
}

function formatNotes(notes) {
  if (!Array.isArray(notes) || notes.length === 0) {
    return "None";
  }
  return notes.map((line) => `- ${line}`).join("\n");
}

function formatConstraints(constraints) {
  if (!Array.isArray(constraints) || constraints.length === 0) {
    return "None";
  }
  return constraints.map((line) => `- ${line}`).join("\n");
}

function serializeArray(value) {
  if (!Array.isArray(value)) {
    return JSON.stringify([], null, 2);
  }
  return JSON.stringify(value, null, 2);
}

async function applyTask(options = {}) {
  const {
    task,
    sourceBlobs = [],
    globalConstraints = [],
    model: modelOverride
  } = options;

  if (!task) {
    throw new Error("applyTask requires a task object.");
  }

  const model = modelOverride || process.env.GLM_MODEL || "glm-4.6";
  const template = await loadPromptTemplate();

  const replacements = {
    task_id: task.id || "unknown-task",
    task_title: task.title || "",
    task_intent: task.intent || "",
    task_acceptance: formatAcceptance(task.acceptance),
    task_notes: formatNotes(task.notes),
    global_constraints: formatConstraints(globalConstraints),
    task_files: serializeArray(task.files),
    source_blobs: serializeArray(sourceBlobs)
  };

  const prompt = renderTemplate(template, replacements);
  logger.debug(`Generated GLM task prompt for ${task.id || "unknown-task"}`);

  const result = await callGLMAPI(prompt, model);

  if (!result || typeof result !== "object") {
    throw new Error("GLM response JSON is not an object.");
  }

  if (!result.task_id) {
    throw new Error("GLM response missing task_id.");
  }

  if (!Array.isArray(result.edits)) {
    throw new Error("GLM response missing edits array.");
  }

  return result;
}

function stripAnsi(s) {
  return s.replace(
    /[\u001b\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]/g,
    ""
  );
}

function extractJSON(raw) {
  const s = raw
    .replace(/^\s*```(?:json)?/i, "")
    .replace(/```\s*$/i, "")
    .trim();
  try {
    return JSON.parse(s);
  } catch (_) {}
  const start = s.indexOf("{");
  if (start === -1) throw new Error("No JSON object in GLM output");
  let depth = 0;
  for (let i = start; i < s.length; i++) {
    const ch = s[i];
    if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) {
        const cand = s.slice(start, i + 1);
        try {
          return JSON.parse(cand);
        } catch (_) {}
      }
    }
  }
  throw new Error("Unable to parse JSON from GLM output");
}

async function callGLMAPI(prompt, modelFromCaller = "glm-4.6") {
  const bin = process.env.CCG_CLI || "ccg";
  const extra = (process.env.CCG_ARGS || `--model ${modelFromCaller}`).trim();
  const args = extra.length ? extra.split(/\s+/) : [];
  debug(`Calling CCG CLI "${bin}" with args: ${args.join(" ")}`);

  return new Promise((resolve, reject) => {
    const child = spawn(bin, args, { stdio: ["pipe", "pipe", "pipe"] });

    let out = "";
    let err = "";

    child.stdout.on("data", (d) => {
      out += d.toString();
    });
    child.stderr.on("data", (d) => {
      err += d.toString();
    });
    child.on("error", (e) => reject(new Error(`Failed to start "${bin}": ${e.message}`)));

    const t = setTimeout(() => {
      try {
        child.kill("SIGKILL");
      } catch (_) {}
      reject(new Error(`CCG CLI timed out. stderr: ${err.slice(0, 500)}`));
    }, 90_000);

    child.on("close", (code) => {
      clearTimeout(t);
      if (code !== 0) {
        return reject(new Error(`CCG exited ${code}. stderr: ${err || "(empty)"}`));
      }
      const clean = stripAnsi(out);
      try {
        const json = extractJSON(clean);
        resolve(json);
      } catch (e) {
        reject(
          new Error(
            `GLM output not valid JSON: ${e.message}\nRaw (first 800):\n${clean.slice(0, 800)}`
          )
        );
      }
    });

    child.stdin.write(prompt);
    child.stdin.end();
  });
}

module.exports = {
  applyTask,
  callGLMAPI
};
