#!/bin/bash
#===============================================================================
# Tor Manager - Health Check Module
# 连通性检测模块：SOCKS 代理检测、自动重启、状态记录
#===============================================================================

# 防止重复 source
[[ -n "${_HEALTH_SH_LOADED:-}" ]] && return 0
readonly _HEALTH_SH_LOADED=1

# 加载公共函数
source "${LIB_DIR}/common.sh"

# 加载配置模块（需要 get_socks_port, get_control_port 等函数）
source "${LIB_DIR}/config.sh"

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
CHECK_LOG_FILE="${LOG_DIR}/health.log"
CHECK_STATUS_FILE="${RUN_DIR}/health.status"
CHECK_HISTORY_FILE="${VAR_DIR}/health_history.csv"

# 检测 URL 列表
CHECK_URLS=(
    "https://check.torproject.org/api/ip"
    "https://torproject.org"
    "https://bridges.torproject.org"
)

#-------------------------------------------------------------------------------
# 健康检测日志函数
#-------------------------------------------------------------------------------
# 写入健康检测日志
health_log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 确保日志目录存在
    mkdir -p "$(dirname "${CHECK_LOG_FILE}")"
    
    # 写入 health.log
    echo "[${timestamp}] [${level}] ${message}" >> "${CHECK_LOG_FILE}"
    
    # 同时输出到标准日志
    case ${level} in
        INFO)  log_info "${message}" ;;
        WARN)  log_warn "${message}" ;;
        ERROR) log_error "${message}" ;;
        DEBUG) log_debug "${message}" ;;
    esac
}

#-------------------------------------------------------------------------------

# 等待 Tor Bootstrap 完成
wait_for_bootstrap() {
    local timeout=${1:-120}
    local socks_port=$(get_socks_port)
    local start_time=$(date +%s)
    
    log_info "等待 Tor 启动 (超时: ${timeout}秒)..."
    
    # 首先等待 SOCKS 端口监听
    while ! ss -tln 2>/dev/null | grep -q ":${socks_port}"; do
        local elapsed=$(($(date +%s) - start_time))
        if [[ ${elapsed} -ge ${timeout} ]]; then
            log_error "等待 SOCKS 端口超时"
            return 1
        fi
        sleep 1
    done
    
    log_debug "SOCKS 端口 ${socks_port} 已监听"
    
    # 然后尝试通过 Tor 连接检测 URL
    local check_url="https://check.torproject.org/api/ip"
    local remaining_timeout=$((timeout - ($(date +%s) - start_time)))
    
    while [[ ${remaining_timeout} -gt 0 ]]; do
        local response
        response=$(curl -s -S \
            --socks5-hostname "127.0.0.1:${socks_port}" \
            --connect-timeout 10 \
            --max-time 10 \
            "${check_url}" 2>&1)
        
        if [[ $? -eq 0 ]] && echo "${response}" | grep -q '"IsTor"\s*:\s*true'; then
            local ip=$(echo "${response}" | grep -oP '"IP"\s*:\s*"\K[^"]+')
            log_info "Tor 已就绪 (IP: ${ip})"
            return 0
        fi
        
        sleep 2
        remaining_timeout=$((timeout - ($(date +%s) - start_time)))
    done
    
    log_error "等待 Tor Bootstrap 超时"
    return 1
}

# 检测函数
#-------------------------------------------------------------------------------
# 通过 SOCKS5 代理检测连接
check_tor_connection() {
    local socks_port=$1
    local timeout=${2:-30}
    local check_url=$3
    
    # 默认使用第一个检测 URL
    check_url=${check_url:-${CHECK_URLS[0]}}
    
    log_debug "检测连接: ${check_url} (SOCKS: ${socks_port})"
    
    # 使用 curl 通过 SOCKS5 代理连接
    local response
    local exit_code
    
    response=$(curl -s -S \
        --socks5-hostname "127.0.0.1:${socks_port}" \
        --connect-timeout "${timeout}" \
        --max-time "${timeout}" \
        -H "User-Agent: Tor-Manager/1.0" \
        "${check_url}" 2>&1)
    
    exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]]; then
        # 检查是否真的是 Tor 连接
        if echo "${response}" | grep -qi "tor"; then
            return 0
        else
            log_warn "连接成功但响应异常"
            return 2
        fi
    else
        log_debug "curl 退出码: ${exit_code}, 错误: ${response}"
        return 1
    fi
}

