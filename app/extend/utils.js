/** @format */

'use strict';

const fs = require('fs');
const path = require('path');

// const seq = require('sequelize');
// const Op = seq.Op;
let isTcpkill = false;

const status = require(path.join(__dirname, './status'));

const { exec } = require('child_process');

const qjson = require('qjson-db');
const configDb = new qjson(path.join(__dirname, '../../config.json'));
// ctx.helper.configDb.set('key', 'value');
// console.log(ctx.helper.configDb.JSON());
// console.log(configDb.get('key'));

const _ = require('lodash');

// const search = searcher.binarySearchSync(ip);
const searcher = require('dy-node-ip2region').create();

const NodeRSA = require('node-rsa');
const cache = require('memory-cache');
const ipsCache = new cache.Cache();
const logCache = new cache.Cache();
const captchaCache = new cache.Cache();

const priKeyToken = fs.readFileSync(path.join(__dirname, '../../secretKey/token/PRIVATE-KEY.txt')).toString();
const pubKeyToken = fs.readFileSync(path.join(__dirname, '../../secretKey/token/PUBLIC-KEY.txt')).toString();
const privateKeyToken = new NodeRSA(priKeyToken);
privateKeyToken.setOptions({ encryptionScheme: 'pkcs1' });
const publicKeyToken = new NodeRSA(pubKeyToken);
publicKeyToken.setOptions({ encryptionScheme: 'pkcs1' });

const priKeyFingerprint = fs.readFileSync(path.join(__dirname, '../../secretKey/fingerprint/PRIVATE-KEY.txt')).toString();
const pubKeyFingerprint = fs.readFileSync(path.join(__dirname, '../../secretKey/fingerprint/PUBLIC-KEY.txt')).toString();
const privateKeyFingerprint = new NodeRSA(priKeyFingerprint);
privateKeyFingerprint.setOptions({ encryptionScheme: 'pkcs1' });
const publicKeyFingerprint = new NodeRSA(pubKeyFingerprint);
publicKeyFingerprint.setOptions({ encryptionScheme: 'pkcs1' });

