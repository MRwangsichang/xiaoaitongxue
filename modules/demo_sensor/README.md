# demo_sensor 模块

## 功能说明

TODO: 描述模块功能

## 主题规范

### 订阅
- `sa/demo_sensor/cmd/#` - 接收命令

### 发布
- `sa/demo_sensor/event/#` - 事件结果
- `sa/demo_sensor/health` - 健康心跳
- `sa/demo_sensor/error` - 错误报告

## 配置

参见 `config/demo_sensor.yml`

## 测试

```bash
python3 tests/test_demo_sensor_module.py
```

## 运行

```bash
python3 modules/demo_sensor/demo_sensor_module.py
```
