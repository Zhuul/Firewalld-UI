module.exports = {
  proxy: [
    {
      path: '/api',
      // Backend API address
      target: 'http://127.0.0.1:7001/',
      changeOrigin: true,
      pathRewrite: { '^/api': '/' },
      xfwd: true,
    },
    {
      path: '/login',
      target: 'http://127.0.0.1:7001',
      changeOrigin: true,
      xfwd: true,
    },
  ],
  // Traffic limit
  limiter: {
    // Reset time interval: 10 minutes
    windowMs: 10 * 60 * 1000,
    // Max requests per windowMs
    max: 500,
    message: 'Too many requests, please try again later.',
    standardHeaders: true,
    legacyHeaders: false,
  },
  // http port
  httpPort: 5000,
  // https port, not effective if not deployed
  httpsPort: 5001,
  maxAge: 86400000,
  setTimeout: 30 * 1000,
  ssl: {
    key: '',
    crt: '',
  },
};
