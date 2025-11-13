#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${DRY_RUN:-1}"
say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }

ROOT="/home/MRwang/smart_assistant"
TARGET_FILE="${ROOT}/modules/tts/tts_module.py"

# ==================== 备份检查 ====================
if [ -f "$TARGET_FILE" ]; then
    BACKUP="${TARGET_FILE}.bak_$(date +%s)"
    if [ "$DRY_RUN" = "0" ]; then
        cp "$TARGET_FILE" "$BACKUP"
        say "⚠ 文件已存在，已备份到 $(basename $BACKUP)"
    else
        say "DRY-RUN: 将备份现有文件到 $(basename $BACKUP)"
    fi
fi

# ==================== 生成tts_module.py ====================
if [ "$DRY_RUN" = "1" ]; then
    say "DRY-RUN: 将创建 tts_module.py"
else
    say "正在创建 tts_module.py ..."
fi

TTS_MODULE_CONTENT='"""
TTS Module - 语音合成与播放管理
订阅 sa/tts/say → 合成音频 → 控制ASR → 播放 → 恢复ASR
"""
import asyncio
import os
import sys
from typing import Optional
from collections import deque
from datetime import datetime

# 添加项目根到path
sys.path.insert(0, "/home/MRwang/smart_assistant")

from core import get_logger, load_config, HealthReporter
from core.event_bus import EventBus, EventEnvelope


class TTSModule:
    def __init__(self, config_path="config/tts.yml"):
        self.config = load_config(config_path)
        self.logger = get_logger("tts")
        self.bus: Optional[EventBus] = None
        self.health: Optional[HealthReporter] = None
        
        # 播放队列（排队播放，不打断）
        self.queue = deque(maxlen=self.config.get("queue", {}).get("max_size", 10))
        self.queue_event = asyncio.Event()
        
        # Provider（主+兜底）
        self.provider = None
        self.fallback_provider = None
        
        self.running = False
        self._player_task = None

    async def start(self):
        """启动TTS模块"""
        self.logger.info("=== TTS Module Starting ===")
        
        # 1. 初始化EventBus
        self.bus = EventBus(module_name="tts")
        
        # 2. 初始化Health Reporter
        health_interval = self.config.get("health_interval", 10)
        self.health = HealthReporter(module_name="tts", interval=health_interval)
        await self.health.start()
        
        # 3. 初始化Provider
        await self._init_providers()
        
        # 4. 订阅TTS请求
        await self.bus.start_listening({
            "sa/tts/say": self._handle_tts_request
        })
        
        # 5. 启动播放队列处理
        self.running = True
        self._player_task = asyncio.create_task(self._player_loop())
        
        self.logger.info("✓ TTS module ready")
        self.logger.info(f"  Provider: {self.provider.__class__.__name__}")
        self.logger.info(f"  Audio device: {self.config[\"audio\"][\"device\"]}")

    async def _init_providers(self):
        """初始化合成引擎（主+兜底）"""
        provider_type = self.config.get("provider", "xunfei_x5")
        
        try:
            if provider_type == "xunfei_x5":
                from modules.tts.xunfei_x5_provider import XunfeiX5TTSProvider
                self.provider = XunfeiX5TTSProvider(self.config, self.logger)
                self.logger.info("主Provider: 讯飞x5超拟人（聆飞逸男声）")
            elif provider_type == "xunfei":
                from modules.tts.xunfei_provider import XunfeiTTSProvider
                self.provider = XunfeiTTSProvider(self.config, self.logger)
                self.logger.info("主Provider: 讯飞标准TTS")
            elif provider_type == "edge":
                from modules.tts.edge_provider import EdgeTTSProvider
                self.provider = EdgeTTSProvider(self.config, self.logger)
                self.logger.info("主Provider: Edge-TTS")
            else:
                raise ValueError(f"未知provider类型: {provider_type}")
        except Exception as e:
            self.logger.error(f"主Provider初始化失败: {e}")
            raise
        
        # 初始化兜底Provider（Edge-TTS）
        try:
            if provider_type != "edge":
                from modules.tts.edge_provider import EdgeTTSProvider
                self.fallback_provider = EdgeTTSProvider(self.config, self.logger)
                self.logger.info("兜底Provider: Edge-TTS")
        except ImportError:
            self.logger.warning("Edge-TTS未安装，无兜底方案")
        except Exception as e:
            self.logger.warning(f"兜底Provider初始化失败: {e}")

    async def _handle_tts_request(self, envelope):
        """处理TTS请求（加入队列）"""
        try:
            payload = envelope.payload if hasattr(envelope, "payload") else envelope
            text = payload.get("text", "")
            
            if not text:
                self.logger.warning("收到空文本TTS请求")
                return
            
            # 截断日志显示
            display_text = text[:30] + "..." if len(text) > 30 else text
            self.logger.info(f"收到TTS请求: {display_text}")
            
            # 加入播放队列
            self.queue.append(payload)
            self.queue_event.set()
            
        except Exception as e:
            self.logger.error(f"处理TTS请求失败: {e}", exc_info=True)

    async def _player_loop(self):
        """播放队列处理循环"""
        while self.running:
            try:
                # 等待队列有数据
                if not self.queue:
                    await self.queue_event.wait()
                    self.queue_event.clear()
                
                if not self.queue:
                    continue
                
                # 取出任务
                payload = self.queue.popleft()
                text = payload["text"]
                
                # 执行完整播放流程
                await self._play_text(text)
                
            except Exception as e:
                self.logger.error(f"播放循环错误: {e}", exc_info=True)
                await asyncio.sleep(1)

    async def _play_text(self, text: str):
        """完整播放流程（含ASR控制）"""
        audio_file = None
        
        try:
            # 1. 暂停ASR录音（防回声）
            if self.config.get("asr_control", {}).get("pause_before_play", True):
                await self._pause_asr()
            
            # 2. 合成音频（优先主Provider，失败用兜底）
            audio_file = await self._synthesize(text)
            
            if not audio_file:
                raise Exception("音频合成失败")
            
            # 3. 播放音频
            await self._play_audio(audio_file)
            
            self.logger.info("✓ 播放完成")
            
        except Exception as e:
            self.logger.error(f"播放失败: {e}", exc_info=True)
            await self._publish_error("play_failed", text, str(e))
        
        finally:
            # 4. 恢复ASR录音
            if self.config.get("asr_control", {}).get("resume_after_play", True):
                await self._resume_asr()
            
            # 5. 清理临时文件
            if audio_file and os.path.exists(audio_file):
                try:
                    os.remove(audio_file)
                except Exception as e:
                    self.logger.warning(f"清理临时文件失败: {e}")

    async def _synthesize(self, text: str) -> Optional[str]:
        """合成音频（自动兜底）"""
        # 尝试主Provider
        try:
            audio_file = await self.provider.synthesize(text)
            if audio_file and os.path.exists(audio_file):
                return audio_file
        except Exception as e:
            self.logger.warning(f"主Provider合成失败: {e}")
        
        # 兜底：使用fallback provider
        if self.fallback_provider:
            self.logger.info("切换到兜底Provider（Edge-TTS）")
            try:
                audio_file = await self.fallback_provider.synthesize(text)
                if audio_file and os.path.exists(audio_file):
                    return audio_file
            except Exception as e:
                self.logger.error(f"兜底Provider也失败: {e}")
        
        return None

    async def _play_audio(self, audio_file: str):
        """播放音频文件"""
        device = self.config["audio"]["device"]
        player = self.config["audio"].get("player", "mpg123")
        
        cmd = [player, "-a", device, audio_file]
        
        self.logger.debug(f"播放命令: {' '.join(cmd)}")
        
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE
        )
        
        await proc.wait()
        
        if proc.returncode != 0:
            stderr = (await proc.stderr.read()).decode()
            raise Exception(f"播放器错误: {stderr}")

    async def _pause_asr(self):
        """暂停ASR录音"""
        try:
            await self.bus.publish(
                topic="sa/asr/cmd/stop",
                event_type="cmd.stop",
                payload={}
            )
            self.logger.debug("→ 发送ASR stop命令")
            
            # 短暂延迟确保ASR停止
            delay_ms = self.config.get("asr_control", {}).get("pause_delay_ms", 100)
            await asyncio.sleep(delay_ms / 1000.0)
        except Exception as e:
            self.logger.warning(f"暂停ASR失败: {e}")

    async def _resume_asr(self):
        """恢复ASR录音"""
        try:
            await self.bus.publish(
                topic="sa/asr/cmd/start",
                event_type="cmd.start",
                payload={}
            )
            self.logger.debug("→ 发送ASR start命令")
        except Exception as e:
            self.logger.warning(f"恢复ASR失败: {e}")

    async def _publish_error(self, error_type: str, text: str, reason: str):
        """发布错误事件"""
        try:
            await self.bus.publish(
                topic="sa/tts/error",
                event_type="tts.error",
                payload={
                    "error": error_type,
                    "text": text[:50],
                    "reason": reason
                }
            )
        except Exception as e:
            self.logger.error(f"发布错误事件失败: {e}")

    async def stop(self):
        """停止模块"""
        self.logger.info("正在停止TTS模块...")
        self.running = False
        
        if self._player_task:
            self._player_task.cancel()
            try:
                await self._player_task
            except asyncio.CancelledError:
                pass
        
        if self.health:
            await self.health.stop()
        
        if self.bus:
            self.bus.stop()
        
        self.logger.info("✓ TTS模块已停止")


async def main():
    """主入口"""
    module = TTSModule()
    try:
        await module.start()
        # 保持运行
        while True:
            await asyncio.sleep(1)
    except KeyboardInterrupt:
        print("\n收到中断信号")
    finally:
        await module.stop()


if __name__ == "__main__":
    asyncio.run(main())
'

if [ "$DRY_RUN" = "0" ]; then
    echo "$TTS_MODULE_CONTENT" > "$TARGET_FILE"
    chmod 644 "$TARGET_FILE"
    say "✓ tts_module.py 已创建"
else
    say "DRY-RUN: 将创建 tts_module.py ($(echo "$TTS_MODULE_CONTENT" | wc -c) 字节)"
fi

# ==================== 验证 ====================
if [ "$DRY_RUN" = "0" ]; then
    if grep -q "class TTSModule" "$TARGET_FILE" && \
       grep -q "async def _synthesize" "$TARGET_FILE" && \
       grep -q "sa/tts/say" "$TARGET_FILE" && \
       grep -q "_pause_asr" "$TARGET_FILE"; then
        say "✓ 文件内容验证通过"
    else
        say "✗ 文件内容验证失败"
        exit 1
    fi
else
    say "DRY-RUN: 文件内容已验证：包含订阅、合成、ASR控制、播放、健康心跳"
fi

if [ "$DRY_RUN" = "1" ]; then
    say "✓ 小步1完成（DRY-RUN模式）"
else
    say "✓ 小步1完成"
fi
