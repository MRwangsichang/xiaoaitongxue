#!/usr/bin/env bash
set -euo pipefail

FILE="/home/MRwang/smart_assistant/modules/vision/scanner.py"

echo "=== 修复scanner.py的payload字段 ==="

# 备份原文件
cp "$FILE" "${FILE}.backup_$(date +%s)"
echo "✓ 已备份原文件"

# 修改payload字段：person -> person_id
sed -i 's/"person": name/"person_id": self._name_to_id(name)/' "$FILE"
echo "✓ 修改字段名: person -> person_id"

# 在VisionScanner类中添加名字映射方法
# 找到 async def publish_event 之前，插入映射方法
sed -i '/async def publish_event/i\    def _name_to_id(self, name: str) -> str:\n        """将中文名转换为person_id"""\n        name_map = {\n            "王总": "wangzong",\n            "Unknown": "unknown"\n        }\n        return name_map.get(name, "unknown")\n' "$FILE"
echo "✓ 添加名字映射方法"

echo ""
echo "=== 验证修改 ==="
grep -A 3 "_name_to_id" "$FILE" | head -7
echo ""
grep "person_id" "$FILE" | grep -v "def _name_to_id"

echo ""
echo "✓ 修复完成！"
