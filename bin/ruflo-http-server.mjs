#!/usr/bin/env node
// ruflo-http-server.mjs -- Standalone HTTP MCP server for ruflo
// Starts the @claude-flow/mcp server in HTTP mode and registers all
// ruflo MCP tools from the CLI package's mcp-client module.
//
// Usage: node ruflo-http-server.mjs [--port PORT]
//
// This avoids the ruflo wrapper's stdio auto-detection that prevents
// background HTTP startup.
//
// Patches applied on top of @claude-flow/mcp HTTP transport:
//   1. protocolVersion: object -> string "2025-11-25" (MCP spec compliance)
//   2. Mcp-Session-Id header on all /mcp responses (Streamable HTTP spec)
//   3. SSE response wrapping when Accept: text/event-stream (Streamable HTTP spec)

import { createRequire } from 'node:module';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { randomUUID } from 'node:crypto';

const PORT = (() => {
  const idx = process.argv.indexOf('--port');
  if (idx !== -1 && process.argv[idx + 1]) {
    const p = parseInt(process.argv[idx + 1], 10);
    if (!isNaN(p) && p > 0 && p < 65536) return p;
  }
  return 3456;
})();

const HOST = 'localhost';

// Resolve ruflo package paths
const RUFLO_BASE = (() => {
  try {
    const require_ = createRequire(import.meta.url);
    const rufloMain = require_.resolve('ruflo/bin/ruflo.js');
    // ruflo/bin/ruflo.js -> ruflo/
    return resolve(rufloMain, '../..');
  } catch {
    // Fallback to known NVM path
    return '/home/jon.gao/.nvm/versions/node/v22.19.0/lib/node_modules/ruflo';
  }
})();

const CLI_BASE = join(RUFLO_BASE, 'node_modules/@claude-flow/cli');
const MCP_BASE = join(RUFLO_BASE, 'node_modules/@claude-flow/mcp');

function toURL(p) {
  return pathToFileURL(p).href;
}

