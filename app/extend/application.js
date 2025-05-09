const path = require('path');
const directory = path.join(__dirname, '../validate');
const crypto = require('crypto');

module.exports = {
  // Query whether to check the blacklist if the system has just booted (booting within 180 seconds is considered a fresh boot),
  ipsCache: [],
  pid: null,
  isStartUp() {
    const { ctx } = this;
    return new Promise(async (resolve, reject) => {
      if (this.env == 'prod') {
        try {
          const { stdout, stderr, err } = await ctx.helper.command(`cat /proc/uptime`);
          if (stderr || err) {
            ctx.helper.serviceAddSystem(11, ctx.helper.getMessage.application(0));
            resolve(false);
          } else {
            const time = this.config?.startupTime ?? 300;
            const startTime = stdout.split(/\s{1,}/)?.[0] ?? 1000000;
            ctx.helper.serviceAddSystem(
              11,
              ctx.helper.getMessage.application(1, {
                startTime,
              })
            );
            resolve(startTime < time ? true : false);
          }
        } catch (e) {
          console.log('');
          this.getLogger('system').info('', ctx.helper.getMessage.application(2));
          console.log('');
          ctx.helper.serviceAddSystem(11, ctx.helper.getMessage.application(3));
          resolve(false);
        }
      } else {
        console.log('');
        this.getLogger('system').info('', ctx.helper.getMessage.application(4));
        console.log('');
        resolve(false);
      }
    });
  },
  async startUp(del = true) {
    if (this.env == 'local') return;
    let reload = false;
    const { ctx } = this;
    const startUp = await this.isStartUp();
    startUp == false && del && (reload = true);
    // Query the blacklist in the database, and re-add the queried entries to the firewall rules (because non-persistent firewall rich rules are lost on reboot)
    const { data } = await ctx.service.blacklist.getBlacklist({ page: 1, pageSize: 10000, unblocked: false });

    await data?.rows?.syncEach?.(async item => {
      let surplus = parseInt(item.expirationTime - (new Date().getTime() - new Date(item.time).getTime()) / 1000);

      ctx.helper.ipsCachePut(item.ip, { ip: item.ip, port: item.port, fullSite: item.site, expirationTime: surplus }, surplus);

      reload
        ? ctx.helper
          .serviceAddSystem(
            3,
            ctx.helper.getMessage.application(5, {
              ip: item.ip,
              surplus,
            })
          )
          .then(() =>
            this.getLogger('drop').info(
              ctx.helper.getMessage.application(6),
              ctx.helper.getMessage.application(7, {
                port: item.port,
                ip: item.ip,
                site: item.site,
                surplus,
              })
            )
          )
        : await ctx.helper.drop(item.ip, surplus).then(({ err, stdout, stderr, success }) => {
          success
            ? (() => {
              del &&
                this.getLogger('drop').info(
                  ctx.helper.getMessage.application(8),
                  ctx.helper.getMessage.application(7, {
                    port: item.port,
                    ip: item.ip,
                    site: item.site,
                    surplus,
                  })
                );
              del &&
                ctx.helper.serviceAddSystem(
                  3,
                  ctx.helper.getMessage.application(9, {
                    ip: item.ip,
                    surplus,
                  })
                );
            })()
            : ctx.helper
              .serviceAddSystem(
                3,
                ctx.helper.getMessage.application(10, {
                  ip: item.ip,
                  surplus,
                })
              )
              .then(() =>
                this.getLogger('drop').info(
                  ctx.helper.getMessage.common(4),
                  ctx.helper.getMessage.application(11, {
                    ip: item.ip,
                  })
                )
              );
        });
    });
  },
  parseIpSite(ip) {
    const { ctx } = this;
    const search = ctx.helper.searcher.memorySearchSync(ip);
    const region = search?.region.split('|').filter(item => item) ?? [];
    const cityNo = search?.city ?? 'Unknown City ID';
    const country = region[0] ?? 'Unknown Country';
    const province = region[2] ?? 'Unknown Province';
    const city = region[3] ?? 'Unknown City';
    const isp = region[4] ?? 'Unknown Network';
    const fullSite = `${country}-${province}-${city}-${isp}`;

    return { country, province, city, cityNo, isp, fullSite };
  },
  ipMatch: str => str?.match?.(/(\d{1,3}\.){3}\d{1,3}/g) ?? [],
  parseIp(value) {
    const data = value.split(/\s/);
    const connectionTime = `${data[5]} ${data[6]}`;
    const ip = this.ipMatch(data?.[3] ?? '')?.[0];
    const type = data[0] ?? 'Unknown Connection Type';
    const localIp = data[1] ?? 'Local IP Unknown';
    const localPort = data[2] ? parseInt(data[2]) : 'Local Port Unknown';
    const remoteIp = ip ?? 'Remote IP Unknown';
    const remotePort = data[4] ?? 'Remote Port Unknown';
    const connectionTimeTo = new Date(connectionTime).toString() != 'Invalid Date' ? connectionTime : this.ctx.helper.getFormatNowDate();

    return { type, localIp, localPort, remoteIp, remotePort, connectionTime: connectionTimeTo };
  },
  async addIpsCache(item) {
    const { ctx } = this;
    const parseIp = this.parseIp(item);

    // --- BEGIN ADDED VALIDATION ---
    const ipv4Regex = /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/;
    if (!parseIp.remoteIp || !ipv4Regex.test(parseIp.remoteIp)) {
      this.getLogger('error').error('[Firewalld-UI] addIpsCache: Invalid or missing remote IP address. Item:', item, 'Parsed IP:', parseIp);
      return; // Skip this item
    }
    // --- END ADDED VALIDATION ---

    const isInips = ctx.helper.isInIpsCache(parseIp.remoteIp);

    if (ctx.helper.isInLogCache(parseIp.remoteIp, parseIp.localPort) || isInips) return;

    const site = this.parseIpSite(parseIp.remoteIp);
    const parse = {
      time: ctx.helper.getFormatNowDate(),
      type: parseIp.type,
      ip: parseIp.remoteIp,
      port: parseIp.localPort,
      fullSite: site.fullSite,
      site,
    };
    isInips || this.ipsCache.some(item => item.ip == parse.ip) || this.ipsCache.push(parse);
    // Filter connection log output: entries already logged within the specified time or added to the blacklist will not be output again
    await ctx.service.access.addAccessLog({ ...parse, site: parse.fullSite });
    ctx.helper.logCachePut(parse.ip, parse.port, parse, this.config?.accessLog?.interval ?? 30);
    this.messenger.sendToApp("logCachePut", parse)
  },
  async addIpset() {
    const { ctx } = this;
    let success = true;
    const isDrop = await ctx.helper.isCustomDrop();
    isDrop || (success = await ctx.helper.newIpset());
    return success;
  },
  parseIp(value) {
    const { ctx } = this;
    const data = value.split(/\s/);
    const connectionTime = `${data[5]} ${data[6]}`;
    const ip = this.ipMatch(data?.[3] ?? '')?.[0];
    return {
      type: data[0] ?? 'Unknown Connection Type',
      localIp: data[1] ?? 'Local IP Unknown',
      localPort: data[2] ? parseInt(data[2]) : 'Local Port Unknown',
      remoteIp: ip ?? 'Remote IP Unknown',
      remotePort: data[4] ?? 'Remote Port Unknown',
      connectionTime: new Date(connectionTime).toString() != 'Invalid Date' ? connectionTime : ctx.helper.getFormatNowDate(),
    };
  },
  ipInSegment(ip, believeAccess) {
    if (believeAccess.length == 1 && believeAccess[0] == 'All') return true;
    try {
      const iParse = ip.split('.').map(item => parseInt(item));
      const ipIn = believeAccess.some(
        item =>
          /\-|\//g.test(item) &&
          item.split('.').every((item, index) => {
            const ipSegment = item.split(/\-|\//).map(item => parseInt(item));
            const ipIn = ipSegment.length == 1 ? ipSegment[0] == iParse[index] : ipSegment[0] <= iParse[index] && iParse[index] <= ipSegment[1];
            return ipIn;
          })
      );
      return ipIn;
    } catch (error) {
      return true;
    }
  },
  async drop(ip, port, fullSite, expirationTime) {
    const { ctx } = this;
    const time = ctx.helper.getFormatNowDate();
    const {
      data: { success, message },
    } = await ctx.service.blacklist.addBlacklist({ ip, port, expirationTime, site: fullSite, time });
    success
      ? ctx.helper.serviceAddSystem(
        4,
        ctx.helper.getMessage.application(12, {
          ip,
          expirationTime,
        })
      )
      : ctx.helper.serviceAddSystem(
        4,
        ctx.helper.getMessage.application(13, {
          message,
        })
      );
    return true;
  },
  async addRule(item, expirationTime = 259200) {
    const { ctx } = this;
    const { ip, port, fullSite } = item;

    const believeAccess = this.config?.believe?.access ?? [];
    if (this.ipInSegment(ip, believeAccess)) return;

    const { data } = await ctx.service.rule.getRule({
      effective: 1,
      page: 1,
      pageSize: 10000,
    });

    data?.rows?.syncEach(async rowItem => {
      const ports = rowItem.ports.includes(item.port) || rowItem.ports.length == 0;
      const ips = rowItem.ips.includes(item.ip) || rowItem.ips.length == 0;
      const sites = rowItem.sites.some(site => item.fullSite.indexOf(site) != -1) || rowItem.sites.length == 0;
      const checkRule = async type => {
        if (type) {
          const sitesDisabled = rowItem.sitesDisabled == false || (rowItem.sitesDisabled && sites);
          const ipsDisabled = rowItem.ipsDisabled == false || (rowItem.ipsDisabled && ips);
          const portsDisabled = rowItem.portsDisabled == false || (rowItem.portsDisabled && ports);
          if (sitesDisabled && ipsDisabled && portsDisabled) return true;
        } else {
          const sitesDisabled = rowItem.sitesDisabled && sites;
          const ipsDisabled = rowItem.ipsDisabled && ips;
          const portsDisabled = rowItem.portsDisabled && ports;
          const abroadDisabled = rowItem.abroadDisabled && item.fullSite.indexOf('China') == -1;
          const limitDisabled = rowItem.limitDisabled;

          if (sitesDisabled || ipsDisabled || portsDisabled || abroadDisabled || limitDisabled) {
            if (limitDisabled) {
              const {
                data: { count = 0 },
                equalNull,
              } = await ctx.service.access.findAllAccessLog({
                ip: item.ip,
                startTime: ctx.helper.getFormatDate(new Date().getTime() - rowItem.limitShield * 60 * 1000),
                endTime: ctx.helper.getFormatNowDate(),
              });
              if (equalNull == false && count >= rowItem.limitTotal) return await this.drop(ip, port, fullSite, rowItem.shieldTime ?? expirationTime);
            } else return await this.drop(ip, port, fullSite, rowItem.shieldTime ?? expirationTime);
          }
        }
      };
      if (await checkRule(rowItem.unblocked)) return true;
    });
  },
  async checkIpsCache() {
    if (this.ipsCache.length == 0) return;
    const item = this.ipsCache[0];
    await this.addRule(item);
    this.ipsCache.splice(0, 1);
    await this.checkIpsCache();
  },
  setSalt(value) {
    const salt = this.config?.jwt?.secret ?? '';
    return crypto.createHash('sha512').update(`${value}${salt}`).digest('hex');
  },
  matchPassword(plaintext, ciphertext) {
    const password = this.setSalt(plaintext);
    return ciphertext === password;
  },
  async serverDidReady() {
    this.pid = process.pid
    this.server.on('timeout', socket => this.ctx.helper.systemTimeOut());
    this.loader.loadToApp(directory, 'validate');
    await this.startUp();
    this.ctx.helper.systemStart();
    this.ctx.runInBackground(async () => {
      this.messenger.on('netstat', async data => {
        await data?.syncEach(async item => await this.addIpsCache(item));
      });
    });
    this.messenger.on('logCachePut', async parse => {
      this.ctx.helper.logCachePut(parse.ip, parse.port, parse, this.config?.accessLog?.interval ?? 30);
    });
  },
  beforeClose() {
    this.ctx = this.createAnonymousContext();
    this.ctx.helper.systemStop();
  },
};
