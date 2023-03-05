<div align="center">

#####   开源不易,点个 🌟🌟🌟 吧!!!
##### 好人一生平安!!!

</div>

<div align="center">

### Firewalld-UI

</div>

基于 <B>Node.js</B> 适用于 <B>个人服务器</B> 和 <B>NAS</B> 的 <B>Firewalld(防火墙) 界面化</B>,不需要记忆操作命令,更没有 Firewalld 的区域概念,和 iptables 复杂的 表链结构 .界面上点击创建一些规则就可以达到 <B>自动</B> 屏蔽和放行 IP 的目的.

关键词: 小型 个人 微型 防火墙 安装 界面 界面化 图形 图形化 防止攻击 屏蔽 访问记录 屏蔽名单

#### [Gitee 码云 (国内极速)](https://gitee.com/SOONXFGetee/Firewalld-UI)

## 演示环境

> 演示环境没有部署在 linux ,因此很多功能是失效的 

### [▶ 点击查看演示(24:00-6:00 服务器关机) ◀](https://340200.xyz:65001)

## 电梯

#### [▶ 部署和运行 ◀](#部署和运行)

#### [▶ 一些问题的解答 ◀](#解答)

#### [▶ 必看:可能会出现的问题 ◀](#问题)

请务必仔细阅读文档...

### 要求

* Linux 系统
* Firewalld 防火墙
* pm2 守护进程管理器
* Node.js (首选 16.18.1,推荐 >= 14.0.0)

脚本会检测安装 除 Firewalld 防火墙外的所有环境,一键部署启动

CentOS7 内置 Firewalld

### 项目介绍和技术栈

---

* 部署启动极其简单,一键 startup.sh 脚本轻松部署
* 前端基于 Vue(element UI), 后端 基于 nodejs(eggjs)
* 修改 element 源码,table 组件增加 defer 延迟加载函数
* vuex 和 数据持久化, pm2 管理和部署项目, pkg 打包前端静态资源
* express 部署前端 https 静态资源,使用 limiter 帽子防护 xss 等攻击
* 使用 jwt 和 浏览器指纹维护前端的登录状态
* 前后端 根据 IP 的限流措施
* 基于 sqlite3 的数据库存储,接口使用事务处理数据
* Linux 防火墙 Firewalld 的使用
* 自动的检测环境和下载所需的依赖
* 自动化屏蔽 IP,可以根据 IP 归属地流量和地点关键词规则屏蔽刻意访问
* 使用 rsa 加密 token 和 指纹等信息
* 自动保存的表格可拖拽宽度配置,所有单元格内容都做了省略处理和 tooltip 提示
* 多种组件大小可供手动调节,多尺寸设备都可兼容

### 目录和文件

* **[shell]:** 自动化脚本目录
* **[secretKey]:** 存放 rsa 密钥,用于加密 token 和 指纹
* **[shell/shell.log]:** 记录自动化脚本的日志
* **[config.json]:** 系统设置,同界面化 系统设置 页面
* **[express]:** 前端根目录
  * **[express/ssl]:** 存放 https 证书
  * **[express/dist]:** 前端静态资源
  * **[express/config.js]:** 前端配置文件
  * **[express/config.js.httpPort]:** http 端口
  * **[express/config.js.httpsPort]:** https 端口(没有部署 https 证书无法访问)
  * **[express/config.js.limiter]:** 前端流量限制配置
  * **[express/config.js.proxy.target]:** 代理的后端路径

