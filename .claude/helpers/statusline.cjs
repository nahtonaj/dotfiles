#!/usr/bin/env node
/**
 * Global Claude Code Statusline
 *
 * Output: <cwd> | <branch>[*][+N/-N] | <Model> [| agents:N] [| tasks:X/Y] [| ctx:N%]
 *
 * Reads Claude Code JSON from stdin when invoked as a statusLine command.
 * Falls back gracefully to process.cwd() when stdin is a TTY.
 * The ctx segment only appears once there is an active API call (used_percentage != null).
 * The agents and tasks segments only appear when there is orchestrator activity.
 */

/* eslint-disable @typescript-eslint/no-var-requires */
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const os = require('os');

// ANSI colors
const c = {
  reset: '\x1b[0m',
  dim: '\x1b[2m',
  red: '\x1b[0;31m',
  green: '\x1b[0;32m',
  yellow: '\x1b[0;33m',
  purple: '\x1b[0;35m',
  cyan: '\x1b[0;36m',
};

// Safe spawnSync wrapper -- returns trimmed stdout or empty string on failure
function safeSpawn(cmd, args, timeoutMs) {
  if (!timeoutMs) timeoutMs = 2000;
  try {
    var result = spawnSync(cmd, args, {
      encoding: 'utf-8',
      timeout: timeoutMs,
    });
    if (result.status === 0 && result.stdout) return result.stdout.trim();
  } catch (e) { /* ignore */ }
  return '';
}


// ─── Git info (three separate spawnSync calls, no shell interpolation) ──────

function getGitInfo() {
  var result = { gitBranch: '', modified: 0, untracked: 0, staged: 0, ahead: 0, behind: 0 };

  // Branch
  result.gitBranch = safeSpawn('git', ['branch', '--show-current'], 2000);

  // Porcelain status
  var porcelain = safeSpawn('git', ['status', '--porcelain'], 2000);
  if (porcelain) {
    var lines = porcelain.split('\n');
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (!line || line.length < 2) continue;
      var x = line[0], y = line[1];
      if (x === '?' && y === '?') { result.untracked++; continue; }
      if (x !== ' ' && x !== '?') result.staged++;
      if (y !== ' ' && y !== '?') result.modified++;
    }
  }

  // Ahead/behind
  var ab = safeSpawn('git', ['rev-list', '--left-right', '--count', 'HEAD...@{upstream}'], 2000);
  if (ab) {
    var parts = ab.split(/\s+/);
    result.ahead = parseInt(parts[0]) || 0;
    result.behind = parseInt(parts[1]) || 0;
  }

  return result;
}

// ─── Model name ─────────────────────────────────────────────────

// Prefer Claude Code's injected JSON; fall back to .claude.json project lookup
function resolveModelName(input) {
  if (input && input.model && input.model.display_name) {
    var dn = input.model.display_name;
    if (dn.toLowerCase().indexOf('opus') !== -1) return 'Opus';
    if (dn.toLowerCase().indexOf('sonnet') !== -1) return 'Sonnet';
    if (dn.toLowerCase().indexOf('haiku') !== -1) return 'Haiku';
    return dn;
  }

  // Fallback: scan ~/.claude.json for last-used model matching cwd
  try {
    var claudeJsonPath = path.join(os.homedir(), '.claude.json');
    var claudeConfig = null;
    if (fs.existsSync(claudeJsonPath)) {
      claudeConfig = JSON.parse(fs.readFileSync(claudeJsonPath, 'utf-8'));
    }
    if (claudeConfig && claudeConfig.projects) {
      var cwd = process.cwd();
      var projectPaths = Object.keys(claudeConfig.projects);
      for (var i = 0; i < projectPaths.length; i++) {
        var projectPath = projectPaths[i];
        if (cwd === projectPath || cwd.indexOf(projectPath + '/') === 0) {
          var projectConfig = claudeConfig.projects[projectPath];
          var usage = projectConfig.lastModelUsage;
          if (usage) {
            var ids = Object.keys(usage);
            if (ids.length > 0) {
              var modelId = ids[ids.length - 1];
              var latest = 0;
              for (var j = 0; j < ids.length; j++) {
                var id = ids[j];
                var ts = usage[id] && usage[id].lastUsedAt
                  ? new Date(usage[id].lastUsedAt).getTime() : 0;
                if (ts > latest) { latest = ts; modelId = id; }
              }
              if (modelId.indexOf('opus') !== -1) return 'Opus';
              if (modelId.indexOf('sonnet') !== -1) return 'Sonnet';
              if (modelId.indexOf('haiku') !== -1) return 'Haiku';
            }
          }
          break;
        }
      }
    }
  } catch (e) { /* ignore */ }

  return 'Claude';
}


// ─── Current working directory (short display) ───────────────────

