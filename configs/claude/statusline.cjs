#!/usr/bin/env node
/**
 * Global Claude Code Statusline
 *
 * Renders a single-line ANSI-colored status bar for the Claude Code terminal,
 * styled after the zsh PROMPT from ~/.zshrc (databricks.zsh-theme):
 *   # <user> at <host> in <dir> (git:<branch>[*][+N/-N]) [HH:MM:SS] | <Model> [| ctx:N%]
 *
 * Invocation:
 *   Claude Code pipes JSON to stdin and reads ANSI-colored text from stdout.
 *   Configured in ~/.claude/settings.json (symlinked from dotfiles):
 *     "statusLine": {
 *       "type": "command",
 *       "command": "node /path/to/statusline.cjs 2>> /tmp/statusline-stderr.log"
 *     }
 *   Stderr is redirected to a log file for debugging; only stdout is displayed.
 *
 * Stdin JSON schema (key fields piped by Claude Code):
 *   model          - { id: string, display_name: string } or plain string (older versions)
 *   cwd            - string, the session's working directory
 *   context_window - { used_percentage, context_window_size, current_usage, total_input_tokens }
 *   workspace      - { current_dir, git_worktree }
 *   worktree       - { name } (only present in --worktree sessions)
 *   cost           - session cost info (not currently rendered)
 *   rate_limits    - rate limit status (not currently rendered)
 *
 * Rendering pipeline: stdin JSON -> parse -> gather git/model/cwd/context -> assemble ANSI line -> stdout
 *
 * Falls back gracefully to process.cwd() when stdin is empty (e.g. manual invocation).
 * The ctx segment only appears once there is an active API call (used_percentage != null).
 */

/* eslint-disable @typescript-eslint/no-var-requires */
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const os = require('os');

// ANSI SGR escape codes for terminal coloring.
// Each key maps to an escape sequence: \x1b[<code>m (reset, bold, dim, or color).
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

// Write a warning to stderr so failures are visible
function warn(msg) {
  process.stderr.write('[statusline] WARN: ' + msg + '\n');
}

/**
 * Safe spawnSync wrapper -- runs a command synchronously and returns trimmed stdout.
 * Returns empty string on any failure (non-zero exit, timeout, exception).
 * Warnings are emitted to stderr unless the exit code is in opts.silentCodes.
 *
 * @param {string} cmd - Command to execute
 * @param {string[]} args - Command arguments
 * @param {number} [timeoutMs=2000] - Max execution time in ms before kill
 * @param {object} [opts] - Options
 * @param {number[]} [opts.silentCodes] - Exit codes to treat as expected (no warning).
 *   For git commands, exit code 128 ("not a git repository") is always silent.
 * @returns {string} Trimmed stdout on success, empty string on failure
 */
function safeSpawn(cmd, args, timeoutMs, opts) {
  if (!timeoutMs) timeoutMs = 2000;
  if (!opts) opts = {};
  // git exits 128 for "not a git repository" -- always treat as silent/expected
  var silentCodes = opts.silentCodes || (cmd === 'git' ? [128] : []);
  try {
    var result = spawnSync(cmd, args, {
      encoding: 'utf-8',
      timeout: timeoutMs,
    });
    if (result.status === 0 && result.stdout) return result.stdout.trim();
    if (result.status !== 0) {
      var isSilent = silentCodes.indexOf(result.status) !== -1;
      if (!isSilent) {
        warn('safeSpawn ' + cmd + ' ' + args.join(' ') + ' exited ' + result.status
          + (result.stderr ? ': ' + result.stderr.trim() : ''));
      }
    }
  } catch (e) {
    warn('safeSpawn ' + cmd + ' threw: ' + String(e));
  }
  return '';
}


// ─── Git info ────────────────────────────────────────────────────────────────

/**
 * Gather git repository status for a given directory.
 * Runs several git commands (branch, porcelain status, rev-list, rev-parse)
 * to build a comprehensive snapshot of the repo state.
 *
 * @param {string} cwd - Directory to inspect (must be inside a git repo, or fields stay default)
 * @returns {{ gitBranch: string, modified: number, untracked: number, staged: number,
 *             ahead: number, behind: number, isWorktree: boolean, worktreeName: string }}
 */
