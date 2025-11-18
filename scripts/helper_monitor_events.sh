#!/bin/bash
# helper_monitor_events.sh - 监听 Memory 模块的所有事件

echo "📡 开始监听 Memory 模块事件..."
echo "主题: sa/memory/event/#"
echo ""
echo "按 Ctrl+C 停止监听"
echo "================================"
echo ""

mosquitto_sub -h localhost -v -t 'sa/memory/event/#'
