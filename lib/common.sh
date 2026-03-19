#!/bin/bash
#===============================================================================
# Tor Manager - Common Functions Library
# 公共函数库：日志、工具函数、常量定义
#===============================================================================

# 防止重复 source
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
readonly _COMMON_SH_LOADED=1

set -o pipefail

#-------------------------------------------------------------------------------
# 全局常量
#-------------------------------------------------------------------------------
readonly SCRIPT_NAME="tor-manager"
readonly SCRIPT_VERSION="1.0.0"

# 程序安装路径（可通过配置文件覆盖）
PROGRAM_INSTALL_DIR="${PROGRAM_INSTALL_DIR:-/opt/self-check-tor-systemd}"

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
ETC_DIR="${SCRIPT_DIR}/etc"
VAR_DIR="${SCRIPT_DIR}/var"
LOG_DIR="${VAR_DIR}/log"
RUN_DIR="${VAR_DIR}/run"
BACKUP_DIR="${VAR_DIR}/backup"

# Tor 相关路径（默认使用当前目录下的 tor 和 torrc）
TOR_INSTALL_DIR="${TOR_INSTALL_DIR:-${SCRIPT_DIR}/tor}"
TOR_BIN="${TOR_INSTALL_DIR}/tor"
TORRC_PATH="${TORRC_PATH:-${SCRIPT_DIR}/torrc}"
TOR_DATA_DIR="${TOR_DATA_DIR:-${SCRIPT_DIR}/data}"
TOR_LOG_DIR="${TOR_LOG_DIR:-${VAR_DIR}/log}"

# 日志级别
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=4

# 颜色代码
readonly COLOR_RESET="\033[0m"
readonly COLOR_RED="\033[0;31m"
readonly COLOR_GREEN="\033[0;32m"
readonly COLOR_YELLOW="\033[0;33m"
readonly COLOR_BLUE="\033[0;34m"
readonly COLOR_CYAN="\033[0;36m"
readonly COLOR_WHITE="\033[1;37m"

#-------------------------------------------------------------------------------
# 全局变量
#-------------------------------------------------------------------------------
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}
ENABLE_COLOR="${ENABLE_COLOR:-false}"  # 默认关闭彩色输出

#-------------------------------------------------------------------------------
# 颜色辅助函数
#-------------------------------------------------------------------------------
# 获取颜色代码（根据 ENABLE_COLOR 设置）
get_color() {
    local color_name=$1
    if [[ "${ENABLE_COLOR}" != "true" ]]; then
        echo ""
        return
    fi
    case ${color_name} in
        reset)   echo "${COLOR_RESET}" ;;
        red)     echo "${COLOR_RED}" ;;
        green)   echo "${COLOR_GREEN}" ;;
        yellow)  echo "${COLOR_YELLOW}" ;;
        blue)    echo "${COLOR_BLUE}" ;;
        cyan)    echo "${COLOR_CYAN}" ;;
        white)   echo "${COLOR_WHITE}" ;;
        *)       echo "" ;;
    esac
}

#-------------------------------------------------------------------------------
# 初始化函数
#-------------------------------------------------------------------------------
init_environment() {
    # 创建必要的目录
    for dir in "${LOG_DIR}" "${RUN_DIR}" "${BACKUP_DIR}"; do
        [[ ! -d "${dir}" ]] && mkdir -p "${dir}"
    done
    
    # 保存默认值
    local _default_tor_install="${SCRIPT_DIR}/tor"
    local _default_torrc="${SCRIPT_DIR}/torrc"
    local _default_tor_data="${SCRIPT_DIR}/data"
    
    # 加载配置文件
    local config_file="${ETC_DIR}/tor-manager.conf"
    if [[ -f "${config_file}" ]]; then
        source "${config_file}"
    fi
    
    # 如果配置文件中的值为空，恢复默认值
    [[ -z "${TOR_INSTALL_DIR}" ]] && TOR_INSTALL_DIR="${_default_tor_install}"
    [[ -z "${TORRC_PATH}" ]] && TORRC_PATH="${_default_torrc}"
    [[ -z "${TOR_DATA_DIR}" ]] && TOR_DATA_DIR="${_default_tor_data}"
    
    # 更新 TOR_BIN
    TOR_BIN="${TOR_INSTALL_DIR}/tor"
}

