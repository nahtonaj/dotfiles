#!/usr/bin/env node
/**
 * Global Claude Code Statusline
 *
 * Styled after the zsh PROMPT from ~/.zshrc (databricks.zsh-theme):
 *   # <user> at <host> in <dir> (git:<branch>[*][+N/-N]) [HH:MM:SS] | <Model> [| ctx:N%]
 *
 * Reads Claude Code JSON from stdin when invoked as a statusLine command.
 * Falls back gracefully to process.cwd() when stdin is a TTY.
 * The ctx segment only appears once there is an active API call (used_percentage != null).
 */

/* eslint-disable @typescript-eslint/no-var-requires */
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const os = require('os');

// ANSI colors
const c = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[0;31m',
  green: '\x1b[0;32m',
  yellow: '\x1b[0;33m',
  blue: '\x1b[0;34m',
  purple: '\x1b[0;35m',
  cyan: '\x1b[0;36m',
  white: '\x1b[0;37m',
  boldBlue: '\x1b[1;34m',
  boldYellow: '\x1b[1;33m',
  boldRed: '\x1b[1;31m',
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


// ─── Git info ────────────────────────────────────────────────────────────────

function getGitInfo(cwd) {
  var result = { gitBranch: '', modified: 0, untracked: 0, staged: 0, ahead: 0, behind: 0, isWorktree: false, worktreeName: '' };

  // Branch
  result.gitBranch = safeSpawn('git', ['-C', cwd, '--no-optional-locks', 'branch', '--show-current'], 2000);

  // Porcelain status
  var porcelain = safeSpawn('git', ['-C', cwd, '--no-optional-locks', 'status', '--porcelain'], 2000);
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
  var ab = safeSpawn('git', ['-C', cwd, '--no-optional-locks', 'rev-list', '--left-right', '--count', 'HEAD...@{upstream}'], 2000);
  if (ab) {
    var abParts = ab.split(/\s+/);
    result.ahead = parseInt(abParts[0]) || 0;
    result.behind = parseInt(abParts[1]) || 0;
  }

  // Worktree detection: git-dir != git-common-dir means we're in a linked worktree
  var gitDir = safeSpawn('git', ['-C', cwd, '--no-optional-locks', 'rev-parse', '--git-dir'], 1000);
  var gitCommonDir = safeSpawn('git', ['-C', cwd, '--no-optional-locks', 'rev-parse', '--git-common-dir'], 1000);
  result.isWorktree = !!(gitDir && gitCommonDir && gitDir !== gitCommonDir);

  // Worktree name: last path component of the worktree directory
  if (result.isWorktree) {
    // gitDir is something like /path/to/.git/worktrees/<name>
    var parts = gitDir.split('/');
    var wtIdx = parts.indexOf('worktrees');
    if (wtIdx !== -1 && parts[wtIdx + 1]) {
      result.worktreeName = parts[wtIdx + 1];
    } else {
      // Fallback: use last component of cwd
      result.worktreeName = cwd.split('/').pop() || '';
    }
  }

  return result;
}

// ─── Model name ──────────────────────────────────────────────────────────────

// Extract short display name from a model ID string.
// e.g. "claude-opus-4-6" -> "Opus 4.6", "claude-haiku-4-5-20251001" -> "Haiku 4.5"
function parseModelId(id) {
  if (!id || typeof id !== 'string') return null;
  var m = id.match(/claude-(\w+)-(\d+)-(\d+)/);
  if (!m) return null;
  var tier = m[1].charAt(0).toUpperCase() + m[1].slice(1);
  return tier + ' ' + m[2] + '.' + m[3];
}

// Prefer Claude Code's injected JSON; fall back to .claude.json project lookup
function resolveModelName(input) {
  // Primary path: Claude Code injects model as a plain string ID
  if (input && typeof input.model === 'string') {
    var parsed = parseModelId(input.model);
    if (parsed) return parsed;
    return input.model;
  }

  // Secondary path: model as an object with display_name
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


// ─── Current working directory (tilde-abbreviated) ───────────────────────────

function getCwdDisplay(input) {
  var dir = (input && input.cwd) ? input.cwd : process.cwd();
  var home = os.homedir();
  if (dir === home) return '~';
  if (dir.indexOf(home + '/') === 0) dir = '~' + dir.slice(home.length);
  return dir;
}

// ─── Context window usage ─────────────────────────────────────────────────────

function getContextDisplay(input) {
  if (!input || !input.context_window) return '';
  var cw = input.context_window;
  var used = cw.used_percentage;
  if ((used === null || used === undefined) && cw.max_tokens > 0) {
    used = ((cw.used_tokens || 0) / cw.max_tokens) * 100;
  }
  // No messages yet -- skip entirely rather than showing 0%
  if (used === null || used === undefined) return '';
  var pct = Math.round(used);
  if (pct === 0) return '';
  var rem = 100 - pct;
  // Color by usage level: green < 50%, yellow 50-80%, red > 80%
  var usedColor = pct < 50 ? c.green : pct < 80 ? c.yellow : c.red;
  // Mini bar: filled blocks out of 10
  var filled = Math.round(pct / 10);
  var bar = '\u2588'.repeat(filled) + '\u2591'.repeat(10 - filled);
  return usedColor + 'ctx ' + bar + ' ' + pct + '%' + c.dim + ' (' + rem + '% left)' + c.reset;
}

// ─── Read stdin JSON (Claude Code injects context) ────────────────────────────

function readStdinSync() {
  try {
    if (process.stdin.isTTY) return null;
    var buf = fs.readFileSync('/dev/stdin', { encoding: 'utf-8' });
    return buf ? JSON.parse(buf) : null;
  } catch (e) { /* ignore */ }
  return null;
}

// ─── Main ─────────────────────────────────────────────────────────────────────

var stdinInput = readStdinSync();
// Use process.cwd() for git detection -- Claude Code sets the subprocess CWD
// to the actual worktree path for agent processes. stdinInput.cwd is always
// the project dir (same for all sessions) and cannot distinguish worktrees.
var gitCwd = (function() {
  var pcwd = process.cwd();
  var test = safeSpawn('git', ['-C', pcwd, '--no-optional-locks', 'rev-parse', '--git-dir'], 500);
  if (test) return pcwd;
  return (stdinInput && stdinInput.cwd) || pcwd;
}());
var git = getGitInfo(gitCwd);
var modelName = resolveModelName(stdinInput);
var cwdDisplay = getCwdDisplay(stdinInput);
var ctxDisplay = getContextDisplay(stdinInput);

// ─── Assemble prompt line styled after the zsh theme ─────────────────────────
// Format: # <user> at <host> in <dir> (git:<branch>[*][+N/-N]) [HH:MM:SS] | <Model> [| ctx:N%]

var user = os.userInfo().username || 'user';
var hostname = os.hostname().split('.')[0]; // short hostname

// Time: HH:MM:SS
var now = new Date();
var hh = String(now.getHours()).padStart(2, '0');
var mm = String(now.getMinutes()).padStart(2, '0');
var ss = String(now.getSeconds()).padStart(2, '0');
var timeStr = hh + ':' + mm + ':' + ss;

// Worktree metadata from Claude Code JSON input (may supplement git detection)
var jsonWorktree = stdinInput && stdinInput.worktree ? stdinInput.worktree : null;

// Resolve worktree name: prefer JSON field, then git-derived name
var resolvedWtName = '';
if (jsonWorktree && jsonWorktree.name) {
  resolvedWtName = jsonWorktree.name;
} else if (git.isWorktree && git.worktreeName) {
  resolvedWtName = git.worktreeName;
}

// isWorktree: either git detection or JSON presence
var isWorktree = git.isWorktree || !!jsonWorktree;

// Git portion
var gitStr = '';
if (git.gitBranch) {
  var branchDisplay = git.gitBranch;
  var dirty = git.staged + git.modified + git.untracked;
  if (dirty > 0) branchDisplay += c.yellow + '*' + c.reset + c.cyan;
  if (git.ahead > 0) branchDisplay += c.green + '+' + git.ahead + c.reset + c.cyan;
  if (git.behind > 0) branchDisplay += c.red + '-' + git.behind + c.reset + c.cyan;

  if (isWorktree) {
    // Worktree sessions: show [WT:<name>] in bold magenta before the branch
    var wtLabel = resolvedWtName ? 'WT:' + resolvedWtName : 'WT';
    gitStr = c.white + ' (' + '\x1b[1;35m' + wtLabel + c.reset + c.white + ' git:' + c.cyan + branchDisplay + c.white + ')' + c.reset;
  } else {
    // Main (non-worktree) sessions: standard display
    gitStr = c.white + ' (git:' + c.cyan + branchDisplay + c.white + ')' + c.reset;
  }
}

// Build the main prompt segment
var line = ''
  + c.boldBlue + '#' + c.reset
  + ' ' + c.cyan + user + c.reset
  + ' ' + c.white + 'at' + c.reset
  + ' ' + c.green + hostname + c.reset
  + ' ' + c.white + 'in' + c.reset
  + ' ' + c.boldYellow + cwdDisplay + c.reset
  + gitStr
  + ' ' + c.white + '[' + timeStr + ']' + c.reset;

// Append model and context separated by dim pipe
var sep = ' ' + c.dim + '|' + c.reset + ' ';
line += sep + c.purple + modelName + c.reset;
if (ctxDisplay) {
  line += sep + ctxDisplay;
}

process.stdout.write(line + '\n');
