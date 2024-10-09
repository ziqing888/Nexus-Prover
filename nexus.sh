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

# 配置并启动 Nexus Prover 的函数
setup_nexus_prover() {
    # 更新系统并安装必要的依赖项
    show_status "正在更新系统并安装必要的依赖项..." "progress"
    if ! sudo apt update && sudo apt upgrade -y && sudo apt install -y curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip; then
        show_status "更新系统或安装依赖项失败。" "error"
        exit 1
    fi

    # 安装 Rust
    show_status "正在安装 Rust..." "progress"
    if ! curl https://sh.rustup.rs -sSf | sh -s -- -y; then
        show_status "Rust 安装失败。" "error"
        exit 1
    fi

    # 将 Rust 添加到系统路径
    show_status "将 Rust 添加到系统路径..." "progress"
    source $HOME/.cargo/env
    export PATH="$HOME/.cargo/bin:$PATH"

    # 更新 Rust
    show_status "更新 Rust..." "progress"
    if ! rustup update; then
        show_status "Rust 更新失败。" "error"
        exit 1
    fi
    rustc --version

    # 确保安装了 Git
    if ! command -v git &> /dev/null; then
        show_status "Git 未安装，正在安装 Git..." "progress"
        if ! sudo apt install git -y; then
            show_status "Git 安装失败。" "error"
            exit 1
        fi
    else
        show_status "Git 已经安装。" "success"
    fi

    # 删除旧的 Nexus API 仓库（如果存在）
    if [ -d "$HOME/network-api" ]; then
        show_status "正在删除旧的 Nexus API 仓库..." "progress"
        rm -rf "$HOME/network-api"
    fi

    # 克隆新的 Nexus API 仓库
    show_status "正在克隆 Nexus-XYZ 网络 API 仓库..." "progress"
    if ! git clone https://github.com/nexus-xyz/network-api.git "$HOME/network-api"; then
        show_status "克隆 Nexus API 仓库失败。" "error"
        exit 1
    fi

    # 切换到工作目录
    cd $HOME/network-api/clients/cli

    # 设置 Nexus Prover 的 systemd 服务
    SERVICE_NAME="nexus"
    SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

    show_status "创建 Nexus Prover 的 systemd 服务..." "progress"
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
        show_status "创建 systemd 服务文件失败。" "error"
        exit 1
    fi

    show_status "重新加载 systemd 配置并启动 Nexus Prover 服务..." "progress"
    if ! sudo systemctl daemon-reload && sudo systemctl start $SERVICE_NAME && sudo systemctl enable $SERVICE_NAME; then
        show_status "Nexus Prover 服务启动失败。" "error"
        exit 1
    fi

    show_status "Nexus Prover 服务已成功启动并配置为自动启动。" "success"
}

# 检查 Nexus Prover 服务状态的函数
check_service_status() {
    SERVICE_NAME="nexus"
    show_status "正在检查 Nexus Prover 服务状态..." "progress"
    sudo systemctl status $SERVICE_NAME --no-pager
}

# 检查 Nexus Prover 服务日志的函数
check_service_logs() {
    SERVICE_NAME="nexus"
    show_status "正在查看 Nexus Prover 服务日志..." "progress"
    sudo journalctl -u $SERVICE_NAME -f -n 50
}

# 主菜单函数
main_menu() {
    while true; do
        echo -e "${PINK}${BOLD}该脚本由子清编写，推特 @qklxsqf，免费开源，请勿相信收费${NORMAL}\n"
        echo -e "${PINK}${BOLD}=== Nexus Prover 安装和管理工具 ===${NORMAL}"
        echo "1. 配置并启动 Nexus Prover"
        echo "2. 检查状态"
        echo "3. 查看日志"
        echo "4. 退出"
        read -p "请选择一个选项 (1-4): " choice

        case $choice in
            1) setup_nexus_prover ;;
            2) check_service_status ;;
            3) check_service_logs ;;
            4) echo "退出脚本。再见！"; exit 0 ;;
            *) echo "无效选项，请重新输入。";;
        esac
    done
}

# 启动主菜单
main_menu
