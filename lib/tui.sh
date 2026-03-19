#!/bin/bash
#===============================================================================
# Tor Manager - TUI Module
# TUI 交互界面：菜单、状态面板、配置编辑、日志查看
#===============================================================================

# 防止重复 source
[[ -n "${_TUI_SH_LOADED:-}" ]] && return 0
readonly _TUI_SH_LOADED=1

# 加载公共函数和模块
source "${LIB_DIR}/common.sh"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/health.sh"
source "${LIB_DIR}/service.sh"

#-------------------------------------------------------------------------------
# TUI 颜色设置
# 根据 ENABLE_COLOR 配置决定是否使用彩色输出
#-------------------------------------------------------------------------------
if [[ "${ENABLE_COLOR}" == "true" ]]; then
    TUI_WHITE="${COLOR_WHITE}"
    TUI_CYAN="${COLOR_CYAN}"
    TUI_GREEN="${COLOR_GREEN}"
    TUI_YELLOW="${COLOR_YELLOW}"
    TUI_RED="${COLOR_RED}"
    TUI_RESET="${COLOR_RESET}"
else
    TUI_WHITE=""
    TUI_CYAN=""
    TUI_GREEN=""
    TUI_YELLOW=""
    TUI_RED=""
    TUI_RESET=""
fi

#-------------------------------------------------------------------------------
# TUI 工具函数
#-------------------------------------------------------------------------------
# 清屏并显示标题
tui_header() {
    clear
    echo -e "${TUI_CYAN}"
    cat << 'ASCII_LOGO'
 █████╗ ██╗      ██████╗  ██████╗ ██████╗ 
██╔══██╗██║     ██╔════╝ ██╔═══██╗██╔══██╗
███████║██║     ██║  ███╗██║   ██║██████╔╝
██╔══██║██║     ██║   ██║██║   ██║██╔══██╗
██║  ██║███████╗╚██████╔╝╚██████╔╝██║  ██║
╚═╝  ╚═╝╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝
   ██████╗ ███████╗██╗   ██╗
   ██╔══██╗██╔════╝██║   ██║
   ██████╔╝█████╗  ██║   ██║
   ██╔══██╗██╔══╝  ╚██╗ ██╔╝
   ██║  ██║███████╗ ╚████╔╝ 
   ╚═╝  ╚═╝╚══════╝  ╚═══╝  
ASCII_LOGO
    echo -e "${TUI_WHITE}                    Manager v${SCRIPT_VERSION} - $(get_language_name "$(get_language)")${TUI_RESET}"
    echo ""
}

# 显示分隔线
tui_separator() {
    echo -e "${TUI_WHITE}────────────────────────────────────────────────────────────${TUI_RESET}"
}

# 暂停等待用户按键
tui_pause() {
    local message=${1:-"$(t "menu.press_any_key" "Press any key to continue...")"}
    echo ""
    echo -en "${TUI_CYAN}${message}${TUI_RESET}"
    read -n 1 -s -r
    echo ""
}

# 显示消息框
tui_msgbox() {
    local title=$1
    local message=$2
    
    tui_header
    echo -e "${TUI_WHITE}【${title}】${TUI_RESET}"
    echo ""
    echo -e "${message}"
    tui_pause
}

# 显示错误框
tui_error() {
    local message=$1
    tui_error "$(t "other.error" "Error")" "${TUI_RED}${message}${TUI_RESET}"
}

# 显示成功框
tui_success() {
    local message=$1
    tui_msgbox "$(t "other.success" "Success")" "${TUI_GREEN}${message}${TUI_RESET}"
}

