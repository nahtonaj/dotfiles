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

function writeState(state) {
  const dir = path.dirname(STATE_FILE);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function trackCall(toolName) {
  const state = readState();
  const now = Date.now();

  if (toolName.includes('memory_search')) state.lastMemorySearch = now;
  if (toolName.includes('semantic-route')) state.lastSemanticRoute = now;
  if (toolName.includes('pattern-store')) state.lastPatternStore = now;
  if (toolName.includes('hierarchical-store')) {
    state.pendingResults = Math.max(0, (state.pendingResults || 0) - 1);
  }
  if (toolName.includes('coordination_metrics')) state.lastMetrics = now;

  writeState(state);
}

function recordAgentSpawn(agentType) {
  const state = readState();
  if (agentType && agentType.includes('ddd')) {
    state.dddAgentSpawned = true;
  }
  state.pendingResults = (state.pendingResults || 0) + 1;
  writeState(state);
}

function resetOnPrompt() {
  const state = readState();
  state.lastUserPrompt = Date.now();
  state.dddRequired = false;
  state.dddAgentSpawned = false;
  state.pendingResults = 0;
  writeState(state);
}

const action = process.argv[2];
const arg = process.argv[3];

switch (action) {
  case 'track': trackCall(arg || ''); break;
  case 'agent-spawn': recordAgentSpawn(arg || ''); break;
  case 'user-prompt': resetOnPrompt(); break;
  default: break;
}