# 检测 Tor 是否在使用
check_tor_in_use() {
    local socks_port=$1
    local timeout=${2:-10}
    
    # 访问 Tor 检测 API
    local api_url="https://check.torproject.org/api/ip"
    
    local response
    response=$(curl -s -S \
        --socks5-hostname "127.0.0.1:${socks_port}" \
        --connect-timeout "${timeout}" \
        --max-time "${timeout}" \
        "${api_url}" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        # 解析 JSON 响应
        local is_tor=$(echo "${response}" | grep -o '"IsTor"\s*:\s*true' 2>/dev/null)
        
        if [[ -n "${is_tor}" ]]; then
            # 提取 IP
            local ip=$(echo "${response}" | grep -oP '"IP"\s*:\s*"\K[^"]+')
            echo "true|${ip}"
            return 0
        else
            echo "false|not using tor"
            return 1
        fi
    fi
    
    echo "false|connection failed"
    return 1
}

# 获取当前出口节点信息
get_exit_node_info() {
    local socks_port=$1
    
    local api_url="https://check.torproject.org/api/ip"
    
    curl -s \
        --socks5-hostname "127.0.0.1:${socks_port}" \
        --connect-timeout 10 \
        --max-time 10 \
        "${api_url}" 2>/dev/null
}

# 检测多个 URL
check_multiple_urls() {
    local socks_port=$1
    local timeout=${2:-15}
    
    local success_count=0
    local total=${#CHECK_URLS[@]}
    
    for url in "${CHECK_URLS[@]}"; do
        log_debug "检测 URL: ${url}"
        
        if curl -s -S \
            --socks5-hostname "127.0.0.1:${socks_port}" \
            --connect-timeout "${timeout}" \
            --max-time "${timeout}" \
            -o /dev/null \
            "${url}" 2>/dev/null; then
            ((success_count++)) || true
        fi
    done
    
    echo "${success_count}/${total}"
    
    [[ ${success_count} -ge $((total / 2)) ]]
}

#-------------------------------------------------------------------------------
# 状态记录函数
#-------------------------------------------------------------------------------
# 记录检测结果
record_check_result() {
    local status=$1
    local message=$2
    local response_time=$3
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 写入状态文件
    cat > "${CHECK_STATUS_FILE}" << EOF
timestamp=${timestamp}
status=${status}
message=${message}
response_time=${response_time}
EOF
    
    # 写入健康检测日志
    local level="INFO"
    [[ "${status}" == "failed" ]] && level="WARN"
    
    # 确保日志目录存在
    mkdir -p "$(dirname "${CHECK_LOG_FILE}")"
    
    # 写入 health.log
    echo "[${timestamp}] [${level}] ${status}: ${message} (${response_time}ms)" >> "${CHECK_LOG_FILE}"
    
    # 追加到历史记录
    echo "${timestamp},${status},${message},${response_time}" >> "${CHECK_HISTORY_FILE}"
    
    # 清理旧记录（保留最近 1000 条）
    if [[ -f "${CHECK_HISTORY_FILE}" ]]; then
        tail -1000 "${CHECK_HISTORY_FILE}" > "${CHECK_HISTORY_FILE}.tmp"
        mv "${CHECK_HISTORY_FILE}.tmp" "${CHECK_HISTORY_FILE}"
    fi
}

# 获取上次检测结果
get_last_check_status() {
    if [[ -f "${CHECK_STATUS_FILE}" ]]; then
        source "${CHECK_STATUS_FILE}"
        echo "时间: ${timestamp}"
        echo "状态: ${status}"
        echo "信息: ${message}"
        echo "响应时间: ${response_time}ms"
    else
        echo "无检测记录"
    fi
}

# 获取历史统计
get_check_statistics() {
    local hours=${1:-24}
    
    if [[ ! -f "${CHECK_HISTORY_FILE}" ]]; then
        echo "无历史记录"
        return 0
    fi
    
    local total=$(wc -l < "${CHECK_HISTORY_FILE}")
    local success=$(grep -c ",success," "${CHECK_HISTORY_FILE}" 2>/dev/null || echo 0)
    local failed=$(grep -c ",failed," "${CHECK_HISTORY_FILE}" 2>/dev/null || echo 0)
    
    local success_rate=0
    if [[ ${total} -gt 0 ]]; then
        success_rate=$((success * 100 / total))
    fi
    
    echo -e "${C_WHITE}检测统计 (总计 ${total} 次)${C_RESET}"
    echo -e "  成功: ${C_GREEN}${success}${C_RESET}"
    echo -e "  失败: ${C_RED}${failed}${C_RESET}"
    echo -e "  成功率: ${success_rate}%"
}

#-------------------------------------------------------------------------------
# 自动修复函数
#-------------------------------------------------------------------------------
# 重启 Tor

# 检测 Tor 运行方式
get_tor_run_method() {
    # 检查是否通过 tor-manager systemd 服务运行
    if systemctl is-active --quiet tor-manager 2>/dev/null; then
        echo "tor-manager-service"
        return 0
    fi
    
    # 检查是否通过系统 tor 服务运行
    if systemctl is-active --quiet tor 2>/dev/null; then
        echo "system-tor-service"
        return 0
    fi
    
    # 检查是否手动运行
    local pid=$(get_tor_pid)
    if [[ -n "${pid}" ]]; then
        # 检查进程的命令行
        local cmdline=$(cat /proc/${pid}/cmdline 2>/dev/null | tr '\0' ' ')
        if [[ "${cmdline}" == *"${TORRC_PATH}"* ]]; then
            echo "manual-our-config"
        else
            echo "manual-other-config"
        fi
        return 0
    fi
    
    echo "not-running"
}

# 安全停止 Tor
stop_tor_safely() {
    local timeout=${1:-30}
    local start_time=$(date +%s)
    
    log_info "正在停止 Tor..."
    
    # 获取运行方式
    local method=$(get_tor_run_method)
    log_debug "Tor 运行方式: ${method}"
    
    case "${method}" in
        tor-manager-service)
            log_debug "通过 tor-manager 服务停止"
            systemctl stop tor-manager 2>/dev/null
            ;;
        system-tor-service)
            log_debug "通过系统 tor 服务停止"
            systemctl stop tor 2>/dev/null
            ;;
        manual-*)
            log_debug "手动停止 Tor 进程"
            local pid=$(get_tor_pid)
            if [[ -n "${pid}" ]]; then
                # 先尝试优雅停止
                kill -TERM "${pid}" 2>/dev/null
                
                # 等待进程结束
                while [[ $(($(date +%s) - start_time)) -lt ${timeout} ]]; do
                    if ! kill -0 "${pid}" 2>/dev/null; then
                        break
                    fi
                    sleep 1
                done
                
                # 如果还在运行，强制杀死
                if kill -0 "${pid}" 2>/dev/null; then
                    log_warn "Tor 未响应 SIGTERM，强制终止"
                    kill -KILL "${pid}" 2>/dev/null
                    sleep 1
                fi
            fi
            ;;
        not-running)
            log_debug "Tor 未运行"
            return 0
            ;;
    esac
    
    # 验证是否已停止
    sleep 2
    if is_tor_running; then
        log_error "Tor 停止失败"
        return 1
    fi
    
    log_info "Tor 已停止"
    return 0
}