# 确认对话框
confirm() {
    local message=$1
    local default=${2:-n}
    local prompt

    if [[ "${default}" == "y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    echo ""
    echo -en "${TUI_YELLOW}${message} ${prompt}: ${TUI_RESET}"
    read -r answer

    if [[ -z "${answer}" ]]; then
        answer="${default}"
    fi

    case "${answer,,}" in
        y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

#-------------------------------------------------------------------------------
# 状态面板
#-------------------------------------------------------------------------------
# 显示状态概览
tui_status_panel() {
    tui_header
    
    echo -e "${TUI_WHITE}【$(t "status.title" "状态概览")】${TUI_RESET}"
    echo ""
    
    # Tor 安装状态
    echo -e "${TUI_CYAN}$(t "status.tor_installed" "Tor 安装"):${TUI_RESET}"
    if is_tor_installed; then
        echo -e "  $(t "status.version" "版本"):   ${TUI_GREEN}$(get_tor_version)${TUI_RESET}"
        echo -e "  $(t "status.path" "路径"):   ${TOR_INSTALL_DIR}"
    else
        echo -e "  ${TUI_RED}$(t "status.not_installed" "未安装")${TUI_RESET}"
    fi
    
    echo ""
    
    # 运行状态
    echo -e "${TUI_CYAN}$(t "status.running" "运行状态"):${TUI_RESET}"
    if is_tor_running; then
        local pid=$(get_tor_pid)
        echo -e "  $(t "status.status" "状态"):   ${TUI_GREEN}$(t "status.running2" "运行中")${TUI_RESET}"
        echo -e "  $(t "status.pid" "PID"):    ${pid}"
        echo -e "  $(t "status.uptime" "运行"):   $(ps -o etime= -p ${pid} 2>/dev/null || echo "$(t "status.unknown" "未知")")"
    else
        echo -e "  $(t "status.status" "状态"):   ${TUI_RED}$(t "status.stopped" "未运行")${TUI_RESET}"
    fi
    
    echo ""
    
    # 端口状态
    echo -e "${TUI_CYAN}$(t "status.ports" "端口监听"):${TUI_RESET}"
    local socks_port=$(get_socks_port)
    local control_port=$(get_control_port)
    
    if ss -tlnp 2>/dev/null | grep -q ":${socks_port} "; then
        echo -e "  SOCKS:  ${TUI_GREEN}${socks_port} $(t "status.listening" "(监听中)")${TUI_RESET}"
    else
        echo -e "  SOCKS:  ${TUI_RED}${socks_port} $(t "status.not_listening" "(未监听)")${TUI_RESET}"
    fi
    
    if ss -tlnp 2>/dev/null | grep -q ":${control_port} "; then
        echo -e "  Control: ${TUI_GREEN}${control_port} $(t "status.listening" "(监听中)")${TUI_RESET}"
    else
        echo -e "  Control: ${TUI_RED}${control_port} $(t "status.not_listening" "(未监听)")${TUI_RESET}"
    fi
    
    echo ""
    
    # $(t "status.config_overview" "配置概览")
    echo -e "${TUI_CYAN}$(t "status.config_overview" "配置概览"):${TUI_RESET}"
    local bridge_count=$(bridge_count)
    local exit_nodes=$(exit_nodes_get)
    
    echo -e "  Bridge: ${bridge_count} $(t "status.count" "个")"
    if [[ -n "${exit_nodes}" ]]; then
        echo -e "  $(t "status.exit_nodes" "Exit Nodes"):   ${exit_nodes}"
    else
        echo -e "  出口:   $(t "config.auto" "自动选择")"
    fi
    
    echo ""
    
    # $(t "status.network" "网络连接")
    if is_tor_running; then
        echo -e "${TUI_CYAN}$(t "status.network" "网络连接"):${TUI_RESET}"
        local result=$(check_tor_in_use "${socks_port}" 10 2>/dev/null)
        local status=$(echo "${result}" | cut -d'|' -f1)
        local ip=$(echo "${result}" | cut -d'|' -f2)
        
        if [[ "${status}" == "true" ]]; then
            echo -e "  连接:   ${TUI_GREEN}$(t "status.ok" "正常")${TUI_RESET}"
            echo -e "  $(t "status.exit_ip" "出口IP"): ${TUI_GREEN}${ip}${TUI_RESET}"
        else
            echo -e "  连接:   ${TUI_RED}$(t "status.error" "异常")${TUI_RESET}"
        fi
    fi
    
    tui_separator
}

#-------------------------------------------------------------------------------
# 主菜单
#-------------------------------------------------------------------------------
# 显示主菜单
# 显示主菜单
tui_main_menu() {
    while true; do
        tui_status_panel
        
        echo -e "${TUI_WHITE}【$(t "menu.main" "主菜单")】${TUI_RESET}"
        echo ""
        echo -e "  ${TUI_CYAN}1${TUI_RESET}. $(t "menu.service" "服务管理")"
        echo -e "  ${TUI_CYAN}2${TUI_RESET}. $(t "menu.config" "配置管理")"
        echo -e "  ${TUI_CYAN}3${TUI_RESET}. $(t "menu.check" "连接检测")"
        echo -e "  ${TUI_CYAN}4${TUI_RESET}. $(t "menu.logs" "查看日志")"
        echo -e "  ${TUI_CYAN}5${TUI_RESET}. $(t "menu.diag" "诊断工具")"
        echo -e "  ${TUI_CYAN}6${TUI_RESET}. $(t "menu.language" "语言设置") ($(get_language_name "$(get_language)"))"
        echo ""
        echo -e "  ${TUI_CYAN}0${TUI_RESET}. $(t "menu.exit" "退出")"
        echo ""
        tui_separator
        
        echo -en "${TUI_WHITE}$(t "menu.select" "请选择") [0-6]: ${TUI_RESET}"
        read -r choice
        
        case ${choice} in
            1) tui_service_menu ;;
            2) tui_config_menu ;;
            3) tui_check_menu ;;
            4) tui_log_viewer ;;
            5) tui_diagnostic ;;
            6) tui_language_menu ;;
            0) 
                clear
                echo "$(t "msg.goodbye" "再见!")"
                exit 0
                ;;
            *)
                tui_error "$(t "msg.invalid_choice" "$(t "config.none" "无")效选择")"
                ;;
        esac
    done
}


