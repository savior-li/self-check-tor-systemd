# Tor Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Language-Bash-green.svg)](https://www.gnu.org/software/bash/)

产品级 Tor 管理系统，提供 Tor 的配置、监控和服务管理功能。采用纯 Shell/Bash 实现，无外部依赖。

## 功能特性

- ✅ **配置管理** - Bridge、ExitNodes、ExcludeExitNodes、端口配置
- ✅ **连通性检测** - SOCKS5 代理检测，自动重启
- ✅ **systemd 集成** - 服务部署、开机自启
- ✅ **TUI 界面** - 交互式菜单操作
- ✅ **日志管理** - 多种日志查看方式
- ✅ **多运行方式支持** - systemd 服务、手动启动

## 快速开始

### 安装

```bash
# 克隆仓库
git clone https://github.com/yourusername/tor-manager.git
cd tor-manager

# 确保 Tor 已安装在 ./tor 目录
# 确保 torrc 配置文件存在

# 设置执行权限
chmod +x tor-manager.sh
```

### 基本使用

```bash
# 查看状态
./tor-manager.sh status

# 查看配置
./tor-manager.sh config show

# 检测连接
./tor-manager.sh check

# 启动 TUI 界面
./tor-manager.sh tui
```

### systemd 服务

```bash
# 安装服务
sudo ./tor-manager.sh service install

# 启动服务
sudo ./tor-manager.sh service start

# 开机自启
sudo ./tor-manager.sh service enable

# 查看状态
./tor-manager.sh service status
```

## 命令参考

| 命令 | 说明 |
|------|------|
| `status` | 显示 Tor 状态 |
| `config show` | 显示当前配置 |
| `config help` | 显示配置帮助 |
| `config bridge add/list` | Bridge 管理 |
| `config exit-nodes {US},{DE}` | 设置出口节点 |
| `config exclude-nodes {CN},{RU}` | 设置排除节点 |
| `check` | 单次连通性检测 |
| `check --continuous` | 持续检测 |
| `check --diagnose` | 诊断工具 |
| `service install/start/stop/restart` | 服务管理 |
| `tui` | 启动交互界面 |
| `logs` | 查看日志 |

## 检测机制

### 原理

```
curl --socks5-hostname 127.0.0.1:9050 \
     https://check.torproject.org/api/ip

响应: {"IsTor":true, "IP":"xxx.xxx.xxx.xxx"}
```

### 自动重启

- **单次检测**: 3 次重试，失败自动重启
- **持续检测**: 每 5 分钟检测，连续失败 3 次自动重启
- **多方式支持**: 自动检测 Tor 运行方式 (systemd/手动)

## 项目结构

```
tor-manager/
├── tor-manager.sh           # 主程序
├── lib/
│   ├── common.sh            # 公共函数
│   ├── config.sh            # 配置管理
│   ├── health.sh            # 连通性检测
│   ├── service.sh           # 服务管理
│   └── tui.sh               # TUI 界面
├── etc/
│   └── tor-manager.conf     # 配置文件
├── systemd/
│   ├── tor-manager.service
│   └── tor-manager-health.service
├── tor/                     # Tor 二进制
├── torrc                    # Tor 配置
└── var/log/                 # 日志目录
```

## 系统图表

详细系统架构和工作流程图请参阅 [docs/diagrams.md](docs/diagrams.md)，包含：

- 系统架构图
- 模块依赖关系图
- 目录结构图
- 健康检测流程图
- Tor 连接原理图
- 配置管理工作流程
- 服务生命周期图
- Bootstrap 等待流程
- 多方法进程管理
- 数据流向图

## 配置参数

编辑 `etc/tor-manager.conf`:

| 参数 | 默认值 | 说明 |
|------|--------|------|
| CHECK_INTERVAL | 300 | 检测间隔 (秒) |
| MAX_FAILURES | 3 | 连续失败次数阈值 |
| CHECK_TIMEOUT | 30 | 单次检测超时 (秒) |
| ENABLE_COLOR | false | 彩色输出开关 |

## 依赖

- Bash 4.0+
- curl
- systemd (可选，用于服务管理)

## 许可证

[MIT License](LICENSE)

## 贡献

欢迎提交 Issue 和 Pull Request。

## 免责声明

本项目仅供学习和研究使用。使用 Tor 需遵守当地法律法规。作者不对任何滥用行为负责。
