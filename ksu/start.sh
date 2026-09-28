#!/system/bin/sh
# wb2api 服务启动入口：唯一实现，被 service.sh（开机自启）与 WebUI（手动启动）复用。
# 集中处理：可执行位兜底、CA 根证书环境、旧进程清理、拉起、启动结果判定与日志。
MODDIR="${MODDIR:-${0%/*}}"
export MODDIR
PERSIST=/data/adb/wb2api
BIN="$MODDIR/wb2api"
LOG="$PERSIST/wb2api.log"

wlog() { /system/bin/log -p i -t wb2api "$@" 2>/dev/null || true; }

mkdir -p "$PERSIST" 2>/dev/null

# ── 1. 可执行位 ──────────────────────────────────────────────────────────────
# 模块安装器会把模块内所有文件统一设为 0644（installer.sh:419 的 set_perm_recursive），
# 根目录下的二进制不会像 system/bin 那样被自动置 0755，不恢复则 exec 报 Permission denied。
[ -x "$BIN" ] || chmod 0755 "$BIN" 2>/dev/null
if [ ! -f "$BIN" ]; then
  wlog "FATAL: binary missing: $BIN"
  echo "启动失败：找不到服务二进制 $BIN"
  exit 1
fi
if [ ! -x "$BIN" ]; then
  wlog "FATAL: binary not executable: $BIN"
  echo "启动失败：无法设置可执行位（$BIN）"
  exit 1
fi

# ── 2. CA 根证书环境 ────────────────────────────────────────────────────────
# Android 上 Go 的默认证书路径全都不存在，不显式指定则所有 HTTPS 请求失败：
#   x509: certificate signed by unknown authority
# cacert.sh 负责拼包并给出目录清单（单一来源，避免两处各写一份目录列表）。
CA_INFO=$(sh "$MODDIR/cacert.sh" 2>/dev/null)
CA_DIRS=$(printf '%s\n' "$CA_INFO" | sed -n 's/^CACERT_DIRS=//p' | head -1)
CA_N=$(printf '%s\n' "$CA_INFO" | sed -n 's/^CACERT_COUNT=//p' | head -1)
export SSL_CERT_DIR="${CA_DIRS:-/system/etc/security/cacerts}"
export SSL_CERT_FILE="$PERSIST/cacert.pem"
wlog "cacert: bundled=${CA_N:-0} dirs=[${CA_DIRS}]"

# ── 3. 清理旧进程（避免端口占用）────────────────────────────────────────────
# comm 最多 15 字符，pkill -x wb2api 按短名精确匹配
pkill -x wb2api 2>/dev/null && { sleep 1; pkill -9 -x wb2api 2>/dev/null; }

# ── 4. 拉起并判定结果 ───────────────────────────────────────────────────────
cd "$PERSIST" || { wlog "FATAL: cannot cd $PERSIST"; echo "启动失败：无法进入 $PERSIST"; exit 1; }
nohup "$BIN" -config "$PERSIST/config.json" >> "$LOG" 2>&1 &
PID=$!

sleep 2
if kill -0 "$PID" 2>/dev/null; then
  wlog "started pid $PID"
  echo "服务已启动（pid $PID，端口见 config.json 的 listen）"
  exit 0
fi

# 进程立刻退出：把日志尾部同时送到 logcat 与返回值，便于排查
wlog "FATAL: wb2api exited immediately"
tail -n 15 "$LOG" 2>/dev/null | while IFS= read -r L; do wlog "log| $L"; done
echo "启动失败，服务已退出。日志末尾："
tail -n 10 "$LOG" 2>/dev/null
exit 1
