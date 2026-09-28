# KernelSU 模块打包：wb2api-panel

本目录是 KernelSU/Magisk 模块模板，CI 在打 `v*` tag 时自动组装打包。

## 文件结构（打包进模块 zip 的内容）

| 文件 | 作用 |
|---|---|
| `module.prop` | 模块元数据（版本号由 CI 注入；`updateJson` 指向在线更新频道） |
| `service.sh` | 开机自启门控：禁启开关、等 `boot_completed` → 调 `start.sh` → 写面板信息文件 |
| `start.sh` | **服务启动唯一实现**：可执行位兜底 + CA 证书环境 + 清旧进程 + 拉起 + 结果判定 |
| `cacert.sh` | **CA 根证书准备**：拼出 Android 各证书目录的 PEM 包，输出目录清单（被 start.sh 调用） |
| `action.sh` | 点模块「操作」按钮：展示面板地址与访问密钥 |
| `info.sh` | **信息采集唯一逻辑源**（端口/密钥/IP/状态），被 action.sh、service.sh、WebUI 复用 |
| `customize.sh` | 安装时：架构校验 + 恢复二进制可执行位 + 提示在哪里查看面板地址 |
| `uninstall.sh` | 卸载：停服务、清数据（`KEEP_DATA` 可保留） |
| `webroot/index.html` | KernelSU 模块 WebUI：查看地址/密钥、启停服务、自启开关、诊断自检 |
| `wb2api` | 服务二进制（CI 从 linux-arm64 产物置入，非仓库文件） |

维护者文件（`README.md`、`.gitattributes`）不进模块 zip。

## Android 上的两个平台坑（都已修）

### 1. 二进制可执行位会被安装器清掉

KSU 安装脚本 `installer.sh:419` 执行 `set_perm_recursive $MODPATH 0 0 0755 0644`，
把模块内**所有文件**设为 0644，只有 `system/bin` 等目录在 420-423 行被恢复 0755。
本模块的 `wb2api` 在模块根目录，所以安装后没有可执行位，`exec` 报 `Permission denied`。
安装器在设完默认权限**之后**才加载 `customize.sh`（`installer.sh:427`），因此在那里
用 `set_perm` 能生效；`start.sh` 每次启动前再 `chmod` 一次作为兜底。

### 2. Go 在 Android 上找不到根证书

用 `GOOS=linux` 编译的 Go 程序，`crypto/x509` 只查找 Linux 发行版路径：

```
/etc/ssl/certs/ca-certificates.crt、/etc/pki/tls/certs …（Android 上一个都不存在）
```

Android 专属路径（`/system/etc/security/cacerts`、`/data/misc/keychain/certs-added`）
只在 `goos.IsAndroid == 1`（即用 `GOOS=android` 编译）时才被加入。因此 linux 构建的
二进制在 Android 上**一个根证书都加载不到**，所有 HTTPS 请求报：

```
x509: certificate signed by unknown authority
```

Docker 里能用，是因为镜像装了 `ca-certificates` 提供了那个文件。

修法（见 `cacert.sh` / `start.sh`）：把各证书目录拼成 PEM 包并显式导出环境变量——
Go 的 `SSL_CERT_DIR` 会**替换**默认目录列表且会读取目录内所有文件（不要求哈希命名）：

```sh
export SSL_CERT_DIR="/system/etc/security/cacerts:/apex/com.android.conscrypt/cacerts:\
/data/misc/keychain/certs-added:/data/misc/user/0/cacerts-added"
export SSL_CERT_FILE="$PERSIST/cacert.pem"
```

覆盖 `apex/com.android.conscrypt/cacerts`（Android 14+ 把系统证书移到了 Conscrypt APEX）
与 `certs-added`（用户安装的证书，代理/MITM 场景需要）。

## 用户怎么找到面板地址和密钥

模块装好后，用户有三个途径，都不需要 root 文件管理器：

1. **KernelSU 模块 WebUI**：模块页 → 本模块 → WebUI 按钮（地址、密钥、启停、自启开关、诊断）
2. **操作按钮**：点模块的「操作」按钮，输出面板地址与密钥
3. **文本文件**：`/sdcard/wb2api-info.txt`（开机自动生成，文件管理器可直接打开）

设计约束：**面板鉴权复用网关 `api_key`**（`internal/panel/panel.go` 用 `VerifyBearer`），
所以用户必须知道这把 key 才能进面板；面板前端把它存在 `localStorage`，输入一次即可。

## 脚本编写约束（重要）

Android 自带的 toybox **没有 `ip`、`awk`**，脚本里一律不用。已确认可用的命令：
`ifconfig`、`grep`（含 `-oE`）、`sed`、`cut`、`head`、`pkill`、`pgrep`、`pidof`、
`nohup`、`sleep`、`date`、`base64`、`printf`、`cat`、`mkdir`、`chmod`、`touch`、`rm`。

进程用 `pkill -x wb2api` 精确匹配短名（comm 最多 15 字符，`wb2api` 安全）。

## 数据目录（持久于模块之外）

模块安装在 `/data/adb/modules/wb2api_panel/`，数据在 `/data/adb/wb2api/`，
**模块升级或重装不丢数据**：

| 路径 | 内容 |
|---|---|
| `config.json` | 配置（首次启动自动生成，含随机 api_key） |
| `auths/` | 账号凭证 |
| `data/` | 状态/用量数据 |
| `wb2api.log` | 运行日志 |
| `INFO.txt` | 面板信息（开机生成：地址/密钥/状态） |
| `DISABLE_AUTOSTART` | 存在即禁用开机自启（WebUI 一键切换） |
| `KEEP_DATA` | 存在则卸载时保留数据 |

## 在线更新机制（updateJson）

`module.prop` 的 `updateJson` 指向 GitHub 的 latest 稳定地址：

```
https://github.com/<owner>/<repo>/releases/latest/download/update.json
```

KernelSU / Magisk 管理器定期拉取；发现 `versionCode` 比已安装的大，就在模块页提示更新，
点击后自动下载 `zipUrl` 指向的模块 zip 安装。

- `update.json` 由 publish job 生成，作为 **Release 资产**随版本发布
- 用 `releases/latest/download/` 而非 jsdelivr CDN：**即时生效、无长时间缓存**，
  且与模块 zip 同源（能下 zip 就能取 json，不额外引入可达性风险）
- `latest` 自动排除 prerelease，因此 `-ci` 演练版本天然不会进更新频道
- 另有一份镜像同步到 `ksu-update` 分支（`https://cdn.jsdelivr.net/gh/<owner>/<repo>@ksu-update/update.json`）：
  实测 jsdelivr 对分支引用缓存很顽固（purge 返回成功后仍可能返回旧内容），故仅作备用，
  需要时可手动改 `updateJson` 用它
- `versionCode` 口径：`1.2.3` → `1*1000000 + 2*1000 + 3`

## 本地打包（不走 CI 时）

本地不要直接 zip 本目录——`module.prop` 的 version 是占位符，需手动改成真实版本。
正常走 CI：提交后 `git tag v1.x.y && git push origin v1.x.y`。
CI 会自动做 CRLF→LF 转换与可执行位设置。
