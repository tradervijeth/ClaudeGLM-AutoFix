"use strict";

const fs = require("fs");
const path = require("path");

async function ensureDir(dirPath) {
  await fs.promises.mkdir(dirPath, { recursive: true });
}

async function readFile(filePath, encoding = "utf8") {
  return fs.promises.readFile(filePath, encoding);
}

async function writeFile(filePath, contents, encoding = "utf8") {
  const dir = path.dirname(filePath);
  await ensureDir(dir);
  await fs.promises.writeFile(filePath, contents, { encoding });
}

async function fileExists(filePath) {
  try {
    await fs.promises.access(filePath, fs.constants.F_OK);
    return true;
  } catch {
    return false;
  }
}

module.exports = {
  ensureDir,
  readFile,
  writeFile,
  fileExists
};
