# Tor Manager - 产品级 Tor 管理系统

## 项目概述

Tor Manager 是一个产品级的 Tor 管理系统，提供 Tor 的配置、监控和服务管理功能。采用纯 Shell/Bash 实现，支持 CLI 和 TUI 两种交互方式。

## 特性

- **配置管理**: Bridge、ExitNodes、ExcludeExitNodes、端口配置
- **连通性检测**: SOCKS5 代理检测，自动重启
- **systemd 集成**: 服务部署、开机自启
- **TUI 界面**: 交互式菜单操作
- **日志管理**: 多种日志查看方式

## 技术栈

- **语言**: Shell/Bash (无外部依赖)
- **交互方式**: CLI + TUI
- **检测方式**: SOCKS5 代理检测 (curl)

## 项目结构

```
tor-manager/
├── tor-manager.sh           # 主程序入口
├── lib/
│   ├── common.sh            # 公共函数（日志、工具）
│   ├── config.sh            # 配置管理模块
│   ├── health.sh            # 连通性检测模块
│   ├── service.sh           # systemd 服务模块
│   └── tui.sh               # TUI 交互界面
├── etc/
│   ├── tor-manager.conf     # 程序配置
│   └── download-sources.conf # 下载源列表
├── systemd/
│   ├── tor-manager.service  # systemd 主服务
│   └── tor-manager-health.service # 健康检测服务
├── tor/                     # Tor 二进制文件目录
├── torrc                    # Tor 配置文件
├── data/                    # Tor 数据目录
├── var/
│   ├── log/                 # 日志目录
│   ├── run/                 # 运行时文件
│   └── backup/              # 备份目录
└── AGENTS.md               # 项目说明
```

## 功能模块

### 1. 配置管理模块 (`lib/config.sh`)
- **Bridge 配置**: add/remove/list/import/export
- **ExitNodes 配置**: 设置出口节点国家
- **ExcludeExitNodes 配置**: 排除出口节点国家（默认排除 CN,RU,KP）
- **端口配置**: SOCKS/Control 端口
- **日志配置**: 级别、路径
- **配置备份/恢复**: 自动备份，支持恢复

### 2. 连通性检测模块 (`lib/health.sh`)
- **检测方式**: 通过 SOCKS5 代理请求 `check.torproject.org/api/ip`
- **单次检测**: 3 次重试，失败自动重启
- **持续检测**: 可配置间隔（默认 5 分钟）
- **自动重启**: 连续失败 3 次自动重启 Tor
- **Bootstrap 等待**: 启动时等待 Tor 就绪

### 3. systemd 集成 (`lib/service.sh`)
- 服务文件生成与部署
- start/stop/restart/status 管理
- 开机自启控制
- 支持 tor-manager 服务和系统 tor 服务

### 4. TUI 界面 (`lib/tui.sh`)
- 状态概览面板
- 服务管理菜单
- 配置管理菜单
- 日志查看器
- 诊断工具

## CLI 命令

```bash
# 配置管理
./tor-manager.sh config show                    # 显示当前配置
./tor-manager.sh config help                    # 显示配置帮助
./tor-manager.sh config bridge add "..."        # 添加 Bridge
./tor-manager.sh config bridge list             # 列出 Bridge
./tor-manager.sh config exit-nodes {US},{DE}    # 设置出口节点
./tor-manager.sh config exclude-nodes {CN},{RU} # 设置排除节点
./tor-manager.sh config ports --socks 9050      # 设置端口

# 连通性检测
./tor-manager.sh check                          # 单次检测
./tor-manager.sh check --continuous             # 持续检测
./tor-manager.sh check --interval 300           # 指定间隔
./tor-manager.sh check --diagnose               # 诊断工具

# 服务管理
./tor-manager.sh service install                # 安装 systemd 服务
./tor-manager.sh service uninstall              # 卸载服务
./tor-manager.sh service start|stop|restart     # 服务控制
./tor-manager.sh service status                 # 服务状态
./tor-manager.sh service enable|disable         # 开机自启

# TUI 界面
./tor-manager.sh tui                            # 启动交互界面

# 其他
./tor-manager.sh status                         # 显示 Tor 状态
./tor-manager.sh logs [--lines N]               # 查看日志
./tor-manager.sh --version                      # 显示版本
./tor-manager.sh --help                         # 显示帮助
```

## 检测机制

### 检测原理
```
curl --socks5-hostname 127.0.0.1:9050 \
     https://check.torproject.org/api/ip

响应: {"IsTor":true, "IP":"xxx.xxx.xxx.xxx"}
```

### 重启机制

**单次检测模式:**
```
检测 1/3 → 失败 → 等待 5s
检测 2/3 → 失败 → 等待 5s
检测 3/3 → 失败 → 自动重启 → 等待 Bootstrap → 再次检测
```

**持续检测模式:**
```
每 5 分钟检测一次
连续失败 >= 3 次 → 自动重启
重启后等待 30 秒继续检测
```

### Tor 运行方式检测
支持检测和处理多种 Tor 运行方式：
- tor-manager systemd 服务
- 系统 tor systemd 服务
- 手动运行的 Tor 进程

## 配置参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| CHECK_INTERVAL | 300 | 检测间隔（秒）|
| MAX_FAILURES | 3 | 连续失败次数阈值 |
| CHECK_TIMEOUT | 30 | 单次检测超时（秒）|
| ENABLE_COLOR | false | 彩色输出开关 |

## 快速开始

```bash
# 1. 克隆项目
git clone https://github.com/your-repo/tor-manager.git
cd tor-manager

# 2. 确保 Tor 已安装在 ./tor 目录
# 或修改 etc/tor-manager.conf 中的 TOR_INSTALL_DIR

# 3. 查看状态
./tor-manager.sh status

# 4. 配置 Tor
./tor-manager.sh config show

# 5. 安装 systemd 服务（可选）
sudo ./tor-manager.sh service install
sudo ./tor-manager.sh service enable

# 6. 检测连接
./tor-manager.sh check

# 7. 启动 TUI
./tor-manager.sh tui
```

## 目录要求

程序默认使用当前目录结构：
- `./tor/` - Tor 二进制文件
- `./torrc` - Tor 配置文件
- `./data/` - Tor 数据目录
- `./var/log/` - 日志目录

可通过 `etc/tor-manager.conf` 修改路径。

## 日志文件

- `var/log/tor-manager.log` - 程序运行日志
- `var/log/health.log` - 健康检测日志
- `var/log/info.log` - Tor 运行日志

## 开发规范

### 代码风格
- 使用 4 空格缩进
- 函数名使用 snake_case
- 常量使用大写下划线命名
- 每个模块必须有清晰的注释头

### 日志规范
```bash
log_debug "调试信息"
log_info "一般信息"
log_warn "警告信息"
log_error "错误信息"
log_fatal "致命错误"
```

### 错误处理
- 使用 `set -o pipefail` 启用管道错误检测
- 使用 `trap` 捕获信号进行清理
- 算术运算使用 `((var++)) || true` 避免返回 1

## 测试

```bash
# 语法检查
bash -n tor-manager.sh
bash -n lib/*.sh

# 运行诊断
./tor-manager.sh check --diagnose

# 测试服务
sudo ./tor-manager.sh service status
```

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request。