#-------------------------------------------------------------------------------
# 日志函数
#-------------------------------------------------------------------------------
get_log_level_name() {
    local level=$1
    case ${level} in
        ${LOG_LEVEL_DEBUG}) echo "DEBUG" ;;
        ${LOG_LEVEL_INFO})  echo "INFO"  ;;
        ${LOG_LEVEL_WARN})  echo "WARN"  ;;
        ${LOG_LEVEL_ERROR}) echo "ERROR" ;;
        ${LOG_LEVEL_FATAL}) echo "FATAL" ;;
        *) echo "UNKNOWN" ;;
    esac
}

get_log_level_color() {
    local level=$1
    case ${level} in
        ${LOG_LEVEL_DEBUG}) echo "${COLOR_CYAN}" ;;
        ${LOG_LEVEL_INFO})  echo "${COLOR_GREEN}" ;;
        ${LOG_LEVEL_WARN})  echo "${COLOR_YELLOW}" ;;
        ${LOG_LEVEL_ERROR}) echo "${COLOR_RED}" ;;
        ${LOG_LEVEL_FATAL}) echo "${COLOR_RED}" ;;
        *) echo "${COLOR_RESET}" ;;
    esac
}

_log() {
    local level=$1
    shift
    local message="$*"
    
    [[ ${level} -lt ${CURRENT_LOG_LEVEL} ]] && return 0
    
    local level_name=$(get_log_level_name ${level})
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 写入日志文件
    echo "[${timestamp}] [${level_name}] ${message}" >> "${LOG_DIR}/${SCRIPT_NAME}.log"
    
    # 控制台输出
    local color=$(get_log_level_color ${level})
    local reset=""
    [[ -n "${color}" ]] && reset="${COLOR_RESET}"
    
    echo -e "${color}[${timestamp}] [${level_name}] ${message}${reset}"
    
    if [[ ${level} -eq ${LOG_LEVEL_FATAL} ]]; then
        exit 1
    fi
}

log_debug() { _log ${LOG_LEVEL_DEBUG} "$@"; }
log_info()  { _log ${LOG_LEVEL_INFO} "$@"; }
log_warn()  { _log ${LOG_LEVEL_WARN} "$@"; }
log_error() { _log ${LOG_LEVEL_ERROR} "$@"; }
log_fatal() { _log ${LOG_LEVEL_FATAL} "$@"; }

#-------------------------------------------------------------------------------
# 工具函数
#-------------------------------------------------------------------------------
# 检查命令是否存在
command_exists() {
    command -v "$1" &>/dev/null
}

# 检查是否为 root 用户
is_root() {
    [[ $EUID -eq 0 ]]
}

# 要求 root 权限
require_root() {
    if ! is_root; then
        log_error "此操作需要 root 权限"
        exit 1
    fi
}

# 检查 Tor 是否已安装
is_tor_installed() {
    [[ -x "${TOR_BIN}" ]]
}

# 获取 Tor 版本
get_tor_version() {
    if is_tor_installed; then
        "${TOR_BIN}" --version 2>/dev/null | head -1 | awk '{print $3}'
    else
        echo "not installed"
    fi
}