function getGitInfo(cwd) {
  var result = { gitBranch: '', modified: 0, untracked: 0, staged: 0, ahead: 0, behind: 0, isWorktree: false, worktreeName: '' };

  // Current branch name (empty string if detached HEAD or not a repo)
  result.gitBranch = safeSpawn('git', ['-C', cwd, '--no-optional-locks', 'branch', '--show-current'], 2000);

  // Parse porcelain status to count staged/modified/untracked files.
  // Porcelain v1 format: two-char status code (XY) followed by filename.
  //   X = index status, Y = working tree status
  //   "??" = untracked, non-space X = staged change, non-space Y = unstaged change
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

  // Commits ahead/behind upstream tracking branch (e.g. "3\t1" = 3 ahead, 1 behind)
  var ab = safeSpawn('git', ['-C', cwd, '--no-optional-locks', 'rev-list', '--left-right', '--count', 'HEAD...@{upstream}'], 2000);
  if (ab) {
    var abParts = ab.split(/\s+/);
    result.ahead = parseInt(abParts[0]) || 0;
    result.behind = parseInt(abParts[1]) || 0;
  }

  // Worktree detection: in a linked worktree, --git-dir points to
  // .git/worktrees/<name> while --git-common-dir points to the main .git.
  // If they differ, we're in a linked worktree (not the main checkout).
  var gitDir = safeSpawn('git', ['-C', cwd, '--no-optional-locks', 'rev-parse', '--git-dir'], 1000);
  var gitCommonDir = safeSpawn('git', ['-C', cwd, '--no-optional-locks', 'rev-parse', '--git-common-dir'], 1000);
  result.isWorktree = !!(gitDir && gitCommonDir && gitDir !== gitCommonDir);

  // Extract worktree name from the git-dir path (e.g. /repo/.git/worktrees/my-feature -> "my-feature")
  if (result.isWorktree) {
    var parts = gitDir.split('/');
    var wtIdx = parts.indexOf('worktrees');
    if (wtIdx !== -1 && parts[wtIdx + 1]) {
      result.worktreeName = parts[wtIdx + 1];
    } else {
      // Fallback: use last path component of the working directory
      result.worktreeName = cwd.split('/').pop() || '';
    }
  }

  return result;
}

// ─── Model name ──────────────────────────────────────────────────────────────

/**
 * Extract a short display name from a Claude model ID string.
 * Matches the pattern "claude-<tier>-<major>-<minor>[...]" and returns "Tier Major.Minor".
 * Examples: "claude-opus-4-6" -> "Opus 4.6", "claude-haiku-4-5-20251001" -> "Haiku 4.5"
 *
 * @param {string} id - Full model ID string (e.g. "claude-opus-4-6")
 * @returns {string|null} Short name like "Opus 4.6", or null if pattern doesn't match
 */
function parseModelId(id) {
  if (!id || typeof id !== 'string') return null;
  var m = id.match(/claude-(\w+)-(\d+)-(\d+)/);
  if (!m) return null;
  var tier = m[1].charAt(0).toUpperCase() + m[1].slice(1);
  return tier + ' ' + m[2] + '.' + m[3];
}

/**
 * Resolve the model display name using a 3-tier fallback chain:
 *   1. Primary:   model object from stdin JSON ({ id, display_name }) -- parse id or use display_name
 *   2. Secondary: model as a plain string ID (older Claude Code versions) -- parse or use verbatim
 *   3. Tertiary:  scan ~/.claude.json for the last-used model matching the current project directory
 * Returns "?model?" if all sources fail.
 *
 * @param {object|null} input - Parsed stdin JSON from Claude Code
 * @returns {string} Human-readable model name (e.g. "Opus 4.6", "Sonnet", "?model?")
 */
function resolveModelName(input) {
  // Primary path: Claude Code injects model as an object { id, display_name }
  if (input && input.model && typeof input.model === 'object') {
    // Try to parse the model id for a clean "Tier Major.Minor" label
    var parsed = parseModelId(input.model.id);
    if (parsed) return parsed;
    // Fall back to display_name verbatim (already human-readable)
    if (input.model.display_name) return input.model.display_name;
    warn('model object present but id "' + input.model.id + '" did not parse and display_name is missing');
  } else if (input && !input.model) {
    warn('input JSON has no "model" field; input keys: ' + Object.keys(input).join(', '));
  }

  // Secondary path: model injected as a plain string ID (older Claude Code versions)
  if (input && typeof input.model === 'string') {
    var parsed2 = parseModelId(input.model);
    if (parsed2) return parsed2;
    return input.model;
  }

  // Tertiary fallback: scan ~/.claude.json (Claude Code's persistent config) for the
  // most recently used model in a project whose path matches the current working directory.
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
  } catch (e) {
    warn('.claude.json lookup failed: ' + String(e));
  }

  warn('could not resolve model name from any source; input was: '
    + (input ? JSON.stringify(input.model) : 'null (no stdin)'));
  return '?model?';
}


