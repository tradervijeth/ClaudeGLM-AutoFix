"use strict";

const LEVELS = {
  error: 0,
  warn: 1,
  info: 2,
  debug: 3
};

// Use AUTO_FIX_LOG_LEVEL env var to set current level. Default to "info".
const requestedLevel = (process.env.AUTO_FIX_LOG_LEVEL || "info").toLowerCase();
const CURRENT_LEVEL = LEVELS.hasOwnProperty(requestedLevel) ? requestedLevel : "info";

function timestamp() {
  return new Date().toISOString();
}

function shouldLog(level) {
  return LEVELS[level] <= LEVELS[CURRENT_LEVEL];
}

function formatMessage(level, message) {
  return `[${timestamp()}] ${level.toUpperCase()}: ${message}`;
}

function info(message) {
  if (shouldLog("info")) {
    console.log(formatMessage("info", message));
  }
}

function warn(message) {
  if (shouldLog("warn")) {
    console.warn(formatMessage("warn", message));
  }
}

function error(message) {
  if (shouldLog("error")) {
    console.error(formatMessage("error", message));
  }
}

function debug(message) {
  if (shouldLog("debug")) {
    console.log(formatMessage("debug", message));
  }
}

module.exports = {
  info,
  warn,
  error,
  debug
};
