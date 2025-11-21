"""
测试 Memory State Machine 状态机逻辑
Step 9 阶段3单元测试
"""

import pytest
from modules.memory.state_machine import (
    state_machine,
    MemoryStatus,
    MemoryType,
    StateTransitionError
)


class TestDetermineInitialStatus:
    """测试初始状态判断逻辑"""

    def test_low_confidence_rejected(self):
        """置信度 < 0.5 应抛出异常"""
        with pytest.raises(StateTransitionError) as exc:
            state_machine.determine_initial_status("short", 0.49)
        assert "置信度过低" in str(exc.value)

    def test_boundary_confidence_accepted(self):
        """置信度 = 0.5 刚好接受"""
        status, reason = state_machine.determine_initial_status("short", 0.50)
        assert status == MemoryStatus.CANDIDATE
        assert "0.50" in reason

    def test_short_memory_candidate(self):
        """短期记忆 0.5 ≤ confidence < 0.8 → candidate"""
        status, reason = state_machine.determine_initial_status("short", 0.79)
        assert status == MemoryStatus.CANDIDATE
        assert "候选" in reason

    def test_short_memory_auto_active(self):
        """短期记忆 confidence ≥ 0.8 → active"""
        status, reason = state_machine.determine_initial_status("short", 0.80)
        assert status == MemoryStatus.ACTIVE
        assert "自动激活" in reason

    def test_profile_needs_confirm(self):
        """profile + confidence ≥ 0.9 → pending_confirm"""
        status, reason = state_machine.determine_initial_status("profile", 0.90)
        assert status == MemoryStatus.PENDING_CONFIRM
        assert "需确认" in reason

    def test_profile_auto_active_below_09(self):
        """profile + 0.8 ≤ confidence < 0.9 → active"""
        status, reason = state_machine.determine_initial_status("profile", 0.89)
        assert status == MemoryStatus.ACTIVE
        assert "自动激活" in reason

    def test_todo_high_confidence(self):
        """todo类型不触发pending_confirm（只有profile触发）"""
        status, reason = state_machine.determine_initial_status("todo", 0.95)
        assert status == MemoryStatus.ACTIVE
        assert "自动激活" in reason


class TestConfirmTransition:
    """测试确认转换逻辑"""

    def test_confirm_pending_to_active(self):
        """pending_confirm + confirm → active"""
        new_status, reason = state_machine.confirm(
            MemoryStatus.PENDING_CONFIRM,
            MemoryType.PROFILE
        )
        assert new_status == MemoryStatus.ACTIVE
        assert "用户确认" in reason

    def test_cannot_confirm_active(self):
        """active状态不应允许确认"""
        assert not state_machine.can_confirm(MemoryStatus.ACTIVE, MemoryType.PROFILE)

    def test_cannot_confirm_non_profile(self):
        """非profile类型不应允许确认（即使pending_confirm）"""
        # 实际上pending_confirm只会出现在profile，但测试边界情况
        assert not state_machine.can_confirm(
            MemoryStatus.PENDING_CONFIRM,
            MemoryType.SHORT
        )

    def test_can_confirm_valid_case(self):
        """有效场景：profile + pending_confirm"""
        assert state_machine.can_confirm(
            MemoryStatus.PENDING_CONFIRM,
            MemoryType.PROFILE
        )


class TestSoftDelete:
    """测试软删除逻辑"""

    def test_soft_delete_from_active(self):
        """active → deleted"""
        new_status, reason = state_machine.soft_delete(
            MemoryStatus.ACTIVE,
            "用户拒绝"
        )
        assert new_status == MemoryStatus.DELETED
        assert "用户拒绝" in reason

    def test_soft_delete_from_pending(self):
        """pending_confirm → deleted"""
        new_status, reason = state_machine.soft_delete(
            MemoryStatus.PENDING_CONFIRM,
            "测试"
        )
        assert new_status == MemoryStatus.DELETED

    def test_soft_delete_from_archived(self):
        """archived → deleted"""
        new_status, reason = state_machine.soft_delete(
            MemoryStatus.ARCHIVED,
            "清理"
        )
        assert new_status == MemoryStatus.DELETED


class TestArchiveTransition:
    """测试归档转换逻辑"""

    def test_archive_from_active(self):
        """active → archived"""
        new_status, reason = state_machine.archive(
            MemoryStatus.ACTIVE,
            "TTL到期"
        )
        assert new_status == MemoryStatus.ARCHIVED
        assert "TTL到期" in reason

    def test_archive_invalid_state(self):
        """candidate不应归档（需先激活）"""
        with pytest.raises(StateTransitionError):
            state_machine.archive(MemoryStatus.CANDIDATE, "错误")


class TestThresholds:
    """测试阈值常量"""

    def test_threshold_values(self):
        """验证阈值设置正确"""
        assert state_machine.CONFIDENCE_DISCARD == 0.5
        assert state_machine.CONFIDENCE_AUTO_ACTIVE == 0.8
        assert state_machine.CONFIDENCE_PROFILE_CONFIRM == 0.9

    def test_threshold_ordering(self):
        """验证阈值递增关系"""
        assert (
            state_machine.CONFIDENCE_DISCARD <
            state_machine.CONFIDENCE_AUTO_ACTIVE <
            state_machine.CONFIDENCE_PROFILE_CONFIRM
        )


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