// ─── Current working directory (tilde-abbreviated) ───────────────────────────

/**
 * Get a display-friendly working directory path, replacing $HOME prefix with "~".
 * Prefers the injected cwd from stdin JSON; falls back to process.cwd().
 *
 * @param {object|null} input - Parsed stdin JSON from Claude Code
 * @returns {string} Tilde-abbreviated directory path (e.g. "~/projects/foo")
 */
function getCwdDisplay(input) {
  var dir = (input && input.cwd) ? input.cwd : process.cwd();
  var home = os.homedir();
  if (dir === home) return '~';
  if (dir.indexOf(home + '/') === 0) dir = '~' + dir.slice(home.length);
  return dir;
}

// ─── Context window usage ─────────────────────────────────────────────────────

/**
 * Render a context window usage indicator with a colored mini progress bar.
 * Uses a 3-tier fallback to determine the usage percentage:
 *   1. Pre-calculated used_percentage from Claude Code JSON
 *   2. Computed from current_usage.input_tokens / context_window_size
 *   3. Computed from total_input_tokens / context_window_size
 *
 * Color thresholds:  green (< 50%)  |  yellow (50-80%)  |  red (> 80%)
 * Bar: 10 unicode block characters (filled + light shade)
 *
 * Returns empty string before the first API call (used_percentage is null).
 *
 * @param {object|null} input - Parsed stdin JSON from Claude Code
 * @returns {string} ANSI-colored context display string, or empty string if unavailable
 */
function getContextDisplay(input) {
  if (!input) {
    // No stdin at all -- already warned elsewhere
    return '';
  }
  if (!input.context_window) {
    warn('input JSON has no "context_window" field; cannot show ctx bar. input keys: '
      + Object.keys(input).join(', '));
    return '';
  }
  var cw = input.context_window;

  // Primary: use pre-calculated used_percentage from Claude Code JSON
  var used = cw.used_percentage;

  // Fallback 1: compute from current_usage.input_tokens and context_window_size
  if ((used === null || used === undefined) && cw.context_window_size > 0 && cw.current_usage) {
    var inputTok = cw.current_usage.input_tokens || 0;
    var cacheTok = cw.current_usage.cache_read_input_tokens || 0;
    var totalUsed = inputTok + cacheTok;
    if (totalUsed > 0) {
      used = (totalUsed / cw.context_window_size) * 100;
    }
  }

  // Fallback 2: use total_input_tokens (cumulative session total) if context_window_size is known
  if ((used === null || used === undefined) && cw.context_window_size > 0
      && cw.total_input_tokens && cw.total_input_tokens > 0) {
    used = (cw.total_input_tokens / cw.context_window_size) * 100;
  }

  // No messages yet (used_percentage is null before first API call) -- skip without warning,
  // this is expected before the first turn.
  if (used === null || used === undefined) {
    warn('context_window present but used_percentage is null and no fallback succeeded; '
      + 'context_window_size=' + cw.context_window_size
      + ' total_input_tokens=' + cw.total_input_tokens
      + ' current_usage=' + JSON.stringify(cw.current_usage));
    return '';
  }
  var pct = Math.round(used);
  // Color by usage level: green < 50%, yellow 50-80%, red > 80%
  var usedColor = pct < 50 ? c.green : pct < 80 ? c.yellow : c.red;
  // Mini bar: 10 unicode block characters (U+2588 filled, U+2591 light shade)
  var filled = Math.round(pct / 10);
  var bar = '\u2588'.repeat(filled) + '\u2591'.repeat(10 - filled);
  return usedColor + 'ctx ' + bar + ' ' + pct + '%' + c.reset;
}

// ─── Main rendering ──────────────────────────────────────────────────────────

/**
 * Assemble and print the full statusline to stdout.
 * Pipeline: resolve git CWD -> gather git info, model name, cwd display, context bar
 *           -> format ANSI-colored prompt line -> write to stdout.
 *
 * Output format:
 *   # <user> at <host> in <dir> [(WT:<name>) git:<branch>[*][+N/-N]] [HH:MM:SS] | <Model> [| ctx ...]
 *
 * @param {object|null} stdinInput - Parsed stdin JSON from Claude Code, or null if stdin was empty
 */
