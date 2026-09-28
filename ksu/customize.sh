#!/system/bin/sh
# 模块安装脚本（Magisk / KernelSU 安装器环境执行）。
# 只做架构校验与安装提示，不干预默认解压流程。
#
# ARCH 由安装器注入（arm64/arm/x64/x86 等）。空值放行：部分 recovery / 管理器
# 版本不注入该变量，误判会导致正常安装被中止，故仅在明确为其它架构时才拦。
case "$ARCH" in
  ""|arm64) : ;;
  *) abort "! 本模块仅提供 arm64-v8a 二进制，当前设备架构为 $ARCH" ;;
esac

ui_print "- WorkBuddy2API 面板（OpenAI 兼容网关 + Web 管理面板）"
ui_print "- 服务开机自动启动，默认监听 :7863"
ui_print ""
ui_print "- 安装完成后重启生效。查看面板地址与访问密钥："
ui_print "    · KernelSU：模块页 → 本模块 → WebUI 按钮"
ui_print "    · 或点本模块的「操作」按钮"
ui_print "    · 或查看 /data/adb/wb2api/INFO.txt"
ui_print "      （同时会复制一份到 /sdcard/wb2api-info.txt，文件管理器可直接打开）"
ui_print ""
ui_print "- 配置与账号数据保存在 /data/adb/wb2api，模块升级不丢失"