# 启动 Tor
start_tor_safely() {
    local timeout=${1:-120}
    
    log_info "正在启动 Tor..."
    
    # 检查是否已运行
    if is_tor_running; then
        log_warn "Tor 已在运行"
        return 0
    fi
    
    # 检查 Tor 是否安装
    if ! is_tor_installed; then
        log_error "Tor 未安装"
        return 1
    fi
    
    # 检查配置文件
    if [[ ! -f "${TORRC_PATH}" ]]; then
        log_error "配置文件不存在: ${TORRC_PATH}"
        return 1
    fi
    
    # 优先使用 systemd 服务
    if [[ -f "/etc/systemd/system/tor-manager.service" ]]; then
        log_debug "通过 tor-manager 服务启动"
        systemctl start tor-manager 2>/dev/null
        sleep 3
        if is_tor_running; then
            log_info "Tor 已通过 systemd 启动"
            return 0
        fi
        log_warn "systemd 启动失败，尝试手动启动"
    fi
    
    # 手动启动
    log_debug "手动启动 Tor"
    # 保持工作目录为脚本根目录，确保 torrc 中的相对路径正确
    cd "${SCRIPT_DIR}"
    "${TOR_BIN}" -f "${TORRC_PATH}" &
    local tor_pid=$!
    
    # 写入 PID 文件
    echo "${tor_pid}" > "${RUN_DIR}/tor.pid"
    
    # 等待启动完成
    if wait_for_bootstrap ${timeout}; then
        log_info "Tor 已启动 (PID: ${tor_pid})"
        return 0
    else
        log_error "Tor 启动超时"
        # 清理
        kill "${tor_pid}" 2>/dev/null
        rm -f "${RUN_DIR}/tor.pid"
        return 1
    fi
}

