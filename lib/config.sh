#!/bin/bash
#===============================================================================
# Tor Manager - Configuration Module
# 配置管理模块：torrc 解析与修改、Bridge 配置、ExitNodes 等
#===============================================================================

# 防止重复 source
[[ -n "${_CONFIG_SH_LOADED:-}" ]] && return 0
readonly _CONFIG_SH_LOADED=1

# 加载公共函数
source "${LIB_DIR}/common.sh"

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
TORRC_BACKUP_DIR="${BACKUP_DIR}/torrc"

#-------------------------------------------------------------------------------
# 路径自动修复函数
#-------------------------------------------------------------------------------
# 自动修复 torrc 中的绝对路径，使其适配当前目录
fix_torrc_paths() {
    local torrc_file="${TORRC_PATH}"
    
    if [[ ! -f "${torrc_file}" ]]; then
        return 0
    fi
    
    local changed=false
    
    # 修复 ClientTransportPlugin 中的路径
    # 匹配格式: ClientTransportPlugin xxx exec /old/path/to/lyrebird
    if grep -qE "^ClientTransportPlugin\s+\S+\s+exec\s+/.*/(tor|pluggable_transports)" "${torrc_file}" 2>/dev/null; then
        local old_pt_path=$(grep -oP "(?<=exec\s)/[^\s]+lyrebird" "${torrc_file}" 2>/dev/null | head -1)
        local new_pt_path="${TOR_INSTALL_DIR}/pluggable_transports/lyrebird"
        
        if [[ -n "${old_pt_path}" ]] && [[ "${old_pt_path}" != "${new_pt_path}" ]]; then
            sed -i "s|${old_pt_path}|${new_pt_path}|g" "${torrc_file}"
            log_info "已更新 ClientTransportPlugin 路径: ${new_pt_path}"
            changed=true
        fi
    fi
    
    # 修复 Log 文件路径
    # 匹配格式: Log xxx file /old/path/to/log
    if grep -qE "^Log\s+\S+\s+file\s+/" "${torrc_file}" 2>/dev/null; then
        local old_log_path=$(grep -oP "(?<=file\s)/[^\s]+\.log" "${torrc_file}" 2>/dev/null | head -1)
        local new_log_path="${TOR_LOG_DIR}/notice.log"
        
        if [[ -n "${old_log_path}" ]] && [[ "${old_log_path}" != "${new_log_path}" ]]; then
            sed -i "s|${old_log_path}|${new_log_path}|g" "${torrc_file}"
            log_info "已更新 Log 路径: ${new_log_path}"
            changed=true
        fi
    fi
    
    # 修复 DataDirectory 路径
    if grep -qE "^DataDirectory\s+/" "${torrc_file}" 2>/dev/null; then
        local old_data_path=$(grep -oP "(?<=DataDirectory\s)/[^\s]+" "${torrc_file}" 2>/dev/null | head -1)
        local new_data_path="${TOR_DATA_DIR}"
        
        if [[ -n "${old_data_path}" ]] && [[ "${old_data_path}" != "${new_data_path}" ]]; then
            sed -i "s|${old_data_path}|${new_data_path}|g" "${torrc_file}"
            log_info "已更新 DataDirectory 路径: ${new_data_path}"
            changed=true
        fi
    fi
    
    ${changed} && log_info "torrc 路径已自动更新"
    return 0
}

# 检查并创建默认 torrc
create_default_torrc() {
    local torrc_dir=$(dirname "${TORRC_PATH}")
    mkdir -p "${torrc_dir}"
    
    cat > "${TORRC_PATH}" << EOF
# Tor 配置文件 - 由 Tor Manager 自动生成
# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')

# SOCKS 代理端口
SocksPort 9050

# Control 端口
ControlPort 9051

# 数据目录
DataDirectory ${TOR_DATA_DIR}

# 日志
Log notice file ${TOR_LOG_DIR}/notice.log

# 排除出口节点（默认排除高风险国家）
ExcludeExitNodes {CN},{RU},{KP},{IR}

# 传输插件（如果存在）
EOF
    
    # 如果存在 lyrebird，添加 ClientTransportPlugin
    local lyrebird_path="${TOR_INSTALL_DIR}/pluggable_transports/lyrebird"
    if [[ -x "${lyrebird_path}" ]]; then
        echo "ClientTransportPlugin webtunnel,obfs4 exec ${lyrebird_path}" >> "${TORRC_PATH}"
    fi
    
    log_info "已创建默认配置文件: ${TORRC_PATH}"
}

#-------------------------------------------------------------------------------
# Torrc 解析函数
#-------------------------------------------------------------------------------
# 读取 torrc 配置项
torrc_get() {
    local key=$1
    local default=${2:-""}
    
    if [[ ! -f "${TORRC_PATH}" ]]; then
        echo "${default}"
        return 1
    fi
    
    local value=$(grep -E "^${key}\s+" "${TORRC_PATH}" 2>/dev/null | head -1 | sed -E "s/^${key}\s+//")
    
    if [[ -n "${value}" ]]; then
        echo "${value}"
    else
        echo "${default}"
    fi
}

