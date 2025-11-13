#!/usr/bin/env python3
"""修复closed属性错误"""

file_path = "/home/MRwang/smart_assistant/modules/asr/cloud_provider.py"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 查找并修改第292-294行
modified = False
for i in range(len(lines)):
    # 找到包含 "if self.ws and not self.ws.closed:" 的行
    if 'if self.ws and not self.ws.closed:' in lines[i]:
        # 改为简单的 if self.ws: 并用try-except包裹
        indent = '                        '  # 保持缩进
        lines[i] = f'{indent}# 主动关闭WebSocket，不等讯飞超时\n'
        lines.insert(i+1, f'{indent}if self.ws:\n')
        lines.insert(i+2, f'{indent}    try:\n')
        lines.insert(i+3, f'{indent}        await self.ws.close()\n')
        lines.insert(i+4, f'{indent}        self.logger.debug("WebSocket主动关闭，准备下一轮")\n')
        lines.insert(i+5, f'{indent}    except Exception:\n')
        lines.insert(i+6, f'{indent}        pass  # 关闭失败不影响重连\n')
        
        # 删除原来的close调用和debug日志（如果存在）
        # 需要删除接下来的几行
        del lines[i+7:i+10]  # 删除原来插入的3行
        
        modified = True
        break

if not modified:
    print("未找到需要修改的代码")
    exit(1)

# 写回文件
with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("✓ 修复完成")

# 验证语法
import py_compile
try:
    py_compile.compile(file_path, doraise=True)
    print("✓ 语法检查通过")
except Exception as e:
    print(f"✗ 语法错误: {e}")
    exit(1)
