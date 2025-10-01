#!/usr/bin/env node

/**
 * Preinstall script to prevent incorrect installation method
 * This package should be run with npx, not installed as a dependency
 */

// Check if being installed as a dependency vs run via npx
// When using npx, npm sets npm_execpath to npx or the install is in a temp directory
const isNpxInstall = process.env.npm_execpath && process.env.npm_execpath.includes('npx');
const isTempInstall = process.env.npm_config_cache && process.cwd().includes('_npx');

// Also check if being installed globally (which is acceptable)
const isGlobalInstall = process.env.npm_config_global === 'true';

// If it's being installed as a local dependency, show warning and exit
if (!isNpxInstall && !isTempInstall && !isGlobalInstall) {
  console.error('\n❌ ERROR: Incorrect installation method!\n');
  console.error('This package is meant to be run directly with npx, not installed as a dependency.\n');
  console.error('✅ Correct usage:');
  console.error('   npx claude-glm-installer\n');
  console.error('❌ Do NOT use:');
  console.error('   npm install claude-glm-installer');
  console.error('   npm i claude-glm-installer\n');
  console.error('For global installation, use:');
  console.error('   npm install -g claude-glm-installer\n');

  process.exit(1);
}

// Allow installation to proceed for npx or global installs
process.exit(0);