function getCwdDisplay(input) {
  // Prefer the CWD injected by Claude Code via stdin JSON
  var dir = (input && input.cwd) ? input.cwd : process.cwd();
  var home = os.homedir();
  // Replace home prefix with ~
  if (dir === home) return '~';
  if (dir.indexOf(home + '/') === 0) dir = '~' + dir.slice(home.length);
  // Show last two path segments for context (e.g. ~/arche)
  var parts = dir.split('/');
  if (parts.length > 2) {
    return '~/' + parts.slice(-1)[0];
  }
  return dir;
}

// ─── Context window usage ─────────────────────────────────────────

function getContextDisplay(input) {
  if (!input || !input.context_window) return '';
  var used = input.context_window.used_percentage;
  if (used === null || used === undefined) return '';
  var pct = Math.round(used);
  // Color: green < 50%, yellow 50-80%, red > 80%
  var color = pct < 50 ? c.green : pct < 80 ? c.yellow : c.red;
  return color + 'ctx:' + pct + '%' + c.reset;
}

// ─── Orchestrator metrics (agents + tasks) ───────────────────────

function getOrchestratorMetrics(input) {
  // Determine project dir: prefer workspace.project_dir injected by Claude Code
  var projectDir = null;
  if (input && input.workspace && input.workspace.project_dir) {
    projectDir = input.workspace.project_dir;
  } else if (input && input.cwd) {
    projectDir = input.cwd;
  } else {
    projectDir = process.cwd();
  }

  var agentCount = 0;
  var taskTotal = 0;
  var taskDone = 0;

  // Read agent store -- {projectDir}/.arche/agents/store.json
  try {
    var agentPath = path.join(projectDir, '.arche', 'agents', 'store.json');
    if (fs.existsSync(agentPath)) {
      var agentStore = JSON.parse(fs.readFileSync(agentPath, 'utf-8'));
      if (agentStore && agentStore.agents) {
        var agents = Object.values(agentStore.agents);
        // Count non-terminated agents as active
        agentCount = agents.filter(function(a) {
          return a.status !== 'terminated';
        }).length;
      }
    }
  } catch (e) { /* ignore */ }

  // Read task store -- {projectDir}/.arche/tasks/store.json
  try {
    var taskPath = path.join(projectDir, '.arche', 'tasks', 'store.json');
    if (fs.existsSync(taskPath)) {
      var taskStore = JSON.parse(fs.readFileSync(taskPath, 'utf-8'));
      if (taskStore && taskStore.tasks) {
        var tasks = Object.values(taskStore.tasks);
        taskTotal = tasks.length;
        taskDone = tasks.filter(function(t) {
          return t.status === 'completed' || t.status === 'done';
        }).length;
      }
    }
  } catch (e) { /* ignore */ }

  var parts = [];

  // agents:N — only show when there are active agents
  if (agentCount > 0) {
    parts.push(c.cyan + 'agents:' + agentCount + c.reset);
  }

  // tasks:X/Y — only show when tasks exist
  if (taskTotal > 0) {
    var taskColor;
    if (taskDone === taskTotal) {
      taskColor = c.green;    // all done
    } else {
      taskColor = c.yellow;   // in progress
    }
    parts.push(taskColor + 'tasks:' + taskDone + '/' + taskTotal + c.reset);
  }

  return parts;
}

// ─── Read stdin JSON (Claude Code injects context) ───────────────

function readStdinSync() {
  try {
    if (process.stdin.isTTY) return null;
    var buf = fs.readFileSync('/dev/stdin', { encoding: 'utf-8' });
    return buf ? JSON.parse(buf) : null;
  } catch (e) { /* ignore */ }
  return null;
}

// ─── Main ────────────────────────────────────────────────────────

var stdinInput = readStdinSync();
var git = getGitInfo();
var modelName = resolveModelName(stdinInput);
var cwdDisplay = getCwdDisplay(stdinInput);
var ctxDisplay = getContextDisplay(stdinInput);
var orchMetrics = getOrchestratorMetrics(stdinInput);

var sep = ' ' + c.dim + '|' + c.reset + ' ';
var parts = [];

// Segment 1: CWD
parts.push(c.dim + cwdDisplay + c.reset);

// Segment 2: Git
if (git.gitBranch) {
  var gitPart = c.cyan + git.gitBranch + c.reset;
  var dirty = git.staged + git.modified + git.untracked;
  if (dirty > 0) gitPart += c.yellow + '*' + c.reset;
  if (git.ahead > 0) gitPart += c.green + '+' + git.ahead + c.reset;
  if (git.behind > 0) gitPart += c.red + '-' + git.behind + c.reset;
  parts.push(gitPart);
} else {
  parts.push(c.dim + 'no-git' + c.reset);
}

// Segment 3: Model
parts.push(c.purple + modelName + c.reset);

// Segment 4: Orchestrator metrics (agents and tasks, only when present)
for (var i = 0; i < orchMetrics.length; i++) {
  parts.push(orchMetrics[i]);
}

// Segment 5: Context window usage (only shown when data is available)
if (ctxDisplay) {
  parts.push(ctxDisplay);
}

process.stdout.write(parts.join(sep) + '\n');
