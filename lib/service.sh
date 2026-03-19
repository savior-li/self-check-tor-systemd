#!/bin/bash
#===============================================================================
# Tor Manager - Systemd Service Module
# systemd 服务模块：服务文件生成与部署、服务管理
#===============================================================================

# 防止重复 source
[[ -n "${_SERVICE_SH_LOADED:-}" ]] && return 0
readonly _SERVICE_SH_LOADED=1

# 加载公共函数
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/health.sh"

#-------------------------------------------------------------------------------
# 颜色变量（根据 ENABLE_COLOR 设置）
#-------------------------------------------------------------------------------
if [[ "${ENABLE_COLOR}" == "true" ]]; then
    C_WHITE="${COLOR_WHITE}"
    C_CYAN="${COLOR_CYAN}"
    C_GREEN="${COLOR_GREEN}"
    C_YELLOW="${COLOR_YELLOW}"
    C_RED="${COLOR_RED}"
    C_RESET="${COLOR_RESET}"
else
    C_WHITE=""
    C_CYAN=""
    C_GREEN=""
    C_YELLOW=""
    C_RED=""
    C_RESET=""
fi

#-------------------------------------------------------------------------------
# 常量定义
#-------------------------------------------------------------------------------
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_NAME="tor-manager"
SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}.service"
HEALTH_SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}-health.service"
readonly HEALTH_TIMER_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}-health.timer"

#-------------------------------------------------------------------------------
# 服务文件生成
#-------------------------------------------------------------------------------
# 生成 Tor 主服务文件
generate_tor_service() {
    local socks_port=$(torrc_get "SocksPort" "9050")
    local control_port=$(torrc_get "ControlPort" "9051")
    
    cat << EOF
[Unit]
Description=Tor Manager - Tor Proxy Service
Documentation=https://www.torproject.org/
After=network-online.target nss-lookup.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${TOR_BIN} -f ${TORRC_PATH}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=5
TimeoutStartSec=120
TimeoutStopSec=30

# 环境变量
Environment=TOR_SOCKS_PORT=${socks_port}
Environment=TOR_CONTROL_PORT=${control_port}
Environment=HOME=${TOR_DATA_DIR}

# 资源限制
LimitNOFILE=65535
LimitNPROC=512

# PID 文件
PIDFile=${RUN_DIR}/tor.pid

[Install]
WantedBy=multi-user.target
EOF
}

# 生成健康检测服务文件
generate_health_service() {
    local socks_port=$(torrc_get "SocksPort" "9050")
    local interval=${1:-300}
    
    cat << EOF
[Unit]
Description=Tor Manager - Health Check Service
After=network.target tor-manager.service
Requires=tor-manager.service

[Service]
Type=simple
User=root
ExecStart=${SCRIPT_DIR}/tor-manager.sh check --continuous --interval ${interval}
Restart=on-failure
RestartSec=30
TimeoutStopSec=10

# 安全加固
NoNewPrivileges=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
}

# 生成健康检测定时器文件
generate_health_timer() {
    local interval=${1:-5m}
    
    cat << EOF
[Unit]
Description=Tor Manager - Health Check Timer
Requires=tor-manager-health.service

[Timer]
OnBootSec=1min
OnUnitActiveSec=${interval}
Unit=tor-manager-health.service

[Install]
WantedBy=timers.target
EOF
}

# 生成日志轮转配置
generate_logrotate_config() {
    cat << EOF
# Tor Manager logrotate configuration
${LOG_DIR}/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}

${TOR_LOG_DIR}/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 tor tor
}
EOF
}

#-------------------------------------------------------------------------------
# 服务部署函数
#-------------------------------------------------------------------------------
# 部署服务文件
deploy_service_file() {
    local name=$1
    local content=$2
    local target_dir=${3:-${SYSTEMD_DIR}}
    
    local target_file="${target_dir}/${name}"
    
    # 备份现有文件
    if [[ -f "${target_file}" ]]; then
        cp "${target_file}" "${target_file}.bak"
    fi
    
    echo "${content}" > "${target_file}"
    chmod 644 "${target_file}"
    
    log_info "已部署: ${target_file}"
}

