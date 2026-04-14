#!/bin/bash
#
# 根据 requirements.txt 自动下载 RK3588 离线 .whl 依赖包
#
# 用法: bash download_packages.sh [requirements_path]
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/app"
PACKAGES_DIR="$APP_DIR/packages"
REQUIREMENTS="${1:-$APP_DIR/requirements.txt}"

# 检查 requirements.txt
if [ ! -f "$REQUIREMENTS" ]; then
    echo "错误: 未找到 $REQUIREMENTS"
    echo "请在 app/ 目录下创建 requirements.txt"
    exit 1
fi

# 创建 packages 目录
mkdir -p "$PACKAGES_DIR"

echo "=== 下载离线依赖包 ==="
echo "  requirements: $REQUIREMENTS"
echo "  目标平台: linux_aarch64 / Python 3.10"
echo "  下载目录: $PACKAGES_DIR"
echo ""

# 下载 whl 文件
pip download -r "$REQUIREMENTS" --platform linux_aarch64 --python-version 310 --only-binary=:all: -d "$PACKAGES_DIR"

if [ $? -eq 0 ]; then
    echo ""
    echo "=== 下载完成 ==="
    echo "已下载的包:"
    ls "$PACKAGES_DIR"/*.whl 2>/dev/null | while read f; do
        echo "  $(basename "$f")"
    done
    echo ""
    echo "运行部署脚本即可部署到设备"
else
    echo ""
    echo "=== 部分包下载失败 ==="
    echo "可能原因: 该包没有 linux_aarch64 的预编译版本"
    echo "解决方法: 从 https://pypi.org 手动下载对应 cp310-linux_aarch64 的 .whl 文件放入 app/packages/"
fi
