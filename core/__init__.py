"""
Core Module - Framework components
Exports: config_loader, logger, event_bus, health
"""

# Config loader
from .config_loader import load_config

# Logger
from .logger import get_logger, setup_logger

# Event bus (MQTT) - import EventBus and alias as MQTTEventBus
from .event_bus import EventBus, EventBus as MQTTEventBus

# Health reporter
from .health import HealthReporter

__all__ = [
    "load_config",
    "get_logger",
    "setup_logger",
    "EventBus",
    "MQTTEventBus",
    "HealthReporter",
]
