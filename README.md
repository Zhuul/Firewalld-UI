<style>
.card {
 width:90%;
 padding: 2%;
 background: rgb(255, 255, 255);
 border-bottom: 2px solid blueviolet;
 border-right: 2px solid blueviolet;
 border-top: 2px solid white;
 border-left: 2px solid white;
 transition-duration: 1s;
 margin-bottom:20px;
 transition-property: border-top, 
    border-left, 
    border-bottom,
    border-right,
    box-shadow;
}
ul li {
  text-align:left;
  font-size:14px;
}
.card:hover {
 border-top: 2px solid blueviolet;
 border-left: 2px solid blueviolet;
 border-bottom: 2px solid rgb(238, 103, 238);
 border-right: 2px solid rgb(238, 103, 238);
 box-shadow: rgba(240, 46, 170, 0.4) 5px 5px, rgba(240, 46, 170, 0.3) 10px 10px, rgba(240, 46, 170, 0.2) 15px 15px, rgba(240, 46, 170, 0.1) 20px 20px, rgba(240, 46, 170, 0.05) 25px 25px;
}

.card__content {
 font-size: small;
 text-align: center;
}

.card__content-heading {
 color: blueviolet;
}

.card__content-body {
 color: rgb(118, 104, 128);
 padding-bottom: 1rem;
}

.card__content-footer button {
 background-color: rgb(255, 255, 255);
 color: grey;
 font-weight: 700;
 border-radius: .2rem;
 border: 1px solid grey;
 padding: .5rem;
 margin: 1rem;
 transition-duration: 1s;
 transition-property: background-color, color, border;
}

button:hover {
 color: white;
 background-color: rgb(238, 103, 238);
 border: 1px solid white;
 box-shadow: rgba(67, 71, 85, 0.27) 0px 0px 0.25em, rgba(90, 125, 188, 0.05) 0px 0.25em 1em;
}




</style>
<div align="center">

##### 开源不易,点个 🌟🌟🌟 吧!!!

##### 好人一生平安!!!

</div>

<div align="center">

### Micro-Firewall

</div>

Micro-Firewall 基于 linux 的 node 微型界面化防火墙,支持自定义创建屏蔽规则,根据规则自动屏蔽 IP

## 演示环境

> 演示环境没有部署在 linux ,因此很多功能是失效的

<div align="center">

## [点击查看演示](https://340200.xyz:65001)

</div>

<div align="center">

