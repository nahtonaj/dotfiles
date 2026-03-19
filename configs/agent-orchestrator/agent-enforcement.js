#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');

const STATE_FILE = path.join(process.env.HOME, '.claude', '.agent-orchestrator-state.json');

const AGENTDB_PROTOCOL = `## agentDB Protocol (MANDATORY)
- Before starting work, call \`ToolSearch\` with query \`select:mcp__agent-orchestrator__agentdb_hierarchical-store,mcp__agent-orchestrator__agentdb_hierarchical-recall,mcp__agent-orchestrator__agentdb_pattern-store,mcp__agent-orchestrator__agentdb_pattern-search,mcp__agent-orchestrator__memory_store,mcp__agent-orchestrator__memory_search\` to load agentDB and memory tools
- If prior agentDB keys are provided, call \`mcp__agent-orchestrator__agentdb_hierarchical-recall\` with the exact key to retrieve context (omit \`tier\` to search all tiers). Note: hierarchical-recall is exact key match only -- it does NOT support semantic search.
- For semantic search across prior context (when exact key is unknown), use \`mcp__agent-orchestrator__memory_search\` with a descriptive query and namespace \`"patterns"\`
- After completing work, call \`mcp__agent-orchestrator__agentdb_hierarchical-store\` directly with:
  - \`key\`: \`{agent-name}-{date}\` format
  - \`value\`: your findings/results
  - \`tier\`: \`"working"\` (always specify explicitly)
- Store discovered patterns via \`mcp__agent-orchestrator__agentdb_pattern-store\` directly
- You MUST list all agentDB keys stored and consumed in your RESULTS section
- After storing, send coordinator a coordination signal via SendMessage with just the agentDB key reference (e.g., "Findings stored under key: X")
- You MUST NOT send findings, code, or data via SendMessage -- store in agentDB directly, then reference the key
- If you need another agent's help, send a spawn request to the coordinator via SendMessage -- do NOT spawn agents yourself`;

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

  // Always inject agentDB protocol into agent context
  // NOTE: additionalContext is advisory -- the coordinator MUST also include
  // the protocol block in the agent prompt for reliable enforcement
  const output = {
    hookSpecificOutput: {
      hookEventName: 'SubagentStart',
      additionalContext: '[MANDATORY] You MUST follow this protocol. Failure to store in agentDB is a violation.\n\n' + AGENTDB_PROTOCOL
    }
  };

  if (warnings.length > 0) {
    output.systemMessage = warnings.join('\n');
  }

  console.log(JSON.stringify(output));
}

const action = process.argv[2];
if (action === 'subagent-start') {
  validatePreSpawn();
}