[▶ 部署 https ◀](#部署https)

> 如 7001 端口被占用,修改 根目录/config/config.prod.js.cluster.listen.port 同步修改 express/config.js.proxy.target 最后面的 端口即可,重启生效

### startup.sh 脚本

> 暖心的自动化脚本,做到了那些功能

* 检测环境 node pm2 Firewalld
* 自动下载 node pm2 ,自动创建 node pm2 软连接
* 检测依赖,并自动下载(node_modules)
* 检测 secretKey 密钥,和自动生成密钥
* 自动检测端口,并自动在防火墙开放项目端口
* 检测开机启动,自动追加开机脚本(/etc/rc.d/rc.local)
* 检测完环境后自动启动前后端服务,默认端口 http:5000,https:5001

> 项目根目录窗口运行

```shell
./shell/startup.sh
```

或者

> 没有执行权限情况下

```shell
chmod -R 777 ./shell/startup.sh && ./shell/startup.sh
```

> 项目出现没有权限

```shell
chmod -R 777 项目根目录
```


> 启动完成浏览器打开 本机IP:5000(5001)

### 部署和运行

* 克隆项目 或者下载 [releases](https://github.com/soonxf/Micro-Firewall/releases) 
* 拷贝解压到 Linux 服务器任意目录
* 项目根目录运行 startup.sh 脚本即部署成功

#### [下载过慢建议使用 Gitee](https://gitee.com/SOONXFGetee/Firewalld-UI/releases)

运行见 startup.sh 脚本 标题

> 注意:
> 部署成功后一定要

* 根目录/secretKey/fingerprint(token) 下面的密钥文件删除重新生成 
* 系统设置 重新生成 jwt 密钥 和 captcha 密钥
* 重新生成 JWT 密钥后需要重新修改密码才能登录

[▶ 修改密码 ◀](#合并示例)

#### 手动运行

> 确保 根目录 和 express 的依赖都已经下载完成(node_modules)

* 根目录执行
  
```
npm run start
```

* express 目录执行

```
node index.js
```

或者安装有 pm2

```
pm2 start index.js --name=HttpServer --exp-backoff-restart-delay=1000
```

### 登录和改密

#### 登录

> 若没有默认用户,登录页手动注册

默认用户名

```
admin
```

默认密码

```
Admin123456@
```

#### 修改密码


步骤

* 进入登录页点击修改密码
* 填入 用户名 新密码 注册口令  JWT 密钥

##### 查看注册口令

> 项目根目录打开终端执行,
>
> Linux 环境下执行,没有自带 sqlite3 环境需要自行下载
>
> 将 你的用户名 (五个汉字)替换为自己注册的用户名,完整复制不要丢失

```shell
echo -e "注册口令:" $(sqlite3 ./database/sqlite-prod.db 'SELECT secret FROM users WHERE username = "你的用户名";')
```

##### 查看 JWT 密钥

> 项目根目录打开 Linux 终端执行,完整复制不要丢失

```shell
echo -e "JWT 密钥:" $(grep secret ./config.json | head -n 1 | awk '{ print $2 }' | sed 's/\"//g')
```

> 注意: 注册口令 和 JWT 密钥 用来修改密码等,妥善保管,切勿泄漏

##### 合并示例

###### 修改密码需要用到 JWT 密钥 和 注册口令

> 复制修改 admin (五个字母)替换为自己注册的用户名,完整复制不要丢失

```shell
echo -e "注册口令:" $(sqlite3 ./database/sqlite-prod.db 'SELECT secret FROM users WHERE username = "admin";') && echo -e "JWT 密钥:" $(grep secret ./config.json | head -n 1 | awk '{ print $2 }' | sed 's/\"//g')
```

### 部署https

* 将证书存储在 express/ssl
* 修改 express/config.js 中的 ssl.key ssl.crt
* 重启生效

> ssl.key ssl.crt 填入文件名即可,不需要路径,空 (表示空 == "") 表示不启用 https

### 问题

### libstdc++ 报错

如图

![image](https://raw.githubusercontent.com/soonxf/Micro-Firewall/main/images/1676604602040.jpg)

###### 关键字

> ERROR 24956 nodejs,ER DLOPEN FAILEDError: /lib64/libstdc++.50.6: version "CXXABL 1.3.8' not found 

还可以升级系统应该也可以解决哈哈哈哈哈哈...

降低 node 版本 应该也是可以的 建议 node 版本>=14

###### 安装 libstdc++

> 安装 libstdc++ 有风险,建议备份后再尝试

[手动安装 libstdc](https://blog.340200.xyz/2022/12/19/ruan-jian/centos-libstdc.so.6-ruan-lian-jie-ku-sheng-ji/)

### 脚本下载依赖失败

* 删除根目录 node_modules

* 使用 cnpm 下载

```
npm install -g cnpm -registry=https://registry.npm.taobao.org
```

* 创建软连接

```
ln -s node目录/bin/cnpm /usr/local/bin/cnpm
```

如果是 startup.sh 脚本安装的 node , node目录一般在 ./shell/node/node版本号

* 修改 cnpm 镜像

```
cnpm config set registry https://registry.npm.taobao.org
```

* 检查 cnpm 是否安装成功

```
cnpm -v
```

* 下载依赖

```
cnpm install -registry=https://registry.npm.taobao.org
```

### 脚本内替换 node 版本

将 ./shell/node.sh 和 ./shell/pm2.sh 中出现 node-v16.18.1-linux-x64 的地方全部替换为手动下载的 node 名字

[下载 node](https://nodejs.org/dist/)


#### 手动安装 node

[教程:安装 node](https://blog.340200.xyz/2022/11/26/ruan-jian/linux-an-zhuang-node/)

### 手动安装 pm2

[教程:安装 pm2](https://blog.340200.xyz/2022/12/16/ruan-jian/pm2-de-an-zhuang-he-shi-yong/)

-----

### 解答

#### 加入黑名单失败

> 可能已经通过终端方式加入过黑名单(白名单)
> 
> 可以通过查看防火墙所有富规则来确定
>
> 任意目录,终端执行

```
firewall-cmd --list-rich-rules
```

#### 开启(关闭)端口失败

> 可能这个端口是范围性端口,目前不支持切换范围性端口的状态
> 
> 可以通过查看防火墙所有开放端口来确定
>
> 任意目录,终端执行

```
firewall-cmd --list-ports
```

#### 写入访问日志频繁

* 增加日志间隔时间(这会影响到屏蔽规则中的 频率检测)
* 将 常用的信任的 IP 加入 信任配置 中的 全部信任 列表

> 注意: 如果访问日志当中出现了 本地地址或者回环地址 请手动将其加入 全部信任 列表

#### 生成 token 或者 fingerprint 密钥失败

* 方法一:安装 ssh-keygen 和 openssl 命令
* 方法二:手动生成 rsa 密钥

> 方法二需要用到的密钥文件名和目录
> 
> 尽量生成 2048 位及以上的 rsa 密钥
> 
> 根目录/secretKey/token PRIVATE-KEY.txt PUBLIC-KEY.txt
> 
> 根目录/secretKey/fingerprint PRIVATE-KEY.txt PUBLIC-KEY.txt

#### 解禁时间

解禁时间是屏蔽 IP 可以访问的时间,当现在时间大于解禁时间 当前 IP 就会被解封从而能够访问,屏蔽名单中的状态也会从 屏蔽 置为 允许

#### 系统防火墙状态 和 屏蔽名单状态

系统防火墙状态 是指 通过 firewall-cmd --list-rich-rules 命令是否能够查询到关于此 IP drop 的富规则,其中包含 prefix="Micro-Firewall"  的是本服务写入的屏蔽规则标志.

屏蔽名单状态 是指 当前 IP 是否在 屏蔽名单 列表中查询到此 IP

注意:有些特殊情况下,屏蔽名单状态 和 系统防火墙状态 可能并不会同步,此时以 系统防火墙状态 为准,只有 系统防火墙状态 为 屏蔽 才是真正达到了屏蔽这个 IP 的目的.

#### 屏蔽规则 和 允许规则

屏蔽规则 指的是,访问的 IP 出现规则当中的其中一项条件就会被屏蔽
允许规则 指的是,访问的 IP 出现规则当中的全部条件就会被允许

注意: 屏蔽规则 和 允许规则 的权重,当权重高的规则被满足后面的规则就不会再执行了,越靠上 权重越高,会被优先判断

#### 屏蔽规则 中的 频率检测

频率检测中的时间 如 30分钟 和 100次,指的是 访问日志 在 30分钟内 写入了 100次 一样的 IP (只关注 IP 和 次数,不关注 访问的究竟是那个端口),其中访问日志写入的次数和 系统设置 中的 日志间隔 配置 息息相关

如 系统设置 中的 日志间隔 配置为 30 ,则表示 同一个 IP 在访问同一个端口的情况下 30 秒才会写入记录一次

例: 

A 机器只 访问了 80端口 ,则 A 机器在 30 秒内访问 80端口 的记录只会记录一次(无限刷新访问也记录一次),如果 30 秒后再次访问就会再次写入一次

A 机器同时 访问了 80 和 443 端口,则是 同时 写入 80 和 443 的访问记录, 30 秒还在访问,则会再重新写入

#### IP 归属地

IP 归属地查询使用的是 离线归属地查询库 ip2region .因此可能部分地区的 信息不能及时更新,极少情况下存在可能有失真的情况

#### 归属地搜索

归属地的搜索对顺序不敏感,如 安徽 和 徽安 会同样搜索出 归属地为 安徽 的访问日志等,但是对于错别字或者符号等是敏感的,需要注意,输入一些错误字符都可能导致搜索结果差强人意.

#### 时间选择

项目中用到的日期选择都做了禁用处理,其中典型的是关于 屏蔽时间 时分秒的禁止选择,当选择 屏蔽时间 到当天时,最少的选择是大于当前时间的 3 分钟 或者 5 分钟后,因为选择屏蔽一个 IP 到 过去的时间是没有意义的,因此禁止选择.

#### 前后端流量限制

前后端流量都有着一套自己的一套流量限制规则 具体查看 express/config.js.limiter(前端流量限制) 和 系统设置>流量限制 (后端流量限制).

重启可以重置这个时间.


### 意见和建议

> 备注问题

```email
soonxf@dingtalk.com
```

#### 完整启动流程截图

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%90%AF%E5%8A%A8%E6%88%AA%E5%9B%BE.png?raw=true)

#### 部分截图

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/1676831778006.jpg?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/1676831984394.jpg?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/1676832038146.jpg?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20235608.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20235644.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20235740.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20235833.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20235951.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20224802.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20224842.png?raw=true)

![image](https://github.com/soonxf/Micro-Firewall/blob/main/images/%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE%202023-01-23%20225144.png?raw=true)