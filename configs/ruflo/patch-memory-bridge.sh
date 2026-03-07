#!/usr/bin/env bash
# Patch memory-bridge.js: fix bridgeStorePattern/bridgeSearchPatterns
#
# bridgeStorePattern() passes an object to ReasoningBank.store() which
# expects positional args (pattern, type, confidence).
# bridgeSearchPatterns() passes (query, {topK, minScore}) to
# ReasoningBank.search() which expects (query, topK, minConfidence).
#
# Safe to re-run: checks for marker before patching.
set -euo pipefail

find_bridge() {
  local candidates=(
    "$HOME/.nvm/versions/node/$(node -v 2>/dev/null)/lib/node_modules/ruflo/node_modules/@claude-flow/cli/dist/src/memory/memory-bridge.js"
    "$HOME/.npm-global/lib/node_modules/ruflo/node_modules/@claude-flow/cli/dist/src/memory/memory-bridge.js"
    "/usr/local/lib/node_modules/ruflo/node_modules/@claude-flow/cli/dist/src/memory/memory-bridge.js"
  )
  for f in "${candidates[@]}"; do
    if [ -f "$f" ]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

BRIDGE_JS=$(find_bridge) || { echo "[patch-mb] memory-bridge.js not found, skipping"; exit 0; }

# Already patched? Check for positional-arg store call
if grep -q 'reasoningBank\.store(options\.pattern,' "$BRIDGE_JS" 2>/dev/null; then
  echo "[patch-mb] Already patched: $BRIDGE_JS"
  exit 0
fi

echo "[patch-mb] Patching: $BRIDGE_JS"

# Use node for reliable multi-line JS replacement
node -e "
const fs = require('fs');
const file = process.argv[1];
let code = fs.readFileSync(file, 'utf8');
let changed = false;

// Fix 1: bridgeStorePattern — object arg → positional args
// Original: reasoningBank.store({ id: patternId, content: options.pattern, ... })
// Fixed:    reasoningBank.store(options.pattern, options.type || 'general', options.confidence ?? 0.8)
const storeBroken = /await reasoningBank\.store\(\{[^}]*\}\)/s;
if (storeBroken.test(code)) {
  code = code.replace(storeBroken,
    \"await reasoningBank.store(options.pattern, options.type || 'general', options.confidence ?? 0.8)\");
  changed = true;
  console.log('[patch-mb] Fixed bridgeStorePattern');
}

// Fix 2: bridgeSearchPatterns — object 2nd arg → positional args
// Original: reasoningBank.search(options.query, { topK: ..., minScore: ... })
// Fixed:    reasoningBank.search(options.query, options.topK || 5, options.minConfidence || 0.3)
const searchBroken = /await reasoningBank\.search\(options\.query,\s*\{[^}]*\}\)/s;
if (searchBroken.test(code)) {
  code = code.replace(searchBroken,
    'await reasoningBank.search(options.query, options.topK || 5, options.minConfidence || 0.3)');
  changed = true;
  console.log('[patch-mb] Fixed bridgeSearchPatterns');
}

if (changed) {
  fs.writeFileSync(file, code);
  console.log('[patch-mb] Patch applied successfully');
} else {
  console.log('[patch-mb] WARNING: broken patterns not found — may need manual review');
}
" "$BRIDGE_JS"
