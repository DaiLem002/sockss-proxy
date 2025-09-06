#!/bin/bash
# Proxy SOCKS5 trên EC2 với thông số tùy chỉnh bên ngoài

# Proxy mặc định (có thể override)
PORT="${PORT:-8888}"
USERNAME="${USER:-proxyuser}"
PASSWORD="${PASS:-proxypass}"

# Telegram mặc định (có thể override)
BOT_TOKEN="${BOT_TOKEN:-}"
CHAT_ID="${CHAT_ID:-}"

install_dependencies() {
  export DEBIAN_FRONTEND=noninteractive
  apt update -y
  apt install -y dante-server curl iptables
}

setup_proxy() {
  install_dependencies

  # Lấy network interface chính EC2
  IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')

  # Cấu hình Dante
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

  # Tạo user proxy
  id -u "$USERNAME" &>/dev/null || useradd -M -s /bin/false "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd

  # Khởi động proxy
  systemctl restart danted
  systemctl enable danted

  # Mở firewall EC2 (Security Group vẫn cần mở TCP PORT)
  iptables -C INPUT -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || \
    iptables -A INPUT -p tcp --dport "$PORT" -j ACCEPT
}

# Chạy proxy
setup_proxy

# Gửi thông tin proxy về Telegram nếu BOT_TOKEN và CHAT_ID tồn tại
if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    PUBLIC_IP=$(curl -s ifconfig.me)
    PROXY_INFO="$PUBLIC_IP:$PORT:$USERNAME:$PASSWORD"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$PROXY_INFO"
    echo "[INFO] Proxy đã gửi về Telegram dạng IP:PORT:USER:PASS"
fi
