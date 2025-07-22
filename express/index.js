const express = require('express');
const spdy = require('spdy');
const rateLimit = require('express-rate-limit');

const helmet = require('helmet');

const path = require('path');
const config = require(path.join(process.cwd(), './config'));

const fs = require('fs');
const http = require('http');

const { createProxyMiddleware } = require('http-proxy-middleware');
const history = require('connect-history-api-fallback');
const compression = require('compression');

const app = express();

app.set('env', 'production');

const key = config.ssl?.key == '' ? '' : fs.readFileSync(path.join(process.cwd(), 'ssl', '/' + config.ssl?.key), 'utf8');
const cert = config.ssl?.crt == '' ? '' : fs.readFileSync(path.join(process.cwd(), 'ssl', '/' + config.ssl?.crt), 'utf8');

const httpServer = http.createServer(
  key == '' || cert == ''
    ? app
    : (req, res) => {
        res.writeHead(301, { Location: 'https://' + req.headers['host'].split(':')[0] + ':' + config.httpsPort + req.url });
        res.end();
      }
);

const limiter = rateLimit(config.limiter);

// Apply rate limiting and compression to all requests
app.use(limiter);
app.use(
  compression({
    filter: (req, res) => {
      if (req.headers['x-no-compression']) {
        return false;
      }
      return compression.filter(req, res);
    },
    level: 5,
  })
);

// Proxy API requests FIRST
if (Array.isArray(config.proxy)) {
  config.proxy.forEach(proxy => {
    const proxyOptions = {
      ...proxy,
      onProxyReq: (proxyReq, req, res) => {
        console.log(`[HPM] Proxying request ${req.method} ${req.url} to ${proxy.target}${proxyReq.path}`);
      },
      onError: (err, req, res) => {
        console.error('[HPM] Proxy error:', err);
        if (!res.headersSent) {
            res.status(500).send('Proxy error');
        }
      }
    };
    app.use(proxy.path, createProxyMiddleware(proxyOptions));
  });
}

// Static files middleware for the main Vue app and login page
app.use(express.static(path.join(__dirname, 'dist'), {
  maxAge: config.maxAge,
}));

// History API fallback for SPA (Vue)
// This should come after static middleware and proxies
app.use(history());

// Serve static files again to catch history fallback rewrites (e.g., /index.html)
app.use(express.static(path.join(__dirname, 'dist'), {
  maxAge: config.maxAge,
}));


httpServer.listen(config.httpPort, () => console.log('http:' + config.httpPort));
httpServer.on('connection', socket => socket.setTimeout(config.setTimeout));

if (key == '' || cert == '') return;
const httpsServer = spdy.createServer(
  {
    key,
    cert,
    spdy: {
      protocols: ['h2', 'spdy/3.1', 'spdy/3', 'spdy/2', 'http/1.1', 'http/1.0'],
    },
  },
  app
);
httpsServer.listen(config.httpsPort, () => console.log('https:' + config.httpsPort));
httpsServer.on('connection', socket => socket.setTimeout(config.setTimeout));