#-------------------------------------------------------------------------------
# 服务管理菜单
#-------------------------------------------------------------------------------
tui_service_menu() {
    while true; do
        tui_header
        echo -e "${TUI_WHITE}【$(t "menu.service" "服务管理")】${TUI_RESET}"
        echo ""
        
        # 服务状态
        echo -e "${TUI_CYAN}$(t "status.current" "当前状态"):${TUI_RESET}"
        if is_tor_running; then
            echo -e "  $(t "status.running" "运行"):   ${TUI_GREEN}$(t "status.yes" "是")${TUI_RESET} ($(t "status.pid" "PID"): $(get_tor_pid))"
        else
            echo -e "  $(t "status.running" "运行"):   ${TUI_RED}$(t "status.no" "否")${TUI_RESET}"
        fi
        
        if [[ -f "${SERVICE_FILE}" ]]; then
            if systemctl is-enabled "${SERVICE_NAME}" &>/dev/null; then
                echo -e "  $(t "status.autostart" "自启"):   ${TUI_GREEN}$(t "status.enabled" "已启用")${TUI_RESET}"
            else
                echo -e "  $(t "status.autostart" "自启"):   ${TUI_YELLOW}$(t "status.disabled" "未启用")${TUI_RESET}"
            fi
        else
            echo -e "  $(t "status.service" "服务"):   ${TUI_YELLOW}$(t "status.not_installed" "未安装")${TUI_RESET}"
        fi
        
        echo ""
        tui_separator
        echo -e "  ${TUI_CYAN}1${TUI_RESET}. $(t "service.start" "启动服务")"
        echo -e "  ${TUI_CYAN}2${TUI_RESET}. $(t "service.stop" "停止服务")"
        echo -e "  ${TUI_CYAN}3${TUI_RESET}. $(t "service.restart" "重启服务")"
        echo -e "  ${TUI_CYAN}4${TUI_RESET}. $(t "service.status" "查看详细状态")"
        echo ""
        echo -e "  ${TUI_CYAN}5${TUI_RESET}. $(t "service.enable" "启用开机自启")"
        echo -e "  ${TUI_CYAN}6${TUI_RESET}. $(t "service.disable" "禁用开机自启")"
        echo ""
        echo -e "  ${TUI_CYAN}7${TUI_RESET}. $(t "service.install_sys" "安装 systemd 服务")"
        echo -e "  ${TUI_CYAN}8${TUI_RESET}. $(t "service.uninstall_sys" "卸载 systemd 服务")"
        echo ""
        echo -e "  ${TUI_CYAN}0${TUI_RESET}. $(t "menu.back_main" "$(t "menu.back" "返回")主菜单")"
        echo ""
        
        echo -en "${TUI_WHITE}$(t "menu.select_prompt" "请选择:") ${TUI_RESET}"
        read -r choice
        
        case ${choice} in
            1) service_start 2>&1; tui_pause ;;
            2) service_stop 2>&1; tui_pause ;;
            3) service_restart 2>&1; tui_pause ;;
            4) service_status; tui_pause ;;
            5) service_enable 2>&1; tui_pause ;;
            6) service_disable 2>&1; tui_pause ;;
            7) install_services 2>&1; tui_pause ;;
            8)
                if confirm "$(t "confirm.uninstall_service" "Are you sure you want to uninstall the service?")" "n"; then
                    uninstall_services 2>&1
                fi
                tui_pause
                ;;
            0) return ;;
            *) tui_error "$(t "config.none" "无")效选择" ;;
        esac
    done
}

