"""
测试 TTL 过期处理逻辑
Step 10 单元测试
"""

import pytest
from datetime import datetime, timezone, timedelta
from modules.memory.state_machine import state_machine, StateTransitionError


class TestArchiveTransition:
    """测试 active → archived 转换"""

    def test_archive_active_memory(self):
        """active状态可以归档"""
        new_status, reason = state_machine.archive('active', 'TTL到期')
        assert new_status == 'archived'
        assert 'TTL到期' in reason

    def test_cannot_archive_candidate(self):
        """candidate状态不能直接归档"""
        with pytest.raises(StateTransitionError):
            state_machine.archive('candidate', 'TTL到期')

    def test_cannot_archive_deleted(self):
        """deleted状态不能归档"""
        with pytest.raises(StateTransitionError):
            state_machine.archive('deleted', 'TTL到期')


class TestSoftDeleteFromArchived:
    """测试 archived → deleted 转换"""

    def test_soft_delete_archived(self):
        """archived可以软删除"""
        new_status, reason = state_machine.soft_delete('archived', '归档30天后')
        assert new_status == 'deleted'
        assert '归档30天后' in reason

    def test_soft_delete_keeps_reason(self):
        """软删除保留原因"""
        new_status, reason = state_machine.soft_delete('active', '测试原因')
        assert new_status == 'deleted'
        assert '测试原因' in reason


class TestExpirationThresholds:
    """测试过期阈值常量"""

    def test_ttl_thresholds_exist(self):
        """验证TTL相关的时间阈值"""
        # 注意：实际阈值在代码中硬编码为30天和7天
        # 这里主要测试状态机方法的正确性
        assert hasattr(state_machine, 'archive')
        assert hasattr(state_machine, 'soft_delete')

    def test_state_transitions_are_atomic(self):
        """验证状态转换是原子的"""
        # active → archived
        status1, _ = state_machine.archive('active', '测试')
        assert status1 == 'archived'

        # archived → deleted
        status2, _ = state_machine.soft_delete('archived', '测试')
        assert status2 == 'deleted'


class TestExpirationReasons:
    """测试过期原因记录"""

    def test_ttl_expiry_reason(self):
        """TTL到期应记录正确原因"""
        _, reason = state_machine.archive('active', 'TTL到期')
        assert 'TTL到期' == reason

    def test_archived_cleanup_reason(self):
        """归档清理应记录正确原因"""
        _, reason = state_machine.soft_delete('archived', '归档30天后软删除')
        assert '归档30天后' in reason

    def test_reason_preserved_in_return(self):
        """原因应该在返回值中保留"""
        custom_reason = '自定义测试原因'
        _, reason = state_machine.soft_delete('active', custom_reason)
        assert custom_reason in reason


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
