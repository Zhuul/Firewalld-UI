const config = {
  httpPort: 5000,
  httpsPort: 5001,
  maxAge: 1000 * 3600 * 24 * 30,
  setTimeout: 1000 * 60 * 10,
  limiter: {
    windowMs: 15 * 60 * 1000,
    max: 10000,
    standardHeaders: true,
    legacyHeaders: false,
  },
  ssl: {
    key: '',
    crt: '',
  },
  proxy: [
    {
      path: '/api',
      target: 'http://127.0.0.1:7001',
      changeOrigin: true,
      logLevel: 'debug',
    },
    {
      path: '/login',
      target: 'http://127.0.0.1:7001',
      changeOrigin: true,
      logLevel: 'debug',
    },
  ],
};

module.exports = config;
