#!/bin/bash

# 定义颜色和样式
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
PINK='\033[1;35m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'

# 状态显示函数，用于不同类型的消息
show_status() {
    local message="$1"
    local status="$2"
    case $status in
        "error")
            echo -e "${RED}${BOLD}🚫 出错: ${message}${NORMAL}"
            ;;
        "progress")
            echo -e "${YELLOW}${BOLD}🔄 进行中: ${message}${NORMAL}"
            ;;
        "success")
            echo -e "${GREEN}${BOLD}🎉 成功: ${message}${NORMAL}"
            ;;
        *)
            echo -e "${PINK}${BOLD}${message}${NORMAL}"
            ;;
    esac
}

SERVICE_NAME="nexus"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

# 更新并升级系统
show_status "更新并升级系统..." "progress"
if ! sudo apt update && sudo apt upgrade -y; then
    show_status "系统更新失败。" "error"
    exit 1
fi

# 安装依赖包
show_status "安装依赖包..." "progress"
if ! sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev; then
    show_status "依赖包安装失败。" "error"
    exit 1
fi

# 安装 Rust
show_status "正在安装 Rust..." "progress"
if ! source <(wget -O - https://raw.githubusercontent.com/zunxbt/installation/main/rust.sh); then
    show_status "Rust 安装失败。" "error"
    exit 1
fi

# 添加 Rust 到路径并更新
show_status "配置 Rust 环境..." "progress"
source $HOME/.cargo/env
export PATH="$HOME/.cargo/bin:$PATH"
if ! rustup update; then
    show_status "Rust 更新失败。" "error"
    exit 1
fi
show_status "Rust 版本: $(rustc --version)" "success"

# 检查 Git 是否已安装
if ! command -v git &> /dev/null; then
    show_status "Git 未安装。正在安装 Git..." "progress"
    if ! sudo apt install git -y; then
        show_status "Git 安装失败。" "error"
        exit 1
    fi
else
    show_status "Git 已安装。" "success"
fi

# 删除现有的 network-api 目录
if [ -d "$HOME/network-api" ]; then
    show_status "正在删除现有的 network-api 仓库..." "progress"
    rm -rf "$HOME/network-api"
fi

# 克隆 Nexus-XYZ network API 仓库
show_status "正在克隆 Nexus-XYZ network API 仓库..." "progress"
if ! git clone https://github.com/nexus-xyz/network-api.git "$HOME/network-api"; then
    show_status "仓库克隆失败。" "error"
    exit 1
fi

# 切换到 CLI 目录
cd $HOME/network-api/clients/cli

# 安装所需的依赖项
show_status "正在安装所需依赖项..." "progress"
if ! sudo apt install pkg-config libssl-dev -y; then
    show_status "依赖项安装失败。" "error"
    exit 1
fi

# 检查 nexus.service 是否在运行
if systemctl is-active --quiet nexus.service; then
    show_status "nexus.service 正在运行。停止并禁用它..." "progress"
    sudo systemctl stop nexus.service
    sudo systemctl disable nexus.service
else
    show_status "nexus.service 未在运行。" "success"
fi

# 创建 systemd 服务
show_status "正在创建 systemd 服务..." "progress"
if ! sudo bash -c "cat > $SERVICE_FILE <<EOF
[Unit]
Description=Nexus XYZ Prover Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/network-api/clients/cli
Environment=NONINTERACTIVE=1
ExecStart=$HOME/.cargo/bin/cargo run --release --bin prover -- beta.orchestrator.nexus.xyz
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF"; then
    show_status "systemd 服务文件创建失败。" "error"
    exit 1
fi

# 重新加载 systemd 并启动服务
show_status "重新加载 systemd 并启动服务..." "progress"
if ! sudo systemctl daemon-reload; then
    show_status "systemd 重新加载失败。" "error"
    exit 1
fi

if ! sudo systemctl start $SERVICE_NAME.service; then
    show_status "服务启动失败。" "error"
    exit 1
fi

if ! sudo systemctl enable $SERVICE_NAME.service; then
    show_status "服务启用失败。" "error"
    exit 1
fi

# 显示服务状态
show_status "服务状态:" "progress"
if ! sudo systemctl status $SERVICE_NAME.service; then
    show_status "获取服务状态失败。" "error"
fi

show_status "Nexus Prover 安装和服务设置完成！" "success"
