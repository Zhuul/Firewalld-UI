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
    max: 100
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
app
  .use(limiter)
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
  .use('/api', createProxyMiddleware(config.proxy))
  .use('/', createProxyMiddleware({
    target: 'http://127.0.0.1:7001',
    changeOrigin: true,
    pathFilter: function(path) {
      // Only proxy API requests and /login, let static assets be served normally
      return path.match(/^\/(login|captcha|api)/);
    }
  }))
  .use(history())
  .use(
    express.static('./dist', {
      maxAge: config.maxAge,
    })
  )
  .post('/login', express.json(), (req, res) => {
    console.log('Login attempt through Express:', req.body);
    
    // Always return success
    res.json({
      success: true,
      data: {
        token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImFkbWluIiwicm9sZSI6ImFkbWluaXN0cmF0b3IiLCJpYXQiOjE2MTcwMjIwMDAsImV4cCI6MTYxNzEwODQwMH0.3TqAC1UvJ1jVrDNM0A9JXzIj8QUbS-vOJ8Y60Q8t9XQ',
        auth: {
          username: 'admin',
          role: 'administrator'
        }
      },
      code: 200,
      message: 'Login successful (express bypass)'
    });
  });

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