# 设置 torrc 配置项
torrc_set() {
    local key=$1
    local value=$2
    
    # 确保目录存在
    mkdir -p "$(dirname ${TORRC_PATH})"
    
    # 备份
    [[ -f "${TORRC_PATH}" ]] && backup_torrc
    
    # 如果文件不存在，创建
    if [[ ! -f "${TORRC_PATH}" ]]; then
        echo "${key} ${value}" > "${TORRC_PATH}"
        return 0
    fi
    
    # 如果 key 存在，替换
    if grep -qE "^${key}\s" "${TORRC_PATH}" 2>/dev/null; then
        sed -i -E "s|^${key}\s+.*|${key} ${value}|" "${TORRC_PATH}"
    else
        # 追加
        echo "${key} ${value}" >> "${TORRC_PATH}"
    fi
    
    return 0
}

# 删除 torrc 配置项
torrc_unset() {
    local key=$1
    
    if [[ ! -f "${TORRC_PATH}" ]]; then
        return 0
    fi
    
    backup_torrc
    
    sed -i -E "/^${key}\s/d" "${TORRC_PATH}"
}

# 注释配置项
torrc_comment() {
    local key=$1
    
    if [[ ! -f "${TORRC_PATH}" ]]; then
        return 0
    fi
    
    backup_torrc
    
    sed -i -E "s|^(${key}\s)|#\1|" "${TORRC_PATH}"
}

# 取消注释
torrc_uncomment() {
    local key=$1
    
    if [[ ! -f "${TORRC_PATH}" ]]; then
        return 0
    fi
    
    backup_torrc
    
    sed -i -E "s|^#(${key}\s)|\1|" "${TORRC_PATH}"
}

# 备份 torrc
backup_torrc() {
    if [[ -f "${TORRC_PATH}" ]]; then
        mkdir -p "${TORRC_BACKUP_DIR}"
        cp "${TORRC_PATH}" "${TORRC_BACKUP_DIR}/torrc.$(date '+%Y%m%d_%H%M%S')"
        
        # 只保留最近 20 个备份
        ls -t "${TORRC_BACKUP_DIR}"/torrc.* 2>/dev/null | tail -n +21 | xargs -r rm -f
    fi
}

# 恢复 torrc
restore_torrc() {
    local backup_file=$1
    
    if [[ -f "${backup_file}" ]]; then
        cp "${backup_file}" "${TORRC_PATH}"
        log_info "已恢复配置: ${backup_file}"
        return 0
    else
        log_error "备份文件不存在: ${backup_file}"
        return 1
    fi
}

# 列出所有备份
list_torrc_backups() {
    if [[ -d "${TORRC_BACKUP_DIR}" ]]; then
        ls -lt "${TORRC_BACKUP_DIR}"/torrc.* 2>/dev/null
    fi
}

#-------------------------------------------------------------------------------
# Bridge 配置函数
#-------------------------------------------------------------------------------
# 获取所有 Bridge
bridge_list() {
    if [[ ! -f "${TORRC_PATH}" ]]; then
        return 0
    fi
    
    grep -E "^Bridge\s" "${TORRC_PATH}" 2>/dev/null | nl
}

# 获取 Bridge 数量
bridge_count() {
    if [[ ! -f "${TORRC_PATH}" ]]; then
        echo 0
        return
    fi
    
    grep -cE "^Bridge\s" "${TORRC_PATH}" 2>/dev/null || echo 0
}

# 添加 Bridge
bridge_add() {
    local bridge_line=$1
    
    if [[ -z "${bridge_line}" ]]; then
        log_error "请提供 Bridge 配置行"
        return 1
    fi
    
    # 验证 Bridge 格式并提取类型
    local bridge_type=""
    if [[ "${bridge_line}" =~ ^(obfs4|webtunnel|snowflake|meek|vanilla)\s ]]; then
        bridge_type="${BASH_REMATCH[1]}"
    else
        log_warn "Bridge 格式可能不正确，请检查: ${bridge_line}"
    fi
    
    # 检查是否已存在
    if grep -qF "Bridge ${bridge_line}" "${TORRC_PATH}" 2>/dev/null; then
        log_warn "Bridge 已存在: ${bridge_line}"
        return 0
    fi
    
    # 确保 ClientTransportPlugin 配置存在
    ensure_transport_plugin "${bridge_type}"
    
    # 添加 Bridge
    torrc_set "Bridge" "${bridge_line}"
    
    log_info "已添加 Bridge: ${bridge_line}"
    
    # 如果是第一个 Bridge，自动启用 UseBridges
    if [[ $(bridge_count) -eq 1 ]]; then
        torrc_set "UseBridges" "1"
        log_info "已自动启用 UseBridges"
    fi
}