function renderStatusline(stdinInput) {
  // Use stdinInput.cwd (the actual session CWD) for git detection when available,
  // falling back to process.cwd(). stdinInput.cwd reflects the real working dir
  // including worktree paths; workspace.current_dir is equivalent.
  var gitCwd = (function() {
    // Prefer the injected CWD from Claude Code JSON (most accurate)
    var injectedCwd = (stdinInput && stdinInput.cwd)
      || (stdinInput && stdinInput.workspace && stdinInput.workspace.current_dir)
      || null;
    if (injectedCwd) {
      var test = safeSpawn('git', ['-C', injectedCwd, '--no-optional-locks', 'rev-parse', '--git-dir'], 500);
      if (test) return injectedCwd;
    }
    // Fallback: process.cwd()
    var pcwd = process.cwd();
    var test2 = safeSpawn('git', ['-C', pcwd, '--no-optional-locks', 'rev-parse', '--git-dir'], 500);
    if (test2) return pcwd;
    return injectedCwd || pcwd;
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

  // Worktree resolution uses three signals (in priority order):
  //   1. stdinInput.worktree.name -- only present when Claude Code launched with --worktree flag
  //   2. stdinInput.workspace.git_worktree -- present for any linked git worktree
  //   3. git.isWorktree / git.worktreeName -- detected from git rev-parse above
  var jsonWorktree = stdinInput && stdinInput.worktree ? stdinInput.worktree : null;
  var wsGitWorktree = stdinInput && stdinInput.workspace && stdinInput.workspace.git_worktree
    ? stdinInput.workspace.git_worktree : null;

  var resolvedWtName = '';
  if (jsonWorktree && jsonWorktree.name) {
    resolvedWtName = jsonWorktree.name;
  } else if (wsGitWorktree) {
    resolvedWtName = wsGitWorktree;
  } else if (git.isWorktree && git.worktreeName) {
    resolvedWtName = git.worktreeName;
  }

  // isWorktree: any of the three signals
  var isWorktree = git.isWorktree || !!jsonWorktree || !!wsGitWorktree;

  // Git portion
  var gitStr = '';
  if (git.gitBranch) {
    var branchDisplay = git.gitBranch;
    var dirty = git.staged + git.modified + git.untracked;
    if (dirty > 0) branchDisplay += c.yellow + '*' + c.reset + c.cyan;
    if (git.ahead > 0) branchDisplay += c.green + '+' + git.ahead + c.reset + c.cyan;
    if (git.behind > 0) branchDisplay += c.red + '-' + git.behind + c.reset + c.cyan;

    if (isWorktree) {
      // Worktree sessions: show WT:<name> in bold magenta before the branch
      var wtLabel = resolvedWtName ? 'WT:' + resolvedWtName : 'WT';
      gitStr = c.white + ' (' + '\x1b[1;35m' + wtLabel + c.reset + c.white + ' git:' + c.cyan + branchDisplay + c.white + ')' + c.reset;
    } else {
      // Main (non-worktree) sessions: standard display
      gitStr = c.white + ' (git:' + c.cyan + branchDisplay + c.white + ')' + c.reset;
    }
  } else if (isWorktree) {
    // No git branch detected but worktree metadata is present (e.g. non-git cwd) --
    // still show the WT indicator so it is never silently dropped.
    var wtLabel2 = resolvedWtName ? 'WT:' + resolvedWtName : 'WT';
    gitStr = ' ' + '\x1b[1;35m' + wtLabel2 + c.reset;
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
}

// ─── Stdin reader (entry point) ──────────────────────────────────────────────
// Claude Code pipes the full JSON blob to stdin then closes the stream.
// We accumulate chunks, parse on 'end', then render. A debug snapshot is
// written to /tmp/statusline-debug.json for field-name inspection during development.
var inputChunks = '';
process.stdin.setEncoding('utf-8');
process.stdin.on('data', function(chunk) { inputChunks += chunk; });
process.stdin.on('end', function() {
  var stdinInput = null;
  if (inputChunks.trim()) {
    try {
      stdinInput = JSON.parse(inputChunks);
      // Persist debug snapshot for field-name inspection
      try {
        fs.writeFileSync('/tmp/statusline-debug.json', JSON.stringify(stdinInput, null, 2), 'utf-8');
      } catch (e) {
        warn('could not write /tmp/statusline-debug.json: ' + String(e));
      }
    } catch (e) {
      warn('failed to parse stdin JSON: ' + String(e) + '\nRaw input was: ' + inputChunks.slice(0, 500));
      try {
        fs.writeFileSync('/tmp/statusline-debug.json', 'PARSE_ERROR: ' + String(e) + '\nRAW: ' + inputChunks, 'utf-8');
      } catch (_) { /* best effort */ }
    }
  } else {
    warn('stdin was empty -- Claude Code did not pipe JSON; rendering with process.cwd() fallback');
  }
  renderStatusline(stdinInput);
});
