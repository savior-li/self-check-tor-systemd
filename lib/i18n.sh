#!/bin/bash
#===============================================================================
# Tor Manager - Internationalization (i18n) Module
#===============================================================================
# 支持语言: 英语、中文、西班牙语
#===============================================================================

# 支持的语言列表
SUPPORTED_LANGUAGES=("en" "zh" "es")
LANGUAGE_NAMES=(
    "English"
    "中文"
    "Español"
)

# 当前语言（默认英语）
CURRENT_LANGUAGE="en"

# 语言文件目录
LANG_DIR="${SCRIPT_DIR}/lang"

#===============================================================================
# 翻译函数
#===============================================================================

# 获取翻译
t() {
    local key="$1"
    local default="$2"
    
    # 尝试从翻译表获取
    local translation=""
    eval "translation=\${TRANSLATIONS_${CURRENT_LANGUAGE}[${key}]:-}"
    
    if [[ -n "${translation}" ]]; then
        echo "${translation}"
    elif [[ -n "${default}" ]]; then
        echo "${default}"
    else
        # 如果没有翻译，返回英文
        eval "translation=\${TRANSLATIONS_en[${key}]:-}"
        if [[ -n "${translation}" ]]; then
            echo "${translation}"
        else
            echo "${key}"
        fi
    fi
}

# 设置语言
set_language() {
    local lang="$1"
    
    # 验证语言是否支持
    if [[ " ${SUPPORTED_LANGUAGES[*]} " =~ " ${lang} " ]]; then
        CURRENT_LANGUAGE="${lang}"
        export TOR_MANAGER_LANG="${lang}"
        
        # 保存到配置文件
        if [[ -f "${ETC_DIR}/tor-manager.conf" ]]; then
            if grep -q "^LANG=" "${ETC_DIR}/tor-manager.conf" 2>/dev/null; then
                sed -i "s|^LANG=.*|LANG=${lang}|" "${ETC_DIR}/tor-manager.conf"
            else
                echo "LANG=${lang}" >> "${ETC_DIR}/tor-manager.conf"
            fi
        fi
        
        return 0
    else
        return 1
    fi
}

# 获取当前语言
get_language() {
    echo "${CURRENT_LANGUAGE}"
}

# 获取语言显示名称
get_language_name() {
    local lang="$1"
    local index=0
    
    for l in "${SUPPORTED_LANGUAGES[@]}"; do
        if [[ "${l}" == "${lang}" ]]; then
            echo "${LANGUAGE_NAMES[${index}]}"
            return
        fi
        ((index++))
    done
    
    echo "English"
}

# 自动检测系统语言
detect_system_language() {
    # 检查配置文件中的设置
    if [[ -f "${ETC_DIR}/tor-manager.conf" ]]; then
        local config_lang=$(grep "^LANG=" "${ETC_DIR}/tor-manager.conf" 2>/dev/null | cut -d= -f2)
        if [[ -n "${config_lang}" ]]; then
            set_language "${config_lang}" && return
        fi
    fi
    
    # 检查环境变量
    local sys_lang="${LANG:-${LC_ALL:-${LANGUAGE:-}}}"
    
    if [[ "${sys_lang}" =~ ^zh ]]; then
        set_language "zh"
    elif [[ "${sys_lang}" =~ ^es ]]; then
        set_language "es"
    else
        set_language "en"
    fi
}

# 初始化语言（脚本启动时调用）
init_language() {
    # 首先尝试从配置文件读取
    if [[ -f "${ETC_DIR}/tor-manager.conf" ]]; then
        local config_lang=$(grep "^LANG=" "${ETC_DIR}/tor-manager.conf" 2>/dev/null | cut -d= -f2)
        if [[ -n "${config_lang}" ]] && [[ " ${SUPPORTED_LANGUAGES[*]} " =~ " ${config_lang} " ]]; then
            set_language "${config_lang}"
            return
        fi
    fi
    
    # 其次尝试从环境变量检测
    local sys_lang="${LANG:-${LC_ALL:-${LANGUAGE:-}}}"
    
    if [[ "${sys_lang}" =~ ^zh ]]; then
        set_language "zh"
    elif [[ "${sys_lang}" =~ ^es ]]; then
        set_language "es"
    else
        set_language "en"
    fi
}