#-------------------------------------------------------------------------------
# 配置管理菜单
#-------------------------------------------------------------------------------
tui_config_menu() {
    while true; do
        tui_header
        echo -e "${TUI_WHITE}【$(t "menu.config" "配置管理")】${TUI_RESET}"
        echo ""
        
        show_config
        echo ""
        tui_separator
        echo -e "  ${TUI_CYAN}1${TUI_RESET}. $(t "config.ports" "端口配置")"
        echo -e "  ${TUI_CYAN}2${TUI_RESET}. $(t "config.bridge" "Bridge 配置")"
        echo -e "  ${TUI_CYAN}3${TUI_RESET}. $(t "config.exit_nodes" "出口节点配置")"
        echo -e "  ${TUI_CYAN}4${TUI_RESET}. $(t "config.exclude_nodes" "排除节点配置")"
        echo -e "  ${TUI_CYAN}5${TUI_RESET}. $(t "config.health" "健康检测配置")"
        echo ""
        echo -e "  ${TUI_CYAN}6${TUI_RESET}. $(t "config.wizard" "配置向导")"
        echo -e "  ${TUI_CYAN}7${TUI_RESET}. $(t "config.edit" "编辑配置文件")"
        echo -e "  ${TUI_CYAN}8${TUI_RESET}. $(t "config.restore" "恢复备份")"
        echo ""
        echo -e "  ${TUI_CYAN}0${TUI_RESET}. $(t "menu.back_main" "$(t "menu.back" "返回")主菜单")"
        echo ""
        
        echo -en "${TUI_WHITE}$(t "menu.select_prompt" "请选择:") ${TUI_RESET}"
        read -r choice
        
        case ${choice} in
            1) tui_ports_config ;;
            2) tui_bridge_config ;;
            3) tui_exit_nodes_config ;;
            4) tui_exclude_nodes_config ;;
            5) tui_health_config ;;
            6) config_wizard ;;
            7) edit_config ;;
            8) tui_restore_backup ;;
            0) return ;;
            *) tui_error "$(t "config.none" "无")效选择" ;;
        esac
        
        tui_pause
    done
}

tui_ports_config() {
    tui_header
    echo -e "${TUI_WHITE}【$(t "config.ports" "$(t "config.ports" "端口配置")")】${TUI_RESET}"
    echo ""
    
    local current_socks=$(get_socks_port)
    local current_control=$(get_control_port)
    
    echo -e "$(t "config.current_socks" "当前 SOCKS 端口"): ${TUI_CYAN}${current_socks}${TUI_RESET}"
    echo -en "$(t "config.new_socks" "新 SOCKS 端口 (留空保持)"): "
    read -r new_socks
    
    if [[ -n "${new_socks}" ]]; then
        if validate_port "${new_socks}"; then
            set_socks_port "${new_socks}"
        else
            tui_error "$(t "config.none" "无")效端口: ${new_socks}"
            return
        fi
    fi
    
    echo ""
    echo -e "$(t "config.current_control" "当前 Control 端口"): ${TUI_CYAN}${current_control}${TUI_RESET}"
    echo -en "$(t "config.new_control" "新 Control 端口 (留空保持)"): "
    read -r new_control
    
    if [[ -n "${new_control}" ]]; then
        if validate_port "${new_control}"; then
            set_control_port "${new_control}"
        else
            tui_error "$(t "config.none" "无")效端口: ${new_control}"
            return
        fi
    fi
    
    echo ""
    tui_success "$(t "config.ports" "端口配置")已更新，请重启 Tor 使配置生效"
}