# 安装所有服务
install_services() {
    log_info "安装 systemd 服务..."
    
    require_root
    
    # 检查 Tor 是否存在
    if [[ ! -x "${TOR_BIN}" ]]; then
        log_error "Tor 可执行文件不存在: ${TOR_BIN}"
        log_error "请确保当前目录下存在 tor/ 目录且包含 tor 可执行文件"
        return 1
    fi
    
    # 检查必要目录
    if [[ ! -d "${TOR_INSTALL_DIR}" ]]; then
        log_error "Tor 目录不存在: ${TOR_INSTALL_DIR}"
        return 1
    fi
    
    if [[ ! -f "${TORRC_PATH}" ]]; then
        log_warn "配置文件不存在，将创建默认配置: ${TORRC_PATH}"
    fi
    
    # 创建运行目录
    mkdir -p "${RUN_DIR}"
    mkdir -p "${TOR_DATA_DIR}"
    mkdir -p "${TOR_LOG_DIR}"
    
    # 设置权限
    if id tor &>/dev/null; then
        chown -R tor:tor "${TOR_DATA_DIR}"
        chown -R tor:tor "${TOR_LOG_DIR}"
    fi
    
    # 部署主服务
    deploy_service_file "${SERVICE_NAME}.service" "$(generate_tor_service)"
    
    # 部署健康检测服务（可选）
    deploy_service_file "${SERVICE_NAME}-health.service" "$(generate_health_service 60)"
    deploy_service_file "${SERVICE_NAME}-health.timer" "$(generate_health_timer 1m)"
    
    # 部署日志轮转配置
    deploy_service_file "tor-manager" "$(generate_logrotate_config)" "/etc/logrotate.d"
    
    # 重载 systemd
    systemctl daemon-reload
    
    log_info "服务安装完成"
    log_info "使用 'systemctl enable ${SERVICE_NAME}' 设置开机自启"
    log_info "使用 'systemctl start ${SERVICE_NAME}' 启动服务"
}

# 检查 systemd 服务路径是否需要更新
check_service_path() {
    # 如果服务文件不存在，跳过检查
    [[ ! -f "${SERVICE_FILE}" ]] && return 0
    
    # 检查服务文件中的路径是否与当前路径一致
    local service_content=$(cat "${SERVICE_FILE}")
    local current_path="${SCRIPT_DIR}"
    
    if ! echo "${service_content}" | grep -q "${current_path}"; then
        log_warn "检测到程序目录已移动，systemd 服务路径需要更新"
        log_warn "请运行: ${SCRIPT_NAME} service install"
        return 1
    fi
    
    return 0
}

# 卸载服务
uninstall_services() {
    log_info "卸载 systemd 服务..."
    
    require_root
    
    # 停止并禁用服务
    for svc in "${SERVICE_NAME}.service" "${SERVICE_NAME}-health.service" "${SERVICE_NAME}-health.timer"; do
        if systemctl is-enabled "${svc}" &>/dev/null; then
            systemctl disable "${svc}"
        fi
        if systemctl is-active "${svc}" &>/dev/null; then
            systemctl stop "${svc}"
        fi
    done
    
    # 删除服务文件
    rm -f "${SERVICE_FILE}"
    rm -f "${HEALTH_SERVICE_FILE}"
    rm -f "${HEALTH_TIMER_FILE}"
    rm -f "/etc/logrotate.d/tor-manager"
    
    # 重载 systemd
    systemctl daemon-reload
    
    log_info "服务已卸载"
}

#-------------------------------------------------------------------------------
# 服务管理函数
#-------------------------------------------------------------------------------
# 启动服务
service_start() {
    log_info "启动 Tor 服务..."
    
    require_root
    
    # 检查是否已在运行
    if is_tor_running; then
        log_warn "Tor 已在运行"
        return 0
    fi
    
    # 检查服务文件是否存在
    if [[ -f "${SERVICE_FILE}" ]]; then
        # 优先使用 systemd 服务启动
        systemctl start "${SERVICE_NAME}" 2>/dev/null
        sleep 3
        
        if is_tor_running; then
            wait_for_bootstrap 120
            log_info "Tor 服务已启动"
            return 0
        fi
        log_warn "systemd 启动失败，尝试手动启动"
    fi
    
    # 使用增强的启动函数
    if start_tor_safely 120; then
        return 0
    else
        log_error "Tor 服务启动失败"
        return 1
    fi
}

# 停止服务
service_stop() {
    log_info "停止 Tor 服务..."
    
    require_root
    
    # 使用增强的停止函数（支持多种运行方式）
    if stop_tor_safely 30; then
        return 0
    else
        log_error "Tor 服务停止失败"
        return 1
    fi
}

# 重启服务
service_restart() {
    log_info "重启 Tor 服务..."
    
    require_root
    
    service_stop
    sleep 2
    service_start
}

