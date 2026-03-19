# Tor Manager 系统图表

本文档包含 Tor Manager 系统的各种专业图表，帮助理解系统架构和工作原理。

---

## 1. 系统架构图

```mermaid
graph TB
    subgraph 用户层["用户层"]
        CLI["CLI 命令行"]
        TUI["TUI 交互界面"]
    end
    
    subgraph 应用层["应用层 - tor-manager.sh"]
        MAIN["主入口"]
        CONFIG["config.sh<br/>配置管理"]
        HEALTH["health.sh<br/>健康检测"]
        SERVICE["service.sh<br/>服务管理"]
        COMMON["common.sh<br/>公共函数"]
    end
    
    subgraph 数据层["数据层"]
        TORRC["torrc<br/>Tor 配置文件"]
        CONF["tor-manager.conf<br/>程序配置"]
        LOGS["var/log/<br/>日志文件"]
        DATA["data/<br/>Tor 数据"]
    end
    
    subgraph 系统层["系统层"]
        SYSTEMD["systemd<br/>服务管理"]
        TOR_PROC["Tor 进程"]
        PT["Pluggable Transports<br/>lyrebird/conjure"]
    end
    
    subgraph 网络层["网络层"]
        BRIDGE["Tor Bridge<br/>网桥服务器"]
        TOR_NET["Tor Network<br/>Tor 网络"]
        INTERNET["目标网站"]
    end
    
    CLI --> MAIN
    TUI --> MAIN
    MAIN --> CONFIG
    MAIN --> HEALTH
    MAIN --> SERVICE
    CONFIG --> COMMON
    HEALTH --> COMMON
    SERVICE --> COMMON
    
    CONFIG --> TORRC
    CONFIG --> CONF
    HEALTH --> LOGS
    SERVICE --> SYSTEMD
    
    SYSTEMD --> TOR_PROC
    TOR_PROC --> PT
    PT --> BRIDGE
    BRIDGE --> TOR_NET
    TOR_NET --> INTERNET
    
    TOR_PROC --> DATA
    TOR_PROC --> TORRC
```

---

## 2. 模块依赖关系图

```mermaid
graph LR
    subgraph 核心模块
        COMMON["common.sh"]
    end
    
    subgraph 功能模块
        CONFIG["config.sh"]
        HEALTH["health.sh"]
        SERVICE["service.sh"]
        TUI["tui.sh"]
    end
    
    subgraph 入口
        MAIN["tor-manager.sh"]
    end
    
    MAIN --> COMMON
    MAIN --> CONFIG
    MAIN --> SERVICE
    CONFIG --> COMMON
    HEALTH --> COMMON
    HEALTH --> CONFIG
    SERVICE --> COMMON
    SERVICE --> CONFIG
    SERVICE --> HEALTH
    TUI --> COMMON
    TUI --> CONFIG
    TUI --> HEALTH
    TUI --> SERVICE
```

---

## 3. 目录结构图

```mermaid
graph TB
    ROOT["tor-manager/"]
    
    ROOT --> BIN["tor-manager.sh<br/>主程序入口"]
    ROOT --> LIB["lib/<br/>核心模块"]
    ROOT --> ETC["etc/<br/>配置文件"]
    ROOT --> VAR["var/<br/>运行时数据"]
    ROOT --> TOR["tor/<br/>Tor 二进制"]
    ROOT --> DATA["data/<br/>Tor 数据目录"]
    ROOT --> SYSTEMD["systemd/<br/>服务文件"]
    ROOT --> DOCS["docs/<br/>文档"]
    
    LIB --> L1["common.sh"]
    LIB --> L2["config.sh"]
    LIB --> L3["health.sh"]
    LIB --> L4["service.sh"]
    LIB --> L5["tui.sh"]
    
    ETC --> E1["tor-manager.conf"]
    
    VAR --> V1["log/"]
    VAR --> V2["run/"]
    VAR --> V3["backup/"]
    
    TOR --> T1["tor"]
    TOR --> T2["pluggable_transports/"]
    
    T2 --> PT1["lyrebird"]
    T2 --> PT2["conjure-client"]
```

