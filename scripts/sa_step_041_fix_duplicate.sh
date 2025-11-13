#!/usr/bin/env bash
set -euo pipefail

say(){ printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ASR_FILE="/home/MRwang/smart_assistant/modules/asr/xunfei_asr.py"

say "修复识别结果重复问题..."

# 备份
cp "$ASR_FILE" "$ASR_FILE.bak_dup_fix"

# 用Python重写_receive_result方法
python3 <<'PYCODE'
import re

# 读取文件
with open("/home/MRwang/smart_assistant/modules/asr/xunfei_asr.py", "r") as f:
    content = f.read()

# 替换_receive_result方法
new_method = '''    async def _receive_result(self):
        """接收识别结果"""
        try:
            sentence_texts = []  # 存储每个句子的文本
            
            while self.is_recording and self.ws and self.ws.state.value <= 1:
                message = await self.ws.recv()
                data = json.loads(message)
                
                code = data.get('code', 0)
                if code != 0:
                    self.logger.error(f"识别错误: {data.get('message', 'Unknown error')}")
                    break
                    
                # 解析结果
                result = data.get('data', {}).get('result', {})
                status = data.get('data', {}).get('status', 0)
                
                # 获取句子序号
                sn = result.get('sn', 0)
                
                # 确保列表足够长
                while len(sentence_texts) <= sn:
                    sentence_texts.append("")
                
                # 提取当前句子的文本
                sentence_text = ""
                ws_list = result.get('ws', [])
                for ws_item in ws_list:
                    for cw in ws_item.get('cw', []):
                        word = cw.get('w', '')
                        sentence_text += word
                        
                # 更新当前句子
                sentence_texts[sn] = sentence_text
                
                # 拼接完整文本
                self.current_text = ''.join(sentence_texts)
                
                # 发布部分结果（降低频率）
                if self.current_text and len(self.current_text) % 5 == 0:  # 每5个字发一次
                    await self.publish_asr_result(self.current_text, is_final=False)
                    
                # 判断是否结束
                if status == 2:
                    # 识别结束
                    if self.current_text:
                        self.logger.info(f"最终识别结果: {self.current_text}")
                        await self.publish_asr_result(self.current_text, is_final=True)
                    self.current_text = ""
                    break
                    
        except Exception as e:
            if self.is_recording:
                self.logger.error(f"接收结果出错: {e}")'''

# 找到并替换方法
pattern = r'async def _receive_result\(self\):.*?(?=\n    async def |\n    def |\nclass |\Z)'
content = re.sub(pattern, new_method, content, flags=re.DOTALL)

# 写回文件
with open("/home/MRwang/smart_assistant/modules/asr/xunfei_asr.py", "w") as f:
    f.write(content)

print("修复完成")
PYCODE

say "识别重复问题已修复"
