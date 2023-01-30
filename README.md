
##### 留个 🌟🌟🌟 再走吧!!!
##### 留个 🌟🌟🌟 再走吧!!!
##### 留个 🌟🌟🌟 再走吧!!!
##### 好人一生平安!!!

## 演示环境

> 演示环境没有部署在 linux ,因此很多功能是失效的

## [点击查看演示](http://340200.xyz:65000)

### Micro-Firewall

Micro-Firewall 基于 linux 的 node 微型界面化防火墙,支持自定义创建屏蔽规则,根据规则自动屏蔽 IP

##### 要求

* linux 系统
* 安装有 firewalld 防火墙
* nodejs 和 pm2 (node 推荐 16.18.1)

> 脚本会检测安装 除 firewalld 防火墙外的所有环境,可以实现一键部署启动

##### 特点

* 自动化屏蔽 IP,可以根据 IP 归属地屏蔽
* 前端基于 Vue(element UI), 后端 基于 nodejs(eggjs)
* 部署简单,一键化部署前端后端,支持 http,https部署
* 使用 rsa 加密重要信息,更加安全

### 目录和文件介绍

* shell: 自动化脚本目录
* secretKey: 存放 rsa 密钥,用于加密 token 和 指纹
* shell/shell.log: 记录自动化脚本的日志
* config.json: 系统设置,同界面化 系统设置 页面
* express 前端根目录
  * express/ssl: 存放 https 证书
  * express/dist: 前端静态资源
  * express/config.js: 前端配置文件

### startup.sh 脚本

> 暖心的自动化脚本,做到了那些功能

* 检测环境 node pm2 firewalld
* 自动下载 node pm2 ,自动创建 node pm2 软连接
* 检测依赖,并自动下载(node_modules)
* 检测 secretKey 密钥,和自动生成密钥
* 自动检测端口,并自动在防火墙开放项目端口
* 检测开机启动,自动追加开机脚本(/etc/rc.d/rc.local)
* 检测完环境后自动启动前后端服务,默认端口 http:5000,https:5001

```
./shell/startup.sh
```

> 启动完成浏览器打开 本机IP:5000(5001)

### 登录

默认用户名

```
admin
```

默认密码

```
Admin123456@
```

### 查看注册口令

> 项目根目录打开终端执行,
>
> linux 环境下执行,没有自带 sqlite3 环境需要自行下载
>
> 将 你的用户名 (五个汉字)替换为自己注册的用户名,完整复制不要丢失

```
sqlite3 ./database/sqlite-prod.db 'SELECT secret FROM users WHERE username = "你的用户名";'
```

### 查看 JWT 密钥

> 项目根目录打开终端执行

```
grep secret ./config.json | head -n 1
```


### 部署 https

* 将证书存储在 express/ssl
* 修改 express/config.js 中的 ssl.key ssl.crt
* 重启生效

> ssl.key ssl.crt 填入文件名即可,不需要路径,空 (表示空 == "") 表示不启用 https


#### 完整启动流程截图

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%90%AF%E5%8A%A8%E6%88%AA%E5%9B%BE.png?raw=true)

#### 部分截图

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20225233.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20224657.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20235608.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20235644.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20235740.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20235833.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20235951.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20224802.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20224842.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20225144.png?raw=true)







