#!/system/bin/sh
# 模块安装脚本（Magisk / KernelSU 安装器以「source」方式加载，见 installer.sh:427）。
#
# 关键：安装器在加载本脚本**之前**已执行 set_perm_recursive $MODPATH 0 0 0755 0644，
# 即把模块内所有文件统一设为 0644，只有 system/bin 等目录被单独恢复 0755
# （installer.sh:419-423）。本模块的 wb2api 放在模块根目录，因此必须在这里显式
# 恢复可执行位，否则 service.sh 里 exec 会直接 Permission denied。
#
# ARCH 由安装器注入（arm64/arm/x64/x86 等）。空值放行：部分 recovery / 管理器
# 版本不注入该变量，误判会导致正常安装被中止，故仅在明确为其它架构时才拦。
case "$ARCH" in
  ""|arm64) : ;;
  *) abort "! 本模块仅提供 arm64-v8a 二进制，当前设备架构为 $ARCH" ;;
esac

# 恢复二进制可执行位（installer 提供的 set_perm：chown/chmod/chcon 三连，
# 缺失时回落纯 chmod——权限位本身才是 exec 成败的关键）。
BIN="$MODPATH/wb2api"
if [ -f "$BIN" ]; then
  set_perm "$BIN" 0 0 0755 2>/dev/null || chmod 0755 "$BIN"
  if [ -x "$BIN" ]; then
    ui_print "- 服务二进制可执行位已设置"
  else
    ui_print "! 警告：无法设置 $BIN 的可执行位"
    ui_print "  若启动失败（Permission denied），请反馈"
  fi
else
  ui_print "! 警告：模块内未找到服务二进制 wb2api"
fi

ui_print "- WorkBuddy2API 面板（OpenAI 兼容网关 + Web 管理面板）"
ui_print "- 服务开机自动启动，默认监听 :7863"
ui_print ""
ui_print "- 重启后查看面板地址与访问密钥："
ui_print "    · KernelSU：模块页 → 本模块 → WebUI 按钮"
ui_print "    · 或点本模块的「操作」按钮"
ui_print "    · 或查看 /data/adb/wb2api/INFO.txt"
ui_print "      （同时会复制一份到 /sdcard/wb2api-info.txt，文件管理器可直接打开）"
ui_print ""
ui_print "- 配置与账号数据保存在 /data/adb/wb2api，模块升级不丢失"
