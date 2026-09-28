#!/system/bin/sh
# KernelSU 管理器里点击模块图标时执行（Magisk 不支持 action.sh，忽略即可）
# 用途：一键切换「开机自启」开关，并同步启动/停止当前服务。
MODDIR="${0%/*}"
PERSIST=/data/adb/wb2api

mkdir -p "$PERSIST"

if [ -f "$PERSIST/DISABLE_AUTOSTART" ]; then
  # 当前禁用 → 切回启用并立即启动
  rm -f "$PERSIST/DISABLE_AUTOSTART"
  if ! pgrep -x wb2api >/dev/null 2>&1; then
    cd "$PERSIST" && nohup "$MODDIR/wb2api" -config "$PERSIST/config.json" >> "$PERSIST/wb2api.log" 2>&1 &
    echo "已启用开机自启，并已启动服务（端口 7863，面板 /panel/）"
  else
    echo "已启用开机自启（服务已在运行中）"
  fi
else
  # 当前启用 → 切换为禁用并停掉运行中的进程
  touch "$PERSIST/DISABLE_AUTOSTART"
  pkill -x wb2api 2>/dev/null && sleep 1 && pkill -9 -x wb2api 2>/dev/null
  echo "已禁用开机自启，并已停止服务"
fi
