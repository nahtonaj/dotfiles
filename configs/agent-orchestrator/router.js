#!/usr/bin/env node
/**
 * Claude Flow Agent Router
 * Routes tasks to optimal agents based on learned patterns
 */

const AGENT_CAPABILITIES = {
  coder: ['code-generation', 'refactoring', 'debugging', 'implementation'],
  tester: ['unit-testing', 'integration-testing', 'coverage', 'test-generation'],
  reviewer: ['code-review', 'security-audit', 'quality-check', 'best-practices'],
  researcher: ['web-search', 'documentation', 'analysis', 'summarization'],
  architect: ['system-design', 'architecture', 'patterns', 'scalability'],
  'backend-dev': ['api', 'database', 'server', 'authentication'],
  'frontend-dev': ['ui', 'react', 'css', 'components'],
  devops: ['ci-cd', 'docker', 'deployment', 'infrastructure'],
  'ddd-domain-expert': ['domain-modeling', 'bounded-context', 'aggregate-design', 'context-mapping', 'ubiquitous-language', 'event-storming'],
};

const TASK_PATTERNS = {
  // Code patterns
  'implement|create|build|add|write code': 'coder',
  'test|spec|coverage|unit test|integration': 'tester',
  'review|audit|check|validate|security': 'reviewer',
  'research|find|search|documentation|explore': 'researcher',
  'design|architect|structure|plan': 'architect',

  // Domain patterns
  'api|endpoint|server|backend|database': 'backend-dev',
  'ui|frontend|component|react|css|style': 'frontend-dev',
  'deploy|docker|ci|cd|pipeline|infrastructure': 'devops',
  'domain model|bounded context|aggregate|ubiquitous language|context map|ddd|event storm': 'ddd-domain-expert',
};

const DDD_SIGNALS = [
  'domain boundar', 'bounded context', 'aggregate', 'context map',
  'ubiquitous language', 'data ownership', 'module boundar', 'coupling',
  'shared model', 'event storm', 'anti-corruption', 'restructur',
  'cross-module', 'cross-package', 'entity relation', 'value object',
  'service decompos', 'domain event'
];

function routeTask(task) {
  const taskLower = task.toLowerCase();

  // Estimate complexity
  const complexitySignals = ['refactor', 'migrate', 'redesign', 'architecture', 'security',
    'multi-file', 'integrate', 'distributed', 'concurrent', 'overhaul'];
  const hits = complexitySignals.filter(s => taskLower.includes(s)).length;
  const wordCount = task.split(/\s+/).length;
  let complexity = 'LOW';
  if (hits >= 2 || wordCount > 30) complexity = 'HIGH';
  else if (hits >= 1 || wordCount > 15) complexity = 'MEDIUM';

  // DDD signal detection
  const dddHits = DDD_SIGNALS.filter(s => taskLower.includes(s));
  let requiresDdd = false;
  if (dddHits.length > 0) {
    requiresDdd = true;
    // Write DDD requirement to state file for enforcement hooks
    const fs = require('fs');
    const path = require('path');
    const stateFile = path.join(process.env.HOME, '.claude', '.ruflo-state.json');
    try {
      let state = {};
      try { state = JSON.parse(fs.readFileSync(stateFile, 'utf8')); } catch {}
      state.dddRequired = true;
      const dir = path.dirname(stateFile);
      if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(stateFile, JSON.stringify(state, null, 2));
    } catch {}
    console.error(`[DDD_REQUIRED] ${dddHits.length} DDD signal(s) detected: ${dddHits.join(', ')}`);
  }

  // Check patterns
  for (const [pattern, agent] of Object.entries(TASK_PATTERNS)) {
    const regex = new RegExp(pattern, 'i');
    if (regex.test(taskLower)) {
      return {
        agent,
        confidence: 0.8,
        reason: `Matched pattern: ${pattern}`,
        complexity,
        requiresDdd,
        dddSignals: dddHits.length,
      };
    }
  }

  // Default to coder for unknown tasks
  return {
    agent: 'coder',
    confidence: 0.5,
    reason: 'Default routing - no specific pattern matched',
    complexity,
    requiresDdd,
    dddSignals: dddHits.length,
  };
}

// CLI
const task = process.argv.slice(2).join(' ');

if (task) {
  const result = routeTask(task);
  console.log(JSON.stringify(result, null, 2));
} else {
  console.log('Usage: router.js <task description>');
  console.log('\nAvailable agents:', Object.keys(AGENT_CAPABILITIES).join(', '));
}

module.exports = { routeTask, AGENT_CAPABILITIES, TASK_PATTERNS };
