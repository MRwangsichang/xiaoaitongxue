#!/bin/bash
# 第 1 小步：目录骨架 + 依赖检查
# 创建 Memory 模块基础目录结构，检查 Python 依赖

set -euo pipefail

# ============================================
# 配置区
# ============================================
PROJECT_ROOT="/home/user/xiaoaitongxue"
DRY_RUN="${DRY_RUN:-1}"  # 默认预演模式

# ============================================
# 颜色输出
# ============================================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ============================================
# 工具函数
# ============================================
log_info() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')]${NC} $1"
}

check_or_create_dir() {
    local dir_path="$1"
    if [ -d "$dir_path" ]; then
        log_info "[检查] 目录已存在: $dir_path"
    else
        if [ "$DRY_RUN" = "1" ]; then
            log_warn "[预演] 将创建目录: $dir_path"
        else
            mkdir -p "$dir_path"
            log_info "[创建] 目录: $dir_path"
        fi
    fi
}

check_or_create_file() {
    local file_path="$1"
    local content="$2"

    if [ -f "$file_path" ]; then
        log_warn "[检查] 文件已存在，跳过: $file_path"
    else
        if [ "$DRY_RUN" = "1" ]; then
            log_warn "[预演] 将创建文件: $file_path"
        else
            echo "$content" > "$file_path"
            log_info "[创建] 文件: $file_path"
        fi
    fi
}

# ============================================
# 主逻辑
# ============================================
echo "========================================"
echo "第 1 小步：目录骨架 + 依赖检查"
echo "========================================"

if [ "$DRY_RUN" = "1" ]; then
    log_warn "[DRY_RUN=1] 预演模式，不会实际创建文件"
    echo ""
fi

# 1. 检查项目根目录
log_info "[检查] 项目根目录: $PROJECT_ROOT"
if [ ! -d "$PROJECT_ROOT" ]; then
    log_error "项目根目录不存在: $PROJECT_ROOT"
    exit 1
fi
cd "$PROJECT_ROOT"

# 2. 检查必要的父目录
check_or_create_dir "$PROJECT_ROOT/modules"
check_or_create_dir "$PROJECT_ROOT/config"
check_or_create_dir "$PROJECT_ROOT/scripts"
check_or_create_dir "$PROJECT_ROOT/data"
check_or_create_dir "$PROJECT_ROOT/logs"
check_or_create_dir "$PROJECT_ROOT/backups"
echo ""

# 3. 创建 memory 模块目录
check_or_create_dir "$PROJECT_ROOT/modules/memory"
check_or_create_dir "$PROJECT_ROOT/backups/memory"
echo ""

# 4. 创建 __init__.py
INIT_CONTENT='# Memory Orchestrator Module
# Version: 1.0.0
# Author: Claude Code

"""
Memory Orchestrator 模块

记忆管家：按 person_id 绑定个人记忆，支持问候、对话、记忆更新的闭环。
"""

__version__ = "1.0.0"
'

check_or_create_file "$PROJECT_ROOT/modules/memory/__init__.py" "$INIT_CONTENT"
echo ""

# 5. 创建 models.py（空占位）
MODELS_CONTENT='# Memory Module Data Models
# Pydantic models for Memory items, commands, and events

"""
数据模型定义
- MemoryItem: 记忆条目
- Commands: MQTT 命令
- Events: MQTT 事件
"""

# TODO: 第 5 小步实现
'

check_or_create_file "$PROJECT_ROOT/modules/memory/models.py" "$MODELS_CONTENT"
echo ""

# 6. 创建 config/memory.yaml（基础配置）
MEMORY_YAML='# Memory Orchestrator 配置
# Version: 1.0.0

memory:
  db_path: "/home/user/xiaoaitongxue/data/memory.db"
  wal_mode: true

  # 阈值
  confidence:
    auto_write: 0.80        # ≥0.8 自动写入 active
    profile_confirm: 0.90   # ≥0.9 profile 进入 pending_confirm
    candidate_low: 0.50     # <0.5 丢弃

  # 默认值
  defaults:
    speakable: true
    ttl_short: 432000       # 5天（秒）
    ttl_todo: 0             # 完成即删
    priority: 3

  # 清理策略
  cleanup:
    archived_days: 30       # archived 保留 30 天
    deleted_days: 7         # deleted 保留 7 天后物理删除
    run_at: "03:00"         # 每日清理时间

  # 查询配置
  query:
    default_limit: 1        # 问候只读 Top1
    max_limit: 20
    slow_threshold_ms: 50   # 慢查询阈值

  # 会话配置
  session:
    silence_timeout_s: 60   # 静默 60s 结束会话
    leave_timeout_s: 20     # 离场 20s 结束会话
    max_duration_s: 600     # 会话最长 10min
    cooldown_same_person_s: 3600  # 上一小时聊过轻问候

  # profile 确认流程
  profile_confirm:
    max_attempts: 2         # 两次未确认删除
    timeout_action: "keep"  # keep=下次再问, delete=直接删除

# MQTT 配置
mqtt:
  broker: "localhost"
  port: 1883
  client_id: "memory_orchestrator"
  topics:
    cmd_prefix: "sa/memory/cmd"
    event_prefix: "sa/memory/event"
    session_prefix: "sa/session"

# HTTP 配置（可选）
http:
  enabled: true
  host: "127.0.0.1"
  port: 8081

# 日志配置
logging:
  level: "INFO"
  slow_query_file: "logs/memory_slow.log"

# 时区
timezone: "Asia/Tokyo"
'

check_or_create_file "$PROJECT_ROOT/config/memory.yaml" "$MEMORY_YAML"
echo ""

# 7. Python 依赖检查
log_info "[依赖检查] Python 版本检查..."
PYTHON_VERSION=$(python3 --version 2>&1)
log_info "Python 版本: $PYTHON_VERSION"
echo ""

log_info "[依赖检查] 检查必要的 Python 库..."
MISSING_DEPS=()

# 检查依赖
check_python_package() {
    local package="$1"
    if python3 -c "import $package" 2>/dev/null; then
        log_info "✓ $package 已安装"
    else
        log_error "✗ $package 未安装"
        MISSING_DEPS+=("$package")
    fi
}

# 检查必要依赖
check_python_package "paho.mqtt"      # MQTT 客户端
check_python_package "yaml"           # PyYAML
check_python_package "pydantic"       # 数据验证
check_python_package "aiosqlite"      # 异步 SQLite（可选，优先用 sqlite3）

echo ""

# 8. 总结
echo "========================================"
if [ "$DRY_RUN" = "1" ]; then
    log_warn "预演完成！确认无误后请执行 DRY_RUN=0"
else
    log_info "第 1 小步执行完成！"

    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        log_warn "缺失以下 Python 包，需要安装："
        for dep in "${MISSING_DEPS[@]}"; do
            echo "  - $dep"
        done
        echo ""
        log_warn "建议安装命令："
        echo "  pip3 install paho-mqtt PyYAML pydantic aiosqlite"
    else
        log_info "所有依赖已满足！"
    fi
fi
echo "========================================"