# 重启 Tor（增强版）
restart_tor() {
    local max_retries=${1:-3}
    local retry_count=0
    
    log_warn "正在重启 Tor..."
    
    while [[ ${retry_count} -lt ${max_retries} ]]; do
        ((retry_count++)) || true
        log_debug "重启尝试 ${retry_count}/${max_retries}"
        
        # 停止 Tor
        if ! stop_tor_safely 30; then
            log_warn "停止 Tor 失败，尝试继续..."
        fi
        
        # 短暂等待
        sleep 2
        
        # 启动 Tor
        if start_tor_safely 120; then
            log_info "Tor 已重启成功"
            return 0
        fi
        
        log_warn "重启失败，重试..."
        sleep 5
    done
    
    log_error "Tor 重启失败 (尝试 ${max_retries} 次)"
    return 1
}


# 检测并自动修复
check_and_repair() {
    local socks_port=$1
    local max_retries=${2:-3}
    
    local retry_count=0
    
    while [[ ${retry_count} -lt ${max_retries} ]]; do
        log_info "检测 Tor 连接 (尝试 $((retry_count + 1))/${max_retries})..."
        
        local start_time=$(date +%s%3N)
        
        if check_tor_connection "${socks_port}"; then
            local end_time=$(date +%s%3N)
            local response_time=$((end_time - start_time))
            
            log_info "连接正常 (响应时间: ${response_time}ms)"
            record_check_result "success" "Connection OK" "${response_time}"
            return 0
        fi
        
        ((retry_count++)) || true
        
        if [[ ${retry_count} -lt ${max_retries} ]]; then
            log_warn "连接失败，等待 5 秒后重试..."
            sleep 5
        fi
    done
    
    # 所有尝试都失败，尝试重启
    log_error "连接检测失败，尝试重启 Tor..."
    record_check_result "failed" "Connection failed" "0"
    
    if restart_tor; then
        # 等待 Tor 启动
        sleep 10
        
        # 再次检测
        if check_tor_connection "${socks_port}"; then
            log_info "重启后连接恢复"
            record_check_result "success" "Recovered after restart" "0"
            return 0
        fi
    fi
    
    log_error "自动修复失败，请检查 Tor 配置"
    record_check_result "failed" "Auto-repair failed" "0"
    return 1
}