---

## 4. 健康检测流程图

```mermaid
flowchart TD
    START([开始检测]) --> CHECK_RUNNING{Tor 是否运行?}
    
    CHECK_RUNNING -->|否| START_TOR[启动 Tor]
    CHECK_RUNNING -->|是| CHECK_PORT{SOCKS 端口监听?}
    
    START_TOR --> WAIT_BOOT[等待 Bootstrap]
    WAIT_BOOT --> CHECK_PORT
    
    CHECK_PORT -->|否| LOG_ERROR[记录错误]
    CHECK_PORT -->|是| CURL_CHECK[curl 通过 SOCKS5<br/>请求检测 URL]
    
    CURL_CHECK --> CHECK_RESPONSE{响应正确?}
    
    CHECK_RESPONSE -->|是| SUCCESS[检测成功]
    CHECK_RESPONSE -->|否| FAIL_COUNT[失败次数 +1]
    
    SUCCESS --> RESET_COUNT[重置失败计数]
    RESET_COUNT --> WRITE_STATUS[写入状态文件]
    WRITE_STATUS --> SLEEP[等待下次检测]
    SLEEP --> CHECK_RUNNING
    
    FAIL_COUNT --> CHECK_MAX{达到最大失败次数?}
    
    CHECK_MAX -->|否| LOG_ERROR
    CHECK_MAX -->|是| RESTART_TOR[重启 Tor]
    
    RESTART_TOR --> STOP[停止 Tor]
    STOP --> START_TOR
    
    LOG_ERROR --> WRITE_LOG[写入日志]
    WRITE_LOG --> SLEEP
```

---

## 5. Tor 连接原理图

```mermaid
sequenceDiagram
    participant App as 应用程序
    participant TM as Tor Manager
    participant Tor as Tor 客户端
    participant PT as Pluggable Transport
    participant Bridge as Tor Bridge
    participant Guard as 入口节点
    participant Middle as 中间节点
    participant Exit as 出口节点
    participant Dest as 目标网站
    
    App->>TM: 请求代理连接
    TM->>Tor: SOCKS5 127.0.0.1:9050
    Tor->>PT: 启动传输插件
    
    Note over PT,Bridge: 使用混淆技术绕过审查
    PT->>Bridge: 加密隧道连接
    
    Bridge->>Guard: 建立电路第一跳
    Guard->>Middle: 建立电路第二跳
    Middle->>Exit: 建立电路第三跳
    
    Note over Guard,Exit: 三跳电路建立完成
    
    Tor->>App: 连接就绪
    App->>Dest: 通过 Tor 电路发送请求
    Dest->>App: 响应数据
```

---

## 6. 配置管理工作流程

```mermaid
flowchart LR
    subgraph 用户操作
        A1[CLI 命令]
        A2[TUI 菜单]
    end
    
    subgraph 配置解析
        B1[读取 torrc]
        B2[解析配置项]
        B3[验证参数]
    end
    
    subgraph 配置修改
        C1[备份原文件]
        C2[修改配置]
        C3[写入文件]
    end
    
    subgraph 应用配置
        D1[重启 Tor]
        D2[验证生效]
    end
    
    A1 --> B1
    A2 --> B1
    B1 --> B2 --> B3
    B3 --> C1 --> C2 --> C3
    C3 --> D1 --> D2
```

---

## 7. 服务生命周期图

```mermaid
stateDiagram-v2
    [*] --> 已安装: service install
    已安装 --> 已停止: 初始状态
    
    已停止 --> 运行中: service start
    运行中 --> 已停止: service stop
    运行中 --> 重启中: service restart
    
    重启中 --> 运行中: 启动成功
    重启中 --> 已停止: 启动失败
    
    已停止 --> 已卸载: service uninstall
    已卸载 --> [*]
    
    运行中 --> 运行中: 健康检测通过
    运行中 --> 重启中: 连续失败触发重启
    
    state 运行中 {
        [*] --> Bootstrap
        Bootstrap --> 就绪
        就绪 --> 检测中
        检测中 --> 就绪: 成功
        检测中 --> 故障: 失败
        故障 --> 重启
        重启 --> Bootstrap
    }
```

