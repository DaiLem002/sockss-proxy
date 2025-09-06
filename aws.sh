#!/bin/bash
# Proxy SOCKS5 tối ưu cho EC2
# Tùy chỉnh user/pass/port và Telegram ngoài script

# ------------------------
# Cấu hình proxy (có thể override)
PORT="${PORT:-8888}"
USERNAME="${USER:-proxyuser}"
PASSWORD="${PASS:-proxypass}"

# ------------------------
# Telegram (có thể override)
BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

# ------------------------
install_dependencies() {
  export DEBIAN_FRONTEND=noninteractive
  apt update -y
  apt install -y dante-server curl iptables
}

setup_proxy() {
  install_dependencies

  # Lấy network interface chính EC2
  IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

  # Tạo file cấu hình Dante
  cat >/etc/danted.conf <<EOF
logoutput: syslog
internal: 0.0.0.0 port = $PORT
external: $IFACE
socksmethod: username
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error
}
EOF

  # Tạo user proxy nếu chưa tồn tại
  id -u "$USERNAME" &>/dev/null || useradd -M -s /bin/false "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd

  # Khởi động và bật Dante
  systemctl restart danted
  systemctl enable danted

  # Mở port cho firewall EC2 (iptables)
  iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || \
    iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
}

# ------------------------
# Chạy proxy
setup_proxy

# ------------------------
# Gửi proxy về Telegram nếu có BOT_TOKEN và CHAT_ID
if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    PUBLIC_IP=$(curl -s ifconfig.me)
    PROXY_INFO="$PUBLIC_IP:$PORT:$USERNAME:$PASSWORD"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$PROXY_INFO"
    echo "[INFO] Proxy đã gửi về Telegram dưới dạng IP:PORT:USER:PASS"
else
    echo "[INFO] BOT_TOKEN hoặc CHAT_ID chưa được cung cấp. Proxy vẫn chạy."
fi
