module.exports = {
  apps: [
    {
      name: 'HttpServer',
      script: 'express/index.js',
      cwd: __dirname,
      watch: false,
      interpreter: process.env.NODE_EXECUTABLE || 'node',
      env: {
        NODE_ENV: 'production',
      },
    },
    {
      name: 'egg-server',
      script: 'node_modules/.bin/egg-scripts',
      args: 'start --daemon=false --hostname=127.0.0.1 --port=7001 --title=egg-server',
      cwd: __dirname,
      watch: false,
      interpreter: process.env.NODE_EXECUTABLE || 'node',
      env: {
        NODE_ENV: 'production',
      },
    },
  ],
};
