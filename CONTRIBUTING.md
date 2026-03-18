# 贡献指南

感谢您考虑为 Tor Manager 做出贡献！

## 如何贡献

### 报告问题

如果您发现了 bug 或有功能建议，请创建 Issue：

1. 使用清晰的标题描述问题
2. 描述重现步骤
3. 说明预期行为和实际行为
4. 附上相关日志（如有）

### 提交代码

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 代码规范

### Shell/Bash

- 使用 4 空格缩进
- 函数名使用 `snake_case`
- 常量使用 `UPPER_SNAKE_CASE`
- 每个函数添加注释说明

```bash
# 函数说明
# @param $1 参数说明
# @return 返回值说明
function_name() {
    local param=$1
    
    # 实现
}
```

### 日志规范

使用统一的日志函数：

```bash
log_debug "调试信息"
log_info "一般信息"
log_warn "警告信息"
log_error "错误信息"
log_fatal "致命错误"
```

### 错误处理

- 使用 `set -o pipefail` 启用管道错误检测
- 算术运算使用 `((var++)) || true` 避免返回非零

## 测试

提交前请确保：

```bash
# 语法检查
bash -n tor-manager.sh
bash -n lib/*.sh

# 功能测试
./tor-manager.sh --help
./tor-manager.sh status
./tor-manager.sh check --diagnose
```

## 许可证

提交代码即表示您同意您的贡献将在 MIT 许可证下授权。
