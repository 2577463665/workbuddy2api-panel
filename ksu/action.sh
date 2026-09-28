#!/system/bin/sh
# KernelSU / Magisk 里点击模块「操作」按钮时执行：展示面板地址与访问密钥。
# 纯展示——启停与自启开关等管理操作放在 WebUI（KernelSU）里做，这里只回答
# 用户最高频的两个问题：「面板在哪」和「密钥是什么」。
MODDIR="${0%/*}"
export MODDIR
PERSIST=/data/adb/wb2api

# 显式用 sh 调用（不依赖可执行位）：权限/SELinux 上下文异常时仍能工作，
# 也避免直接执行失败时静默输出空白，让用户无从排查。
INFO=$(sh "$MODDIR/info.sh" 2>/dev/null)
if [ -z "$INFO" ]; then
  echo "读取模块信息失败（info.sh 未能执行）"
  echo
  echo "请确认模块完整安装；仍不行可查看日志："
  echo "  $PERSIST/wb2api.log"
  echo "或用文件管理器打开 /sdcard/wb2api-info.txt"
  exit 1
fi
get() { printf '%s\n' "$INFO" | sed -n "s/^$1=//p" | head -1; }

STATUS=$(get STATUS)
AUTOSTART=$(get AUTOSTART)
URL=$(get URL)
KEY=$(get KEY)
VER=$(get VERSION)

case "$STATUS" in
  running) ST="运行中" ;;
  *)       ST="未运行（可在 KernelSU 里打开本模块 WebUI 启动）" ;;
esac
case "$AUTOSTART" in
  on) AS="已开启" ;;
  *)  AS="已关闭" ;;
esac

echo "WorkBuddy2API 面板 ${VER}"
echo "服务状态：${ST}"
echo "开机自启：${AS}"
echo
echo "──── 面板地址 ────"
echo "${URL}"
echo
echo "──── 访问密钥 ────"
if [ -n "$KEY" ]; then
  echo "${KEY}"
else
  echo "（尚未生成，服务首次启动后自动创建）"
fi
echo
echo "浏览器打开上面的地址，粘贴密钥即可进入面板；"
echo "密钥只需输入一次，此后浏览器会记住。"
echo
echo "手机与电脑在同一 WiFi 下均可访问；换网络后 IP 会变，重新点这里查看。"
