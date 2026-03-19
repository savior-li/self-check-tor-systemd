#!/bin/bash
#===============================================================================
# Tor Manager - Internationalization (i18n) Module
#===============================================================================
# 支持语言: 英语、中文、西班牙语、阿拉伯语、印尼语、葡萄牙语、法语、日语
#===============================================================================

# 支持的语言列表
SUPPORTED_LANGUAGES=("en" "zh" "es" "ar" "id" "pt" "fr" "ja")
LANGUAGE_NAMES=(
    "English"
    "中文"
    "Español"
    "العربية"
    "Bahasa Indonesia"
    "Português"
    "Français"
    "日本語"
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
    elif [[ "${sys_lang}" =~ ^ar ]]; then
        set_language "ar"
    elif [[ "${sys_lang}" =~ ^id ]]; then
        set_language "id"
    elif [[ "${sys_lang}" =~ ^pt ]]; then
        set_language "pt"
    elif [[ "${sys_lang}" =~ ^fr ]]; then
        set_language "fr"
    elif [[ "${sys_lang}" =~ ^ja ]]; then
        set_language "ja"
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
    elif [[ "${sys_lang}" =~ ^ar ]]; then
        set_language "ar"
    elif [[ "${sys_lang}" =~ ^id ]]; then
        set_language "id"
    elif [[ "${sys_lang}" =~ ^pt ]]; then
        set_language "pt"
    elif [[ "${sys_lang}" =~ ^fr ]]; then
        set_language "fr"
    elif [[ "${sys_lang}" =~ ^ja ]]; then
        set_language "ja"
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
#===============================================================================
declare -A TRANSLATIONS_ar=(
    # 通用
    ["app.name"]="مدير تور"
    ["app.version"]="الإصدار"
    ["app.description"]="نظام إدارة بروكسي تور"
    
    # 状态
    ["status.title"]="نظرة عامة على الحالة"
    ["status.tor.installed"]="تور مثبت"
    ["status.tor.version"]="الإصدار"
    ["status.tor.running"]="قيد التشغيل"
    ["status.tor.stopped"]="متوقف"
    ["status.tor.pid"]="معرف العملية"
    ["status.tor.method"]="طريقة التشغيل"
    ["status.tor.socks_port"]="منفذ SOCKS"
    ["status.tor.control_port"]="منفذ التحكم"
    ["status.service.enabled"]="مفعّل"
    ["status.service.disabled"]="معطّل"
    ["status.service.not_installed"]="غير مثبت"
    
    # 配置
    ["config.title"]="إدارة التكوين"
    ["config.show"]="عرض التكوين"
    ["config.edit"]="تحرير التكوين"
    ["config.wizard"]="معالج التكوين"
    ["config.bridge"]="تكوين الجسر"
    ["config.ports"]="تكوين المنافذ"
    ["config.exit_nodes"]="عقد الخروج"
    ["config.exclude_nodes"]="عقد مستثناة"
    ["config.health"]="إعدادات الصحة"
    ["config.torrc_path"]="مسار التكوين"
    ["config.saved"]="تم حفظ التكوين"
    ["config.restart_required"]="إعادة التشغيل مطلوبة لتطبيق التغييرات"
    
    # Bridge
    ["bridge.add"]="إضافة جسر"
    ["bridge.remove"]="إزالة جسر"
    ["bridge.list"]="قائمة الجسور"
    ["bridge.clear"]="مسح جميع الجسور"
    ["bridge.count"]="عدد الجسور"
    
    # 服务
    ["service.title"]="إدارة الخدمات"
    ["service.install"]="تثبيت الخدمة"
    ["service.uninstall"]="إلغاء تثبيت الخدمة"
    ["service.start"]="بدء"
    ["service.stop"]="إيقاف"
    ["service.restart"]="إعادة التشغيل"
    ["service.status"]="الحالة"
    ["service.enable"]="تفعيل البدء التلقائي"
    ["service.disable"]="تعطيل البدء التلقائي"
    ["service.installed"]="الخدمة مثبتة"
    ["service.uninstalled"]="الخدمة غير مثبتة"
    ["service.running"]="الخدمة قيد التشغيل"
    ["service.stopped"]="الخدمة متوقفة"
    
    # 健康检测
    ["health.title"]="فحص الصحة"
    ["health.check"]="افحص الآن"
    ["health.continuous"]="فحص مستمر"
    ["health.interval"]="فترة الفحص"
    ["health.max_failures"]="الحد الأقصى للفشل"
    ["health.timeout"]="مهلة الفحص"
    ["health.success"]="الاتصال ناجح"
    ["health.failed"]="الاتصال فاشل"
    ["health.restarting"]="جاري إعادة تشغيل تور..."
    ["health.diagnose"]="أداة التشخيص"
    
    # 日志
    ["logs.title"]="عارض السجلات"
    ["logs.follow"]="وضع المتابعة"
    ["logs.lines"]="عدد الأسطر"
    ["logs.not_found"]="ملف السجل غير موجود"
    
    # TUI 菜单
    ["menu.main"]="القائمة الرئيسية"
    ["menu.status"]="الحالة"
    ["menu.config"]="التكوين"
    ["menu.service"]="الخدمات"
    ["menu.health"]="الصحة"
    ["menu.logs"]="السجلات"
    ["menu.language"]="اللغة"
    ["menu.exit"]="خروج"
    ["menu.back"]="رجوع"
    ["menu.select"]="الرجاء الاختيار"
    
    # 帮助
    ["help.title"]="معلومات المساعدة"
    ["help.usage"]="الاستخدام"
    ["help.example"]="أمثلة"
    
    # 错误
    ["error.not_found"]="غير موجود"
    ["error.permission"]="الإذن مرفوض"
    ["error.invalid_param"]="معامل غير صالح"
    ["error.tor_not_running"]="تور لا يعمل"
    ["error.service_failed"]="فشلت عملية الخدمة"
    
    # 确认
    ["confirm.yes"]="نعم"
    ["confirm.no"]="لا"
    ["confirm.cancel"]="إلغاء"
    ["confirm.continue"]="متابعة؟"
    
    # 其它
    ["other.loading"]="جاري التحميل..."
    ["other.saving"]="جاري الحفظ..."
    ["other.done"]="تم"
    ["other.error"]="خطأ"
    ["other.warning"]="تحذير"
    ["other.info"]="معلومات"
    ["other.success"]="نجاح"
)

#===============================================================================
# 翻译数据 - 印尼语 (Indonesian)
#===============================================================================
declare -A TRANSLATIONS_id=(
    # 通用
    ["app.name"]="Tor Manager"
    ["app.version"]="Versi"
    ["app.description"]="Sistem Manajemen Proxy Tor"
    
    # 状态
    ["status.title"]="Ringkasan Status"
    ["status.tor.installed"]="Tor Terpasang"
    ["status.tor.version"]="Versi"
    ["status.tor.running"]="Berjalan"
    ["status.tor.stopped"]="Berhenti"
    ["status.tor.pid"]="PID"
    ["status.tor.method"]="Metode Jalankan"
    ["status.tor.socks_port"]="Port SOCKS"
    ["status.tor.control_port"]="Port Kontrol"
    ["status.service.enabled"]="Diaktifkan"
    ["status.service.disabled"]="Dinonaktifkan"
    ["status.service.not_installed"]="Tidak Terpasang"
    
    # 配置
    ["config.title"]="Manajemen Konfigurasi"
    ["config.show"]="Tampilkan Konfigurasi"
    ["config.edit"]="Edit Konfigurasi"
    ["config.wizard"]="Panduan Konfigurasi"
    ["config.bridge"]="Konfigurasi Bridge"
    ["config.ports"]="Konfigurasi Port"
    ["config.exit_nodes"]="Node Keluar"
    ["config.exclude_nodes"]="Node Dikecualikan"
    ["config.health"]="Pengaturan Kesehatan"
    ["config.torrc_path"]="Path Torrc"
    ["config.saved"]="Konfigurasi disimpan"
    ["config.restart_required"]="Restart diperlukan untuk menerapkan perubahan"
    
    # Bridge
    ["bridge.add"]="Tambah Bridge"
    ["bridge.remove"]="Hapus Bridge"
    ["bridge.list"]="Daftar Bridge"
    ["bridge.clear"]="Hapus Semua Bridge"
    ["bridge.count"]="Jumlah Bridge"
    
    # 服务
    ["service.title"]="Manajemen Layanan"
    ["service.install"]="Pasang Layanan"
    ["service.uninstall"]="Copot Layanan"
    ["service.start"]="Mulai"
    ["service.stop"]="Hentikan"
    ["service.restart"]="Restart"
    ["service.status"]="Status"
    ["service.enable"]="Aktifkan Auto-start"
    ["service.disable"]="Nonaktifkan Auto-start"
    ["service.installed"]="Layanan terpasang"
    ["service.uninstalled"]="Layanan dicopot"
    ["service.running"]="Layanan berjalan"
    ["service.stopped"]="Layanan berhenti"
    
    # 健康检测
    ["health.title"]="Pemeriksaan Kesehatan"
    ["health.check"]="Periksa Sekarang"
    ["health.continuous"]="Pemeriksaan Berkelanjutan"
    ["health.interval"]="Interval Pemeriksaan"
    ["health.max_failures"]="Maksimum Kegagalan"
    ["health.timeout"]="Waktu Habis Pemeriksaan"
    ["health.success"]="Koneksi OK"
    ["health.failed"]="Koneksi Gagal"
    ["health.restarting"]="Merestart Tor..."
    ["health.diagnose"]="Alat Diagnostik"
    
    # 日志
    ["logs.title"]="Penampil Log"
    ["logs.follow"]="Mode Ikuti"
    ["logs.lines"]="Jumlah Baris"
    ["logs.not_found"]="File log tidak ditemukan"
    
    # TUI 菜单
    ["menu.main"]="Menu Utama"
    ["menu.status"]="Status"
    ["menu.config"]="Konfigurasi"
    ["menu.service"]="Layanan"
    ["menu.health"]="Kesehatan"
    ["menu.logs"]="Log"
    ["menu.language"]="Bahasa"
    ["menu.exit"]="Keluar"
    ["menu.back"]="Kembali"
    ["menu.select"]="Silakan pilih"
    
    # 帮助
    ["help.title"]="Informasi Bantuan"
    ["help.usage"]="Penggunaan"
    ["help.example"]="Contoh"
    
    # 错误
    ["error.not_found"]="Tidak ditemukan"
    ["error.permission"]="Izin ditolak"
    ["error.invalid_param"]="Parameter tidak valid"
    ["error.tor_not_running"]="Tor tidak berjalan"
    ["error.service_failed"]="Operasi layanan gagal"
    
    # 确认
    ["confirm.yes"]="Ya"
    ["confirm.no"]="Tidak"
    ["confirm.cancel"]="Batal"
    ["confirm.continue"]="Lanjutkan?"
    
    # 其它
    ["other.loading"]="Memuat..."
    ["other.saving"]="Menyimpan..."
    ["other.done"]="Selesai"
    ["other.error"]="Kesalahan"
    ["other.warning"]="Peringatan"
    ["other.info"]="Informasi"
    ["other.success"]="Berhasil"
)

#===============================================================================
# 翻译数据 - 葡萄牙语 (Portuguese)
#===============================================================================
declare -A TRANSLATIONS_pt=(
    # 通用
    ["app.name"]="Gerenciador Tor"
    ["app.version"]="Versão"
    ["app.description"]="Sistema de Gerenciamento de Proxy Tor"
    
    # 状态
    ["status.title"]="Visão Geral do Status"
    ["status.tor.installed"]="Tor Instalado"
    ["status.tor.version"]="Versão"
    ["status.tor.running"]="Executando"
    ["status.tor.stopped"]="Parado"
    ["status.tor.pid"]="PID"
    ["status.tor.method"]="Método de Execução"
    ["status.tor.socks_port"]="Porta SOCKS"
    ["status.tor.control_port"]="Porta de Controle"
    ["status.service.enabled"]="Habilitado"
    ["status.service.disabled"]="Desabilitado"
    ["status.service.not_installed"]="Não Instalado"
    
    # 配置
    ["config.title"]="Gerenciamento de Configuração"
    ["config.show"]="Mostrar Configuração"
    ["config.edit"]="Editar Configuração"
    ["config.wizard"]="Assistente de Configuração"
    ["config.bridge"]="Configuração de Bridge"
    ["config.ports"]="Configuração de Portas"
    ["config.exit_nodes"]="Nós de Saída"
    ["config.exclude_nodes"]="Nós Excluídos"
    ["config.health"]="Configurações de Saúde"
    ["config.torrc_path"]="Caminho do Torrc"
    ["config.saved"]="Configuração salva"
    ["config.restart_required"]="Reinicialização necessária para aplicar alterações"
    
    # Bridge
    ["bridge.add"]="Adicionar Bridge"
    ["bridge.remove"]="Remover Bridge"
    ["bridge.list"]="Listar Bridges"
    ["bridge.clear"]="Limpar Todos os Bridges"
    ["bridge.count"]="Quantidade de Bridges"
    
    # 服务
    ["service.title"]="Gerenciamento de Serviços"
    ["service.install"]="Instalar Serviço"
    ["service.uninstall"]="Desinstalar Serviço"
    ["service.start"]="Iniciar"
    ["service.stop"]="Parar"
    ["service.restart"]="Reiniciar"
    ["service.status"]="Status"
    ["service.enable"]="Habilitar Início Automático"
    ["service.disable"]="Desabilitar Início Automático"
    ["service.installed"]="Serviço instalado"
    ["service.uninstalled"]="Serviço desinstalado"
    ["service.running"]="Serviço em execução"
    ["service.stopped"]="Serviço parado"
    
    # 健康检测
    ["health.title"]="Verificação de Saúde"
    ["health.check"]="Verificar Agora"
    ["health.continuous"]="Verificação Contínua"
    ["health.interval"]="Intervalo de Verificação"
    ["health.max_failures"]="Máximo de Falhas"
    ["health.timeout"]="Tempo Limite"
    ["health.success"]="Conexão OK"
    ["health.failed"]="Conexão Falhou"
    ["health.restarting"]="Reiniciando Tor..."
    ["health.diagnose"]="Ferramenta de Diagnóstico"
    
    # 日志
    ["logs.title"]="Visualizador de Logs"
    ["logs.follow"]="Modo Segui"
    ["logs.lines"]="Número de Linhas"
    ["logs.not_found"]="Arquivo de log não encontrado"
    
    # TUI 菜单
    ["menu.main"]="Menu Principal"
    ["menu.status"]="Status"
    ["menu.config"]="Configuração"
    ["menu.service"]="Serviços"
    ["menu.health"]="Saúde"
    ["menu.logs"]="Logs"
    ["menu.language"]="Idioma"
    ["menu.exit"]="Sair"
    ["menu.back"]="Voltar"
    ["menu.select"]="Por favor selecione"
    
    # 帮助
    ["help.title"]="Informações de Ajuda"
    ["help.usage"]="Uso"
    ["help.example"]="Exemplos"
    
    # 错误
    ["error.not_found"]="Não encontrado"
    ["error.permission"]="Permissão negada"
    ["error.invalid_param"]="Parâmetro inválido"
    ["error.tor_not_running"]="Tor não está executando"
    ["error.service_failed"]="Operação de serviço falhou"
    
    # 确认
    ["confirm.yes"]="Sim"
    ["confirm.no"]="Não"
    ["confirm.cancel"]="Cancelar"
    ["confirm.continue"]="Continuar?"
    
    # 其它
    ["other.loading"]="Carregando..."
    ["other.saving"]="Salvando..."
    ["other.done"]="Concluído"
    ["other.error"]="Erro"
    ["other.warning"]="Aviso"
    ["other.info"]="Informação"
    ["other.success"]="Sucesso"
)

#===============================================================================
# 翻译数据 - 法语 (French)
#===============================================================================
declare -A TRANSLATIONS_fr=(
    # 通用
    ["app.name"]="Gestionnaire Tor"
    ["app.version"]="Version"
    ["app.description"]="Système de Gestion de Proxy Tor"
    
    # 状态
    ["status.title"]="Aperçu du Statut"
    ["status.tor.installed"]="Tor Installé"
    ["status.tor.version"]="Version"
    ["status.tor.running"]="En cours"
    ["status.tor.stopped"]="Arrêté"
    ["status.tor.pid"]="PID"
    ["status.tor.method"]="Méthode d'Exécution"
    ["status.tor.socks_port"]="Port SOCKS"
    ["status.tor.control_port"]="Port de Contrôle"
    ["status.service.enabled"]="Activé"
    ["status.service.disabled"]="Désactivé"
    ["status.service.not_installed"]="Non Installé"
    
    # 配置
    ["config.title"]="Gestion de Configuration"
    ["config.show"]="Afficher Configuration"
    ["config.edit"]="Modifier Configuration"
    ["config.wizard"]="Assistant Configuration"
    ["config.bridge"]="Configuration Bridge"
    ["config.ports"]="Configuration des Ports"
    ["config.exit_nodes"]="Noeuds de Sortie"
    ["config.exclude_nodes"]="Noeuds Exclus"
    ["config.health"]="Paramètres de Santé"
    ["config.torrc_path"]="Chemin Torrc"
    ["config.saved"]="Configuration enregistrée"
    ["config.restart_required"]="Redémarrage nécessaire pour appliquer les modifications"
    
    # Bridge
    ["bridge.add"]="Ajouter Bridge"
    ["bridge.remove"]="Supprimer Bridge"
    ["bridge.list"]="Lister Bridges"
    ["bridge.clear"]="Effacer Tous les Bridges"
    ["bridge.count"]="Nombre de Bridges"
    
    # 服务
    ["service.title"]="Gestion des Services"
    ["service.install"]="Installer Service"
    ["service.uninstall"]="Désinstaller Service"
    ["service.start"]="Démarrer"
    ["service.stop"]="Arrêter"
    ["service.restart"]="Redémarrer"
    ["service.status"]="Statut"
    ["service.enable"]="Activer Démarrage Auto"
    ["service.disable"]="Désactiver Démarrage Auto"
    ["service.installed"]="Service installé"
    ["service.uninstalled"]="Service désinstallé"
    ["service.running"]="Service en cours"
    ["service.stopped"]="Service arrêté"
    
    # 健康检测
    ["health.title"]="Vérification Santé"
    ["health.check"]="Vérifier Maintenant"
    ["health.continuous"]="Vérification Continue"
    ["health.interval"]="Intervalle de Vérification"
    ["health.max_failures"]="Échecs Maximums"
    ["health.timeout"]="Délai de Vérification"
    ["health.success"]="Connexion OK"
    ["health.failed"]="Connexion Échouée"
    ["health.restarting"]="Redémarrage de Tor..."
    ["health.diagnose"]="Outil de Diagnostic"
    
    # 日志
    ["logs.title"]="Visionneuse de Logs"
    ["logs.follow"]="Mode Suivi"
    ["logs.lines"]="Nombre de Lignes"
    ["logs.not_found"]="Fichier log non trouvé"
    
    # TUI 菜单
    ["menu.main"]="Menu Principal"
    ["menu.status"]="Statut"
    ["menu.config"]="Configuration"
    ["menu.service"]="Services"
    ["menu.health"]="Santé"
    ["menu.logs"]="Logs"
    ["menu.language"]="Langue"
    ["menu.exit"]="Quitter"
    ["menu.back"]="Retour"
    ["menu.select"]="Veuillez sélectionner"
    
    # 帮助
    ["help.title"]="Informations d'Aide"
    ["help.usage"]="Utilisation"
    ["help.example"]="Exemples"
    
    # 错误
    ["error.not_found"]="Non trouvé"
    ["error.permission"]="Permission refusée"
    ["error.invalid_param"]="Paramètre invalide"
    ["error.tor_not_running"]="Tor n'est pas en cours"
    ["error.service_failed"]="Opération de service échouée"
    
    # 确认
    ["confirm.yes"]="Oui"
    ["confirm.no"]="Non"
    ["confirm.cancel"]="Annuler"
    ["confirm.continue"]="Continuer?"
    
    # 其它
    ["other.loading"]="Chargement..."
    ["other.saving"]="Enregistrement..."
    ["other.done"]="Terminé"
    ["other.error"]="Erreur"
    ["other.warning"]="Avertissement"
    ["other.info"]="Information"
    ["other.success"]="Succès"
)

#===============================================================================
# 翻译数据 - 日语 (Japanese)
#===============================================================================
declare -A TRANSLATIONS_ja=(
    # 通用
    ["app.name"]="Tor マネージャー"
    ["app.version"]="バージョン"
    ["app.description"]="Tor プロキシ管理システム"
    
    # 状态
    ["status.title"]="ステータス概要"
    ["status.tor.installed"]="Tor インストール済み"
    ["status.tor.version"]="バージョン"
    ["status.tor.running"]="実行中"
    ["status.tor.stopped"]="停止"
    ["status.tor.pid"]="PID"
    ["status.tor.method"]="実行方法"
    ["status.tor.socks_port"]="SOCKS ポート"
    ["status.tor.control_port"]="コントロールポート"
    ["status.service.enabled"]="有効"
    ["status.service.disabled"]="無効"
    ["status.service.not_installed"]="未インストール"
    
    # 配置
    ["config.title"]="設定管理"
    ["config.show"]="設定を表示"
    ["config.edit"]="設定を編集"
    ["config.wizard"]="設定ウィザード"
    ["config.bridge"]="ブリッジ設定"
    ["config.ports"]="ポート設定"
    ["config.exit_nodes"]="出口ノード"
    ["config.exclude_nodes"]="除外ノード"
    ["config.health"]="ヘルスチェック設定"
    ["config.torrc_path"]="torrc パス"
    ["config.saved"]="設定を保存しました"
    ["config.restart_required"]="変更を適用するには再起動が必要です"
    
    # Bridge
    ["bridge.add"]="ブリッジを追加"
    ["bridge.remove"]="ブリッジを削除"
    ["bridge.list"]="ブリッジを一覧"
    ["bridge.clear"]="すべてのブリッジをクリア"
    ["bridge.count"]="ブリッジ数"
    
    # 服务
    ["service.title"]="サービス管理"
    ["service.install"]="サービスをインストール"
    ["service.uninstall"]="サービスをアンインストール"
    ["service.start"]="開始"
    ["service.stop"]="停止"
    ["service.restart"]="再起動"
    ["service.status"]="ステータス"
    ["service.enable"]="自動起動を有効化"
    ["service.disable"]="自動起動を無効化"
    ["service.installed"]="サービス installed"
    ["service.uninstalled"]="サービス uninstalled"
    ["service.running"]="サービス実行中"
    ["service.stopped"]="サービス停止"
    
    # 健康检测
    ["health.title"]="ヘルスチェック"
    ["health.check"]="今すぐチェック"
    ["health.continuous"]="連続チェック"
    ["health.interval"]="チェック間隔"
    ["health.max_failures"]="最大失敗回数"
    ["health.timeout"]="チェックタイムアウト"
    ["health.success"]="接続正常"
    ["health.failed"]="接続失敗"
    ["health.restarting"]="Torを再起動中..."
    ["health.diagnose"]="診断ツール"
    
    # 日志
    ["logs.title"]="ログビューア"
    ["logs.follow"]="フォローモード"
    ["logs.lines"]="行数"
    ["logs.not_found"]="ログファイルが見つかりません"
    
    # TUI 菜单
    ["menu.main"]="メインメニュー"
    ["menu.status"]="ステータス"
    ["menu.config"]="設定"
    ["menu.service"]="サービス"
    ["menu.health"]="ヘルス"
    ["menu.logs"]="ログ"
    ["menu.language"]="言語"
    ["menu.exit"]="終了"
    ["menu.back"]="戻る"
    ["menu.select"]="選択してください"
    
    # 帮助
    ["help.title"]="ヘルプ情報"
    ["help.usage"]="使用方法"
    ["help.example"]="例"
    
    # 错误
    ["error.not_found"]="見つかりません"
    ["error.permission"]="権限が拒否されました"
    ["error.invalid_param"]="無効なパラメータ"
    ["error.tor_not_running"]="Torが実行されていません"
    ["error.service_failed"]="サービス操作に失敗しました"
    
    # 确认
    ["confirm.yes"]="はい"
    ["confirm.no"]="いいえ"
    ["confirm.cancel"]="キャンセル"
    ["confirm.continue"]="続行しますか？"
    
    # 其它
    ["other.loading"]="読み込み中..."
    ["other.saving"]="保存中..."
    ["other.done"]="完了"
    ["other.error"]="エラー"
    ["other.warning"]="警告"
    ["other.info"]="情報"
    ["other.success"]="成功"
)

#===============================================================================
# 初始化 i18n
#===============================================================================
init_i18n() {
    detect_system_language
}

# 如果脚本直接运行，初始化
if [[ "${TOR_MANAGER_I18N_INITIALIZED:-}" != "true" ]]; then
    init_i18n
    export TOR_MANAGER_I18N_INITIALIZED="true"
fi
