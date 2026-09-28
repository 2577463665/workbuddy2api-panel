#!/system/bin/sh
# 模块卸载时清理（KernelSU/Magisk 卸载时以 root 执行）
# 保留开关：/data/adb/wb2api/KEEP_DATA 存在则不删数据（重装前防误删账号）
PERSIST=/data/adb/wb2api

pkill -x wb2api 2>/dev/null && sleep 1 && pkill -9 -x wb2api 2>/dev/null

if [ -f "$PERSIST/KEEP_DATA" ]; then
  echo "wb2api-panel: KEEP_DATA present, keeping $PERSIST"
  exit 0
fi
rm -rf "$PERSIST"