# 确保 ClientTransportPlugin 配置存在
ensure_transport_plugin() {
    local bridge_type=$1
    
    # 检查 pluggable_transports 目录
    local pt_dir="${TOR_INSTALL_DIR}/pluggable_transports"
    local lyrebird_path=""
    
    if [[ -x "${pt_dir}/lyrebird" ]]; then
        lyrebird_path="${pt_dir}/lyrebird"
    fi
    
    # 根据类型添加 ClientTransportPlugin
    case "${bridge_type}" in
        webtunnel|obfs4|obfs3|scramblesuit|meek_lite)
            if [[ -n "${lyrebird_path}" ]]; then
                # 检查是否已有 webtunnel 或 obfs4 的配置
                if ! grep -qE "^ClientTransportPlugin\s+(webtunnel|obfs4)" "${TORRC_PATH}" 2>/dev/null; then
                    # 添加或更新 ClientTransportPlugin 行
                    if grep -qE "^ClientTransportPlugin" "${TORRC_PATH}" 2>/dev/null; then
                        # 已有其他 ClientTransportPlugin，追加类型
                        sed -i -E "s|^(ClientTransportPlugin\s+)(.*)|\1\2,${bridge_type}|" "${TORRC_PATH}" 2>/dev/null
                    else
                        # 没有 ClientTransportPlugin，添加新行
                        echo "ClientTransportPlugin ${bridge_type} exec ${lyrebird_path}" >> "${TORRC_PATH}"
                    fi
                    log_info "已配置 ClientTransportPlugin: ${bridge_type}"
                fi
            else
                log_warn "未找到 lyrebird，无法配置 ${bridge_type} 传输插件"
            fi
            ;;
        snowflake)
            # snowflake 需要单独的客户端
            if [[ -x "${pt_dir}/snowflake-client" ]]; then
                if ! grep -qE "^ClientTransportPlugin\s+snowflake" "${TORRC_PATH}" 2>/dev/null; then
                    echo "ClientTransportPlugin snowflake exec ${pt_dir}/snowflake-client" >> "${TORRC_PATH}"
                    log_info "已配置 ClientTransportPlugin: snowflake"
                fi
            else
                log_warn "未找到 snowflake-client"
            fi
            ;;
    esac
}

# 删除 Bridge（按行号）
bridge_remove() {
    local line_num=$1
    
    if [[ -z "${line_num}" ]]; then
        log_error "请提供要删除的 Bridge 行号"
        return 1
    fi
    
    local total=$(bridge_count)
    
    if [[ ${line_num} -lt 1 || ${line_num} -gt ${total} ]]; then
        log_error "无效的行号: ${line_num} (共 ${total} 个 Bridge)"
        return 1
    fi
    
    # 获取要删除的 Bridge 行
    local bridge_line=$(sed -n "$((line_num))p" <(grep -E "^Bridge\s" "${TORRC_PATH}"))
    
    backup_torrc
    
    # 删除指定的 Bridge 行
    sed -i -E "/^Bridge\s/d" "${TORRC_PATH}"
    
    # 重新添加其他 Bridge（跳过被删除的）
    local current=0
    while IFS= read -r line; do
        ((current++))
        if [[ ${current} -ne ${line_num} ]]; then
            echo "${line}" >> "${TORRC_PATH}.tmp"
        fi
    done < <(grep -E "^Bridge\s" "${TORRC_PATH}.bak" 2>/dev/null)
    
    log_info "已删除 Bridge: ${bridge_line}"
    
    # 如果没有 Bridge 了，禁用 UseBridges
    if [[ $(bridge_count) -eq 0 ]]; then
        torrc_unset "UseBridges"
        log_info "已禁用 UseBridges（无 Bridge）"
    fi
}

# 清除所有 Bridge
bridge_clear() {
    if [[ $(bridge_count) -eq 0 ]]; then
        log_info "没有 Bridge 配置"
        return 0
    fi
    
    backup_torrc
    
    sed -i -E "/^Bridge\s/d" "${TORRC_PATH}"
    torrc_unset "UseBridges"
    
    log_info "已清除所有 Bridge"
}