# $(t "config.bridge" "Bridge 配置")
tui_bridge_config() {
    while true; do
        tui_header
        echo -e "${TUI_WHITE}【$(t "config.bridge" "$(t "config.bridge" "Bridge 配置")")】${TUI_RESET}"
        echo ""
        
        bridge_list
        echo ""
        tui_separator
        echo -e "  ${TUI_CYAN}1${TUI_RESET}. $(t "bridge.add" "添加 Bridge")"
        echo -e "  ${TUI_CYAN}2${TUI_RESET}. $(t "bridge.remove" "删除 Bridge")"
        echo -e "  ${TUI_CYAN}3${TUI_RESET}. $(t "bridge.clear" "清除所有 Bridge")"
        echo -e "  ${TUI_CYAN}4${TUI_RESET}. $(t "bridge.import" "从文件导入")"
        echo -e "  ${TUI_CYAN}5${TUI_RESET}. $(t "bridge.export" "导出 Bridge")"
        echo ""
        echo -e "  ${TUI_CYAN}0${TUI_RESET}. $(t "menu.back" "返回")"
        echo ""
        
        echo -en "${TUI_WHITE}$(t "menu.select_prompt" "请选择:") ${TUI_RESET}"
        read -r choice
        
        case ${choice} in
            1)
                echo ""
                echo -e "${TUI_YELLOW}$(t "bridge.format_example" "Bridge 格式示例"):${TUI_RESET}"
                echo "  obfs4 1.2.3.4:443 cert=... iat-mode=0"
                echo "  webtunnel 1.2.3.4:443 url=https://..."
                echo ""
                echo -en "粘贴 $(t "config.bridge" "Bridge 配置"): "
                read -r bridge_line
                
                if [[ -n "${bridge_line}" ]]; then
                    bridge_add "${bridge_line}"
                fi
                ;;
            2)
                echo ""
                local count=$(bridge_count)
                if [[ ${count} -eq 0 ]]; then
                    echo "没有 $(t "config.bridge" "Bridge 配置")"
                else
                    echo -en "$(t "bridge.delete_prompt" "输入要删除的 Bridge 编号"): "
                    read -r num
                    bridge_remove "${num}"
                fi
                ;;
            3)
                if confirm "确定$(t "bridge.clear" "清除所有 Bridge")？" "n"; then
                    bridge_clear
                fi
                ;;
            4)
                echo ""
                echo -en "$(t "config.file_path" "输入文件路径"): "
                read -r import_file
                if [[ -f "${import_file}" ]]; then
                    bridge_import "${import_file}"
                else
                    tui_error "$(t "error.file_not_found" "File not found")"
                fi
                ;;
            5)
                echo ""
                echo -en "$(t "config.export_file" "导出到文件") ($(t "config.leave_empty_show" "留空显示")): "
                read -r export_file
                bridge_export "${export_file}"
                ;;
            0) return ;;
            *) tui_error "$(t "config.none" "无")效选择" ;;
        esac
        
        tui_pause
    done
}

# $(t "config.exit_nodes" "出口节点配置")
tui_exit_nodes_config() {
    tui_header
    echo -e "${TUI_WHITE}【$(t "config.exit_nodes" "$(t "config.exit_nodes" "出口节点配置")")】${TUI_RESET}"
    echo ""
    
    show_country_codes
    echo ""
    
    local current=$(exit_nodes_get)
    echo -e "当前配置: ${TUI_CYAN}${current:-$(t "config.auto" "自动选择")}${TUI_RESET}"
    echo ""
    
    echo -en "$(t "config.set_exit_nodes" "设置出口节点") ($(t "config.exit_nodes_hint" "如 {US},{DE},输入 clear 清除")): "
    read -r new_exit
    
    if [[ -n "${new_exit}" ]]; then
        if [[ "${new_exit}" == "clear" ]]; then
            exit_nodes_clear
        else
            exit_nodes_set "${new_exit}"
        fi
    fi
    
    echo ""
    tui_success "$(t "msg.config_updated" "配置已更新")"
}

# 日志配置

# $(t "config.exclude_nodes" "排除节点配置")
tui_exclude_nodes_config() {
    tui_header
    echo -e "${TUI_WHITE}【$(t "config.exclude_nodes" "$(t "config.exclude_nodes" "排除节点配置")")】${TUI_RESET}"
    echo ""
    
    show_country_codes
    echo ""
    
    local current=$(exclude_nodes_get)
    echo -e "当前配置: ${TUI_RED}${current:-$(t "config.none" "无")}${TUI_RESET}"
    echo ""
    
    echo -en "$(t "config.set_exclude_nodes" "设置排除节点") ($(t "config.exclude_nodes_hint" "如 {CN},{RU},{KP},输入 clear 清除")): "
    read -r new_exclude
    
    if [[ -n "${new_exclude}" ]]; then
        if [[ "${new_exclude}" == "clear" ]]; then
            exclude_nodes_clear
        else
            exclude_nodes_set "${new_exclude}"
        fi
    fi
    
    echo ""
    tui_success "$(t "msg.config_updated" "配置已更新")"
}

