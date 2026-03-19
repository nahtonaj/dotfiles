#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const STATE_FILE = path.join(process.env.HOME, '.claude', '.ruflo-state.json');

function readState() {
  try {
    return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
  } catch {
    return {};
  }
}

function validatePreSpawn() {
  const state = readState();
  const warnings = [];
  const now = Date.now();
  const threshold = 60000; // 60s window

  if (!state.lastMemorySearch || (now - state.lastMemorySearch) > threshold) {
    warnings.push('[ENFORCEMENT] memory_search was not called before spawning agent');
  }
  if (!state.lastSemanticRoute || (now - state.lastSemanticRoute) > threshold) {
    warnings.push('[ENFORCEMENT] agentdb_semantic-route was not called before spawning agent');
  }
  if (state.dddRequired && !state.dddAgentSpawned) {
    warnings.push('[ENFORCEMENT] DDD routing required but no ddd-domain-expert spawned');
  }

  if (warnings.length > 0) {
    console.error(warnings.join('\n'));
  }
}

const action = process.argv[2];
if (action === 'subagent-start') {
  validatePreSpawn();
}