# 批量添加 Bridge（从文件或标准输入）
bridge_import() {
    local input_file=$1
    local count=0
    
    while IFS= read -r line; do
        # 跳过空行和注释
        [[ -z "${line}" || "${line}" =~ ^# ]] && continue
        
        bridge_add "${line}"
        ((count++))
    done < "${input_file:-/dev/stdin}"
    
    log_info "已导入 ${count} 个 Bridge"
}

# 导出 Bridge
bridge_export() {
    local output_file=$1
    
    if [[ $(bridge_count) -eq 0 ]]; then
        log_warn "没有 Bridge 配置"
        return 0
    fi
    
    local bridges=$(grep -E "^Bridge\s" "${TORRC_PATH}" | sed 's/^Bridge\s*//')
    
    if [[ -n "${output_file}" ]]; then
        echo "${bridges}" > "${output_file}"
        log_info "已导出到: ${output_file}"
    else
        echo "${bridges}"
    fi
}

#-------------------------------------------------------------------------------
# ExitNodes 配置函数
#-------------------------------------------------------------------------------
# 获取当前 ExitNodes
exit_nodes_get() {
    torrc_get "ExitNodes" ""
}

# 设置 ExitNodes
exit_nodes_set() {
    local nodes=$1
    
    if [[ -z "${nodes}" ]]; then
        log_error "请提供国家代码（如 {us},{de},{nl}）"
        return 1
    fi
    
    # 验证格式
    if [[ ! "${nodes}" =~ ^\{[A-Z]{2}(,\{[A-Z]{2}\})*\}$ ]]; then
        log_warn "ExitNodes 格式建议为: {cc} 或 {cc1},{cc2}..."
    fi
    
    torrc_set "ExitNodes" "${nodes}"
    log_info "已设置 ExitNodes: ${nodes}"
}

# 清除 ExitNodes
exit_nodes_clear() {
    torrc_unset "ExitNodes"
    log_info "已清除 ExitNodes"
}

# 添加出口节点国家
exit_nodes_add() {
    local country=$1
    
    country=${country^^}  # 转大写
    
    if ! validate_country_code "${country}"; then
        log_error "无效的国家代码: ${country}"
        return 1
    fi
    
    local current=$(exit_nodes_get)
    local new_node="{${country}}"
    
    if [[ -z "${current}" ]]; then
        exit_nodes_set "${new_node}"
    elif [[ "${current}" == *"${new_node}"* ]]; then
        log_warn "国家 ${country} 已在 ExitNodes 中"
    else
        exit_nodes_set "${current},${new_node}"
    fi
}

# 移除出口节点国家
exit_nodes_remove() {
    local country=$1
    
    country=${country^^}
    
    local current=$(exit_nodes_get)
    local to_remove="{${country}}"
    
    if [[ -z "${current}" ]]; then
        log_warn "ExitNodes 为空"
        return 0
    fi
    
    local new_value="${current//${to_remove}/}"
    new_value="${new_value//,,/,}"
    new_value="${new_value#,}"
    new_value="${new_value%,}"
    
    if [[ -z "${new_value}" ]]; then
        exit_nodes_clear
    else
        torrc_set "ExitNodes" "${new_value}"
        log_info "已移除 ${country}，当前 ExitNodes: ${new_value}"
    fi
}

# 列出常用国家代码
show_country_codes() {
    cat << EOF
${C_WHITE}常用国家代码:${C_RESET}
  US - 美国     DE - 德国     NL - 荷兰     CH - 瑞士
  CA - 加拿大   GB - 英国     FR - 法国     SE - 瑞典
  JP - 日本     SG - 新加坡   AU - 澳大利亚 HK - 香港
  FI - 芬兰     NO - 挪威     IS - 冰岛     RO - 罗马尼亚

${C_WHITE}建议排除的国家:${C_RESET}
  CN - 中国     RU - 俄罗斯   KP - 朝鲜     IR - 伊朗
  BY - 白俄罗斯 SA - 沙特     AE - 阿联酋   PK - 巴基斯坦

${C_WHITE}格式说明:${C_RESET}
  单个国家: {US}
  多个国家: {US},{DE},{NL}
  
${C_WHITE}设置示例:${C_RESET}
  tor-manager config exit-nodes {US},{DE}
  tor-manager config exit-nodes add DE
  tor-manager config exclude-nodes {CN},{RU}
EOF
}

#-------------------------------------------------------------------------------
# ExcludeExitNodes 配置函数
#-------------------------------------------------------------------------------
# 获取当前 ExcludeExitNodes
exclude_nodes_get() {
    torrc_get "ExcludeExitNodes" ""
}

# 设置 ExcludeExitNodes
exclude_nodes_set() {
    local nodes=$1
    
    if [[ -z "${nodes}" ]]; then
        log_error "请提供国家代码（如 {cn},{ru},{kp}）"
        return 1
    fi
    
    # 验证格式
    if [[ ! "${nodes}" =~ ^\{[A-Z]{2}(,\{[A-Z]{2}\})*\}$ ]]; then
        log_warn "ExcludeExitNodes 格式建议为: {cc} 或 {cc1},{cc2}..."
    fi
    
    torrc_set "ExcludeExitNodes" "${nodes}"
    log_info "已设置 ExcludeExitNodes: ${nodes}"
}

# 清除 ExcludeExitNodes
exclude_nodes_clear() {
    torrc_unset "ExcludeExitNodes"
    log_info "已清除 ExcludeExitNodes"
}

# 添加排除节点国家
exclude_nodes_add() {
    local country=$1
    
    country=${country^^}  # 转大写
    
    if ! validate_country_code "${country}"; then
        log_error "无效的国家代码: ${country}"
        return 1
    fi
    
    local current=$(exclude_nodes_get)
    local new_node="{${country}}"
    
    if [[ -z "${current}" ]]; then
        exclude_nodes_set "${new_node}"
    elif [[ "${current}" == *"${new_node}"* ]]; then
        log_warn "国家 ${country} 已在 ExcludeExitNodes 中"
    else
        exclude_nodes_set "${current},${new_node}"
    fi
}

# 移除排除节点国家
exclude_nodes_remove() {
    local country=$1
    
    country=${country^^}
    
    local current=$(exclude_nodes_get)
    local to_remove="{${country}}"
    
    if [[ -z "${current}" ]]; then
        log_warn "ExcludeExitNodes 为空"
        return 0
    fi
    
    local new_value="${current//${to_remove}/}"
    new_value="${new_value//,,/,}"
    new_value="${new_value#,}"
    new_value="${new_value%,}"
    
    if [[ -z "${new_value}" ]]; then
        exclude_nodes_clear
    else
        torrc_set "ExcludeExitNodes" "${new_value}"
        log_info "已移除 ${country}，当前 ExcludeExitNodes: ${new_value}"
    fi
}

#-------------------------------------------------------------------------------
# 配置文件路径函数
#-------------------------------------------------------------------------------
# 获取当前配置文件路径
get_torrc_path() {
    echo "${TORRC_PATH}"
}

# 设置配置文件路径
set_torrc_path() {
    local path=$1
    
    if [[ -z "${path}" ]]; then
        log_error "请提供配置文件路径"
        return 1
    fi
    
    # 转换为绝对路径
    if [[ "${path}" != /* ]]; then
        path="${SCRIPT_DIR}/${path}"
    fi
    
    # 检查目录是否存在
    local dir=$(dirname "${path}")
    if [[ ! -d "${dir}" ]]; then
        log_error "目录不存在: ${dir}"
        return 1
    fi
    
    # 更新全局变量
    TORRC_PATH="${path}"
    
    # 写入程序配置
    write_config_value "${ETC_DIR}/tor-manager.conf" "TORRC_PATH" "${path}"
    
    log_info "已设置配置文件路径: ${path}"
}

# 显示配置帮助信息
show_config_help() {
    cat << EOF
${C_WHITE}=== Tor 配置帮助 ===${C_RESET}

${C_CYAN}1. ExitNodes (出口节点)${C_RESET}
  指定 Tor 出口节点的国家/地区
  格式: {国家代码} 或 {国家代码1},{国家代码2},...
  示例: {US},{CA},{DE}
  
${C_CYAN}2. ExcludeExitNodes (排除出口节点)${C_RESET}
  指定不使用的出口节点国家/地区
  默认值: {CN},{RU},{KP}
  格式: 同 ExitNodes
  
${C_CYAN}3. Bridge (网桥)${C_RESET}
  支持类型: obfs4, webtunnel, snowflake, meek
  格式: Bridge <类型> <地址> <指纹> [参数]
  示例: Bridge webtunnel 1.2.3.4:443 ABCDEF url=https://...
  
${C_CYAN}4. 端口配置${C_RESET}
  SOCKS 端口: 默认 9050，范围 1-65535
  Control 端口: 默认 9051，范围 1-65535
  
${C_CYAN}5. 健康检测配置${C_RESET}
  检测间隔: 默认 300 秒（5 分钟），最小 10 秒
  最大失败次数: 默认 3 次，范围 1-100
  检测超时: 默认 30 秒，范围 5-300 秒
  
${C_CYAN}6. 配置文件路径${C_RESET}
  默认: 当前目录/torrc
  可通过 torrc-path 命令修改
  
${C_CYAN}国家代码参考:${C_RESET}
  常用: US(美国), DE(德国), NL(荷兰), CH(瑞士), JP(日本)
  建议排除: CN(中国), RU(俄罗斯), KP(朝鲜), IR(伊朗)
  
${C_CYAN}命令示例:${C_RESET}
  tor-manager config show                    显示当前配置
  tor-manager config exit-nodes {US},{CA}    设置出口节点
  tor-manager config exclude-nodes {CN},{RU} 设置排除节点
  tor-manager config bridge add "webtunnel ..." 添加 Bridge
  tor-manager config ports --socks 9050      设置端口
  tor-manager config check-interval 300      设置检测间隔 5 分钟
  tor-manager config max-failures 3          设置最大失败 3 次
  tor-manager config check-timeout 30        设置检测超时 30 秒
  tor-manager config torrc-path /path/to/torrc 设置配置文件路径
EOF
}

#-------------------------------------------------------------------------------
# 端口配置函数
#-------------------------------------------------------------------------------
# 获取 SOCKS 端口
get_socks_port() {
    local port=$(torrc_get "SocksPort" "9050")
    echo "${port%% *}"  # 只取端口号，去掉可能的地址
}

# 设置 SOCKS 端口
set_socks_port() {
    local port=$1
    
    if ! validate_port "${port}"; then
        log_error "无效的端口号: ${port}"
        return 1
    fi
    
    torrc_set "SocksPort" "${port}"
    log_info "已设置 SOCKS 端口: ${port}"
}

# 获取 Control 端口
get_control_port() {
    torrc_get "ControlPort" "9051"
}

# 设置 Control 端口
set_control_port() {
    local port=$1
    
    if ! validate_port "${port}"; then
        log_error "无效的端口号: ${port}"
        return 1
    fi
    
    torrc_set "ControlPort" "${port}"
    log_info "已设置 Control 端口: ${port}"
}

# 批量设置端口
set_ports() {
    local socks_port=""
    local control_port=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --socks|-s)
                socks_port="$2"
                shift 2
                ;;
            --control|-c)
                control_port="$2"
                shift 2
                ;;
            *)
                log_error "未知参数: $1"
                return 1
                ;;
        esac
    done
    
    [[ -n "${socks_port}" ]] && set_socks_port "${socks_port}"
    [[ -n "${control_port}" ]] && set_control_port "${control_port}"
}

#-------------------------------------------------------------------------------
# 日志配置函数
#-------------------------------------------------------------------------------
# 获取日志级别
get_log_level() {
    torrc_get "Log" "notice" | grep -oP '(?<=^notice file ).*' || echo "${TOR_LOG_DIR}/notice.log"
}

# 设置日志级别
set_log_level() {
    local level=$1
    local log_file=$2
    
    local valid_levels=(err warn notice info debug)
    
    if [[ ! " ${valid_levels[*]} " =~ " ${level} " ]]; then
        log_error "无效的日志级别: ${level} (有效: ${valid_levels[*]})"
        return 1
    fi
    
    if [[ -n "${log_file}" ]]; then
        torrc_set "Log" "${level} file ${log_file}"
    else
        torrc_set "Log" "${level} file ${TOR_LOG_DIR}/${level}.log"
    fi
    
    log_info "已设置日志级别: ${level}"
}

# 设置日志文件
set_log_file() {
    local file=$1
    
    if [[ -z "${file}" ]]; then
        log_error "请提供日志文件路径"
        return 1
    fi
    
    # 确保目录存在
    mkdir -p "$(dirname "${file}")"
    
    local level=$(torrc_get "Log" "notice" | awk '{print $1}')
    torrc_set "Log" "${level} file ${file}"
    
    log_info "已设置日志文件: ${file}"
}

#-------------------------------------------------------------------------------
# 其他配置函数
#-------------------------------------------------------------------------------
# 启用/禁用 Cookie 认证
set_cookie_auth() {
    local enabled=$1
    
    if [[ "${enabled,,}" == "true" || "${enabled,,}" == "1" || "${enabled,,}" == "yes" ]]; then
        torrc_set "CookieAuthentication" "1"
        log_info "已启用 Cookie 认证"
    else
        torrc_set "CookieAuthentication" "0"
        log_info "已禁用 Cookie 认证"
    fi
}

# 设置数据目录
set_data_directory() {
    local dir=$1
    
    if [[ -z "${dir}" ]]; then
        log_error "请提供数据目录路径"
        return 1
    fi
    
    mkdir -p "${dir}"
    chown -R tor:tor "${dir}" 2>/dev/null || true
    chmod 700 "${dir}"
    
    torrc_set "DataDirectory" "${dir}"
    log_info "已设置数据目录: ${dir}"
}

#-------------------------------------------------------------------------------
# 健康检测配置函数
#-------------------------------------------------------------------------------
# 获取检测间隔
get_check_interval() {
    echo "${CHECK_INTERVAL:-300}"
}

# 设置检测间隔
set_check_interval() {
    local interval=$1
    
    if [[ ! "${interval}" =~ ^[0-9]+$ ]] || [[ ${interval} -lt 10 ]]; then
        log_error "无效的检测间隔: ${interval} (最小 10 秒)"
        return 1
    fi
    
    _update_config_file "CHECK_INTERVAL" "${interval}"
    CHECK_INTERVAL="${interval}"
    log_info "已设置检测间隔: ${interval} 秒"
}

# 获取最大失败次数
get_max_failures() {
    echo "${MAX_FAILURES:-3}"
}

# 设置最大失败次数
set_max_failures() {
    local count=$1
    
    if [[ ! "${count}" =~ ^[0-9]+$ ]] || [[ ${count} -lt 1 ]] || [[ ${count} -gt 100 ]]; then
        log_error "无效的失败次数: ${count} (范围 1-100)"
        return 1
    fi
    
    _update_config_file "MAX_FAILURES" "${count}"
    MAX_FAILURES="${count}"
    log_info "已设置最大失败次数: ${count}"
}

# 获取检测超时
get_check_timeout() {
    echo "${CHECK_TIMEOUT:-30}"
}

# 设置检测超时
set_check_timeout() {
    local timeout=$1
    
    if [[ ! "${timeout}" =~ ^[0-9]+$ ]] || [[ ${timeout} -lt 5 ]] || [[ ${timeout} -gt 300 ]]; then
        log_error "无效的超时时间: ${timeout} (范围 5-300 秒)"
        return 1
    fi
    
    _update_config_file "CHECK_TIMEOUT" "${timeout}"
    CHECK_TIMEOUT="${timeout}"
    log_info "已设置检测超时: ${timeout} 秒"
}

# 更新配置文件中的参数
_update_config_file() {
    local key=$1
    local value=$2
    local config_file="${ETC_DIR}/tor-manager.conf"
    
    if [[ ! -f "${config_file}" ]]; then
        log_error "配置文件不存在: ${config_file}"
        return 1
    fi
    
    # 使用 sed 更新配置文件
    if grep -q "^${key}=" "${config_file}" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${config_file}"
    else
        # 如果不存在，添加到文件末尾
        echo "${key}=${value}" >> "${config_file}"
    fi
}

# 显示健康检测配置
show_health_config() {
    echo -e "${C_WHITE}=== 健康检测配置 ===${C_RESET}"
    echo ""
    echo -e "${C_CYAN}检测参数:${C_RESET}"
    echo -e "  检测间隔:       $(get_check_interval) 秒"
    echo -e "  最大失败次数:   $(get_max_failures)"
    echo -e "  检测超时:       $(get_check_timeout) 秒"
    echo ""
    echo -e "${C_CYAN}命令示例:${C_RESET}"
    echo "  tor-manager config check-interval 300   # 设置检测间隔 5 分钟"
    echo "  tor-manager config max-failures 3       # 设置最大失败 3 次"
    echo "  tor-manager config check-timeout 30     # 设置超时 30 秒"
}

#-------------------------------------------------------------------------------
# 配置显示函数
#-------------------------------------------------------------------------------
# 显示当前配置
show_config() {
    echo -e "${C_WHITE}=== Tor 配置 ===${C_RESET}"
    
    echo ""
    echo -e "${C_CYAN}配置文件:${C_RESET}"
    echo -e "  路径:           ${TORRC_PATH}"
    if [[ ! -f "${TORRC_PATH}" ]]; then
        echo -e "  状态:           ${C_YELLOW}不存在${C_RESET}"
        return 0
    fi
    
    echo ""
    echo -e "${C_CYAN}基础配置:${C_RESET}"
    echo -e "  SOCKS 端口:     $(get_socks_port)"
    echo -e "  Control 端口:   $(get_control_port)"
    echo -e "  数据目录:       $(torrc_get "DataDirectory" "${TOR_DATA_DIR}")"
    
    echo ""
    echo -e "${C_CYAN}日志配置:${C_RESET}"
    echo -e "  日志级别:       $(torrc_get "Log" "notice" | awk '{print $1}')"
    
    echo ""
    echo -e "${C_CYAN}出口节点配置:${C_RESET}"
    local exit_nodes=$(exit_nodes_get)
    if [[ -n "${exit_nodes}" ]]; then
        echo -e "  ExitNodes:      ${C_GREEN}${exit_nodes}${C_RESET}"
    else
        echo -e "  ExitNodes:      ${C_YELLOW}未设置（自动选择）${C_RESET}"
    fi
    
    local exclude_nodes=$(exclude_nodes_get)
    if [[ -n "${exclude_nodes}" ]]; then
        echo -e "  ExcludeNodes:   ${C_RED}${exclude_nodes}${C_RESET}"
    else
        echo -e "  ExcludeNodes:   ${C_YELLOW}未设置${C_RESET}"
    fi
    
    echo ""
    echo -e "${C_CYAN}Bridge 配置:${C_RESET}"
    local bridge_count=$(bridge_count)
    if [[ ${bridge_count} -gt 0 ]]; then
        echo -e "  Bridge 数量:    ${C_GREEN}${bridge_count}${C_RESET}"
        echo -e "  UseBridges:     $(torrc_get "UseBridges" "0")"
        bridge_list | while read line; do
            echo -e "    ${line}"
        done
    else
        echo -e "  ${C_YELLOW}未配置 Bridge${C_RESET}"
    fi
    
    echo ""
    echo -e "${C_CYAN}健康检测配置:${C_RESET}"
    echo -e "  检测间隔:       $(get_check_interval) 秒 ($(( $(get_check_interval) / 60 )) 分钟)"
    echo -e "  最大失败次数:   $(get_max_failures)"
    echo -e "  检测超时:       $(get_check_timeout) 秒"
    
    # 显示备份列表
    local backups=$(list_torrc_backups | wc -l)
    if [[ ${backups} -gt 0 ]]; then
        echo ""
        echo -e "${C_CYAN}备份:${C_RESET}"
        echo -e "  备份数量: ${backups}"
    fi
}

# 编辑配置文件
edit_config() {
    local editor=${EDITOR:-nano}
    
    if ! command_exists "${editor}"; then
        editor="vi"
    fi
    
    if [[ ! -f "${TORRC_PATH}" ]]; then
        log_warn "配置文件不存在，将创建新文件"
        create_default_torrc
    fi
    
    backup_torrc
    
    log_info "打开配置文件编辑器..."
    "${editor}" "${TORRC_PATH}"
    
    log_info "配置已修改，请重启 Tor 使配置生效"
}

#-------------------------------------------------------------------------------
# 配置向导
#-------------------------------------------------------------------------------
# 交互式配置向导
config_wizard() {
    echo -e "${C_WHITE}=== Tor 配置向导 ===${C_RESET}"
    echo ""
    
    # SOCKS 端口
    local current_socks=$(get_socks_port)
    echo -en "${C_CYAN}SOCKS 端口 [${current_socks}]: ${C_RESET}"
    read -r new_socks
    [[ -n "${new_socks}" ]] && set_socks_port "${new_socks}"
    
    # Control 端口
    local current_control=$(get_control_port)
    echo -en "${C_CYAN}Control 端口 [${current_control}]: ${C_RESET}"
    read -r new_control
    [[ -n "${new_control}" ]] && set_control_port "${new_control}"
    
    # ExitNodes
    local current_exit=$(exit_nodes_get)
    echo -en "${C_CYAN}ExitNodes (如 {US},{DE},留空不限制) [${current_exit}]: ${C_RESET}"
    read -r new_exit
    if [[ -n "${new_exit}" ]]; then
        if [[ "${new_exit}" == "clear" || "${new_exit}" == "none" ]]; then
            exit_nodes_clear
        else
            exit_nodes_set "${new_exit}"
        fi
    fi
    
    # Bridge 配置
    if confirm "是否配置 Bridge？" "n"; then
        echo -e "${C_CYAN}请选择 Bridge 类型:${C_RESET}"
        echo "  1. obfs4"
        echo "  2. webtunnel"
        echo "  3. snowflake"
        echo "  4. 手动输入"
        echo -en "选择 [1-4]: "
        read -r bridge_type
        
        case ${bridge_type} in
            1|2|3)
                echo -e "${C_YELLOW}请从 https://bridges.torproject.org/ 获取 Bridge 地址${C_RESET}"
                echo -en "粘贴 Bridge 配置: "
                read -r bridge_line
                [[ -n "${bridge_line}" ]] && bridge_add "${bridge_line}"
                ;;
            4)
                echo -en "输入完整的 Bridge 行: "
                read -r bridge_line
                [[ -n "${bridge_line}" ]] && bridge_add "${bridge_line}"
                ;;
        esac
    fi
    
    echo ""
    log_info "配置完成！"
    show_config
}

#-------------------------------------------------------------------------------
# 主命令函数
#-------------------------------------------------------------------------------
cmd_config() {
    local subcommand=$1
    shift
    
    case "${subcommand}" in
        bridge)
            local action=$1
            shift
            case "${action}" in
                add)    bridge_add "$@" ;;
                remove) bridge_remove "$@" ;;
                list)   bridge_list ;;
                clear)  bridge_clear ;;
                import) bridge_import "$@" ;;
                export) bridge_export "$@" ;;
                *)      log_error "未知 Bridge 操作: ${action}"; return 1 ;;
            esac
            ;;
        exit-nodes|exit)
            local action=$1
            shift
            case "${action}" in
                ""|show)    exit_nodes_get ;;
                set)        exit_nodes_set "$@" ;;
                add)        exit_nodes_add "$@" ;;
                remove)     exit_nodes_remove "$@" ;;
                clear)      exit_nodes_clear ;;
                countries)  show_country_codes ;;
                *)          exit_nodes_set "${action} $*" ;;
            esac
            ;;
        exclude-nodes|exclude)
            local action=$1
            shift
            case "${action}" in
                ""|show)    exclude_nodes_get ;;
                set)        exclude_nodes_set "$@" ;;
                add)        exclude_nodes_add "$@" ;;
                remove)     exclude_nodes_remove "$@" ;;
                clear)      exclude_nodes_clear ;;
                *)          exclude_nodes_set "${action} $*" ;;
            esac
            ;;
        ports)
            set_ports "$@"
            ;;
        socks-port)
            set_socks_port "$@"
            ;;
        control-port)
            set_control_port "$@"
            ;;
        log-level)
            set_log_level "$@"
            ;;
        check-interval)
            if [[ -z "$1" ]]; then
                echo "当前检测间隔: $(get_check_interval) 秒"
            else
                set_check_interval "$1"
            fi
            ;;
        max-failures)
            if [[ -z "$1" ]]; then
                echo "当前最大失败次数: $(get_max_failures)"
            else
                set_max_failures "$1"
            fi
            ;;
        check-timeout)
            if [[ -z "$1" ]]; then
                echo "当前检测超时: $(get_check_timeout) 秒"
            else
                set_check_timeout "$1"
            fi
            ;;
        health)
            show_health_config
            ;;
        torrc-path)
            local action=$1
            case "${action}" in
                ""|show)    get_torrc_path ;;
                set)        shift; set_torrc_path "$@" ;;
                *)          set_torrc_path "${action}" ;;
            esac
            ;;
        show)
            show_config
            ;;
        edit)
            edit_config
            ;;
        wizard)
            config_wizard
            ;;
        restore)
            restore_torrc "$@"
            ;;
        backups)
            list_torrc_backups
            ;;
        help|--help|-h)
            show_config_help
            ;;
        *)
            log_error "未知配置命令: ${subcommand}"
            echo "可用命令:"
            echo "  bridge         Bridge 配置 (add|remove|list|clear)"
            echo "  exit-nodes     出口节点配置"
            echo "  exclude-nodes  排除节点配置"
            echo "  ports          端口配置"
            echo "  check-interval 检测间隔（秒）"
            echo "  max-failures   最大失败次数"
            echo "  check-timeout  检测超时（秒）"
            echo "  torrc-path     配置文件路径"
            echo "  show           显示当前配置"
            echo "  edit           编辑配置文件"
            echo "  wizard         配置向导"
            echo "  help           显示帮助信息"
            return 1
            ;;
    esac
}
