#!/system/bin/sh
# wb2api 模块信息采集：唯一逻辑源。
# 被 action.sh（点击模块操作按钮）、service.sh（写 INFO.txt）、WebUI（exec 调用）复用，
# 避免三处各自解析配置导致口径漂移。
#
# 输出 key=value（每行一项），便于 shell 解析、落盘与前端消费：
#   STATUS=running|stopped  AUTOSTART=on|off  IP/PORT/URL  KEY  VERSION
#
# 依赖说明：只用 Android toybox 确认存在的命令（ifconfig/grep/sed/cut/head/pidof/getprop）。
# Android toybox **没有 ip 和 awk**，故一律不用。
MODDIR="${MODDIR:-${0%/*}}"
PERSIST=/data/adb/wb2api
CONF="$PERSIST/config.json"

# ── 端口：config.json 的 listen（":7863" / "0.0.0.0:7863" / "7863"）──────────
PORT=7863
if [ -f "$CONF" ]; then
  L=$(sed -n 's/.*"listen"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONF" | head -1)
  case "$L" in
    *:*) PORT="${L##*:}" ;;
    ?*)  PORT="$L" ;;
  esac
fi
# 非纯数字（含空）一律回落默认端口，避免拼出非法 URL
case "$PORT" in ''|*[!0-9]*) PORT=7863 ;; esac

# ── 访问密钥：config.json 顶层 api_key（面板鉴权复用网关同一把 key）───────
KEY=""
if [ -f "$CONF" ]; then
  KEY=$(sed -n 's/.*"api_key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONF" | head -1)
fi

# ── 本机 IPv4：优先无线接口（wlan0/热点），回落有线，再回落 getprop ────────
IP=""
for i in wlan0 ap0 wlan1 swlan0 eth0; do
  V=$(ifconfig "$i" 2>/dev/null \
      | grep -oE 'inet (addr:)?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1 \
      | sed 's/^inet addr://; s/^inet //')
  case "$V" in ''|127.*) ;; *) IP="$V"; break ;; esac
done
if [ -z "$IP" ]; then
  # 兜底：部分设备/ROM 的 ifconfig 拿不到地址，用 DHCP 属性
  for P in dhcp.wlan0.ipaddress dhcp.ap0.ipaddress dhcp.eth0.ipaddress; do
    V=$(getprop "$P" 2>/dev/null)
    case "$V" in ''|0.0.0.0) ;; *) IP="$V"; break ;; esac
  done
fi
# 全部失败：仅本机可访问（面板监听 0.0.0.0，但无外部地址）
[ -n "$IP" ] || IP=127.0.0.1

# ── 运行状态 / 自启开关 / 模块版本 ─────────────────────────────────────────
if pidof wb2api >/dev/null 2>&1; then STATUS=running; else STATUS=stopped; fi
if [ -f "$PERSIST/DISABLE_AUTOSTART" ]; then AUTOSTART=off; else AUTOSTART=on; fi
VER=$(sed -n 's/^version=//p' "$MODDIR/module.prop" 2>/dev/null | head -1)

printf 'STATUS=%s\n'    "$STATUS"
printf 'AUTOSTART=%s\n' "$AUTOSTART"
printf 'IP=%s\n'        "$IP"
printf 'PORT=%s\n'      "$PORT"
printf 'URL=http://%s:%s/panel/\n' "$IP" "$PORT"
printf 'KEY=%s\n'       "$KEY"
printf 'VERSION=%s\n'   "$VER"
