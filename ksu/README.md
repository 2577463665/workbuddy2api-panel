# KernelSU 模块打包：wb2api-panel

本目录是 KernelSU/Magisk 模块模板（module.prop / service.sh / action.sh / uninstall.sh）。
`.github/workflows/go-binaries.yml` 的 CI 会在打 `v*` tag 时：

1. 交叉编译 linux/arm64(arm64-v8a) 二进制（与五平台发布矩阵同一棵源码树、同一套 `-s -w` 剥离纪律）
2. 断言二进制版本串 == 源码 appVersion（沿用仓库既有发布纪律）
3. 组装模块结构，注入 module.prop 真实版本号
4. 打包为 `wb2api-panel-v<版本>-ksu-arm64-v8a.zip`，随其他平台产物一起进同一 GitHub Release
5. 把 `update.json` 推到 `ksu-update` 分支（在线更新频道）

## 在线更新机制（updateJson）

`module.prop` 的 `updateJson` 字段指向固定 URL：

```
https://cdn.jsdelivr.net/gh/linguo2625469/workbuddy2api-panel@ksu-update/update.json
```

KernelSU / Magisk 管理器会定期拉取该 URL；发现 `versionCode` 比已安装的大，就在模块页提示更新，点击后自动下载 `zipUrl` 指向的模块 zip 安装。

- `update.json` 由 publish job 每次发版时推送到 `ksu-update` 分支（单文件，整体覆盖语义）
- 走 jsdelivr CDN：国内可达性好于 raw.githubusercontent.com；缓存最长 12h，提示更新最多延迟半天
- 模块 zip 下载直连 GitHub Releases（`zipUrl`），不受 CDN 缓存影响
- `versionCode` 拼装规则：`1.2.3` → `1*1000000 + 2*1000 + 3`（与 ksu-module job 同口径，必须保持一致）

## 数据目录（持久于模块之外）

模块安装到 `/data/adb/modules/wb2api_panel/`，但配置/账号/状态都在 `/data/adb/wb2api/`，
**模块升级或重装不丢数据**：

| 路径 | 内容 |
|---|---|
| `config.json` | 配置（首次启动自动生成，含随机 api_key） |
| `auths/` | 账号凭证 |
| `data/` | 状态/用量数据 |
| `wb2api.log` | 运行日志 |
| `DISABLE_AUTOSTART` | 存在即禁用开机自启（action.sh 一键切换） |
| `KEEP_DATA` | 存在则卸载模块时保留数据 |

## 本地打包（不走 CI 时）

本地不要直接 zip 本目录——`module.prop` 里的 version 字段是占位符，需要手动改成真实版本
（或直接跑 CI：提交后打 tag `git tag v1.x.y && git push origin v1.x.y`）。
CI 组装时会自动做 CRLF→LF 转换与可执行位设置。