tui_log_config() {
    tui_header
    echo -e "${TUI_WHITE}【$(t "config.logs" "日志配置")】${TUI_RESET}"
    echo ""
    
    echo -e "$(t "config.log_levels" "可用级别"): ${TUI_CYAN}err, warn, notice, info, debug${TUI_RESET}"
    echo ""
    
    local current=$(torrc_get "Log" "notice" | awk '{print $1}')
    echo -e "$(t "config.current_level" "当前级别"): ${TUI_CYAN}${current}${TUI_RESET}"
    echo ""
    
    echo -en "$(t "config.new_log_level" "新日志级别 (留空保持)"): "
    read -r new_level
    
    if [[ -n "${new_level}" ]]; then
        set_log_level "${new_level}"
    fi
    
    tui_success "日志$(t "msg.config_updated" "配置已更新")"
}

# $(t "config.health" "健康检测配置")
tui_health_config() {
    tui_header
    echo -e "${TUI_WHITE}【$(t "config.health" "$(t "config.health" "健康检测配置")")】${TUI_RESET}"
    echo ""
    
    # 检测间隔
    local current_interval=$(get_check_interval)
    echo -e "$(t "config.check_interval" "当前检测间隔"): ${TUI_CYAN}${current_interval} $(t "config.seconds" "秒")${TUI_RESET} ($(( current_interval / 60 )) $(t "config.minutes" "分钟"))"
    echo -en "$(t "config.new_interval" "新检测间隔，$(t "config.seconds" "秒") (留空保持，最小 10)"): "
    read -r new_interval
    
    if [[ -n "${new_interval}" ]]; then
        if [[ "${new_interval}" =~ ^[0-9]+$ ]] && [[ ${new_interval} -ge 10 ]]; then
            set_check_interval "${new_interval}"
        else
            tui_error "$(t "config.none" "无")效的检测间隔: ${new_interval} (最小 10 $(t "config.seconds" "秒"))"
            return
        fi
    fi
    
    echo ""
    
    # 最大失败次数
    local current_failures=$(get_max_failures)
    echo -e "$(t "config.max_failures" "当前最大失败次数"): ${TUI_CYAN}${current_failures}${TUI_RESET}"
    echo -en "$(t "config.new_failures" "新最大失败次数 (留空保持，范围 1-100)"): "
    read -r new_failures
    
    if [[ -n "${new_failures}" ]]; then
        if [[ "${new_failures}" =~ ^[0-9]+$ ]] && [[ ${new_failures} -ge 1 ]] && [[ ${new_failures} -le 100 ]]; then
            set_max_failures "${new_failures}"
        else
            tui_error "$(t "config.none" "无")效的失败次数: ${new_failures} (范围 1-100)"
            return
        fi
    fi
    
    echo ""
    
    # 检测超时
    local current_timeout=$(get_check_timeout)
    echo -e "$(t "config.check_timeout" "当前检测超时"): ${TUI_CYAN}${current_timeout} $(t "config.seconds" "秒")${TUI_RESET}"
    echo -en "新检测超时，$(t "config.seconds" "秒") (留空保持，范围 5-300): "
    read -r new_timeout
    
    if [[ -n "${new_timeout}" ]]; then
        if [[ "${new_timeout}" =~ ^[0-9]+$ ]] && [[ ${new_timeout} -ge 5 ]] && [[ ${new_timeout} -le 300 ]]; then
            set_check_timeout "${new_timeout}"
        else
            tui_error "$(t "config.none" "无")效的超时时间: ${new_timeout} (范围 5-300 $(t "config.seconds" "秒"))"
            return
        fi
    fi
    
    echo ""
    tui_success "$(t "config.health" "健康检测配置")已更新"
}