#===============================================================================
# 翻译数据 - 英语 (English)
#===============================================================================
declare -A TRANSLATIONS_en=(
    # 通用
    ["app.name"]="Tor Manager"
    ["app.version"]="Version"
    ["app.description"]="Tor Proxy Management System"
    
    # 状态
    ["status.title"]="Status Overview"
    ["status.tor.installed"]="Tor Installed"
    ["status.tor.version"]="Version"
    ["status.tor.running"]="Running"
    ["status.tor.stopped"]="Stopped"
    ["status.tor.pid"]="PID"
    ["status.tor.method"]="Run Method"
    ["status.tor.socks_port"]="SOCKS Port"
    ["status.tor.control_port"]="Control Port"
    ["status.service.enabled"]="Enabled"
    ["status.service.disabled"]="Disabled"
    ["status.service.not_installed"]="Not Installed"
    
    # 配置
    ["config.title"]="Configuration Management"
    ["config.show"]="Show Configuration"
    ["config.edit"]="Edit Configuration"
    ["config.wizard"]="Configuration Wizard"
    ["config.bridge"]="Bridge Configuration"
    ["config.ports"]="Port Configuration"
    ["config.exit_nodes"]="Exit Nodes"
    ["config.exclude_nodes"]="Exclude Nodes"
    ["config.health"]="Health Check Settings"
    ["config.torrc_path"]="Torrc Path"
    ["config.saved"]="Configuration saved"
    ["config.restart_required"]="Restart required to apply changes"
    
    # Bridge
    ["bridge.add"]="Add Bridge"
    ["bridge.remove"]="Remove Bridge"
    ["bridge.list"]="List Bridges"
    ["bridge.clear"]="Clear All Bridges"
    ["bridge.count"]="Bridge Count"
    
    # 服务
    ["service.title"]="Service Management"
    ["service.install"]="Install Service"
    ["service.uninstall"]="Uninstall Service"
    ["service.start"]="Start"
    ["service.stop"]="Stop"
    ["service.restart"]="Restart"
    ["service.status"]="Status"
    ["service.enable"]="Enable Auto-start"
    ["service.disable"]="Disable Auto-start"
    ["service.installed"]="Service installed"
    ["service.uninstalled"]="Service uninstalled"
    ["service.running"]="Service running"
    ["service.stopped"]="Service stopped"
    
    # 健康检测
    ["health.title"]="Health Check"
    ["health.check"]="Check Now"
    ["health.continuous"]="Continuous Check"
    ["health.interval"]="Check Interval"
    ["health.max_failures"]="Max Failures"
    ["health.timeout"]="Check Timeout"
    ["health.success"]="Connection OK"
    ["health.failed"]="Connection Failed"
    ["health.restarting"]="Restarting Tor..."
    ["health.diagnose"]="Diagnostic Tool"
    
    # 日志
    ["logs.title"]="Log Viewer"
    ["logs.follow"]="Follow Mode"
    ["logs.lines"]="Number of Lines"
    ["logs.not_found"]="Log file not found"
    
    # TUI 菜单
    ["menu.main"]="Main Menu"
    ["menu.status"]="Status"
    ["menu.config"]="Configuration"
    ["menu.service"]="Service"
    ["menu.health"]="Health Check"
    ["menu.logs"]="Logs"
    ["menu.language"]="Language"
    ["menu.exit"]="Exit"
    ["menu.back"]="Back"
    ["menu.select"]="Please select"
    
    # 帮助
    ["help.title"]="Help Information"
    ["help.usage"]="Usage"
    ["help.example"]="Examples"
    
    # 错误
    ["error.not_found"]="Not found"
    ["error.permission"]="Permission denied"
    ["error.invalid_param"]="Invalid parameter"
    ["error.tor_not_running"]="Tor is not running"
    ["error.service_failed"]="Service operation failed"
    
    # 确认
    ["confirm.yes"]="Yes"
    ["confirm.no"]="No"
    ["confirm.cancel"]="Cancel"
    ["confirm.continue"]="Continue?"
    
    # 其它
    ["other.loading"]="Loading..."
    ["other.saving"]="Saving..."
    ["other.done"]="Done"
    ["other.error"]="Error"
    ["other.warning"]="Warning"
    ["other.info"]="Information"
    ["other.success"]="Success"
)