module.exports = {
  //lodash
  _,
  configDb,
  seq() {
    return this.app.Sequelize;
  },
  async seqTransaction(resolve = async () => {}, reject = async () => {}) {
    const { ctx } = this;
    const transaction = await ctx.model.transaction();
    try {
      const response = await resolve();
      await transaction.commit();
      return response;
    } catch (error) {
      console.log(error);
      const message = `Transaction execution failed ${error.toString()}`;
      await transaction.rollback();
      this.serviceAddSystem(13, message);
      this.app.getLogger('system').info('', message);
      reject && reject();
      return { data: null };
    }
  },
  status,
  searcher,
  throw(message, callBack) {
    const err = new Error(message);
    err.name = 'custom';
    try {
      callBack && callBack();
    } catch (error) {
      console.log('Concurrent error occurred');
      console.log(error);
      throw err;
    }
    throw err;
  },
  delay(time = 500, callBack) {
    return new Promise(resolve1 => {
      new Promise(resolve2 => {
        var timer = setTimeout(() => {
          resolve2(timer);
        }, time);
      }).then(result => {
        resolve1();
        callBack && callBack();
        clearTimeout(result);
      });
    });
  },
  getXwf() {
    const { ctx, app } = this;
    const xwf = (ctx.request.header?.['x-forwarded-for']?.split?.(',') ?? []).pop();
    return xwf ? app.ipMatch(xwf).join('') : ctx.ip;
  },
  getFormatNowDate(format = 'yyyy-MM-dd hh:mm:ss') {
    return new Date().Format(format);
  },
  getFormatDate(date, format = 'yyyy-MM-dd hh:mm:ss') {
    return new Date(date).Format(format);
  },
  betweenTime(startTime, endTime) {
    return [new Date(`${startTime} 00:00:00`).Format('yyyy-MM-dd hh:mm:ss'), new Date(`${endTime} 23:59:59`).Format('yyyy-MM-dd hh:mm:ss')];
  },
  captchaCheck(playload, code) {
    const { ctx, app } = this;
    const captcha = playload.split('|')[0];
    captchaCache.get(playload) != null && ctx.helper.throw('CAPTCHA has been used');
    ctx.helper._.toUpper(captcha) !== ctx.helper._.toUpper(code) && ctx.helper.throw('Incorrect CAPTCHA');
    captchaCache.put(playload, new Date(), app.config?.captcha?.expiresIn * 600000 ?? 600000);
  },
  isInLogCache(ip, port) {
    return logCache.get(`${ip}-${port}`) != null;
  },
  logCacheKeys() {
    return logCache.keys();
  },
  logCachePut(ip, port, res, expirationTime) {
    const log = `${res.type}   ${res.port}  ${res.ip}   ${res.fullSite}`;
    logCache.put(`${ip}-${port}`, log, expirationTime * 1000, (key, value) => {
      // This is the callback for cache expiration, not for successful insertion
    });
  },
  ipsCacheKeys() {
    return ipsCache.keys();
  },
  ipsCacheGet(ip) {
    return ipsCache.get(`ip-${ip}`);
  },
  isInIpsCache(ip) {
    return ipsCache.get(`ip-${ip}`) != null;
  },
  ipsCachePut(ip, data, expirationTime) {
    const { ctx } = this;
    try {
      ipsCache.del(`ip-${ip}`);
      // Solve timer overflow problem
      const time = 100000;
      if (expirationTime > time) {
        data.expirationTimeSplit = expirationTime - time;
        ipsCache.put(`ip-${ip}`, data, time * 1000, (key, value) => {
          ctx.helper.ipsCachePut(value.ip, value, data.expirationTimeSplit);
        });
      } else {
        ipsCache.put(`ip-${ip}`, data, expirationTime * 1000, (key, value) => {
          // This is the callback for cache expiration, not for successful insertion
        });
      }
    } catch (error) {
      console.log(error);
    }
  },
  ipsCacheDel(ip) {
    return ipsCache.del(`ip-${ip}`);
  },
  async blacklistCreate({ ip, expirationTime, site, port, time, expirationTimeFormat }) {
    const { ctx } = this;
    if (await ctx.helper.dropCommand(ip, expirationTime)) {
      await ctx.model.Blacklist.sync();
      const blacklist = await ctx.model.Blacklist.create({ ip, expirationTime, site, port, time, expirationTimeFormat });
      await blacklist.save();
      ctx.helper.ipsCachePut(ip, { ip, port, fullSite: site, expirationTime }, expirationTime);
      this.serviceAddSystem(4, `Added to blacklist IP: ${ip} Location: ${site} Port: ${port} Block time ${expirationTimeFormat}`);
      return { ip, success: true, message: 'Successfully added to blacklist' };
    } else {
      this.serviceAddSystem(4, `Failed to add to blacklist, may already be in firewall IP: ${ip} Location: ${site} Port: ${port}`);
      return { ip, success: false, message: 'Failed to add to blacklist, may already be in firewall' };
    }
  },
  drop(ip, time) {
    return new Promise((resolve, reject) => {
      const command = `firewall-cmd --add-rich-rule='rule family=ipv4 source address="${ip}" log prefix="Micro-Firewall"   drop' --timeout=${time}`;
      exec(command, (err, stdout, stderr) => {
        resolve({ err, stdout, stderr, success: stderr || err ? false : true });
      });
    });
  },
  removeDrop(ip, unblocked = true) {
    const { ctx } = this;
    ctx.helper.ipsCacheDel(ip);
    return new Promise((resolve, reject) => {
      const command = `firewall-cmd --remove-rich-rule 'rule family=ipv4 source address="${ip}" log prefix="Micro-Firewall"   drop'`;
      if (unblocked == false) {
        resolve({ success: true });
      } else {
        exec(command, (err, stdout, stderr) => {
          const success = stderr || err ? false : true;
          success && ctx.helper.serviceAddSystem(5, unblocked ? `Removed unblocked blacklist IP ${ip}` : `Removed blocked blacklist IP ${ip}`);
          resolve({ err, stdout, stderr, success });
        });
      }
    });
  },
  async dropCommand(ip, expirationTime) {
    const { stdout, stderr, err } = await this.drop(ip, expirationTime);
    stdout && this.app.getLogger('drop').info('Blacklist', `ip ${ip}  Block time  ${expirationTime} seconds`);
    stderr && this.app.getLogger('drop').info('Blacklist', `Repeated addition ${ip}`);
    err && this.app.getLogger('drop').info('Blacklist', `Failed to add to blacklist ${ip}`);
    return stderr || err ? false : true;
  },
  async queryNodeVersion() {
    const version = (await this.command('node -v'))?.replace(/\n+/g, '');
    const isReturn = version?.replace(/[A-Za-z]+/g, '').split('.')[0] < 16;
    isReturn && console.log('Node version needs to be greater than or equal to 16');
    return isReturn;
  },
  millisecondToDay(millisecond = 86400000) {
    return parseInt(millisecond / 86400000);
  },
  dayToMillisecond(day = 1) {
    return parseInt(day * 86400000);
  },
  async getFirewalldStatus() {
    const { ctx } = this;
    const { success, stdout } = await ctx.helper.command('firewall-cmd --state');
    return success ? (stdout.indexOf('running') == -1 ? false : true) : false;
  },
  command(command = '') {
    return new Promise((resolve, reject) => {
      exec(command, (err, stdout, stderr) => {
        resolve({ stdout, stderr, err, success: stderr || err ? false : true });
      });
    });
  },
  tcpkill(ip, timeout = 300000) {
    return new Promise((resolve, reject) => {
      if (isTcpkill) return resolve(true);
      console.log('Starting execution');
      let timer;
      try {
        const response = exec(`tcpkill -i any -9 host ${ip}`, { timeout: timeout * 2, maxBuffer: 50 * 1024 });
        response.on('close', code => resolve(true));
        response.on('error', code => {
          isTcpkill = true;
          resolve(true);
        });
        response.on('exit', code => {
          code != null && (isTcpkill = true);
          resolve(true);
        });
        timer = setTimeout(() => {
          response?.kill();
          resolve(true);
          clearTimeout(timer);
        }, timeout);
      } catch (error) {
        timer && clearTimeout(timer);
        reject(false);
      }
    });
  },
  boolFormat(num) {
    const bool =
      num === 1 || num === '1' || num === true || num === 'true' ? true : num === 0 || num === '0' || num === false || num === 'false' ? false : '';
    return bool;
  },
  notEmpty(params) {
    return Array.isArray(params) ? params.map(item => (Array.isArray(item) ? item.every(item => item !== '') : item !== '')) : params !== '';
  },
  async commandQueryportStatus(data) {
    if (Array.isArray(data)) {
      const { success, stdout } = await this.command(`firewall-cmd --list-ports`);
      const listPorts = success
        ? stdout?.split(/\s{1,}/).map(item => {
            item = item.split('/');
            return [item[0].indexOf('-') != -1 ? item[0].split('-') : item[0], item[1]];
          })
        : [];

      data.forEach(item1 => {
        const port = item1.getDataValue('port');
        item1.setDataValue('tcpPort', false);
        item1.setDataValue('udpPort', false);
        listPorts.forEach(item2 => {
          item2[1] === 'tcp' &&
            (Array.isArray(item2[0]) ? item2[0][0] <= port && port <= item2[0][1] : port == item2[0]) &&
            item1.setDataValue('tcpPort', true);

          item2[1] === 'udp' &&
            (Array.isArray(item2[0]) ? item2[0][0] <= port && port <= item2[0][1] : port == item2[0]) &&
            item1.setDataValue('udpPort', true);
        });
      });
      return data;
    } else return [];
  },
  async commandQueryIpRule(ip) {
    const { success, stdout } = await this.command(`firewall-cmd --list-rich-rules | grep ${ip} | grep Micro-Firewall | grep drop`);
    return success ? (stdout == '' ? false : true) : false;
  },
  async isCustomDrop() {
    const { err, stdout, stderr } = await this.command('firewall-cmd --permanent --get-ipsets');
    const isDrop = stdout.indexOf('CUSTOM-DROP') != -1;
    this.app.getLogger('system').info('', `------------------Custom ipsets CUSTOM-DROP ${isDrop ? 'exists' : 'does not exist'} ---------------`);
    return isDrop;
  },
  async triggerChangePort(status, port, protocol) {
    const { ctx } = this;
    let success = false;
    if (status) {
      const { success: querySuccess, stdout } = await ctx.helper.command(`firewall-cmd --query-port=${port}/${protocol}`);

      if (querySuccess && stdout.indexOf('yes') != -1) return true;

      const add = await ctx.helper.command(`firewall-cmd --add-port=${port}/${protocol}`);
      const addPermanent = await ctx.helper.command(`firewall-cmd --add-port=${port}/${protocol} --permanent`);
      success = add.success && addPermanent.success;
    } else {
      const remove = await ctx.helper.command(`firewall-cmd --remove-port=${port}/${protocol}`);
      const removePermanent = await ctx.helper.command(`firewall-cmd --remove-port=${port}/${protocol} --permanent`);
      success = remove.success && removePermanent.success;
    }
    return success;
  },
  async newIpset() {
    this.app.getLogger('system').info('', `------------------Will create new ipsets CUSTOM-DROP---------------`);
    const { err, stdout, stderr } = await this.command('firewall-cmd --permanent --new-ipset=CUSTOM-DROP --type=hash:ip');
    stdout && this.app.getLogger('system').info('', `------------------Creation successful---------------`);
    (stderr || err) && this.app.getLogger('system').info('', `------------------Creation failed---------------`);
    return stdout != null;
  },
  deleteFolder(path) {
    if (fs.existsSync(path)) {
      fs.readdirSync(path).forEach(file => {
        const curPath = path + '/' + file;
        if (fs.statSync(curPath).isDirectory()) {
          // recurse
          deleteFolder(curPath);
        } else {
          // delete file
          fs.unlinkSync(curPath);
        }
      });
      fs.rmdirSync(path);
    }
  },
  //rsa 解密
  decrypt(msg, type = 1) {
    try {
      const rsa = type == 1 ? privateKeyToken : privateKeyFingerprint;
      const decrypted = rsa.decrypt(msg);
      return decrypted.toString();
    } catch (error) {
      return new Date().getTime();
    }
  },
  //rsa 加密
  encrypt(msg, type = 1) {
    try {
      const rsa = type == 1 ? publicKeyToken : publicKeyFingerprint;
      const encrypt = rsa.encrypt(msg, 'base64', 'utf8');
      return encrypt.toString();
    } catch (error) {
      return new Date().getTime();
    }
  },
  // jwt 生成 token
  jwtSecret(playload) {
    const { app, ctx } = this;
    const jwtSecret = app.config?.jwt.secret ?? '';
    const token = app.jwt.sign({ playload }, jwtSecret, {
      expiresIn: app.config?.jwt.expiresIn,
    });
    return ctx.helper.encrypt(token);
  },
  // jwt 验签
  jwtVerify(token) {
    const { app, ctx } = this;
    const jwtSecret = app.config?.jwt.secret ?? '';
    //先解 token 的 rsa 加密
    token = ctx.helper.decrypt(token);
    //解码 jwt token
    const decode = app.jwt.verify(token, jwtSecret);
    return decode;
  },
  //验证码 生成 jwt token
  captchaJwtSecret(playload) {
    const { ctx, app } = this;
    const jwtSecret = app.config?.captcha.secret ?? '';
    const token = app.jwt.sign({ playload }, jwtSecret, {
      expiresIn: `${app.config?.captcha.expiresIn}m`,
    });
    return ctx.helper.encrypt(token);
  },
  //验证码 jwt 验签
  captchaJwtVerify(token) {
    const { ctx, app } = this;
    const jwtSecret = app.config?.captcha.secret ?? '';
    //先解 token 的 rsa 加密
    token = ctx.helper.decrypt(token);
    //解码 jwt token
    const decode = app.jwt.verify(token, jwtSecret);
    return decode;
  },
  getPublicKey() {
    return pubKeyToken;
  },
  getPublicKeyFingerprint() {
    return pubKeyFingerprint;
  },
  systemStart() {
    console.log('');
    this.app.getLogger('system').info('', `------------------${this.app.env} environment has started---------------`);
    console.log('');
    this.serviceAddSystem(1, `${this.app.env} environment has started`);
  },
  systemStop() {
    console.log('');
    console.log(`[SYSTEM STOP] ${this.app.env} service has stopped (logged via console.log)`);
    console.log('');
  },
  systemTimeOut() {
    console.log('');
    this.app.getLogger('system').info('', `------------------Startup timeout---------------`);
    console.log('');
    this.serviceAddSystem(0, `${this.app.env} startup timeout`);
  },
  async serviceAddSystem(type, details, callBack) {
    const {
      ctx,
      ctx: { header },
    } = this;
    try {
      const ip = this.getXwf();
      const jwt = header?.token ? ctx.helper.jwtVerify(header.token) : {};
      const json = jwt?.playload ? JSON.parse(jwt.playload) : {};
      const user = json.username ?? 'System Default';
      await ctx.service.system.addSystem({ ip, user, type, details });
      callBack && callBack();
    } catch (error) {
      console.log(error);
    }
  },
  controllerGetOverview(startTime, endTime) {
    const { ctx } = this;
    const str =
      new Date(startTime == '' ? new Date(new Date().Format('yyyy-MM-dd')).getTime() - ctx.helper.dayToMillisecond(15) : `${startTime}`).getTime() -
      ctx.helper.dayToMillisecond();

    const end = new Date(endTime == '' ? ctx.helper.getFormatNowDate('yyyy-MM-dd') : `${endTime}`).getTime();

    const day = Math.floor((end - str) / (24 * 3600 * 1000));

    const rangeDate = Array.from({ length: day }).map((item, index) => {
      const date = end - ctx.helper.dayToMillisecond() * index;
      return {
        date: ctx.helper.getFormatDate(date, 'yyyy-MM-dd'),
        startTime: ctx.helper.getFormatDate(date, 'yyyy-MM-dd 00:00:00'),
        endTime: ctx.helper.getFormatDate(date, 'yyyy-MM-dd 23:59:59'),
      };
    });

    return { str, end, day, rangeDate };
  },
  getMessage: {
    common(index, obj = {}) {
      const message = ['Failed', 'Success', 'Creation failed', 'Service will restart soon', 'Blacklist'];
      return message[index];
    },
    blacklist(index, obj = {}) {
      const message = [
        'Successfully re-added to blacklist',
        'Successfully modified block time for existing blacklist entry',
        `Re-added to blacklist IP: ${obj.ip} Location: ${obj.site} Port: ${obj.port} Block time ${obj.expirationTimeFormat}`,
        `Modified block time for blacklist IP: ${obj.ip} Location: ${obj.site} Port: ${obj.port} Block time ${obj.expirationTimeFormat}`,
        'Failed to re-add or modify block time for existing blacklist entry',
      ];
      return message[index];
    },
    user(index, obj = {}) {
      const message = [
        'Already registered',
        `Username ${obj.username} registration failed, already registered`,
        `Username ${obj.username} registration successful`,
        'Modification failed',
        `Username ${obj.username} password modification failed`,
        `Username ${obj.username} password modification successful`,
        'Please check username or password',
        `Username ${obj.usernameDecrypt} does not exist`,
        `Username ${obj.usernameDecrypt} incorrect login password`,
        `Username ${obj.usernameDecrypt} login successful`,
      ];
      return message[index];
    },
    access(index, obj = {}) {
      const message = [`Deleted ${obj.count} log entries`];
      return message[index];
    },
    overview(index, obj = {}) {
      const message = [`Firewall turned on ${obj.success ? 'successfully' : 'failed'} Time:${obj.time}`, `Firewall turned off ${obj.success ? 'successfully' : 'failed'} Time:${obj.time}`];
      return message[index];
    },
    project(index, obj = {}) {
      const message = [
        `New project, Project name:${obj.name} Project port:${obj.port}`,
        `Delete project, Project name:${obj.name} Project port:${obj.port}`,
        `Port ${obj.port} already bound`,
        `Failed, error reason:${obj.message?.join(',')}`,
      ];
      return message[index];
    },
    rule(index, obj = {}) {
      const message = [`New rule Time ${obj.time}`, `Deleted ${obj.count} rules`];
      return message[index];
    },
    application(index, obj = {}) {
      const message = [
        `Failed to query boot time, please check if cat /proc/uptime command is normal`,
        `Successfully queried boot time, boot time ${obj.startTime} seconds`,
        `------------------Failed to query boot time err------------------`,
        `Failed to query boot time, please check if cat /proc/uptime command is normal`,
        `------------------${this.env} environment does not verify boot time------------------`,
        `Restart detected blacklist, IP :${obj.ip} Block time:${obj.surplus} seconds`,
        'Found blacklist in database upon service restart',
        `${obj.port}  ${obj.ip}  ${obj.site} Block time  ${obj.surplus} seconds`,
        'Found blacklist in database upon boot',
        `Boot detected blacklist, IP :${obj.ip} Block time:${obj.surplus} seconds`,
        `Boot detected blacklist block failed, IP :${obj.ip} Block time:${obj.surplus} seconds`,
        `Failed to add to blacklist ${obj.ip}`,
        `Successfully added to blacklist, IP :${obj.ip} Block time ${obj.expirationTime} seconds`,
        `Failed to add to blacklist, IP :${obj.ip} ${obj.message}`,
      ];
      return message[index];
    },
  },
};

