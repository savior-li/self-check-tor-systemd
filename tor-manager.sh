#!/bin/bash
#===============================================================================
# Tor Manager - Main Entry Point
# Tor 管理系统主入口
#
# 用法: tor-manager <command> [options]
#
# 命令:
#   config      配置管理
#   check       连通性检测
#   service     服务管理
#   tui         启动交互界面
#   logs        查看日志
#   status      显示状态
#   help        显示帮助
#   version     显示版本
#===============================================================================

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# 加载公共函数
source "${LIB_DIR}/common.sh"

# 加载国际化模块
source "${LIB_DIR}/i18n.sh"

# 初始化环境
init_environment

# 初始化语言（自动检测或从配置读取）
init_language

# 加载配置模块并自动修复路径
source "${LIB_DIR}/config.sh"
fix_torrc_paths

# 加载服务模块并检查路径
source "${LIB_DIR}/service.sh"
check_service_path 2>/dev/null || true

# 获取锁（防止多实例运行）
acquire_lock

#-------------------------------------------------------------------------------
# 主命令解析
#-------------------------------------------------------------------------------
main() {
    local command=${1:-help}
    shift || true
    
    case "${command}" in
        config)
            cmd_config "$@"
            ;;
        
        check)
            source "${LIB_DIR}/health.sh"
            cmd_check "$@"
            ;;
        
        service)
            cmd_service "$@"
            ;;
        
        tui)
            source "${LIB_DIR}/tui.sh"
            cmd_tui
            ;;
        
        logs)
            view_logs "$@"
            ;;
        
        lang|language)
            cmd_language "$@"
            ;;
        
        status)
            show_status
            ;;
        
        version|--version|-v)
            show_version
            ;;
        
        help|--help|-h)
            show_help
            ;;
        
        *)
            log_error "未知命令: ${command}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 显示状态
show_status() {
    echo "=== $(t "status.title" "Tor Status") ==="
    
    if [[ -x "${TOR_BIN}" ]]; then
        echo "$(t "status.tor.version" "Tor Version"): $(${TOR_BIN} --version 2>/dev/null | head -1)"
        echo "$(t "status.path" "Install Path"): ${TOR_INSTALL_DIR}"
    else
        echo "Tor: $(t "error.not_found" "Not Found") (${TOR_BIN})"
    fi
    
    echo ""
    echo "$(t "config.torrc_path" "Config File"): ${TORRC_PATH}"
    echo "$(t "status.data_dir" "Data Directory"): ${TOR_DATA_DIR}"
    echo "$(t "status.log_dir" "Log Directory"): ${TOR_LOG_DIR}"
    
    echo ""
    if is_tor_running; then
        echo "$(t "status.running_status" "Running Status"): $(t "status.running" "Running") (PID: $(get_tor_pid))"
    else
        echo "$(t "status.running_status" "Running Status"): $(t "status.stopped" "Stopped")"
    fi
}

# 执行主函数
main "$@"