#===============================================================================
# 翻译数据 - 中文 (Chinese)
#===============================================================================
declare -A TRANSLATIONS_zh=(
    # 通用
    ["app.name"]="Tor 管理器"
    ["app.version"]="版本"
    ["app.description"]="Tor 代理管理系统"
    
    # 状态
    ["status.title"]="状态概览"
    ["status.tor.installed"]="Tor 已安装"
    ["status.tor.version"]="版本"
    ["status.tor.running"]="运行中"
    ["status.tor.stopped"]="已停止"
    ["status.tor.pid"]="进程ID"
    ["status.tor.method"]="运行方式"
    ["status.tor.socks_port"]="SOCKS 端口"
    ["status.tor.control_port"]="Control 端口"
    ["status.service.enabled"]="已启用"
    ["status.service.disabled"]="已禁用"
    ["status.service.not_installed"]="未安装"
    
    # 配置
    ["config.title"]="配置管理"
    ["config.show"]="显示配置"
    ["config.edit"]="编辑配置"
    ["config.wizard"]="配置向导"
    ["config.bridge"]="网桥配置"
    ["config.ports"]="端口配置"
    ["config.exit_nodes"]="出口节点"
    ["config.exclude_nodes"]="排除节点"
    ["config.health"]="健康检测设置"
    ["config.torrc_path"]="配置文件路径"
    ["config.saved"]="配置已保存"
    ["config.restart_required"]="需要重启以应用更改"
    
    # Bridge
    ["bridge.add"]="添加网桥"
    ["bridge.remove"]="删除网桥"
    ["bridge.list"]="列出网桥"
    ["bridge.clear"]="清除所有网桥"
    ["bridge.count"]="网桥数量"
    
    # 服务
    ["service.title"]="服务管理"
    ["service.install"]="安装服务"
    ["service.uninstall"]="卸载服务"
    ["service.start"]="启动"
    ["service.stop"]="停止"
    ["service.restart"]="重启"
    ["service.status"]="状态"
    ["service.enable"]="启用开机自启"
    ["service.disable"]="禁用开机自启"
    ["service.installed"]="服务已安装"
    ["service.uninstalled"]="服务已卸载"
    ["service.running"]="服务运行中"
    ["service.stopped"]="服务已停止"
    
    # 健康检测
    ["health.title"]="健康检测"
    ["health.check"]="立即检测"
    ["health.continuous"]="持续检测"
    ["health.interval"]="检测间隔"
    ["health.max_failures"]="最大失败次数"
    ["health.timeout"]="检测超时"
    ["health.success"]="连接正常"
    ["health.failed"]="连接失败"
    ["health.restarting"]="正在重启 Tor..."
    ["health.diagnose"]="诊断工具"
    
    # 日志
    ["logs.title"]="日志查看器"
    ["logs.follow"]="跟踪模式"
    ["logs.lines"]="显示行数"
    ["logs.not_found"]="日志文件不存在"
    
    # TUI 菜单
    ["menu.main"]="主菜单"
    ["menu.status"]="状态"
    ["menu.config"]="配置"
    ["menu.service"]="服务"
    ["menu.health"]="健康检测"
    ["menu.logs"]="日志"
    ["menu.language"]="语言"
    ["menu.exit"]="退出"
    ["menu.back"]="返回"
    ["menu.select"]="请选择"
    
    # 帮助
    ["help.title"]="帮助信息"
    ["help.usage"]="使用方法"
    ["help.example"]="示例"
    
    # 错误
    ["error.not_found"]="未找到"
    ["error.permission"]="权限拒绝"
    ["error.invalid_param"]="参数无效"
    ["error.tor_not_running"]="Tor 未运行"
    ["error.service_failed"]="服务操作失败"
    
    # 确认
    ["confirm.yes"]="是"
    ["confirm.no"]="否"
    ["confirm.cancel"]="取消"
    ["confirm.continue"]="是否继续?"
    
    # 其它
    ["other.loading"]="加载中..."
    ["other.saving"]="保存中..."
    ["other.done"]="完成"
    ["other.error"]="错误"
    ["other.warning"]="警告"
    ["other.info"]="信息"
    ["other.success"]="成功"
)