#-------------------------------------------------------------------------------
# 持续检测模式
#-------------------------------------------------------------------------------
# 后台持续检测
continuous_check_daemon() {
    local socks_port=$1
    local interval=${2:-60}
    local max_failures=${3:-3}
    
    log_info "启动持续检测模式 (间隔: ${interval}s)"
    
    local consecutive_failures=0
    
    while true; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # 检测连接
        local start_time=$(date +%s%3N)
        
        if check_tor_connection "${socks_port}" 15; then
            local end_time=$(date +%s%3N)
            local response_time=$((end_time - start_time))
            
            log_info "[${timestamp}] 连接正常 (${response_time}ms)"
            record_check_result "success" "OK" "${response_time}"
            consecutive_failures=0
        else
            ((consecutive_failures++)) || true
            log_warn "[${timestamp}] 连接失败 (${consecutive_failures}/${max_failures})"
            record_check_result "failed" "Connection failed" "0"
            
            # 达到最大失败次数，尝试重启
            if [[ ${consecutive_failures} -ge ${max_failures} ]]; then
                log_error "连续失败 ${consecutive_failures} 次，尝试重启 Tor"
                restart_tor
                consecutive_failures=0
                sleep 30  # 重启后等待更长时间
            fi
        fi
        
        sleep "${interval}"
    done
}

# 启动后台检测服务
start_health_daemon() {
    local socks_port=$1
    local interval=${2:-60}
    
    local pid_file="${RUN_DIR}/health-check.pid"
    
    # 检查是否已在运行
    if [[ -f "${pid_file}" ]]; then
        local old_pid=$(cat "${pid_file}")
        if kill -0 "${old_pid}" 2>/dev/null; then
            log_warn "健康检测服务已在运行 (PID: ${old_pid})"
            return 0
        fi
    fi
    
    # 启动后台进程
    continuous_check_daemon "${socks_port}" "${interval}" &
    local pid=$!
    
    echo ${pid} > "${pid_file}"
    log_info "健康检测服务已启动 (PID: ${pid})"
}

# 停止后台检测服务
stop_health_daemon() {
    local pid_file="${RUN_DIR}/health-check.pid"
    
    if [[ ! -f "${pid_file}" ]]; then
        log_warn "健康检测服务未运行"
        return 0
    fi
    
    local pid=$(cat "${pid_file}")
    
    if kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}"
        rm -f "${pid_file}"
        log_info "健康检测服务已停止"
    else
        rm -f "${pid_file}"
        log_warn "健康检测服务进程不存在"
    fi
}

