#!/usr/bin/env bash
# Patch @claude-flow/memory to export ControllerRegistry
# Required because memory-bridge.js imports it but the package doesn't export it.
# This creates a SQLite-backed ControllerRegistry with HierarchicalMemory,
# TieredCache, and ReasoningBank controllers.
#
# Safe to re-run: checks for marker before patching.
set -euo pipefail

# Find the index.js to patch — nvm global install
find_index() {
  for f in "$HOME"/.nvm/versions/node/*/lib/node_modules/ruflo/node_modules/@claude-flow/memory/dist/index.js; do
    if [ -f "$f" ]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

INDEX_JS=$(find_index) || { echo "[patch-cr] @claude-flow/memory not found, skipping"; exit 0; }

# Idempotency: skip if already patched WITH contextSynthesizer + n-gram embedder
if grep -q 'export class ControllerRegistry' "$INDEX_JS" 2>/dev/null && \
   grep -q '_ContextSynthesizer' "$INDEX_JS" 2>/dev/null && \
   grep -q '0x811c9dc5' "$INDEX_JS" 2>/dev/null; then
  echo "[patch-cr] Already patched (with contextSynthesizer + embedder): $INDEX_JS"
  exit 0
fi

# If old patch exists, strip it and re-apply
if grep -q 'export class ControllerRegistry' "$INDEX_JS" 2>/dev/null; then
  echo "[patch-cr] Upgrading patch (adding contextSynthesizer + embedder): $INDEX_JS"
  # Remove old patch (everything from the shim marker to end)
  sed -i '/^\/\/ ===== ControllerRegistry shim/,$d' "$INDEX_JS"
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

class _ContextSynthesizer {
    synthesize(memories, options = {}) {
        if (!memories || memories.length === 0) {
            return { summary: '', entries: 0, recommendations: [] };
        }
        // Deduplicate by key
        const seen = new Set();
        const unique = memories.filter(m => {
            const k = m.key || m.content;
            if (seen.has(k)) return false;
            seen.add(k);
            return true;
        });
        // Build synthesized context from memory entries
        const parts = unique.map((m, i) => {
            const label = m.key ? `[${m.key}]` : `[entry-${i}]`;
            return `${label} ${m.content}`;
        });
        const summary = parts.join('\n\n');
        const result = {
            summary,
            entries: unique.length,
            sources: unique.map(m => m.key || 'unknown'),
        };
        if (options.includeRecommendations) {
            result.recommendations = unique.length > 5
                ? ['Consider consolidating related entries']
                : [];
        }
        return result;
    }
}

class _HashEmbedder {
    constructor(dimensions = 384) {
        this._dimensions = dimensions;
    }
    _hash(str) {
        let h = 0x811c9dc5;
        for (let i = 0; i < str.length; i++) {
            h ^= str.charCodeAt(i);
            h = Math.imul(h, 0x01000193);
        }
        return h >>> 0;
    }
    async embed(text) {
        const dims = this._dimensions;
        const embedding = new Float32Array(dims);
        const normalized = String(text).toLowerCase().replace(/[^a-z0-9 ]/g, '');
        const words = normalized.split(/\s+/).filter(w => w.length > 0);
        // Word unigrams (position-independent)
        for (const word of words) {
            const idx = this._hash('w:' + word) % dims;
            embedding[idx] += 1.0;
        }
        // Character trigrams for fuzzy matching (deploy ↔ deployment)
        const padded = '  ' + normalized + '  ';
        for (let i = 0; i < padded.length - 2; i++) {
            const tri = padded.substring(i, i + 3);
            const idx = this._hash('t:' + tri) % dims;
            embedding[idx] += 0.3;
        }
        // Normalize to unit vector
        let mag = 0;
        for (let i = 0; i < dims; i++) mag += embedding[i] * embedding[i];
        mag = Math.sqrt(mag) || 1;
        for (let i = 0; i < dims; i++) embedding[i] /= mag;
        return embedding;
    }
}

class _CausalMemoryGraph {
    constructor(db) { this._db = db; this._init(); }
    _init() {
        this._db.exec(`CREATE TABLE IF NOT EXISTS causal_edges (
            id TEXT PRIMARY KEY,
            source_id TEXT NOT NULL,
            target_id TEXT NOT NULL,
            relation TEXT NOT NULL,
            weight REAL DEFAULT 1.0,
            metadata TEXT DEFAULT '{}',
            created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')*1000),
            UNIQUE(source_id, target_id, relation)
        )`);
        this._db.exec(`CREATE INDEX IF NOT EXISTS idx_ce_source ON causal_edges(source_id)`);
        this._db.exec(`CREATE INDEX IF NOT EXISTS idx_ce_target ON causal_edges(target_id)`);
    }
    addEdge(sourceId, targetId, options = {}) {
        const id = _cr_crypto.randomUUID();
        this._db.prepare(
            `INSERT OR REPLACE INTO causal_edges (id, source_id, target_id, relation, weight, metadata, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)`
        ).run(id, sourceId, targetId, options.relation || 'caused', options.weight ?? 1.0,
            JSON.stringify({ timestamp: options.timestamp || Date.now() }), Date.now());
        return id;
    }
    getEdges(nodeId) {
        const outgoing = this._db.prepare(
            `SELECT * FROM causal_edges WHERE source_id = ? ORDER BY created_at DESC`
        ).all(nodeId);
        const incoming = this._db.prepare(
            `SELECT * FROM causal_edges WHERE target_id = ? ORDER BY created_at DESC`
        ).all(nodeId);
        return { outgoing, incoming };
    }
    getPath(sourceId, targetId, maxDepth = 5) {
        const visited = new Set();
        const queue = [[sourceId]];
        while (queue.length > 0) {
            const path = queue.shift();
            const current = path[path.length - 1];
            if (current === targetId) return path;
            if (path.length >= maxDepth || visited.has(current)) continue;
            visited.add(current);
            const edges = this._db.prepare(
                `SELECT target_id FROM causal_edges WHERE source_id = ?`
            ).all(current);
            for (const edge of edges) {
                queue.push([...path, edge.target_id]);
            }
        }
        return null;
    }
    getStats() {
        const total = this._db.prepare(`SELECT COUNT(*) as cnt FROM causal_edges`).get();
        const relations = this._db.prepare(
            `SELECT relation, COUNT(*) as cnt FROM causal_edges GROUP BY relation`
        ).all();
        return { totalEdges: total?.cnt || 0, byRelation: Object.fromEntries(relations.map(r => [r.relation, r.cnt])) };
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
        if (ctrlConfig.causalGraph !== false) {
            this._controllers.set('causalGraph', new _CausalMemoryGraph(this._db));
        }
        if (ctrlConfig.contextSynthesizer !== false) {
            this._controllers.set('contextSynthesizer', new _ContextSynthesizer());
        }
        this._embedder = new _HashEmbedder(config.dimension || 384);
        const stubs = ['memoryConsolidation','memoryGraph','learningBridge',
            'reflexion','nightlyLearner','semanticRouter','learningSystem',
            'attestationLog','mutationGuard','skills','batchOperations'];
        for (const name of stubs) {
            if (!this._controllers.has(name)) this._controllers.set(name, null);
        }
    }
    get(name) { return this._controllers.get(name) ?? null; }
    getAgentDB() { return { database: this._db, embedder: this._embedder }; }
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
