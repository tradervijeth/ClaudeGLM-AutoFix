"use strict";

const path = require("path");
const Ajv = require("ajv");
const { readFile } = require("../utils/file_system");
const logger = require("../utils/logger");

let validator = null;

function loadSchema() {
  try {
    const schemaPath = path.join(__dirname, "..", "..", "schemas", "fixplan.schema.json");
    return require(schemaPath);
  } catch (error) {
    logger.error(`Failed to load FixPlan schema: ${error.message}`);
    throw error;
  }
}

function getValidator() {
  if (validator) {
    return validator;
  }
  const ajv = new Ajv({
    allErrors: true,
    strict: false // Change to true later if needed
  });
  validator = ajv.compile(loadSchema());
  return validator;
}

async function parsePlan(planOrPath) {
  if (typeof planOrPath === "string") {
    try {
      const contents = await readFile(planOrPath, "utf8");
      return JSON.parse(contents);
    } catch (error) {
      logger.error(`Failed to parse FixPlan JSON at ${planOrPath}: ${error.message}`);
      throw error;
    }
  }

  if (typeof planOrPath === "object" && planOrPath !== null) {
    return planOrPath;
  }

  throw new TypeError("validateFixPlan expected a file path or plan object.");
}

async function validateFixPlan(planOrPath) {
  const plan = await parsePlan(planOrPath);
  const validate = getValidator();
  const valid = validate(plan);

  if (valid) {
    return { valid: true };
  }

  return {
    valid: false,
    errors: validate.errors || []
  };
}

module.exports = {
  validateFixPlan
};