# 获取服务状态
service_status() {
    echo -e "${C_WHITE}=== Tor 服务状态 ===${C_RESET}"
    
    # systemd 服务状态
    if [[ -f "${SERVICE_FILE}" ]]; then
        echo -e "\n${C_CYAN}[Systemd 服务]${C_RESET}"
        systemctl status "${SERVICE_NAME}" --no-pager 2>/dev/null || echo "服务未运行"
        
        # 开机自启状态
        local enabled=""
        if systemctl is-enabled "${SERVICE_NAME}" &>/dev/null; then
            enabled="${C_GREEN}已启用${C_RESET}"
        else
            enabled="${C_YELLOW}未启用${C_RESET}"
        fi
        echo -e "\n开机自启: ${enabled}"
    else
        echo -e "\n${C_YELLOW}Systemd 服务未安装${C_RESET}"
    fi
    
    # 进程状态
    echo -e "\n${C_CYAN}[进程状态]${C_RESET}"
    if is_tor_running; then
        local pid=$(get_tor_pid)
        echo -e "  PID: ${C_GREEN}${pid}${C_RESET}"
        echo "  运行时间: $(ps -o etime= -p ${pid} 2>/dev/null || echo "未知")"
        echo "  内存使用: $(ps -o rss= -p ${pid} 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')"
        echo "  CPU 使用: $(ps -o %cpu= -p ${pid} 2>/dev/null)%"
    else
        echo -e "  ${C_RED}未运行${C_RESET}"
    fi
    
    # 端口状态
    echo -e "\n${C_CYAN}[端口状态]${C_RESET}"
    local socks_port=$(get_socks_port)
    local control_port=$(get_control_port)
    
    if ss -tlnp 2>/dev/null | grep -q ":${socks_port} "; then
        echo -e "  SOCKS (${socks_port}): ${C_GREEN}监听中${C_RESET}"
    else
        echo -e "  SOCKS (${socks_port}): ${C_RED}未监听${C_RESET}"
    fi
    
    if ss -tlnp 2>/dev/null | grep -q ":${control_port} "; then
        echo -e "  Control (${control_port}): ${C_GREEN}监听中${C_RESET}"
    else
        echo -e "  Control (${control_port}): ${C_YELLOW}未监听${C_RESET}"
    fi
}

# 启用开机自启
service_enable() {
    log_info "启用 Tor 开机自启..."
    
    require_root
    
    # 安装服务（如果未安装）
    if [[ ! -f "${SERVICE_FILE}" ]]; then
        install_services
    fi
    
    systemctl enable "${SERVICE_NAME}"
    
    log_info "已启用开机自启"
}

# 禁用开机自启
service_disable() {
    log_info "禁用 Tor 开机自启..."
    
    require_root
    
    systemctl disable "${SERVICE_NAME}"
    
    log_info "已禁用开机自启"
}

#-------------------------------------------------------------------------------
# 健康检测服务管理
#-------------------------------------------------------------------------------
# 启用健康检测
enable_health_check() {
    local interval=${1:-300}
    
    log_info "启用健康检测服务..."
    
    require_root
    
    # 更新服务文件（使用新间隔）
    deploy_service_file "${SERVICE_NAME}-health.service" "$(generate_health_service ${interval})"
    deploy_service_file "${SERVICE_NAME}-health.timer" "$(generate_health_timer ${interval}s)"
    
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}-health.timer"
    systemctl start "${SERVICE_NAME}-health.timer"
    
    log_info "健康检测服务已启用 (间隔: ${interval}s)"
}

# 禁用健康检测
disable_health_check() {
    log_info "禁用健康检测服务..."
    
    require_root
    
    systemctl stop "${SERVICE_NAME}-health.timer" 2>/dev/null || true
    systemctl stop "${SERVICE_NAME}-health.service" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}-health.timer" 2>/dev/null || true
    
    log_info "健康检测服务已禁用"
}

#-------------------------------------------------------------------------------
# 日志管理
#-------------------------------------------------------------------------------
# 查看日志
view_logs() {
    local follow=false
    local lines=50
    local unit=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --follow|-f)
                follow=true
                shift
                ;;
            --lines|-n)
                lines=$2
                shift 2
                ;;
            --unit|-u)
                unit=$2
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    unit=${unit:-${SERVICE_NAME}}
    
    if ${follow}; then
        journalctl -u "${unit}" -f
    else
        journalctl -u "${unit}" --no-pager -n "${lines}"
    fi
}

# 查看健康检测日志
view_health_logs() {
    local follow=${1:-false}
    
    if [[ -f "${CHECK_LOG_FILE}" ]]; then
        if ${follow}; then
            tail -f "${CHECK_LOG_FILE}"
        else
            tail -50 "${CHECK_LOG_FILE}"
        fi
    else
        log_warn "健康检测日志不存在"
    fi
}

#-------------------------------------------------------------------------------
# 主命令函数
#-------------------------------------------------------------------------------
cmd_service() {
    local action=$1
    shift
    
    case "${action}" in
        start)
            service_start
            ;;
        stop)
            service_stop
            ;;
        restart)
            service_restart
            ;;
        status)
            service_status
            ;;
        enable)
            service_enable
            ;;
        disable)
            service_disable
            ;;
        install)
            install_services
            ;;
        uninstall)
            uninstall_services
            ;;
        health-enable)
            enable_health_check "$@"
            ;;
        health-disable)
            disable_health_check
            ;;
        logs)
            view_logs "$@"
            ;;
        *)
            log_error "未知服务操作: ${action}"
            echo "可用操作: start|stop|restart|status|enable|disable|install|uninstall|health-enable|health-disable|logs"
            return 1
            ;;
    esac
}

