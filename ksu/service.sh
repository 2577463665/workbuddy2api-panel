#!/system/bin/sh
# wb2api-panel KernelSU/Magisk 模块开机自启脚本
# 由模块管理器在 late_start service 阶段以 root 执行。
# 数据目录 /data/adb/wb2api 持久于模块之外：模块升级/重装不丢配置与账号。
#
# 启动逻辑本身在 start.sh（与 WebUI 的手动启动共用同一实现，避免两处漂移）；
# 本脚本只负责开机特有的部分：禁启开关、等开机完成、启动后写面板信息。
MODDIR="${0%/*}"
export MODDIR
PERSIST=/data/adb/wb2api

# 日志进 logcat（tag wb2api）：/system/bin/log 是 toybox android 组件，KSU/Magisk 环境均有；
# 极端缺失时静默降级（输出对功能非必需）。
wlog() { /system/bin/log -p i -t wb2api "$@" 2>/dev/null || true; }

# 写一份人可读的面板信息（地址/密钥/状态），方便用户随时查看：
#   1) /data/adb/wb2api/INFO.txt      —— 持久目录内（root）
#   2) /sdcard/wb2api-info.txt        —— 外部存储，文件管理器直接打开，无需 root
# 两次写入都失败不影响服务本身。
write_info() {
  # 显式 sh 调用（不依赖可执行位，权限异常时仍可用）
  sh "$MODDIR/info.sh" > "$PERSIST/INFO.txt" 2>/dev/null || true

  if [ -d /sdcard ]; then
    # /sdcard 在部分设备的 boot 早期尚未挂载完成，失败即跳过（下次重启会重写）
    {
      echo "WorkBuddy2API 面板信息（开机自动生成）"
      echo "生成时间：$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
      echo
      sh "$MODDIR/info.sh" 2>/dev/null
      echo
      echo "面板地址用于浏览器访问；访问密钥首次登录面板时粘贴，之后浏览器会记住。"
      echo "换 WiFi/热点后 IP 会变化：可在 KernelSU 里点本模块的「操作」按钮查看最新地址。"
    } > /sdcard/wb2api-info.txt 2>/dev/null || wlog "write /sdcard/wb2api-info.txt failed"
  fi
}

# 开机禁启开关：/data/adb/wb2api/DISABLE_AUTOSTART 存在即跳过启动
# （在 KernelSU 的模块 WebUI 里一键切换；也可 adb shell 手动 touch/rm）
if [ -f "$PERSIST/DISABLE_AUTOSTART" ]; then
  wlog "autostart disabled, skip"
  exit 0
fi

# 等 boot completed，最多 60s（个别设备 late_start 阶段尚未完全开机）
waited=0
until [ "$(getprop sys.boot_completed)" = "1" ] || [ "$waited" -ge 60 ]; do
  sleep 2
  waited=$((waited + 2))
done

# 持久目录兜底：旧版本模块升级/意外删除时，先建回来再启动
mkdir -p "$PERSIST" 2>/dev/null

# 启动（含可执行位兜底、CA 证书环境、旧进程清理、结果判定与日志）
sh "$MODDIR/start.sh"

# 无论启动成功与否都写面板信息（启动失败时用户仍需知道去哪里看日志）
write_info
wlog "panel info written to $PERSIST/INFO.txt"
