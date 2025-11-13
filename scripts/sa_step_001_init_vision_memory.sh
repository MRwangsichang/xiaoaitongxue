#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="${DRY_RUN:-1}"
ROOT="/home/MRwang/smart_assistant"

say() { printf "[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
check() { 
    if [ "$DRY_RUN" = "1" ]; then
        say "[✓] 将$*"
    else
        say "[✓] $*"
    fi
}

say "=== Phase 1A Step 1: 初始化 Vision & Memory 模块结构 ==="
[ "$DRY_RUN" = "1" ] && say "DRY-RUN: 仅打印将执行的操作，不改系统"

VISION_MAIN="${ROOT}/modules/vision/vision_manager.py"
if [ "$DRY_RUN" = "0" ]; then
    mkdir -p "$(dirname "$VISION_MAIN")"
    cat > "$VISION_MAIN" <<'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Vision Manager - 视觉模块主入口
职责：统一管理人脸识别、扫描调度、相机资源
作者：MRwang
创建：2025-10-30
"""

class VisionManager:
    """视觉模块总控制器"""
    
    def __init__(self):
        self.recognizer = None
        self.detector = None
        
    def initialize(self):
        """初始化视觉子系统"""
        pass
        
    def cleanup(self):
        """清理资源"""
        pass

if __name__ == "__main__":
    print("Vision Manager - 主入口文件已就绪")
PYEOF
    chmod 644 "$VISION_MAIN"
    check "创建主入口: modules/vision/vision_manager.py"
else
    check "创建主入口: modules/vision/vision_manager.py"
fi

MEMORY_MAIN="${ROOT}/modules/memory/memory_manager.py"
if [ "$DRY_RUN" = "0" ]; then
    mkdir -p "$(dirname "$MEMORY_MAIN")"
    cat > "$MEMORY_MAIN" <<'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Memory Manager - 记忆模块主入口
职责：统一管理画像存储、近事摘要、未了事项
作者：MRwang
创建：2025-10-30
"""

class MemoryManager:
    """记忆模块总控制器"""
    
    def __init__(self):
        self.storage = None
        self.retrieval = None
        
    def initialize(self):
        """初始化记忆子系统"""
        pass
        
    def cleanup(self):
        """清理资源"""
        pass

if __name__ == "__main__":
    print("Memory Manager - 主入口文件已就绪")
PYEOF
    chmod 644 "$MEMORY_MAIN"
    check "创建主入口: modules/memory/memory_manager.py"
else
    check "创建主入口: modules/memory/memory_manager.py"
fi

VISION_SUBDIRS=(
    "${ROOT}/modules/vision/recognizer"
    "${ROOT}/modules/vision/detector"
    "${ROOT}/modules/vision/utils"
)

for dir in "${VISION_SUBDIRS[@]}"; do
    if [ "$DRY_RUN" = "0" ]; then
        mkdir -p "$dir"
        touch "$dir/__init__.py"
        chmod 644 "$dir/__init__.py"
    fi
    check "创建子目录: ${dir#$ROOT/}"
done

MEMORY_SUBDIRS=(
    "${ROOT}/modules/memory/storage"
    "${ROOT}/modules/memory/retrieval"
)

for dir in "${MEMORY_SUBDIRS[@]}"; do
    if [ "$DRY_RUN" = "0" ]; then
        mkdir -p "$dir"
        touch "$dir/__init__.py"
        chmod 644 "$dir/__init__.py"
    fi
    check "创建子目录: ${dir#$ROOT/}"
done

FACE_DATA_DIR="${ROOT}/data/faces/王总/raw"
if [ "$DRY_RUN" = "0" ]; then
    mkdir -p "$FACE_DATA_DIR"
    chmod 755 "$FACE_DATA_DIR"
    cat > "${ROOT}/data/faces/README.md" <<'MDEOF'
# 人脸数据目录说明

## 目录结构
```
faces/
├── 王总/
│   ├── raw/          # 原始采集照片（100张）
│   └── processed/    # 预处理后的照片（后续生成）
├── model.yml         # 训练好的LBPH模型（后续生成）
└── README.md         # 本文件
```

## 采集规范
- 每人100张照片
- 分辨率：1280×960（采集） / 640×480（识别）
- 格式：PNG
- 命名：img_0001.png ~ img_0100.png
MDEOF
    chmod 644 "${ROOT}/data/faces/README.md"
fi
check "创建人脸数据目录: data/faces/王总/raw/"

say "开始环境健康检查..."

if [ -e "/dev/video0" ] && [ -r "/dev/video0" ]; then
    check "相机设备检查: /dev/video0 存在且可读"
else
    say "[✗] 相机设备不可访问: /dev/video0"
    exit 1
fi

if groups | grep -q '\bvideo\b'; then
    check "用户权限检查: $(whoami) 在 video 组"
else
    say "[✗] 用户 $(whoami) 不在 video 组，需执行: sudo usermod -aG video $(whoami)"
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
if python3 -c "import sys; exit(0 if sys.version_info >= (3, 11) else 1)" 2>/dev/null; then
    OPENCV_CHECK=$(python3 -c "import cv2; print('OK')" 2>&1)
    if [ "$OPENCV_CHECK" = "OK" ]; then
        check "Python环境检查: ${PYTHON_VERSION} & opencv-python 已安装"
    else
        say "[✗] opencv-python 未安装，需执行: pip3 install opencv-python --break-system-packages"
        exit 1
    fi
else
    say "[✗] Python版本不符合要求（需 >= 3.11），当前: ${PYTHON_VERSION}"
    exit 1
fi

if [ "$DRY_RUN" = "1" ]; then
    say "=== DRY-RUN 完成，设置 DRY_RUN=0 执行真实操作 ==="
else
    say "=== 初始化完成！可执行下一步：编写人脸采集工具 ==="
fi
