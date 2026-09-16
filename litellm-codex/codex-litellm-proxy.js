// codex-litellm-proxy.js - bridge between Codex and LiteLLM
// Corrige /v1/models : Codex attend {"models":[...]}, LiteLLM renvoie {"data":[...]}
// Launch: node "C:\Serveurs\Codex Free\litellm-codex\codex-litellm-proxy.js"
const http = require('http');
const LITELLM_PORT = 4200;
const PROXY_PORT = 4201;

const server = http.createServer((req, res) => {
  const options = {
    hostname: '127.0.0.1',
    port: LITELLM_PORT,
    path: req.url,
    method: req.method,
    headers: { ...req.headers, host: '127.0.0.1:' + LITELLM_PORT }
  };

  if (req.url === '/v1/models') {
    const proxy = http.request(options, (proxyRes) => {
      let body = '';
      proxyRes.on('data', chunk => body += chunk);
      proxyRes.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          if (parsed.data && !parsed.models) {
            parsed.models = parsed.data;
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify(parsed));
            return;
          }
        } catch (_) { /* ignore parse errors */ }
        res.writeHead(proxyRes.statusCode, proxyRes.headers);
        res.end(body);
      });
    });
    proxy.on('error', () => { res.writeHead(502); res.end('Proxy error'); });
    proxy.end();
    return;
  }

  // Toutes les autres requêtes : proxy pass-through
  const proxy = http.request(options, (proxyRes) => {
    res.writeHead(proxyRes.statusCode, proxyRes.headers);
    proxyRes.pipe(res);
  });
  proxy.on('error', () => { res.writeHead(502); res.end('Proxy error'); });
  req.pipe(proxy);
});

server.listen(PROXY_PORT, '127.0.0.1', () => {
  console.log('codex-litellm-proxy: :' + LITELLM_PORT + ' -> :' + PROXY_PORT + ' (models fix)');
});
