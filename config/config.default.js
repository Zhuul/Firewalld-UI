/**
 * eslint valid-jsdoc: "off"
 *
 * @format
 */

'use strict';

/**
 * @param {Egg.EggAppInfo} appInfo app info
 */
const path = require('path');
//  pkg packaging configuration begin
const process = require('process');

const I18n = require('i18n');

I18n.configure({
  locales: ['en-US'],
  defaultLocale: 'en-US',
  directory: __dirname + '/locale',
});

module.exports = appInfo => {
  /**
   * built-in config
   * @type {Egg.EggAppConfig}
   **/

  // Custom middleware

  const db = new Map();

  const qjson = require('qjson-db');
  const configDb = new qjson(path.join(__dirname, '../config.json'));
  const { jwt, captcha, startupTime, ratelimit, firewalld, accessLog, clean, believe } = configDb.JSON();

  const config = (exports = {
    middleware: ['ratelimit'],
    configs: {},
    firewalld,
    accessLog,
    clean,
    believe,
    jwt: {
      enable: false, // false means non-global, effective on routes
      expiresIn: `${jwt.expiresIn}d`,
      secret: jwt.secret,
    },
    captcha: {
      expiresIn: captcha.expiresIn,
      secret: captcha.secret,
    },
    startupTime,
    rundir: path.join(appInfo.baseDir, 'run'), // Explicitly set rundir
    cluster: {
      listen: {
        port: 7001,
        hostname: '0.0.0.0', // It is not recommended to set hostname to '0.0.0.0', as it will allow connections from external networks and sources. Use with caution.
        // path: '/var/run/egg.sock',
      },
    },
    cors: {
      origin: '*',
      allowMethods: 'GET,HEAD,PUT,POST,DELETE,PATCH',
    },
    security: {
      csrf: {
        enable: false,
      },
      ctoken: false,
      domainWhiteList: ['340200.xyz:8013'], // Allowed cross-domain whitelist, no restriction if false
    },
    sequelize: {
      sync: true,
      dialect: 'sqlite',
      storage: path.join(__dirname, '../database/sqlite-default.db'), // I am using an absolute path here
    },
    onerror: {
      all(err, ctx) {
        try {
          ctx.status = 200;
          let message = ctx.helper.status?.[err.name]?.(err) ?? 'Unknown error';
          ctx.helper.response({ success: false, message });
        } catch (error) {
          ctx.helper.response({ success: false });
        }
      },
      html(err, ctx) {
        // html handler
        ctx.body = '<h3>error</h3>';
        ctx.status = 500;
      },
      json(err, ctx) {
        // json handler
        ctx.body = { message: 'error' };
        ctx.status = 500;
      },
      jsonp(err, ctx) {
        // Generally, there is no need to define special error handling for jsonp. The error handling for jsonp will automatically call the json error handler and wrap it in the jsonp response format.
      },
    },
    validate: {
      // Configure parameter validator, based on parameter
      convert: true, // Parameters can be type-converted using the convertType rule
      // validateRoot: false,   // Restrict the validated value to be an object.
      widelyUndefined: false,
      translate() {
        const args = Array.prototype.slice.call(arguments);
        return I18n.__.apply(I18n, args);
      },
    },
    logrotator: {
      filesRotateBySize: [path.join(appInfo.root, 'logs', appInfo.name, 'egg-web.log')],
      maxFileSize: 100 * 1024 * 1024,
    },
    customLogger: {
      system: {
        file: path.join(__dirname, '../logs/system/system.log'),
        maxFileSize: 100 * 1024 * 1024,
      },
      drop: {
        file: path.join(__dirname, '../logs/drop/drop.log'),
        maxFileSize: 100 * 1024 * 1024,
      },
    },
    ratelimit: {
      db,
      driver: 'memory',
      duration: ratelimit.duration * 60 * 1000,
      max: ratelimit.max,
      errorMessage: 'Access restricted, please try again later!',
      id: ctx => ctx.helper.getXwf(),
      headers: {
        remaining: 'Rate-Limit-Remaining',
        reset: 'Rate-Limit-Reset',
        total: 'Rate-Limit-Total',
      },
      disableHeader: false,
      whitelist: ctx => {
        // some logic that returns a boolean
      },
      blacklist: ctx => {
        // some logic that returns a boolean
      },
    },
    // compress: {
    //   threshold: 2048,
    // },
  });

  // use for cookie sign key, should change to your own and keep security
  config.keys = appInfo.name + '_1670808067708_8840';

  // add your user config here
  const userConfig = {
    appName: 'myWaf',
  };

  return {
    ...config,
    ...userConfig,
  };
};
