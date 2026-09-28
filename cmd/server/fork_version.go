// fork_version.go —— 本 fork 的发布版本号（与上游 appVersion 相互独立）。
//
// 为什么不直接改 main.go 里的 appVersion：
//
//	cmd/server/main.go 属于上游代码。本 fork 若在那里改版本号，上游每次发版
//	（同样改那一行）都会与本 fork 冲突，而本 fork 是**定时自动跟随上游**的
//	（sync-upstream，每小时检查），冲突会反复出现、每次都要人工介入。
//	所以版本号放在本 fork 专属文件里，上游代码保持零改动，合并永不冲突。
//
// 版本号的唯一来源是仓库根目录的 FORK_VERSION 文件；CI 在构建时通过
// -ldflags "-X main.forkVersion=<版本>" 注入到二进制（源码里的 "dev" 是占位值）。
//
// 启动时打印一行，便于核对「这个二进制属于哪个发布版本」——
// 与 module.prop、GitHub Release 的版本号对得上，排查时不用猜。
package main

import "log"

// forkVersion 本 fork 的发布版本（如 0.0.1），由 CI 注入；本地未注入时为 "dev"。
var forkVersion = "dev"

func init() {
	log.Printf("workbuddy2api-panel fork %s (upstream panel %s)", forkVersion, appVersion)
}
