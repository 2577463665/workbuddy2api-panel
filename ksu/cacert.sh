#!/system/bin/sh
# CA 根证书准备：Android 上 Go（GOOS=linux 编译）默认只找 Linux 发行版路径
#   /etc/ssl/certs/ca-certificates.crt、/etc/pki/tls/certs 等 —— Android 上一个都不存在，
# 导致一个根证书都加载不到，所有 HTTPS 请求报：
#   x509: certificate signed by unknown authority
# （Docker 里能跑，是因为镜像装了 ca-certificates 提供了 /etc/ssl/certs/ca-certificates.crt）
#
# 解决：把 Android 各证书目录里的证书拼成一个 PEM 包，供 SSL_CERT_FILE 使用；
# 同时输出目录清单供 SSL_CERT_DIR 使用（Go 会读取目录内所有文件，不要求哈希命名）。
#
# 覆盖的目录（含 Android 14+ 把证书移到 Conscrypt APEX 后的新路径）：
#   /system/etc/security/cacerts            系统根证书（传统路径）
#   /apex/com.android.conscrypt/cacerts     系统根证书（Android 14+ 实际位置）
#   /data/misc/keychain/certs-added         用户安装的证书（旧路径）
#   /data/misc/user/0/cacerts-added         用户安装的证书（现路径，如代理/MITM 的 CA）
#
# 输出（供 start.sh 解析）：
#   CACERT_DIRS=<冒号分隔的目录清单，可能含不存在的目录>
#   CACERT_FOUND=<实际存在的目录>
#   CACERT_COUNT=<拼进包里的证书数量>
MODDIR="${MODDIR:-${0%/*}}"
PERSIST=/data/adb/wb2api

CA_DIRS="/system/etc/security/cacerts:/apex/com.android.conscrypt/cacerts:/data/misc/keychain/certs-added:/data/misc/user/0/cacerts-added"

mkdir -p "$PERSIST" 2>/dev/null
OUT="$PERSIST/cacert.pem"
: > "$OUT" 2>/dev/null

n=0
found=""
OLD_IFS=$IFS
IFS=:
for d in $CA_DIRS; do
  [ -d "$d" ] || continue
  found="$found $d"
  for f in "$d"/*; do
    [ -f "$f" ] || continue
    # 只收 PEM 证书，跳过目录里可能的其它文件
    if grep -q 'BEGIN CERTIFICATE' "$f" 2>/dev/null; then
      if cat "$f" >> "$OUT" 2>/dev/null; then
        n=$((n + 1))
        printf '\n' >> "$OUT"
      fi
    fi
  done
done
IFS=$OLD_IFS

# 一张都没拿到就删掉空文件：避免把空的 SSL_CERT_FILE 交给 Go
# （Go 读到空文件不会报错，但也不会退回去扫描目录，容易白白排查半天）
if [ "$n" -eq 0 ]; then
  rm -f "$OUT" 2>/dev/null
fi

echo "CACERT_DIRS=$CA_DIRS"
echo "CACERT_FOUND=$found"
echo "CACERT_COUNT=$n"
