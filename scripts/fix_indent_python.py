#!/usr/bin/env python3
"""修复asr_module.py的缩进问题"""

file_path = "/home/MRwang/smart_assistant/modules/asr/asr_module.py"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 修复第113-115行的缩进
# 第113行: "开始初始化 CloudProvider..." 应该是16个空格
if 113 < len(lines) and "开始初始化 CloudProvider" in lines[112]:
    lines[112] = "                self.logger.info(\"开始初始化 CloudProvider...\")\n"

# 第114行: "else:" 应该是12个空格  
if 114 < len(lines) and lines[113].strip() == "else:":
    lines[113] = "            else:\n"

# 第115行: "CloudProvider 初始化完成" 应该是16个空格
if 115 < len(lines) and "CloudProvider 初始化完成" in lines[114]:
    lines[114] = "                self.logger.info(\"CloudProvider 初始化完成\")\n"

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("✓ 缩进已修复")

# 验证语法
import py_compile
try:
    py_compile.compile(file_path, doraise=True)
    print("✓ 语法检查通过")
except py_compile.PyCompileError as e:
    print(f"✗ 仍有语法错误: {e}")
