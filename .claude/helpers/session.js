#!/usr/bin/env node
/**
 * Claude Flow Session Manager
 * Handles session lifecycle: start, restore, end
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const SESSION_DIR = path.join(process.cwd(), '.claude-flow', 'sessions');
const SESSION_FILE = path.join(SESSION_DIR, 'current.json');

/** Safe JSON parse — returns null and removes corrupted file on failure */
function safeParseSessionFile(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
  } catch (e) {
    console.log(`[WARN] Corrupted session file, resetting: ${e.message}`);
    try { fs.unlinkSync(filePath); } catch (_) {}
    return null;
  }
}

/** Atomic write — write to tmp file then rename to avoid partial writes */
function atomicWriteSync(filePath, data) {
  const tmp = filePath + `.tmp.${process.pid}`;
  fs.writeFileSync(tmp, data);
  fs.renameSync(tmp, filePath);
}

const commands = {
  start: () => {
    const sessionId = `session-${Date.now()}`;
    const session = {
      id: sessionId,
      startedAt: new Date().toISOString(),
      cwd: process.cwd(),
      context: {},
      metrics: {
        edits: 0,
        commands: 0,
        tasks: 0,
        errors: 0,
      },
    };

    fs.mkdirSync(SESSION_DIR, { recursive: true });
    atomicWriteSync(SESSION_FILE, JSON.stringify(session, null, 2));

    console.log(`Session started: ${sessionId}`);
    return session;
  },

  restore: () => {
    if (!fs.existsSync(SESSION_FILE)) {
      console.log('No session to restore');
      return null;
    }

    const session = safeParseSessionFile(SESSION_FILE);
    if (!session) return null;
    session.restoredAt = new Date().toISOString();
    atomicWriteSync(SESSION_FILE, JSON.stringify(session, null, 2));

    console.log(`Session restored: ${session.id}`);
    return session;
  },

  end: () => {
    if (!fs.existsSync(SESSION_FILE)) {
      console.log('No active session');
      return null;
    }

    const session = safeParseSessionFile(SESSION_FILE);
    if (!session) return null;
    session.endedAt = new Date().toISOString();
    session.duration = Date.now() - new Date(session.startedAt).getTime();

    // Archive session
    const archivePath = path.join(SESSION_DIR, `${session.id}.json`);
    atomicWriteSync(archivePath, JSON.stringify(session, null, 2));
    fs.unlinkSync(SESSION_FILE);

    console.log(`Session ended: ${session.id}`);
    console.log(`Duration: ${Math.round(session.duration / 1000 / 60)} minutes`);
    console.log(`Metrics: ${JSON.stringify(session.metrics)}`);

    return session;
  },

  status: () => {
    if (!fs.existsSync(SESSION_FILE)) {
      console.log('No active session');
      return null;
    }

    const session = safeParseSessionFile(SESSION_FILE);
    if (!session) return null;
    const duration = Date.now() - new Date(session.startedAt).getTime();

    console.log(`Session: ${session.id}`);
    console.log(`Started: ${session.startedAt}`);
    console.log(`Duration: ${Math.round(duration / 1000 / 60)} minutes`);
    console.log(`Metrics: ${JSON.stringify(session.metrics)}`);

    return session;
  },

  update: (key, value) => {
    if (!fs.existsSync(SESSION_FILE)) {
      console.log('No active session');
      return null;
    }

    const session = safeParseSessionFile(SESSION_FILE);
    if (!session) return null;
    session.context[key] = value;
    session.updatedAt = new Date().toISOString();
    atomicWriteSync(SESSION_FILE, JSON.stringify(session, null, 2));

    return session;
  },

  get: (key) => {
    if (!fs.existsSync(SESSION_FILE)) return null;
    try {
      const session = JSON.parse(fs.readFileSync(SESSION_FILE, 'utf-8'));
      return key ? (session.context || {})[key] : session.context;
    } catch { return null; }
  },

  metric: (name) => {
    if (!fs.existsSync(SESSION_FILE)) {
      return null;
    }

    const session = safeParseSessionFile(SESSION_FILE);
    if (!session) return null;
    if (session.metrics[name] !== undefined) {
      session.metrics[name]++;
      atomicWriteSync(SESSION_FILE, JSON.stringify(session, null, 2));
    }

    return session;
  },
};

// CLI
const [,, command, ...args] = process.argv;

if (command && commands[command]) {
  commands[command](...args);
} else {
  console.log('Usage: session.js <start|restore|end|status|update|metric> [args]');
}

module.exports = commands;
