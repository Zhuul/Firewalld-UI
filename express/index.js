const express = require('express');
const spdy = require('spdy');
const rateLimit = require('express-rate-limit');

const helmet = require('helmet');

const path = require('path');
const config = {
  httpPort: 5000,
  httpsPort: 5001,
  setTimeout: 30000,
  maxAge: 31536000,
  ssl: { key: '', crt: '' },
  limiter: {
    windowMs: 15 * 60 * 1000,
    max: 1000  // Increased from 100 to 1000
  },
  proxy: {
    target: 'http://127.0.0.1:7001',
    changeOrigin: true,
    pathRewrite: { '^/api': '/' }
  }
};

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

if (key != '' && cert != '') {
  app.use(
    helmet({
      hsts: {
        maxAge: 0,
        includeSubDomains: false,
        preload: true,
      },
      dnsPrefetchControl: { allow: true },
      contentSecurityPolicy: {
        directives: {
          'img-src': ['data:', 'blob:', 'mediastream:', 'filesystem:', "'self' img.example.com"],
        },
      },
    })
  );
}

// First define a route handler that always sends our custom login page
app.get('/login', (req, res) => {
  console.log("[DEBUG] Explicitly serving custom login page");
  return res.sendFile(path.resolve(__dirname, './dist/login.html'));
});