async function main() {
  console.error(`[ruflo-http] Starting HTTP MCP server on ${HOST}:${PORT}`);
  console.error(`[ruflo-http] CLI base: ${CLI_BASE}`);
  console.error(`[ruflo-http] MCP base: ${MCP_BASE}`);

  // Import the MCP server creator
  const { createMCPServer } = await import(
    toURL(join(MCP_BASE, 'dist/index.js'))
  );

  // Import the tool registry from mcp-client
  const { listMCPTools, callMCPTool, hasTool } = await import(
    toURL(join(CLI_BASE, 'dist/src/mcp-client.js'))
  );

  const logger = {
    debug: (msg, data) => {},
    info: (msg, data) =>
      console.error(`[ruflo-http] INFO: ${msg}`, data ? JSON.stringify(data) : ''),
    warn: (msg, data) =>
      console.error(`[ruflo-http] WARN: ${msg}`, data ? JSON.stringify(data) : ''),
    error: (msg, data) =>
      console.error(`[ruflo-http] ERROR: ${msg}`, data ? JSON.stringify(data) : ''),
  };

  // Create MCP server in HTTP mode
  const server = createMCPServer(
    {
      name: 'ruflo-shared',
      version: '3.0.0',
      transport: 'http',
      host: HOST,
      port: PORT,
      enableMetrics: true,
      enableCaching: true,
      corsEnabled: true,
      corsOrigins: ['*'],
    },
    logger
  );

  // Register all ruflo tools from the CLI package
  const tools = listMCPTools();
  let registered = 0;

  // Patch inputSchema properties that lack a "type" field.
  // The upstream MCP server's registerTool validates that every property has a
  // type and silently drops tools that fail (e.g. memory_store, config_set).
  // These "typeless" properties accept any JSON value, so we default them to
  // "string" which matches the handlers (they JSON.stringify non-strings).
  function patchSchema(schema) {
    if (!schema || !schema.properties) return schema;
    const patched = { ...schema, properties: { ...schema.properties } };
    for (const [key, prop] of Object.entries(patched.properties)) {
      if (prop && typeof prop === 'object' && !prop.type && !prop.oneOf && !prop.anyOf && !prop.allOf && !prop.$ref) {
        patched.properties[key] = { ...prop, type: 'string' };
      }
    }
    return patched;
  }

  for (const tool of tools) {
    try {
      server.registerTool({
        name: tool.name,
        description: tool.description || '',
        inputSchema: patchSchema(tool.inputSchema) || { type: 'object', properties: {} },
        handler: async (input) => {
          return await callMCPTool(tool.name, input);
        },
        category: tool.category,
        cacheable: tool.cacheable,
        cacheTTL: tool.cacheTTL,
      });
      registered++;
    } catch (e) {
      // Skip duplicate registrations from built-in tools
      if (!e.message?.includes('already registered')) {
        logger.warn(`Failed to register tool ${tool.name}: ${e.message}`);
      }
    }
  }

  logger.info(`Registered ${registered}/${tools.length} ruflo tools`);

  // Start the server
  await server.start();

  // --- Patch 1: Fix protocolVersion format ---
  // Upstream returns {major:2025, minor:11, patch:25} but MCP spec requires
  // the string "2025-11-25". Setting the instance property shadows the class
  // default so handleInitialize returns the correct format.
  server.protocolVersion = '2025-11-25';

  // --- Patches 2 & 3: Mcp-Session-Id header + SSE response wrapping ---
  // The Streamable HTTP transport spec requires:
  //   - Mcp-Session-Id header in all responses (generated on initialize)
  //   - SSE format when client sends Accept: text/event-stream
  const sessionId = randomUUID();
  const transport = server.transport;
  const origHandleHttp = transport.handleHttpRequest.bind(transport);

  // Track whether any client has completed the initialize handshake.
  // Subagents sharing the daemon may never send one, causing -32002.
  let autoInitialized = false;

  transport.handleHttpRequest = async function patchedHandler(req, res) {
    // Patch 2: Add session header to every /mcp response
    res.set('Mcp-Session-Id', sessionId);

    // Patch 4: Auto-initialize for subagents that skip the handshake.
    // If a tools/call or tools/list arrives before any initialize, we
    // synthesize the initialize call internally so the server transitions
    // to the initialized state.
    if (!autoInitialized) {
      const method = Array.isArray(req.body)
        ? req.body[0]?.method
        : req.body?.method;
      if (method === 'initialize') {
        autoInitialized = true;
      } else if (method) {
        autoInitialized = true;
        logger.info('Auto-initializing for client (no prior initialize handshake)');
        const fakeRes = {
          set: () => fakeRes, status: () => fakeRes,
          json: () => fakeRes, send: () => fakeRes,
          write: () => true, end: () => {},
          headersSent: false,
        };
        const fakeReq = {
          headers: { ...req.headers },
          body: {
            jsonrpc: '2.0', method: 'initialize', id: '_auto_init_',
            params: {
              protocolVersion: '2025-11-25',
              capabilities: {},
              clientInfo: { name: 'ruflo-auto-init', version: '1.0.0' },
            },
          },
          method: req.method,
          url: req.url,
          get: (h) => req.headers[(h || '').toLowerCase()],
        };
        try {
          await origHandleHttp(fakeReq, fakeRes);
          // Step 2: Send notifications/initialized to complete the handshake.
          // Without this the server stays in "not initialized" state (-32002).
          const notifRes = {
            set: () => notifRes, status: () => notifRes,
            json: () => notifRes, send: () => notifRes,
            write: () => true, end: () => {},
            headersSent: false,
          };
          const notifReq = {
            headers: { ...req.headers },
            body: {
              jsonrpc: '2.0',
              method: 'notifications/initialized',
            },
            method: req.method,
            url: req.url,
            get: (h) => req.headers[(h || '').toLowerCase()],
          };
          await origHandleHttp(notifReq, notifRes);
        } catch (e) {
          logger.warn(`Auto-initialize failed: ${e.message}`);
        }
      }
    }

    // Patch 3: If client wants SSE, intercept res.json to wrap in SSE format
    const wantsSSE = (req.headers['accept'] || '').includes('text/event-stream');
    if (wantsSSE) {
      const origJson = res.json.bind(res);
      res.json = function sseWrap(data) {
        res.set('Content-Type', 'text/event-stream');
        res.set('Cache-Control', 'no-cache');
        res.set('Connection', 'keep-alive');
        res.write('event: message\n');
        res.write('data: ' + JSON.stringify(data) + '\n\n');
        res.end();
        return res;
      };
    }

    return origHandleHttp(req, res);
  };

  logger.info(`HTTP MCP server listening on http://${HOST}:${PORT}`);
  logger.info('Endpoints: POST /mcp, GET /health, WS /ws');
  logger.info(`Session ID: ${sessionId}`);

  // Graceful shutdown
  const shutdown = async (signal) => {
    logger.info(`Received ${signal}, shutting down...`);
    try {
      await server.stop();
    } catch {
      // ignore
    }
    process.exit(0);
  };

  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));

  // Keep alive
  setInterval(() => {}, 60000);
}

main().catch((e) => {
  console.error(`[ruflo-http] Fatal: ${e.message}`);
  console.error(e.stack);
  process.exit(1);
});
