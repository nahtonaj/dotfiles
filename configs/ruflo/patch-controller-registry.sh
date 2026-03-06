#!/usr/bin/env bash
# Patch @claude-flow/memory to export ControllerRegistry
# Required because memory-bridge.js imports it but the package doesn't export it.
# This creates a SQLite-backed ControllerRegistry with HierarchicalMemory,
# TieredCache, and ReasoningBank controllers.
#
# Safe to re-run: checks for marker before patching.
set -euo pipefail

# Find the index.js to patch — search NVM, npm-global, and common paths
find_index() {
  local candidates=(
    "$HOME/.nvm/versions/node/$(node -v 2>/dev/null)/lib/node_modules/ruflo/node_modules/@claude-flow/memory/dist/index.js"
    "$HOME/.npm-global/lib/node_modules/ruflo/node_modules/@claude-flow/memory/dist/index.js"
    "/usr/local/lib/node_modules/ruflo/node_modules/@claude-flow/memory/dist/index.js"
  )
  for f in "${candidates[@]}"; do
    if [ -f "$f" ]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

INDEX_JS=$(find_index) || { echo "[patch-cr] @claude-flow/memory not found, skipping"; exit 0; }

# Idempotency: skip if already patched
if grep -q 'export class ControllerRegistry' "$INDEX_JS" 2>/dev/null; then
  echo "[patch-cr] Already patched: $INDEX_JS"
  exit 0
fi

echo "[patch-cr] Patching: $INDEX_JS"

# Remove trailing sourcemap comment if present (we'll re-add it)
sed -i '/^\/\/# sourceMappingURL=index\.js\.map$/d' "$INDEX_JS"

cat >> "$INDEX_JS" << 'PATCH_EOF'

// ===== ControllerRegistry shim (missing upstream export — required by memory-bridge.js) =====
import * as _cr_path from 'path';
import * as _cr_crypto from 'crypto';
import * as _cr_fs from 'fs';

class _HierarchicalMemory {
    constructor(db) { this._db = db; this._init(); }
    _init() {
        this._db.exec(`CREATE TABLE IF NOT EXISTS hierarchical_memory (
            id TEXT PRIMARY KEY,
            key TEXT,
            content TEXT NOT NULL,
            tier TEXT NOT NULL DEFAULT 'working',
            importance REAL DEFAULT 0.5,
            tags TEXT DEFAULT '[]',
            metadata TEXT DEFAULT '{}',
            access_count INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')*1000),
            updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now')*1000),
            decayed_at INTEGER
        )`);
        this._db.exec(`CREATE INDEX IF NOT EXISTS idx_hm_tier ON hierarchical_memory(tier)`);
        this._db.exec(`CREATE INDEX IF NOT EXISTS idx_hm_key ON hierarchical_memory(key)`);
    }
    async store(content, importance = 0.5, tier = 'working', options = {}) {
        const id = _cr_crypto.randomUUID();
        const key = options?.metadata?.key || null;
        const tags = JSON.stringify(options?.tags || []);
        const metadata = JSON.stringify(options?.metadata || {});
        const now = Date.now();
        this._db.prepare(
            `INSERT INTO hierarchical_memory (id, key, content, tier, importance, tags, metadata, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
        ).run(id, key, content, tier, importance, tags, metadata, now, now);
        return id;
    }
    async recall(query) {
        const q = typeof query === 'string' ? { query, k: 5 } : query;
        const k = q.k || 5;
        const tierFilter = q.tier ? `AND tier = ?` : '';
        const searchPattern = `%${q.query}%`;
        const params = q.tier
            ? [searchPattern, searchPattern, searchPattern, q.tier, k]
            : [searchPattern, searchPattern, searchPattern, k];
        const rows = this._db.prepare(
            `SELECT * FROM hierarchical_memory
             WHERE (content LIKE ? OR key LIKE ? OR tags LIKE ?) ${tierFilter}
             ORDER BY importance DESC, updated_at DESC LIMIT ?`
        ).all(...params);
        return rows.map(r => ({
            id: r.id, key: r.key, content: r.content, tier: r.tier,
            importance: r.importance, tags: JSON.parse(r.tags || '[]'),
            metadata: JSON.parse(r.metadata || '{}'),
            createdAt: r.created_at, updatedAt: r.updated_at,
            accessCount: r.access_count,
        }));
    }
    getStats() {
        const total = this._db.prepare(`SELECT COUNT(*) as cnt FROM hierarchical_memory`).get();
        const byTier = this._db.prepare(
            `SELECT tier, COUNT(*) as cnt FROM hierarchical_memory GROUP BY tier`
        ).all();
        return { total: total?.cnt || 0, byTier: Object.fromEntries(byTier.map(r => [r.tier, r.cnt])) };
    }
    async promote(id, toTier = 'semantic') {
        this._db.prepare(`UPDATE hierarchical_memory SET tier = ?, updated_at = ? WHERE id = ?`)
            .run(toTier, Date.now(), id);
    }
}

class _TieredCache {
    constructor() { this._cache = new Map(); }
    get(key) { return this._cache.get(key) ?? null; }
    set(key, value, ttl) { this._cache.set(key, value); }
    delete(key) { this._cache.delete(key); }
    clear() { this._cache.clear(); }
    getStats() { return { size: this._cache.size, hits: 0, misses: 0 }; }
}

class _ReasoningBank {
    constructor(db) { this._db = db; this._init(); }
    _init() {
        this._db.exec(`CREATE TABLE IF NOT EXISTS reasoning_patterns (
            id TEXT PRIMARY KEY, pattern TEXT NOT NULL, type TEXT DEFAULT 'general',
            confidence REAL DEFAULT 0.8, hits INTEGER DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')*1000)
        )`);
    }
    async store(pattern, type = 'general', confidence = 0.8) {
        const id = _cr_crypto.randomUUID();
        this._db.prepare(`INSERT INTO reasoning_patterns (id, pattern, type, confidence, created_at) VALUES (?,?,?,?,?)`)
            .run(id, pattern, type, confidence, Date.now());
        return id;
    }
    async search(query, topK = 5, minConfidence = 0.3) {
        return this._db.prepare(
            `SELECT * FROM reasoning_patterns WHERE pattern LIKE ? AND confidence >= ? ORDER BY confidence DESC, hits DESC LIMIT ?`
        ).all(`%${query}%`, minConfidence, topK);
    }
    async recordFeedback(patternId, success, quality) {
        if (success) this._db.prepare(`UPDATE reasoning_patterns SET hits = hits + 1 WHERE id = ?`).run(patternId);
    }
}

export class ControllerRegistry {
    constructor() {
        this._db = null;
        this._controllers = new Map();
        this._config = null;
    }
    async initialize(config) {
        this._config = config;
        const dbPath = config.dbPath || _cr_path.join(process.cwd(), '.swarm', 'memory.db');
        const dir = _cr_path.dirname(dbPath);
        if (!_cr_fs.existsSync(dir)) _cr_fs.mkdirSync(dir, { recursive: true });
        const Database = (await import('better-sqlite3')).default;
        this._db = new Database(dbPath);
        this._db.pragma('journal_mode = WAL');
        this._db.pragma('synchronous = NORMAL');
        const ctrlConfig = config.controllers || {};
        if (ctrlConfig.hierarchicalMemory !== false) {
            this._controllers.set('hierarchicalMemory', new _HierarchicalMemory(this._db));
        }
        if (ctrlConfig.tieredCache !== false) {
            this._controllers.set('tieredCache', new _TieredCache());
        }
        if (ctrlConfig.reasoningBank !== false) {
            this._controllers.set('reasoningBank', new _ReasoningBank(this._db));
        }
        const stubs = ['memoryConsolidation','memoryGraph','learningBridge','causalGraph',
            'reflexion','nightlyLearner','semanticRouter','learningSystem',
            'attestationLog','mutationGuard','skills','batchOperations','contextSynthesizer'];
        for (const name of stubs) {
            if (!this._controllers.has(name)) this._controllers.set(name, null);
        }
    }
    get(name) { return this._controllers.get(name) ?? null; }
    getAgentDB() { return { database: this._db }; }
    listControllers() {
        return Array.from(this._controllers.entries()).map(([name, ctrl]) => ({
            name, enabled: ctrl !== null, type: ctrl?.constructor?.name || 'stub',
        }));
    }
    async shutdown() {
        if (this._db) { try { this._db.close(); } catch {} this._db = null; }
        this._controllers.clear();
    }
}
//# sourceMappingURL=index.js.map
PATCH_EOF

echo "[patch-cr] Patch applied successfully"
