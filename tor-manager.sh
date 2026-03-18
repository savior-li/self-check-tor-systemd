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

# 初始化环境
init_environment

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
            source "${LIB_DIR}/config.sh"
            cmd_config "$@"
            ;;
        
        check)
            source "${LIB_DIR}/health.sh"
            cmd_check "$@"
            ;;
        
        service)
            source "${LIB_DIR}/service.sh"
            cmd_service "$@"
            ;;
        
        tui)
            source "${LIB_DIR}/tui.sh"
            cmd_tui
            ;;
        
        logs)
            source "${LIB_DIR}/service.sh"
            view_logs "$@"
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
    echo "=== Tor 状态 ==="
    
    if [[ -x "${TOR_BIN}" ]]; then
        echo "Tor 版本: $(${TOR_BIN} --version 2>/dev/null | head -1)"
        echo "安装路径: ${TOR_INSTALL_DIR}"
    else
        echo "Tor: 未找到 (${TOR_BIN})"
    fi
    
    echo ""
    echo "配置文件: ${TORRC_PATH}"
    echo "数据目录: ${TOR_DATA_DIR}"
    echo "日志目录: ${TOR_LOG_DIR}"
    
    echo ""
    if is_tor_running; then
        echo "运行状态: 运行中 (PID: $(get_tor_pid))"
    else
        echo "运行状态: 未运行"
    fi
}

# 执行主函数
main "$@"