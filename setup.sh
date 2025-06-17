#!/bin/bash

echo ">>> TẮT TOÀN BỘ FIREWALL ĐỂ ĐẢM BẢO QEMU HOẠT ĐỘNG"

# Tắt UFW nếu có
if command -v ufw >/dev/null 2>&1; then
  echo "[+] Tắt UFW..."
  sudo ufw disable
fi

# Tắt firewalld nếu có
if systemctl list-units --type=service | grep -q firewalld; then
  echo "[+] Dừng firewalld..."
  sudo systemctl stop firewalld
  sudo systemctl disable firewalld
fi

# Flush iptables nếu có
if command -v iptables >/dev/null 2>&1; then
  echo "[+] Xóa toàn bộ rule iptables..."
  sudo iptables -F
  sudo iptables -X
  sudo iptables -t nat -F
  sudo iptables -t nat -X
  sudo iptables -t mangle -F
  sudo iptables -t mangle -X
  sudo iptables -P INPUT ACCEPT
  sudo iptables -P FORWARD ACCEPT
  sudo iptables -P OUTPUT ACCEPT
fi

# Reset nftables nếu có
if command -v nft >/dev/null 2>&1; then
  echo "[+] Reset nftables..."
  sudo nft flush ruleset
fi

echo ">>> HOÀN TẤT TẮT FIREWALL"

# Cài QEMU và công cụ liên quan
sudo apt-get update && sudo apt-get install -y qemu qemu-utils qemu-system-x86-xen qemu-system-x86

# Tạo ổ cứng ảo 32GB định dạng RAW nếu chưa tồn tại
if [ ! -f win.img ]; then
  qemu-img create -f raw win.img 32G
fi

# Kiểm tra và tải file virtio-win.iso nếu chưa có
if [ ! -f virtio-win.iso ]; then
  wget -O virtio-win.iso 'https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.215-1/virtio-win-0.1.215.iso'
else
  echo "File virtio-win.iso đã tồn tại, bỏ qua tải."
fi

# Kiểm tra và tải file win.iso nếu chưa có
if [ ! -f win.iso ]; then
  wget -O win.iso 'https://archive.org/download/en_windows_server_2022x64_dvd_/en_windows_server_2022x64_dvd_.iso'
else
  echo "File win.iso đã tồn tại, bỏ qua tải."
fi

# Chạy máy ảo Windows qua QEMU, dùng VNC cổng :9 (tức là 5909)
sudo qemu-system-x86_64 \
  -m 8G \
  -cpu EPYC \
  -boot order=d \
  -drive file=win.iso,media=cdrom \
  -drive file=win.img,format=raw,if=virtio \
  -drive file=virtio-win.iso,media=cdrom \
  -device usb-ehci,id=usb,bus=pci.0,addr=0x4 \
  -device usb-tablet \
  -vnc :9 \
  -smp cores=2
