import http from 'node:http';

const port = Number.parseInt(process.env.DYNAMIC_MCP_FIXTURE_PORT || '8799', 10);

function sendJson(res, status, payload, extraHeaders = {}) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Mcp-Session-Id': 'fixture-session',
    ...extraHeaders
  });
  res.end(body);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', chunk => chunks.push(chunk));
    req.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'));
      } catch (error) {
        reject(error);
      }
    });
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method !== 'POST' || req.url !== '/mcp') {
      sendJson(res, 404, { jsonrpc: '2.0', id: null, error: { code: -32004, message: 'Not found' } });
      return;
    }
    const body = await readJson(req);
    if (body.method === 'initialize') {
      sendJson(res, 200, {
        jsonrpc: '2.0',
        id: body.id,
        result: {
          protocolVersion: '2025-06-18',
          capabilities: { tools: {} },
          serverInfo: { name: 'fixture-mcp', version: '0.1' }
        }
      });
      return;
    }
    if (body.method === 'tools/list') {
      sendJson(res, 200, {
        jsonrpc: '2.0',
        id: body.id,
        result: {
          tools: [
            {
              name: 'echo',
              description: 'Return a deterministic echo result',
              inputSchema: {
                type: 'object',
                required: ['query'],
                properties: { query: { type: 'string' } }
              }
            }
          ]
        }
      });
      return;
    }
    if (body.method === 'tools/call') {
      sendJson(res, 200, {
        jsonrpc: '2.0',
        id: body.id,
        result: {
          content: [{ type: 'text', text: 'fixture echo: ' + (body.params?.arguments?.query || '') }],
          structuredContent: {
            query: body.params?.arguments?.query || '',
            source: 'fixture'
          },
          isError: false
        }
      });
      return;
    }
    sendJson(res, 400, { jsonrpc: '2.0', id: body.id || null, error: { code: -32601, message: 'Unknown method' } });
  } catch (error) {
    sendJson(res, 500, {
      jsonrpc: '2.0',
      id: null,
      error: {
        code: -32000,
        message: error instanceof Error ? error.message : String(error)
      }
    });
  }
});

server.on('error', error => {
  console.error(`dynamic MCP fixture failed to listen: ${error.message}`);
  process.exit(1);
});

server.listen(port, '127.0.0.1', () => {
  console.log(`dynamic MCP fixture listening on http://127.0.0.1:${port}/mcp`);
});