# $(t "config.restore" "恢复备份")
tui_restore_backup() {
    tui_header
    echo -e "${TUI_WHITE}【$(t "config.restore" "$(t "config.restore" "恢复备份")")】${TUI_RESET}"
    echo ""
    
    local backups=$(list_torrc_backups)
    
    if [[ -z "${backups}" ]]; then
        echo "$(t "logs.no_backup" "No backups available")"
        return
    fi
    
    echo "$(t "logs.available_backups" "Available backups:")"
    echo ""
    echo "${backups}" | head -10 | nl
    echo ""
    
    echo -en "$(t "logs.select_backup" "Select backup number to restore (1-10): ")"
    read -r num
    
    if [[ ${num} -ge 1 && ${num} -le 10 ]]; then
        local backup_file=$(echo "${backups}" | sed -n "${num}p" | awk '{print $NF}')
        if [[ -f "${backup_file}" ]]; then
            restore_torrc "${backup_file}"
        fi
    fi
}

#-------------------------------------------------------------------------------
# 连接检测菜单
#-------------------------------------------------------------------------------
tui_check_menu() {
    while true; do
        tui_header
        echo -e "${TUI_WHITE}【$(t "menu.check" "连接检测")】${TUI_RESET}"
        echo ""
        
        # 显示上次检测结果
        get_last_check_status 2>/dev/null || echo "$(t "config.none" "无")检测记录"
        
        echo ""
        tui_separator
        echo -e "  ${TUI_CYAN}1${TUI_RESET}. $(t "check.now" "Check Now")"
        echo -e "  ${TUI_CYAN}2${TUI_RESET}. $(t "check.continuous2" "Continuous Check")"
        echo -e "  ${TUI_CYAN}3${TUI_RESET}. $(t "check.run_diag" "Run Diagnostics")"
        echo -e "  ${TUI_CYAN}4${TUI_RESET}. $(t "check.view_stats" "View Statistics")"
        echo ""
        echo -e "  ${TUI_CYAN}0${TUI_RESET}. $(t "menu.back_main" "$(t "menu.back" "返回")主菜单")"
        echo ""
        
        echo -en "${TUI_WHITE}$(t "menu.select_prompt" "请选择:") ${TUI_RESET}"
        read -r choice
        
        case ${choice} in
            1)
                echo ""
                local socks_port=$(get_socks_port)
                check_and_repair "${socks_port}"
                ;;
            2)
                echo ""
                echo -en "检测间隔 ($(t "config.seconds" "秒")) [60]: "
                read -r interval
                interval=${interval:-60}
                
                echo ""
                echo "$(t "check.start_continuous" "Starting continuous check (Ctrl+C to stop)")..."
                local socks_port=$(get_socks_port)
                continuous_check_daemon "${socks_port}" "${interval}"
                ;;
            3)
                diagnose_tor
                ;;
            4)
                get_check_statistics
                ;;
            0) return ;;
            *) tui_error "$(t "config.none" "无")效选择" ;;
        esac
        
        tui_pause
    done
}

