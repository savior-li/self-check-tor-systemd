# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-18

### Added
- Configuration management module
  - Bridge configuration (add/remove/list/import/export)
  - ExitNodes configuration
  - ExcludeExitNodes configuration (default: CN, RU, KP)
  - Port configuration (SOCKS/Control)
  - Log level configuration
  - Configuration backup/restore
- Health check module
  - SOCKS5 proxy connectivity detection
  - Single check mode with 3 retries
  - Continuous check mode (default: 5 minutes interval)
  - Auto-restart on consecutive failures
  - Bootstrap waiting for Tor startup
- Systemd service integration
  - Service file generation and deployment
  - start/stop/restart/status management
  - Enable/disable auto-start
  - Support for multiple Tor running methods
- TUI interface
  - Status overview panel
  - Service management menu
  - Configuration management menu
  - Log viewer
  - Diagnostic tools
- Logging system
  - Unified log functions (debug/info/warn/error/fatal)
  - Multiple log file support
- Documentation
  - README.md
  - AGENTS.md
  - CONTRIBUTING.md
  - LICENSE (MIT)

### Features
- Pure Bash implementation, no external dependencies
- Support for manual and systemd managed Tor processes
- Color output toggle (disabled by default)
- Configurable check interval and failure threshold
