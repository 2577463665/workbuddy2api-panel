#!/system/bin/sh
# wb2api-panel KernelSU/Magisk 模块开机自启脚本
# 由模块管理器在 late_start service 阶段以 root 执行。
# 数据目录 /data/adb/wb2api 持久于模块之外：模块升级/重装不丢配置与账号。
MODDIR="${0%/*}"
PERSIST=/data/adb/wb2api

# 日志进 logcat（tag wb2api）：/system/bin/log 是 toybox android 组件，KSU/Magisk 环境均有；
# 极端缺失时静默降级（输出对功能非必需）。
wlog() { /system/bin/log -p i -t wb2api "$@" 2>/dev/null || true; }

# 开机禁启开关：/data/adb/wb2api/DISABLE_AUTOSTART 存在即跳过启动
# （action.sh 在 KernelSU 管理器里一键切换；也可 adb shell 手动 touch/rm）
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
mkdir -p "$PERSIST"

# 进程清理：comm 最多 15 字符，pkill -x wb2api 按短名精确匹配；
# 上一进程未退干净先杀掉，避免端口占用
pkill -x wb2api 2>/dev/null && { sleep 1; pkill -9 -x wb2api 2>/dev/null; }

cd "$PERSIST" || { wlog "cannot cd $PERSIST, abort"; exit 1; }
nohup "$MODDIR/wb2api" -config "$PERSIST/config.json" >> "$PERSIST/wb2api.log" 2>&1 &
wlog "started pid $! on :7863 (panel http://127.0.0.1:7863/panel/)"
