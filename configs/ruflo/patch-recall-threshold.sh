#!/usr/bin/env bash
# Patch memory-bridge.js: fix recall threshold mismatch
#
# bridgeHierarchicalRecall() and bridgeContextSynthesize() call
# HierarchicalMemory.recall() without passing a threshold, inheriting
# the agentdb default of 0.5.  bridgeSearchEntries() uses 0.3.
# Compound/multi-topic queries produce averaged embeddings that fall
# between 0.3-0.5, so they pass search but fail recall/synthesize.
#
# Also fixes key mapping in bridgeContextSynthesize: MemoryItem objects
# from real HierarchicalMemory store the user key in r.metadata.key,
# not r.key.
#
# Safe to re-run: checks for marker before patching.
set -euo pipefail

find_bridge() {
  for f in "$HOME"/.nvm/versions/node/*/lib/node_modules/ruflo/node_modules/@claude-flow/cli/dist/src/memory/memory-bridge.js; do
    if [ -f "$f" ]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

BRIDGE_JS=$(find_bridge) || { echo "[patch-rt] memory-bridge.js not found, skipping"; exit 0; }

# Already patched? Check for threshold: 0.3 in bridgeHierarchicalRecall
if grep -q 'threshold: 0\.3,' "$BRIDGE_JS" 2>/dev/null; then
  echo "[patch-rt] Already patched: $BRIDGE_JS"
  exit 0
fi

echo "[patch-rt] Patching: $BRIDGE_JS"

node -e "
const fs = require('fs');
const file = process.argv[1];
let code = fs.readFileSync(file, 'utf8');
let changed = false;

// Fix 1: bridgeHierarchicalRecall -- add threshold: 0.3 to MemoryQuery
// Original:
//   const memoryQuery = {
//       query: params.query,
//       k: params.topK || 5,
//   };
// Fixed:
//   const memoryQuery = {
//       query: params.query,
//       k: params.topK || 5,
//       threshold: 0.3,
//   };
const recallPattern = /const memoryQuery = \{\s*\n\s*query: params\.query,\s*\n\s*k: params\.topK \|\| 5,\s*\n\s*\};/;
if (recallPattern.test(code)) {
  code = code.replace(recallPattern,
    'const memoryQuery = {\n                query: params.query,\n                k: params.topK || 5,\n                threshold: 0.3,\n            };');
  changed = true;
  console.log('[patch-rt] Fixed bridgeHierarchicalRecall threshold');
}

// Fix 2: bridgeContextSynthesize -- add threshold: 0.3 to recall call
// Original: hm.recall({ query: params.query, k: params.maxEntries || 10 })
// Fixed:    hm.recall({ query: params.query, k: params.maxEntries || 10, threshold: 0.3 })
const synthRecallPattern = /hm\.recall\(\{ query: params\.query, k: params\.maxEntries \|\| 10 \}\)/;
if (synthRecallPattern.test(code)) {
  code = code.replace(synthRecallPattern,
    'hm.recall({ query: params.query, k: params.maxEntries || 10, threshold: 0.3 })');
  changed = true;
  console.log('[patch-rt] Fixed bridgeContextSynthesize threshold');
}

// Fix 3: bridgeContextSynthesize -- fix key mapping for MemoryItem
// Original: key: r.key || r.id || '',
// Fixed:    key: r.metadata?.key || r.key || r.id || '',
// Only target the one inside the .map() in bridgeContextSynthesize (near 'verdict')
const keyPattern = /key: r\.key \|\| r\.id \|\| '',\s*\n\s*reward: 1,/;
if (keyPattern.test(code)) {
  code = code.replace(keyPattern,
    \"key: r.metadata?.key || r.key || r.id || '',\n                reward: 1,\");
  changed = true;
  console.log('[patch-rt] Fixed bridgeContextSynthesize key mapping');
}

if (changed) {
  fs.writeFileSync(file, code);
  console.log('[patch-rt] Patch applied successfully');
} else {
  console.log('[patch-rt] WARNING: patterns not found -- may already be fixed or code has changed');
}
" "$BRIDGE_JS"