Array.prototype.syncEach = async function (callBack = async () => {}) {
  try {
    const data = Array.isArray(this) ? this : [];
    for await (let item of data) {
      const res = await callBack(item);
      if (res !== undefined) {
        if (res === true) {
          break;
        } else {
          continue;
        }
      }
    }
  } catch (error) {
    console.log(error);
    return [];
  }
};

Array.prototype.syncMap = async function (callBack = async () => {}) {
  try {
    const data = Array.isArray(this) ? this : [];
    const response = [];
    for await (let item of data) {
      const res = await callBack(item, response.length);
      response.push(res);
    }
    return response;
  } catch (error) {
    console.log(error);
    return [];
  }
};

Date.prototype.Format = function (fmt) {
  var o = {
    'M+': this.getMonth() + 1, //月份
    'd+': this.getDate(), //日
    'h+': this.getHours(), //小时
    'm+': this.getMinutes(), //分
    's+': this.getSeconds(), //秒
    'q+': Math.floor((this.getMonth() + 3) / 3), //季度
    S: this.getMilliseconds(), //毫秒
  };
  if (/(y+)/.test(fmt)) fmt = fmt.replace(RegExp.$1, (this.getFullYear() + '').substr(4 - RegExp.$1.length));
  for (var k in o)
    if (new RegExp('(' + k + ')').test(fmt)) fmt = fmt.replace(RegExp.$1, RegExp.$1.length == 1 ? o[k] : ('00' + o[k]).substr(('' + o[k]).length));
  return fmt;
};
