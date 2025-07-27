const express = require('express');
const spdy = require('spdy');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { createProxyMiddleware } = require('http-proxy-middleware');
const history = require('connect-history-api-fallback');
const compression = require('compression');
const config = require('./config');

const app = express();
app.set('env', 'production');

// --- SSL Configuration ---
// Read SSL certificate and key. If not present, HTTPS will be disabled.
const key = config.ssl?.key ? fs.readFileSync(path.join(process.cwd(), 'ssl', config.ssl.key), 'utf8') : '';
const cert = config.ssl?.crt ? fs.readFileSync(path.join(process.cwd(), 'ssl', config.ssl.crt), 'utf8') : '';

// --- Middleware Setup ---

// NEW: Body Parser Middleware
// This is crucial for parsing JSON and URL-encoded request bodies, e.g., for POST /login.
// It should come before any routes or proxies that need to read the body.
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 1. Security with Helmet
// Note: HSTS is disabled by default (maxAge: 0) to avoid browser caching issues during development.
// It can be enabled in a production environment by setting a maxAge.
if (key && cert) {
  app.use(
    helmet({
      hsts: { maxAge: 0, includeSubDomains: false },
      contentSecurityPolicy: {
        directives: {
          ...helmet.contentSecurityPolicy.getDefaultDirectives(),
          'img-src': ["'self'", 'data:', 'blob:', 'mediastream:', 'filesystem:'],
        },
      },
    })
  );
}

// 2. Rate Limiting
// Applied to all requests to prevent abuse.
const limiter = rateLimit(config.limiter);
app.use(limiter);

// 3. Compression
// Compresses responses to save bandwidth.
app.use(
  compression({
    filter: (req, res) => !req.headers['x-no-compression'] && compression.filter(req, res),
    level: 5,
  })
);

// 4. API Proxying
// This MUST come before static file serving and history fallback.
// It intercepts requests to /api or /login and forwards them to the backend.
const proxyLogProvider = () => ({
    log: (message) => console.log(`[HPM] ${message}`),
    debug: (message) => console.log(`[HPM-DEBUG] ${message}`),
    info: (message) => console.info(`[HPM-INFO] ${message}`),
    warn: (message) => console.warn(`[HPM-WARN] ${message}`),
    error: (message) => console.error(`[HPM-ERROR] ${message}`),
});

if (Array.isArray(config.proxy)) {
  config.proxy.forEach(proxyConfig => {
    app.use(proxyConfig.path, createProxyMiddleware({ ...proxyConfig, logLevel: 'debug', logProvider: proxyLogProvider }));
  });
}

// 5. Static File Serving
// Serves the Vue.js app (and login.html) from the 'dist' directory.
app.use(express.static(path.join(__dirname, 'dist'), {
  maxAge: config.maxAge,
}));

// 6. SPA History API Fallback
// Rewrites all non-file requests to /index.html, allowing Vue Router to handle them.
app.use(history());

// 7. Serve Static Files Again
// This is necessary to correctly serve files like index.html after the history fallback rewrite.
app.use(express.static(path.join(__dirname, 'dist'), {
  maxAge: config.maxAge,
}));


// --- Server Initialization ---

// HTTP Server
const httpServer = http.createServer(
  // If SSL is enabled, redirect HTTP to HTTPS. Otherwise, serve the app directly.
  key && cert
    ? (req, res) => {
        const host = req.headers['host']?.split(':')[0] || '';
        res.writeHead(301, { Location: `https://${host}:${config.httpsPort}${req.url}` });
        res.end();
      }
    : app
);

httpServer.listen(config.httpPort, () => console.log(`HTTP server listening on http://127.0.0.1:${config.httpPort}`));
httpServer.on('connection', socket => socket.setTimeout(config.setTimeout));

// HTTPS Server (only if SSL is configured)
if (key && cert) {
  const httpsServer = spdy.createServer({ key, cert, spdy: { protocols: ['h2', 'http/1.1'] } }, app);
  httpsServer.listen(config.httpsPort, () => console.log(`HTTPS server listening on https://127.0.0.1:${config.httpsPort}`));
  httpsServer.on('connection', socket => socket.setTimeout(config.setTimeout));
}
