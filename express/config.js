module.exports = {
  proxy: {
    path: '/api',
    // Backend API address
    target: 'http://0.0.0.0:7001/',
    changeOrigoin: false,
    pathRewrite: { '^/api': '/' },
    xfwd: true,
  },
  // Traffic limit
  limiter: {
    // Reset time interval 10 minutes
    windowMs: 10 * 60 * 1000,
    // Maximum number of visits
    max: 500,
    message: 'Too many visits, please try again later!!!',
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