#-------------------------------------------------------------------------------
# 日志查看器
#-------------------------------------------------------------------------------
tui_log_viewer() {
    while true; do
        tui_header
        echo -e "${TUI_WHITE}【$(t "menu.logs" "日志查看")】${TUI_RESET}"
        echo ""
        
        # 显示可用日志文件
        echo -e "$(t "logs.available" "Available Logs:"):"
        echo -e "  $(t "logs.tor_log" "Tor Log"):     ${LOG_DIR}/info.log"
        echo -e "  $(t "logs.app" "程序日志"):     ${LOG_DIR}/tor-manager.log"
        echo -e "  $(t "logs.health_log" "Health Log"):     ${LOG_DIR}/health.log"
        echo ""
        tui_separator
        
        echo -e "  ${TUI_CYAN}1${TUI_RESET}. $(t "logs.systemd" "Systemd 服务日志") (journalctl)"
        echo -e "  ${TUI_CYAN}2${TUI_RESET}. $(t "logs.tor" "Tor 运行日志")"
        echo -e "  ${TUI_CYAN}3${TUI_RESET}. $(t "logs.health" "健康检测日志")"
        echo -e "  ${TUI_CYAN}4${TUI_RESET}. $(t "logs.app" "程序日志")"
        echo ""
        echo -e "  ${TUI_CYAN}0${TUI_RESET}. $(t "menu.back_main" "$(t "menu.back" "返回")主菜单")"
        echo ""
        
        echo -en "${TUI_WHITE}$(t "menu.select_prompt" "请选择:") ${TUI_RESET}"
        read -r choice
        
        case ${choice} in
            1)
                tui_header
                echo -e "${TUI_WHITE}【$(t "logs.systemd" "$(t "logs.systemd" "Systemd 服务日志")")】${TUI_RESET}"
                echo ""
                journalctl -u tor-manager --no-pager -n 100 2>/dev/null || echo "$(t "config.none" "无")法读取 systemd 日志"
                echo ""
                tui_pause
                ;;
            2)
                local tor_log="${LOG_DIR}/info.log"
                tui_header
                echo -e "${TUI_WHITE}【$(t "logs.tor" "$(t "logs.tor" "Tor 运行日志")")】${TUI_RESET}"
                echo ""
                if [[ -f "${tor_log}" ]]; then
                    tail -100 "${tor_log}"
                else
                    echo "$(t "logs.not_exist" "Log file does not exist:"): ${tor_log}"
                fi
                echo ""
                tui_pause
                ;;
            3)
                local health_log="${LOG_DIR}/health.log"
                tui_header
                echo -e "${TUI_WHITE}【$(t "logs.health" "$(t "logs.health" "健康检测日志")")】${TUI_RESET}"
                echo ""
                if [[ -f "${health_log}" ]]; then
                    tail -100 "${health_log}"
                else
                    echo "$(t "logs.not_exist" "Log file does not exist:"): ${health_log}"
                    echo ""
                    echo "提示: $(t "logs.health" "健康检测日志")在首次运行 'tor-manager check' 后生成"
                fi
                echo ""
                tui_pause
                ;;
            4)
                local app_log="${LOG_DIR}/tor-manager.log"
                tui_header
                echo -e "${TUI_WHITE}【$(t "logs.app" "$(t "logs.app" "程序日志")")】${TUI_RESET}"
                echo ""
                if [[ -f "${app_log}" ]]; then
                    tail -100 "${app_log}"
                else
                    echo "$(t "logs.not_exist" "Log file does not exist:"): ${app_log}"
                fi
                echo ""
                tui_pause
                ;;
            0) return ;;
            *) tui_error "$(t "config.none" "无")效选择" ;;
        esac
    done
}


#-------------------------------------------------------------------------------
# 诊断工具
#-------------------------------------------------------------------------------
tui_diagnostic() {
    tui_header
    echo -e "${TUI_WHITE}【$(t "menu.diag" "诊断工具")】${TUI_RESET}"
    echo ""
    
    diagnose_tor
    
    echo ""
    echo -e "$(t "diag.common_cmds" "Common Diagnostic Commands:"):"
    echo "  tor-manager check --diagnose"
    echo "  journalctl -u tor-manager -f"
    echo "  ss -tlnp | grep tor"
    echo ""
    
    tui_pause
}

#-------------------------------------------------------------------------------
# 启动 TUI
#-------------------------------------------------------------------------------
cmd_tui() {
    # 检查 dialog 是否可用（可选）
    if ! command_exists dialog; then
        log_debug "$(t "diag.no_dialog" "dialog not installed, using built-in TUI")"
    fi
    
    # 初始化环境
    init_environment
    
    # 进入主菜单
    tui_main_menu
}


#-------------------------------------------------------------------------------
# 语言设置菜单
#-------------------------------------------------------------------------------
tui_language_menu() {
    while true; do
        tui_header
        echo -e "${TUI_WHITE}【$(t "menu.language" "语言设置 / Language")】${TUI_RESET}"
        echo ""
        echo -e "  ${TUI_CYAN}1${TUI_RESET}. English (英语)"
        echo -e "  ${TUI_CYAN}2${TUI_RESET}. 中文 (简体)"
        echo -e "  ${TUI_CYAN}3${TUI_RESET}. Español (西班牙语)"
        echo ""
        echo -e "  ${TUI_CYAN}0${TUI_RESET}. $(t "menu.back" "$(t "menu.back" "返回")上级菜单")"
        echo ""
        tui_separator
        
        echo -en "${TUI_WHITE}$(t "menu.select" "请选择") [0-3]: ${TUI_RESET}"
        read -r choice
        
        case ${choice} in
            1) set_language "en" && tui_success "已设置为 English" ;;
            2) set_language "zh" && tui_success "已设置为 中文" ;;
            3) set_language "es" && tui_success "已设置为 Español" ;;
            0) break ;;
            *) tui_error "$(t "msg.invalid_choice" "$(t "config.none" "无")效选择")" ;;
        esac
        tui_pause
    done
}