# 检查健康检测服务状态
health_daemon_status() {
    local pid_file="${RUN_DIR}/health-check.pid"
    
    if [[ ! -f "${pid_file}" ]]; then
        echo "健康检测服务: 未运行"
        return 1
    fi
    
    local pid=$(cat "${pid_file}")
    
    if kill -0 "${pid}" 2>/dev/null; then
        echo "健康检测服务: 运行中 (PID: ${pid})"
        get_last_check_status
        return 0
    else
        echo "健康检测服务: 已停止"
        rm -f "${pid_file}"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# 诊断函数
#-------------------------------------------------------------------------------
# 诊断 Tor 连接问题
diagnose_tor() {
    echo -e "${C_WHITE}=== Tor 诊断 ===${C_RESET}"
    
    # 1. 检查 Tor 是否安装
    echo -e "\n${C_CYAN}[1] Tor 安装检查${C_RESET}"
    if is_tor_installed; then
        echo -e "  Tor 版本: ${C_GREEN}$(get_tor_version)${C_RESET}"
        echo "  安装路径: ${TOR_BIN}"
    else
        echo -e "  ${C_RED}Tor 未安装${C_RESET}"
        return 1
    fi
    
    # 2. 检查 Tor 是否运行
    echo -e "\n${C_CYAN}[2] Tor 进程检查${C_RESET}"
    if is_tor_running; then
        local pid=$(get_tor_pid)
        echo -e "  状态: ${C_GREEN}运行中${C_RESET} (PID: ${pid})"
    else
        echo -e "  ${C_RED}Tor 未运行${C_RESET}"
    fi
    
    # 3. 检查配置文件
    echo -e "\n${C_CYAN}[3] 配置文件检查${C_RESET}"
    if [[ -f "${TORRC_PATH}" ]]; then
        echo -e "  配置文件: ${C_GREEN}存在${C_RESET}"
        echo "  路径: ${TORRC_PATH}"
        
        # 检查关键配置
        local socks_port=$(torrc_get "SocksPort" "9050")
        local control_port=$(torrc_get "ControlPort" "9051")
        
        echo "  SOCKS 端口: ${socks_port}"
        echo "  Control 端口: ${control_port}"
    else
        echo -e "  ${C_RED}配置文件不存在${C_RESET}"
    fi
    
    # 4. 检查端口监听
    echo -e "\n${C_CYAN}[4] 端口监听检查${C_RESET}"
    local socks_port=$(get_socks_port)
    
    if ss -tlnp 2>/dev/null | grep -q ":${socks_port} "; then
        echo -e "  SOCKS 端口 ${socks_port}: ${C_GREEN}监听中${C_RESET}"
    else
        echo -e "  SOCKS 端口 ${socks_port}: ${C_RED}未监听${C_RESET}"
    fi
    
    local control_port=$(get_control_port)
    if ss -tlnp 2>/dev/null | grep -q ":${control_port} "; then
        echo -e "  Control 端口 ${control_port}: ${C_GREEN}监听中${C_RESET}"
    else
        echo -e "  Control 端口 ${control_port}: ${C_YELLOW}未监听${C_RESET}"
    fi
    
    # 5. 检查网络连接
    echo -e "\n${C_CYAN}[5] 网络连接检查${C_RESET}"
    
    if is_tor_running; then
        echo -e "  检测 Tor 连接..."
        local result=$(check_tor_in_use "${socks_port}" 10)
        local status=$(echo "${result}" | cut -d'|' -f1)
        local ip=$(echo "${result}" | cut -d'|' -f2)
        
        if [[ "${status}" == "true" ]]; then
            echo -e "  Tor 连接: ${C_GREEN}正常${C_RESET}"
            echo -e "  出口 IP: ${C_GREEN}${ip}${C_RESET}"
        else
            echo -e "  Tor 连接: ${C_RED}异常${C_RESET}"
            echo -e "  信息: ${ip}"
        fi
    else
        echo -e "  ${C_YELLOW}跳过（Tor 未运行）${C_RESET}"
    fi
    
    # 6. 检查日志
    echo -e "\n${C_CYAN}[6] 最近日志${C_RESET}"
    local notice_log="${TOR_LOG_DIR}/notice.log"
    
    if [[ -f "${notice_log}" ]]; then
        tail -5 "${notice_log}" | while read line; do
            echo "  ${line}"
        done
    else
        echo -e "  ${C_YELLOW}日志文件不存在${C_RESET}"
    fi
    
    echo ""
}

#-------------------------------------------------------------------------------
# 主命令函数
#-------------------------------------------------------------------------------
cmd_check() {
    local continuous=false
    local interval=300
    local daemon_action=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --continuous|-c)
                continuous=true
                shift
                ;;
            --interval|-i)
                interval=$2
                shift 2
                ;;
            --daemon)
                daemon_action=$2
                shift 2
                ;;
            --status)
                health_daemon_status
                return $?
                ;;
            --stop)
                stop_health_daemon
                return $?
                ;;
            --diagnose)
                diagnose_tor
                return $?
                ;;
            --stats)
                get_check_statistics
                return $?
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    # 处理 daemon 操作
    case "${daemon_action}" in
        start)
            local socks_port=$(get_socks_port)
            start_health_daemon "${socks_port}" "${interval}"
            return $?
            ;;
        stop)
            stop_health_daemon
            return $?
            ;;
        status)
            health_daemon_status
            return $?
            ;;
    esac
    
    # 单次检测或持续检测
    local socks_port=$(get_socks_port)
    
    if ${continuous}; then
        continuous_check_daemon "${socks_port}" "${interval}"
    else
        check_and_repair "${socks_port}"
    fi
}