[▶ 必看:几乎大概肯定一定会发生的问题及解决方法 ◀](#问题)

</div>

### 请务必仔细阅读文档...

### 联系我

> 备注问题

```email
soonxf@dingtalk.com
```


<div class="card">
  <div class="card__content">
    <div class="card__content-heading">
      <h2>要求</h2>
      <br>
    </div>
    <div class="card__content-body">
   <ul>
  <li>linux 系统</li>
  <li>安装有 firewalld 防火墙</li>
  <li>nodejs 和 pm2 (node 推荐 16.18.1)</li>
  <li>脚本会检测安装 除 firewalld 防火墙外的所有环境,可以实现一键部署启动</li>
  </ul>
    </div>
  </div>
</div>

<div class="card">
  <div class="card__content">
    <div class="card__content-heading">
      <h2>项目介绍和技术栈</h2>
      <br>
    </div>
    <div class="card__content-body">
      <ul>
<li>部署启动极其简单,一键 startup.sh 脚本轻松部署</li>
<li>前端基于 Vue(element UI), 后端 基于 nodejs(eggjs)</li>
<li>修改 element 源码,table 组件增加 defer 延迟加载函数</li>
<li>vuex 和 数据持久化, pm2 管理和部署项目, pkg 打包前端静态资源</li>
<li>express 部署前端 https 静态资源,使用 limiter 帽子防护 xss 等攻击</li>
<li>使用 jwt 和 浏览器指纹维护前端的登录状态</li>
<li>前后端 根据 IP 的限流措施</li>
<li>基于 sqlite3 的数据库存储,接口使用事务处理数据</li>
<li>linux 防火墙 firewall 的使用</li>
<li>自动的检测环境和下载所需的依赖</li>
<li>自动化屏蔽 IP,可以根据 IP 归属地流量和地点关键词规则屏蔽刻意访问</li>
<li>使用 rsa 加密 token 和 指纹等信息</li>
<li>自动保存的表格可拖拽宽度配置,所有单元格内容都做了省略处理和 tooltip 提示</li>
<li>多种组件大小可供手动调节,多尺寸设备都可兼容</li>
  </ul>
    </div>
  </div>
</div>


<div class="card">
  <div class="card__content">
    <div class="card__content-heading">
      <h2>目录和文件</h2>
      <br>
    </div>
    <div class="card__content-body">
    <ul>
<li>shell: 自动化脚本目录</li>
<li>secretKey: 存放 rsa 密钥,用于加密 token 和 指纹</li>
<li>shell/shell.log: 记录自动化脚本的日志</li>
<li>config.json: 系统设置,同界面化 系统设置 页面</li>
<li>express 前端根目录</li>
<ul>
  <li>express/ssl: 存放 https 证书</li>
  <li>express/dist: 前端静态资源</li>
  <li>express/config.js: 前端配置文件</li>
  <li>express/config.js.httpPort: http 端口</li>
  <li>express/config.js.httpsPort: https 端口(没有部署 https 证书无法访问)</li>
  <li>express/config.js.limiter: 前端流量限制配置</li>
  <li>express/config.js.proxy.target:代理的后端路径</li>
  </ul>
  </ul>
    </div>
  </div>
</div>



[▶ 部署 https ◀](#部署https)

> 如 7001 端口被占用,修改 根目录/config/config.prod.js.cluster.listen.port 同步修改 express/config.js.proxy.target 最后面的 端口即可,重启生效

---

### startup.sh 脚本

> 暖心的自动化脚本,做到了那些功能

- 检测环境 node pm2 firewalld
- 自动下载 node pm2 ,自动创建 node pm2 软连接
- 检测依赖,并自动下载(node_modules)
- 检测 secretKey 密钥,和自动生成密钥
- 自动检测端口,并自动在防火墙开放项目端口
- 检测开机启动,自动追加开机脚本(/etc/rc.d/rc.local)
- 检测完环境后自动启动前后端服务,默认端口 http:5000,https:5001

> 项目根目录运行

```
./shell/startup.sh
```

或者

> 没有执行权限情况下

```
chmod -R 777 ./shell/startup.sh && ./shell/startup.sh
```

> 启动完成浏览器打开 本机 IP:5000(5001)

---

### 部署和运行

- clone 项目 或者下载 [releases](https://github.com/soonxf/Micro-Firewall/releases)
- 拷贝解压到 linux 服务器任意目录
- 项目根目录运行 startup.sh 脚本即部署成功

> 注意:部署成功后一定要在 系统设置 重新生成一下 jwt 密钥 和 captcha 密钥,请勿泄漏两种密钥
> 重新生成 JWT 密钥后需要重新修改密码才能登录

[▶ 修改密码 ◀](#合并示例)

---

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

- 进入登录页点击修改密码
- 填入 用户名 新密码 注册口令 JWT 密钥

##### 查看注册口令

> 项目根目录打开终端执行,
>
> linux 环境下执行,没有自带 sqlite3 环境需要自行下载
>
> 将 你的用户名 (五个汉字)替换为自己注册的用户名,完整复制不要丢失

```
echo -e "注册口令:" $(sqlite3 ./database/sqlite-prod.db 'SELECT secret FROM users WHERE username = "你的用户名";')
```

##### 查看 JWT 密钥

> 项目根目录打开 linux 终端执行,完整复制不要丢失

```
echo -e "JWT 密钥:" $(grep secret ./config.json | head -n 1 | awk '{ print $2 }' | sed 's/\"//g')
```

> 注意: 注册口令 和 JWT 密钥 用来修改密码等,妥善保管,切勿泄漏

##### 合并示例

###### 修改密码需要用到 JWT 密钥 和 注册口令

> 复制修改 admin (五个字母)替换为自己注册的用户名,完整复制不要丢失

```
echo -e "注册口令:" $(sqlite3 ./database/sqlite-prod.db 'SELECT secret FROM users WHERE username = "admin";') && echo -e "JWT 密钥:" $(grep secret ./config.json | head -n 1 | awk '{ print $2 }' | sed 's/\"//g')
```

---

### 部署 https

- 将证书存储在 express/ssl
- 修改 express/config.js 中的 ssl.key ssl.crt
- 重启生效

> ssl.key ssl.crt 填入文件名即可,不需要路径,空 (表示空 == "") 表示不启用 https

---

### 问题

### libstdc++ 报错

如图

![image](https://raw.githubusercontent.com/soonxf/Micro-Firewall/main/images/1676604602040.jpg)

> 关键字
>
> ERROR 24956 nodejs,ER DLOPEN FAILEDError: /lib64/libstdc++.50.6: version "CXXABL 1.3.8' not found
>
> 还可以升级系统应该也可以解决哈哈哈哈哈哈...
>
> 降低 node 版本 应该也是可以的 建议 node 版本>=14

###### 安装 libstdc++

> 安装 libstdc++ 有风险,建议备份后再尝试

[手动安装 libstdc](https://blog.340200.xyz/2022/12/19/ruan-jian/centos-libstdc.so.6-ruan-lian-jie-ku-sheng-ji/)

### 脚本下载依赖失败

> 删除根目录 node_modules

> 使用 cnpm 下载

```
npm install -g cnpm -registry=https://registry.npm.taobao.org
```

> 如果是 startup.sh 脚本安装的 node , node 目录一般在 ./shell/node/node 版本号

```
ln -s node目录/bin/cnpm /usr/local/bin/cnpm
```

```
cnpm config set registry https://registry.npm.taobao.org
```

##### 检查是否安装成功

```
cnpm -v
```

##### 下载依赖

```
cnpm install -registry=https://registry.npm.taobao.org
```

---

### 脚本内替换 node 版本

将 ./shell/node.sh 和 ./shell/pm2.sh 中出现 node-v16.18.1-linux-x64 的地方全部替换为手动下载的 node 名字

[下载 node](https://nodejs.org/dist/)

#### 手动安装 node

[手动安装 node](https://blog.340200.xyz/2022/11/26/ruan-jian/linux-an-zhuang-node/)

### 手动安装 pm2

[手动安装 pm2 教程](https://blog.340200.xyz/2022/12/16/ruan-jian/pm2-de-an-zhuang-he-shi-yong/)

---

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

#### gitee

[Micro-Firewall](https://gitee.com/SOONXFGetee/micro-firewall)

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