---

## 8. Bootstrap 等待流程

```mermaid
flowchart TD
    START([启动 Tor]) --> WAIT_SOCKS{等待 SOCKS 端口}
    
    WAIT_SOCKS -->|超时| FAIL1[启动失败]
    WAIT_SOCKS -->|端口监听| CURL_TEST[测试 Tor 连接]
    
    CURL_TEST --> REQUEST[请求 check.torproject.org/api/ip]
    REQUEST --> PARSE{解析响应}
    
    PARSE -->|IsTor: true| SUCCESS[Bootstrap 完成]
    PARSE -->|IsTor: false| RETRY{重试?}
    PARSE -->|请求失败| RETRY
    
    RETRY -->|是| CURL_TEST
    RETRY -->|超时| FAIL2[Bootstrap 超时]
    
    SUCCESS --> RETURN_IP[返回出口 IP]
    FAIL1 --> ERROR([错误])
    FAIL2 --> ERROR
```

---

## 9. 多方法 Tor 进程管理

```mermaid
flowchart TD
    DETECT[检测 Tor 运行方式]
    
    DETECT --> CHECK_SYSTEMD{tor-manager.service<br/>运行中?}
    
    CHECK_SYSTEMD -->|是| METHOD1[方法1: systemd 服务]
    CHECK_SYSTEMD -->|否| CHECK_SYSTEM_TOR{系统 Tor 服务<br/>运行中?}
    
    CHECK_SYSTEM_TOR -->|是| METHOD2[方法2: 系统 Tor]
    CHECK_SYSTEM_TOR -->|否| CHECK_MANUAL{手动 Tor 进程?}
    
    CHECK_MANUAL -->|是| METHOD3[方法3: 手动进程]
    CHECK_MANUAL -->|否| NOT_RUNNING[Tor 未运行]
    
    METHOD1 --> STOP1["systemctl stop tor-manager"]
    METHOD2 --> STOP2["systemctl stop tor"]
    METHOD3 --> STOP3["kill SIGTERM → SIGKILL"]
    
    STOP1 --> RESULT[停止完成]
    STOP2 --> RESULT
    STOP3 --> RESULT
```

---

## 10. 数据流向图

```mermaid
flowchart LR
    subgraph 输入
        I1[用户命令]
        I2[配置文件]
        I3[环境变量]
    end
    
    subgraph 处理
        P1[参数解析]
        P2[配置加载]
        P3[路径修复]
        P4[命令执行]
    end
    
    subgraph 输出
        O1[日志文件]
        O2[状态文件]
        O3[备份文件]
        O4[Tor 进程]
    end
    
    I1 --> P1
    I2 --> P2
    I3 --> P2
    
    P1 --> P3
    P2 --> P3
    P3 --> P4
    
    P4 --> O1
    P4 --> O2
    P4 --> O3
    P4 --> O4
```

---

## 图表说明

| 图表 | 说明 |
|------|------|
| 系统架构图 | 展示整体系统的分层结构和组件关系 |
| 模块依赖图 | 展示各 Shell 模块之间的依赖关系 |
| 目录结构图 | 展示项目的文件和目录组织 |
| 健康检测流程 | 展示检测、失败处理、自动重启的完整流程 |
| Tor 连接原理 | 展示 Tor 电路建立和数据传输过程 |
| 配置管理工作流 | 展示配置修改的完整流程 |
| 服务生命周期 | 展示服务状态转换关系 |
| Bootstrap 等待流程 | 展示启动后等待就绪的过程 |
| 多方法进程管理 | 展示如何检测和管理不同方式运行的 Tor |
| 数据流向图 | 展示输入、处理、输出的数据流向 |