// Then structure the rest of the middleware
app
  .use((req, res, next) => {
    console.log(`[DEBUG] ${new Date().toISOString()} - ${req.method} ${req.url}`);
    // If the request is for /login, send our custom login page
    if (req.path === '/login' && req.method === 'GET') {
      return res.sendFile(path.resolve(__dirname, './dist/login.html'));
    }
    next();
  })
  // Apply rate limiter but exclude certain paths
  .use((req, res, next) => {
    if (req.path === '/login' || req.path.startsWith('/assets/') || req.path === '/favicon.ico') {
      return next();
    }
    limiter(req, res, next);
  })
  .use(
    compression({
      filter: (req, res) => {
        if (req.headers['x-no-compression']) {
          return false;
        }
        return compression.filter(req, res);
      },
      level: 5,
    })
  )
  // API endpoints
  .get('/api/user/getPublicKeyFingerprint', (req, res) => {
    console.log("[DEBUG] Serving fingerprint request");
    res.json({
      success: true,
      data: {
        publicKeyFingerprint: 'static-fingerprint-for-testing',
        publicKey: '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxDfiU7rx04EfpxJcZ0Bq\nvZjtL9UhcX8YVBKg8KWrxh4Sb5wLQ4HwQvFIFt82S42g7I2hLi2cw6wVpjKifcAE\nz63KCH8peWm2eEZuLqhhxYt/mHMBqNficSzT+CPt/SvGuFj08gOzjqRUcukdoFqo\n/ThV4QGlUWfeIqg7sG+1ex+icsU3s0DxtoUK2pQwapTofuD9GbgdabanaQf1YAHT\nNtYzXdhnQ3y/j8yKwAbvgI5tJhjkQk4OnQL6lo9vASNnn6XuhAOFlYLmzGGEAC3b\nkkUhqcpxseyXAcs6stTjMeZZiyvF75MeHh+wfq/iI07DoanBp4SdpoW+FXvmJMUo\nZwIDAQAB\n-----END PUBLIC KEY-----\n'
      },
      message: 'success',
      code: 200
    });
  })
  .get('/captcha', (req, res) => {
    console.log("[DEBUG] Serving captcha request");
    res.json({
      success: true,
      data: {
        publicKey: '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxDfiU7rx04EfpxJcZ0Bq\nvZjtL9UhcX8YVBKg8KWrxh4Sb5wLQ4HwQvFIFt82S42g7I2hLi2cw6wVpjKifcAE\nz63KCH8peWm2eEZuLqhhxYt/mHMBqNficSzT+CPt/SvGuFj08gOzjqRUcukdoFqo\n/ThV4QGlUWfeIqg7sG+1ex+icsU3s0DxtoUK2pQwapTofuD9GbgdabanaQf1YAHT\nNtYzXdhnQ3y/j8yKwAbvgI5tJhjkQk4OnQL6lo9vASNnn6XuhAOFlYLmzGGEAC3b\nkkUhqcpxseyXAcs6stTjMeZZiyvF75MeHh+wfq/iI07DoanBp4SdpoW+FXvmJMUo\nZwIDAQAB\n-----END PUBLIC KEY-----\n',
        captchaSecret: 'static-captcha-secret',
        svg: '<svg xmlns="http://www.w3.org/2000/svg" width="150" height="50" viewBox="0,0,150,50"><path d="M 40,40 L 80,40 L 80,10 L 40,10 Z" fill="#f2f2f2"/><path fill="#333" d="M61.32 28.24L61.33 28.25L61.60 27.08L61.71 27.19Q62.85 26.92 64.11 26.88L64.09 26.86L64.20 26.97Q64.15 24.24 64.31 23.04L64.28 23.01L64.21 22.94Q63.75 22.98 62.13 22.92L62.14 22.93L61.91 24.89L61.80 24.78Q60.37 24.74 58.50 24.41L58.43 24.34L58.59 24.50Q58.43 23.18 58.43 22.24L58.46 22.26L58.48 22.29Q59.21 22.29 60.55 22.41L60.64 22.50L60.57 22.44Q63.23 22.31 65.92 22.62L65.84 22.54L65.80 22.49Q65.84 23.24 65.63 24.75L65.54 24.66L65.54 24.66Q67.48 25.13 67.70 25.15L67.71 25.15L67.77 25.22Q67.72 26.59 67.62 27.30L67.60 27.27L67.65 27.32Q66.81 27.46 65.63 27.63L65.72 27.72L65.72 27.72Q65.74 30.12 65.74 31.34L65.72 31.32L65.64 31.24Q64.92 31.21 63.98 31.23L63.89 31.15L63.92 31.18Q63.92 29.14 63.92 27.88L63.95 27.91L63.33 27.98L63.22 27.87Q62.32 27.96 61.25 28.18Z"/><text style="font-family: Arial; font-size: 20px; font-weight: bold;" x="55" y="35" fill="#333">8</text></svg>',
        expiredTime: Date.now() + 60000 // 1 minute from now
      },
      message: 'success',
      code: 200
    });
  })
  .post('/login', express.json(), (req, res) => {
    console.log("[DEBUG] Login attempt through Express:", req.body);
    res.json({
      success: true,
      data: {
        token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImFkbWluIiwicm9sZSI6ImFkbWluaXN0cmF0b3IiLCJpYXQiOjE2MTcwMjIwMDAsImV4cCI6MTYxNzEwODQwMH0.3TqAC1UvJ1jVrDNM0A9JXzIj8QUbS-vOJ8Y60Q8t9XQ',
        auth: {
          username: req.body.username || 'admin',
          role: 'administrator'
        }
      },
      message: 'success',
      code: 200
    });
  })
  .get('/direct-login', (req, res) => {
    console.log("[DEBUG] Serving direct login page");
    res.sendFile(path.resolve(__dirname, './dist/login.html'));
  })
  .use('/api', createProxyMiddleware(config.proxy))
  // Add a special handler to redirect /login to our custom page even after history API
  .use((req, res, next) => {
    if (req.url === '/login') {
      return res.sendFile(path.resolve(__dirname, './dist/login.html'));
    }
    next();
  })
  .use(history({
    rewrites: [
      { from: /^\/api\/.*$/, to: context => context.parsedUrl.pathname },
      { from: /^\/captcha$/, to: '/captcha' },
      // Removing the login rewrite from history - we handle it directly
    ]
  }))
  .use(express.static('./dist', {
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
