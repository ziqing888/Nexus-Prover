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

# 显示菜单
show_menu() {
    echo "=========================="
    echo " Nexus XYZ Prover 菜单"
    echo "=========================="
    echo "1. 安装依赖"
    echo "2. 安装 Rust"
    echo "3. 设置 Nexus 服务"
    echo "4. 启动 Nexus 服务"
    echo "5. 检查 Nexus 服务状态"
    echo "6. 查看 Nexus 服务日志"
    echo "7. 退出"
    echo "=========================="
}

# 添加一个函数以避免重复刷新菜单
wait_for_input() {
    echo -n "请输入选项 [1-7]: "
}

# 安装依赖
install_dependencies() {
    show_status "更新并升级系统..." "progress"
    if ! sudo apt update && sudo apt upgrade -y; then
        show_status "系统更新失败。" "error"
        exit 1
    fi

    show_status "安装依赖包..." "progress"
    if ! sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip; then
        show_status "依赖包安装失败。" "error"
        exit 1
    fi
    show_status "依赖包安装完成。" "success"
}

# 安装 Rust
install_rust() {
    if command -v rustc >/dev/null 2>&1; then
        show_status "Rust 已安装，正在更新..." "progress"
        if ! rustup update; then
            show_status "Rust 更新失败。" "error"
            exit 1
        fi
    else
        show_status "正在安装 Rust..." "progress"
        if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
            show_status "Rust 安装失败。" "error"
            exit 1
        fi
        source $HOME/.cargo/env
    fi
    show_status "Rust 版本: $(rustc --version)" "success"
}

# 设置 Nexus 服务
setup_nexus_service() {
    show_status "正在创建 Nexus XYZ 服务..." "progress"
    if [ -d "$HOME/network-api" ]; then
        show_status "正在删除现有的 network-api 仓库..." "progress"
        rm -rf "$HOME/network-api"
    fi

    show_status "正在克隆 Nexus-XYZ network API 仓库..." "progress"
    if ! git clone https://github.com/nexus-xyz/network-api.git "$HOME/network-api"; then
        show_status "仓库克隆失败，检查网络连接或 GitHub 仓库地址是否正确。" "error"
        exit 1
    fi

    cd "$HOME/network-api/clients/cli" || { show_status "目录切换失败。" "error"; exit 1; }

    show_status "正在安装所需依赖项..." "progress"
    if ! sudo apt install pkg-config libssl-dev -y; then
        show_status "依赖项安装失败。" "error"
        exit 1
    fi

    show_status "正在编译 Nexus Prover..." "progress"
    if ! cargo build --release --bin prover; then
        show_status "编译失败。" "error"
        exit 1
    fi

    show_status "正在创建 systemd 服务..." "progress"
    sudo bash -c "cat > $SERVICE_FILE <<EOF
[Unit]
Description=Nexus XYZ Prover Service
After=network.target

[Service]
User=$(whoami)
WorkingDirectory=$HOME/network-api/clients/cli
Environment=NONINTERACTIVE=1
Environment=PATH=/usr/local/bin:/usr/bin:/bin:$HOME/.cargo/bin
ExecStart=$HOME/network-api/clients/cli/target/release/prover beta.orchestrator.nexus.xyz
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF"

    if [ $? -ne 0 ]; then
        show_status "systemd 服务文件创建失败。" "error"
        exit 1
    fi

    show_status "Nexus 服务设置完成。" "success"
}

# 启动 Nexus 服务
start_nexus_service() {
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

    show_status "Nexus 服务已启动并已启用。" "success"
}

# 检查 Nexus 服务状态
check_nexus_status() {
    show_status "服务状态:" "progress"
    sudo systemctl status $SERVICE_NAME.service
}

# 查看 Nexus 服务日志
view_nexus_logs() {
    show_status "正在显示 Nexus 服务日志..." "progress"
    sudo journalctl -u $SERVICE_NAME.service -f
}

# 主程序循环
while true; do
    show_menu
    wait_for_input
    read -r choice
    case $choice in
        1) install_dependencies ;;
        2) install_rust ;;
        3) setup_nexus_service ;;
        4) start_nexus_service ;;
        5) check_nexus_status ;;
        6) view_nexus_logs ;;
        7) echo "退出程序。再见！"; exit 0 ;;
        *) echo "无效选项，请重新输入。"; sleep 1 ;;
    esac
done