#===============================================================================
# 翻译数据 - 西班牙语 (Spanish)
#===============================================================================
declare -A TRANSLATIONS_es=(
    # 通用
    ["app.name"]="Tor Manager"
    ["app.version"]="Versión"
    ["app.description"]="Sistema de Gestión de Proxy Tor"
    
    # 状态
    ["status.title"]="Estado del Sistema"
    ["status.tor.installed"]="Tor Instalado"
    ["status.tor.version"]="Versión"
    ["status.tor.running"]="Ejecutando"
    ["status.tor.stopped"]="Detenido"
    ["status.tor.pid"]="PID"
    ["status.tor.method"]="Método de Ejecución"
    ["status.tor.socks_port"]="Puerto SOCKS"
    ["status.tor.control_port"]="Puerto de Control"
    ["status.service.enabled"]="Habilitado"
    ["status.service.disabled"]="Deshabilitado"
    ["status.service.not_installed"]="No Instalado"
    
    # 配置
    ["config.title"]="Gestión de Configuración"
    ["config.show"]="Mostrar Configuración"
    ["config.edit"]="Editar Configuración"
    ["config.wizard"]="Asistente de Configuración"
    ["config.bridge"]="Configuración de Bridge"
    ["config.ports"]="Configuración de Puertos"
    ["config.exit_nodes"]="Nodos de Salida"
    ["config.exclude_nodes"]="Nodos Excluidos"
    ["config.health"]="Configuración de Salud"
    ["config.torrc_path"]="Ruta de Torrc"
    ["config.saved"]="Configuración guardada"
    ["config.restart_required"]="Reinicio necesario para aplicar cambios"
    
    # Bridge
    ["bridge.add"]="Agregar Bridge"
    ["bridge.remove"]="Eliminar Bridge"
    ["bridge.list"]="Listar Bridges"
    ["bridge.clear"]="Limpiar Todos los Bridges"
    ["bridge.count"]="Cantidad de Bridges"
    
    # 服务
    ["service.title"]="Gestión de Servicios"
    ["service.install"]="Instalar Servicio"
    ["service.uninstall"]="Desinstalar Servicio"
    ["service.start"]="Iniciar"
    ["service.stop"]="Detener"
    ["service.restart"]="Reiniciar"
    ["service.status"]="Estado"
    ["service.enable"]="Habilitar Inicio Automático"
    ["service.disable"]="Deshabilitar Inicio Automático"
    ["service.installed"]="Servicio instalado"
    ["service.uninstalled"]="Servicio desinstalado"
    ["service.running"]="Servicio en ejecución"
    ["service.stopped"]="Servicio detenido"
    
    # 健康检测
    ["health.title"]="Verificación de Salud"
    ["health.check"]="Verificar Ahora"
    ["health.continuous"]="Verificación Continua"
    ["health.interval"]="Intervalo de Verificación"
    ["health.max_failures"]="Máximo de Fallos"
    ["health.timeout"]="Tiempo de Espera"
    ["health.success"]="Conexión OK"
    ["health.failed"]="Conexión Fallida"
    ["health.restarting"]="Reiniciando Tor..."
    ["health.diagnose"]="Herramienta de Diagnóstico"
    
    # 日志
    ["logs.title"]="Visor de Registros"
    ["logs.follow"]="Modo Seguimiento"
    ["logs.lines"]="Número de Líneas"
    ["logs.not_found"]="Archivo de registro no encontrado"
    
    # TUI 菜单
    ["menu.main"]="Menú Principal"
    ["menu.status"]="Estado"
    ["menu.config"]="Configuración"
    ["menu.service"]="Servicios"
    ["menu.health"]="Salud"
    ["menu.logs"]="Registros"
    ["menu.language"]="Idioma"
    ["menu.exit"]="Salir"
    ["menu.back"]="Volver"
    ["menu.select"]="Por favor seleccione"
    
    # 帮助
    ["help.title"]="Información de Ayuda"
    ["help.usage"]="Uso"
    ["help.example"]="Ejemplos"
    
    # 错误
    ["error.not_found"]="No encontrado"
    ["error.permission"]="Permiso denegado"
    ["error.invalid_param"]="Parámetro inválido"
    ["error.tor_not_running"]="Tor no está ejecutando"
    ["error.service_failed"]="Operación de servicio fallida"
    
    # 确认
    ["confirm.yes"]="Sí"
    ["confirm.no"]="No"
    ["confirm.cancel"]="Cancelar"
    ["confirm.continue"]="Continuar?"
    
    # 其它
    ["other.loading"]="Cargando..."
    ["other.saving"]="Guardando..."
    ["other.done"]="Hecho"
    ["other.error"]="Error"
    ["other.warning"]="Advertencia"
    ["other.info"]="Información"
    ["other.success"]="Éxito"
)

#===============================================================================
# 翻译数据 - 阿拉伯语 (Arabic)
