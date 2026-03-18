#!/usr/bin/env bash
# Patch diff-classifier.js: fix ESM/CJS mismatch
#
# diff-classifier.js uses require('child_process') and require('util')
# but the package is "type": "module" (ESM). Node throws "require is not defined".
# Fix: add ESM imports at the top and remove inline require() calls.
#
# Safe to re-run: checks for marker before patching.
set -euo pipefail

find_diff_classifier() {
  for f in "$HOME"/.nvm/versions/node/*/lib/node_modules/ruflo/node_modules/@claude-flow/cli/dist/src/ruvector/diff-classifier.js; do
    if [ -f "$f" ]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

DIFF_JS=$(find_diff_classifier) || { echo "[patch-dc] diff-classifier.js not found, skipping"; exit 0; }

# Already patched? Check for ESM import of child_process
if grep -q "^import.*execFileSync.*from 'child_process'" "$DIFF_JS" 2>/dev/null; then
  echo "[patch-dc] Already patched: $DIFF_JS"
  exit 0
fi

# Verify the bug exists
if ! grep -q "require('child_process')" "$DIFF_JS" 2>/dev/null; then
  echo "[patch-dc] No require('child_process') found, skipping: $DIFF_JS"
  exit 0
fi

echo "[patch-dc] Patching: $DIFF_JS"

node -e "
const fs = require('fs');
const file = process.argv[1];
let code = fs.readFileSync(file, 'utf8');
let changed = false;

// Fix 1: Add ESM imports at the top of the file (after the initial comment block)
const importBlock = [
  \"import { execFileSync, execFile } from 'child_process';\",
  \"import { promisify } from 'util';\",
  \"const execFileAsync = promisify(execFile);\",
].join('\n');

// Insert after the opening comment
const commentEnd = code.indexOf('*/');
if (commentEnd !== -1) {
  const insertPos = code.indexOf('\n', commentEnd) + 1;
  code = code.slice(0, insertPos) + importBlock + '\n' + code.slice(insertPos);
  changed = true;
  console.log('[patch-dc] Added ESM imports');
}

// Fix 2: Remove inline require('child_process') calls
// In getGitDiffNumstat (sync):
const syncRequire = /const \{ execFileSync \} = require\('child_process'\);\n/g;
if (syncRequire.test(code)) {
  code = code.replace(syncRequire, '');
  changed = true;
  console.log('[patch-dc] Removed sync require(child_process)');
}

// In getGitDiffNumstatAsync (async):
const asyncRequire = /const \{ execFile \} = require\('child_process'\);\n\s*const \{ promisify \} = require\('util'\);\n\s*const execFileAsync = promisify\(execFile\);\n/g;
if (asyncRequire.test(code)) {
  code = code.replace(asyncRequire, '');
  changed = true;
  console.log('[patch-dc] Removed async require(child_process/util)');
}

if (changed) {
  fs.writeFileSync(file, code);
  console.log('[patch-dc] Patch applied successfully');
} else {
  console.log('[patch-dc] WARNING: patterns not matched — may need manual review');
}
" "$DIFF_JS"