# 检查 Tor 是否正在运行
is_tor_running() {
    local pid_file="${RUN_DIR}/tor.pid"
    if [[ -f "${pid_file}" ]]; then
        local pid=$(cat "${pid_file}")
        [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null
    else
        pgrep -x "tor" &>/dev/null
    fi
}

# 获取 Tor PID
get_tor_pid() {
    local pid_file="${RUN_DIR}/tor.pid"
    if [[ -f "${pid_file}" ]]; then
        cat "${pid_file}"
    else
        pgrep -x "tor" | head -1
    fi
}

# 安全读取配置值
read_config_value() {
    local config_file=$1
    local key=$2
    local default=$3
    
    if [[ -f "${config_file}" ]]; then
        grep -E "^${key}=" "${config_file}" 2>/dev/null | cut -d'=' -f2- | head -1
    else
        echo "${default}"
    fi
}

# 写入配置值
write_config_value() {
    local config_file=$1
    local key=$2
    local value=$3
    
    mkdir -p "$(dirname "${config_file}")"
    
    if [[ ! -f "${config_file}" ]]; then
        echo "${key}=${value}" > "${config_file}"
        return
    fi
    
    if grep -q "^${key}=" "${config_file}" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${config_file}"
    else
        echo "${key}=${value}" >> "${config_file}"
    fi
}

# 验证端口号
validate_port() {
    local port=$1
    [[ "${port}" =~ ^[0-9]+$ ]] && [[ ${port} -ge 1 ]] && [[ ${port} -le 65535 ]]
}

# 验证国家代码
validate_country_code() {
    local code=$1
    [[ "${code}" =~ ^[A-Z]{2}$ ]]
}

# 等待进程启动
wait_for_process() {
    local pid_file=$1
    local timeout=${2:-30}
    local count=0
    
    while [[ ! -f "${pid_file}" ]] && [[ ${count} -lt ${timeout} ]]; do
        sleep 1
        ((count++))
    done
    
    [[ -f "${pid_file}" ]]
}

# 等待端口监听
wait_for_port() {
    local port=$1
    local timeout=${2:-30}
    local count=0
    
    while ! ss -tln | grep -q ":${port}" && [[ ${count} -lt ${timeout} ]]; do
        sleep 1
        ((count++))
    done
    
    ss -tln | grep -q ":${port}"
}

# 生成随机字符串
random_string() {
    local length=${1:-16}
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c ${length}
}

# 备份文件
backup_file() {
    local file=$1
    local backup_dir=${2:-${BACKUP_DIR}}
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local filename=$(basename "${file}")
    
    mkdir -p "${backup_dir}"
    cp "${file}" "${backup_dir}/${filename}.${timestamp}"
}

# 确保目录存在
ensure_dir() {
    local dir=$1
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}"
    fi
}

#-------------------------------------------------------------------------------
# 锁管理
#-------------------------------------------------------------------------------
acquire_lock() {
    local lock_file="${RUN_DIR}/${SCRIPT_NAME}.lock"
    
    if [[ -f "${lock_file}" ]]; then
        local pid=$(cat "${lock_file}")
        if kill -0 "${pid}" 2>/dev/null; then
            log_error "另一个实例正在运行 (PID: ${pid})"
            exit 1
        else
            rm -f "${lock_file}"
        fi
    fi
    
    echo $$ > "${lock_file}"
}

release_lock() {
    local lock_file="${RUN_DIR}/${SCRIPT_NAME}.lock"
    rm -f "${lock_file}"
}

# 设置退出时释放锁
trap release_lock EXIT

