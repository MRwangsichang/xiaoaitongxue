"""
意图匹配器：根据用户输入智能选择最合适的回复
"""
import re
from typing import List, Dict, Tuple


class IntentMatcher:
    """意图匹配器"""
    
    def __init__(self, logger):
        self.logger = logger
        
        # 关键词权重映射（高权重=强相关）
        self.keyword_weights = {
            # 问候相关
            "想": 5, "念": 5, "想你": 8,
            
            # 吃饭相关  
            "吃": 6, "饭": 6, "饱": 5, "饿": 5,
            
            # 状态询问（提高权重）
            "干": 5, "干嘛": 8, "干吗": 8,
            "吗": 3, "嘛": 3, 
            "在": 5, "做": 5,
            
            # 情绪相关
            "爽": 5, "好": 3, "开心": 6, "高兴": 6,
            "一般": 5, "不好": 5, "差": 5,
            
            # 生意相关
            "生意": 8, "行情": 6, "门路": 6, "赚": 5,
            
            # 吹牛相关
            "吹牛": 8, "牛": 5, "厉害": 5,
            
            # 其他
            "真": 3, "假": 3, "真的": 5, "假的": 5,
            "知道": 5, "懂": 5, "听": 3, "说": 3,
        }
    
    def extract_keywords(self, text: str) -> List[str]:
        """从文本中提取关键词"""
        # 去除标点
        text = re.sub(r'[，。！？、；：""''（）《》【】]', '', text)
        
        keywords = []
        # 提取在权重表中的关键词
        for kw in self.keyword_weights.keys():
            if kw in text:
                keywords.append(kw)
        
        return keywords
    
    def calculate_match_score(self, user_input: str, response_text: str) -> float:
        """
        计算匹配分数
        
        Args:
            user_input: 用户输入
            response_text: 候选回复文本
            
        Returns:
            匹配分数（0-100）
        """
        user_kw = self.extract_keywords(user_input)
        response_kw = self.extract_keywords(response_text)
        
        if not user_kw:
            # 用户输入没有关键词，无法匹配
            return 0.0
        
        # 计算共同关键词的权重和
        score = 0.0
        matched_kw = []
        
        for kw in user_kw:
            if kw in response_kw:
                weight = self.keyword_weights.get(kw, 1)
                score += weight * 10  # 放大分数
                matched_kw.append(kw)
        
        # 如果回复中包含问号，降低分数（避免用反问回答问题）
        if '？' in response_text or '?' in response_text:
            score *= 0.5
        
        # 长度惩罚（避免过长回复）
        if len(response_text) > 30:
            score *= 0.9
        
        if matched_kw:
            self.logger.debug(f"匹配关键词: {matched_kw}, 分数: {score:.1f}")
        
        return score
    
    def select_best_response(self, user_input: str, candidates: List[Dict]) -> Dict:
        """
        从候选回复中选择最佳匹配
        
        Args:
            user_input: 用户输入
            candidates: 候选回复列表（每个包含actions字段）
            
        Returns:
            最佳匹配的回复
        """
        if not candidates:
            return None
        
        # 计算每个候选的匹配分数
        scored_candidates = []
        for candidate in candidates:
            # 获取回复文本
            response_text = ""
            for action in candidate.get('actions', []):
                if action['type'] == 'say':
                    response_text = action['params'].get('text', '')
                    break
            
            score = self.calculate_match_score(user_input, response_text)
            scored_candidates.append((score, candidate))
        
        # 按分数排序
        scored_candidates.sort(key=lambda x: x[0], reverse=True)
        
        best_score, best_candidate = scored_candidates[0]
        
        if best_score > 0:
            self.logger.info(f"智能匹配: 分数={best_score:.1f}")
            return best_candidate
        else:
            # 没有匹配，随机选择
            import random
            self.logger.info("无关键词匹配，随机选择")
            return random.choice(candidates)

    def detect_correction(self, user_input: str) -> bool:
        """
        检测用户是否在纠正/追问（表示不满意上次回复）
        
        Args:
            user_input: 用户输入
            
        Returns:
            True=检测到纠正信号
        """
        correction_signals = [
            "我不是问", "我问的是", "我说的是",
            "不对", "不是", "错了",
            "你没理解", "你没懂", "没听懂",
            "重新", "再说", "再问",
            "我的意思是", "我想问"
        ]
        
        for signal in correction_signals:
            if signal in user_input:
                self.logger.info(f"检测到纠正信号: {signal}")
                return True
        
        return False