#-------------------------------------------------------------------------------
# 显示帮助信息
#-------------------------------------------------------------------------------
show_help() {
    local white="" cyan="" reset=""
    if [[ "${ENABLE_COLOR}" == "true" ]]; then
        white="${COLOR_WHITE}"
        cyan="${COLOR_CYAN}"
        reset="${COLOR_RESET}"
    fi
    
    cat << EOF
${white}Tor Manager v${SCRIPT_VERSION}${reset}
产品级 Tor 管理系统

${cyan}用法:${reset}
    ${SCRIPT_NAME} <命令> [选项] [参数]

${cyan}命令:${reset}
    config              配置管理
        show            显示当前配置
        edit            编辑配置文件
        wizard          配置向导
        bridge          Bridge 配置 (add|remove|list)
        exit-nodes      设置出口节点国家
        exclude-nodes   设置排除节点国家
        ports           配置端口
        check-interval  检测间隔（秒）
        max-failures    最大失败次数
        check-timeout   检测超时（秒）
        torrc-path      设置配置文件路径
    
    check               检测 Tor 连通性
        --continuous    持续检测模式
        --interval SEC  检测间隔（秒）
        --diagnose      诊断工具
    
    service             服务管理
        install         安装 systemd 服务
        uninstall       卸载 systemd 服务
        start|stop|restart|status
        enable|disable  开机自启
    
    tui                 启动交互式界面
    
    logs                查看日志
        --follow        实时跟踪
        --lines N       显示行数
    
    status              显示 Tor 状态
    version             显示版本信息
    help                显示此帮助信息

${cyan}示例:${reset}
    ${SCRIPT_NAME} config show
    ${SCRIPT_NAME} config bridge add
    ${SCRIPT_NAME} config exit-nodes {us},{ca}
    ${SCRIPT_NAME} config check-interval 300
    ${SCRIPT_NAME} check --continuous --interval 60
    ${SCRIPT_NAME} service install
    ${SCRIPT_NAME} service start

${cyan}配置文件:${reset}
    Tor 配置: ${TORRC_PATH}
    程序配置: ${ETC_DIR}/tor-manager.conf
    日志目录: ${LOG_DIR}
EOF
}

# 显示版本信息
show_version() {
    echo "${SCRIPT_NAME} version ${SCRIPT_VERSION}"
    
    if is_tor_installed; then
        echo "Tor version: $(get_tor_version)"
    else
        echo "Tor: not installed"
    fi
}

# 语言管理命令
cmd_language() {
    local lang=$1
    
    if [[ -z "${lang}" ]]; then
        # 显示当前语言和支持的语言
        echo "当前语言: $(get_language_name "$(get_language)")"
        echo ""
        echo "支持的语言:"
        local index=0
        for l in "${SUPPORTED_LANGUAGES[@]}"; do
            local name="${LANGUAGE_NAMES[${index}]}"
            local current=""
            [[ "${l}" == "$(get_language)" ]] && current=" *"
            echo "  ${l} - ${name}${current}"
            ((index++))
        done
        echo ""
        echo "用法: ${SCRIPT_NAME} lang <语言代码>"
        echo "示例: ${SCRIPT_NAME} lang zh"
        return 0
    fi
    
    # 设置语言
    if set_language "${lang}"; then
        echo "语言已设置为: $(get_language_name "$(get_language)")"
    else
        echo "不支持的语言: ${lang}"
        echo "支持的语言: ${SUPPORTED_LANGUAGES[*]}"
        return 1
    fi
}

# 显示状态
show_status() {
    local white="" cyan="" green="" yellow="" red="" reset=""
    if [[ "${ENABLE_COLOR}" == "true" ]]; then
        white="${COLOR_WHITE}"
        cyan="${COLOR_CYAN}"
        green="${COLOR_GREEN}"
        yellow="${COLOR_YELLOW}"
        red="${COLOR_RED}"
        reset="${COLOR_RESET}"
    fi
    
    echo -e "${white}=== Tor 状态 ===${reset}"
    echo ""
    
    echo -e "${cyan}安装状态:${reset}"
    if is_tor_installed; then
        echo -e "  安装路径:   ${TOR_INSTALL_DIR}"
        echo -e "  版本:       $(get_tor_version)"
    else
        echo -e "  ${yellow}Tor 未安装${reset}"
        return 0
    fi
    
    echo ""
    echo -e "${cyan}运行状态:${reset}"
    if is_tor_running; then
        echo -e "  状态:       ${green}运行中${reset}"
        echo -e "  PID:        $(get_tor_pid)"
    else
        echo -e "  状态:       ${yellow}未运行${reset}"
    fi
    
    echo ""
    echo -e "${cyan}网络配置:${reset}"
    echo -e "  SOCKS 端口: $(grep -E '^SocksPort' ${TORRC_PATH} 2>/dev/null | awk '{print $2}' || echo '9050')"
    echo -e "  Control 端口: $(grep -E '^ControlPort' ${TORRC_PATH} 2>/dev/null | awk '{print $2}' || echo '9051')"
}
