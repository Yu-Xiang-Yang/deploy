#!/bin/bash
#
# 一键部署脚本：将应用部署到 RK3588 并配置自启动
#
# 用法: ./deploy.sh [app_dir]
#   app_dir: 要部署的应用目录，默认为脚本同级的 app 目录
#

set -e

# Windows Git Bash 下禁止路径自动转换，避免 adb 远程路径被篡改
export MSYS_NO_PATHCONV=1

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="${1:-$SCRIPT_DIR/app}"
REMOTE_APP_DIR="/data/rk3588app"
REMOTE_INIT_DIR="/etc/init.d"
SERVICE_NAME="S99rk3588app"

# 检查 adb 连接
echo "=== 检查 ADB 连接 ==="
if ! adb devices | grep -q "device$"; then
    echo "错误: 未检测到 ADB 设备，请检查连接"
    exit 1
fi
echo "ADB 设备已连接"

# 检查应用目录
if [ ! -d "$APP_DIR" ]; then
    echo "错误: 应用目录不存在: $APP_DIR"
    exit 1
fi

if [ ! -f "$APP_DIR/main.py" ]; then
    echo "错误: 应用目录中缺少 main.py"
    exit 1
fi

# 停止旧服务
echo ""
echo "=== 停止旧服务 ==="
MSYS_NO_PATHCONV=1 adb shell "$REMOTE_INIT_DIR/$SERVICE_NAME stop" 2>/dev/null || echo "旧服务未运行，跳过"

# 创建远程目录
echo ""
echo "=== 创建远程目录 ==="
MSYS_NO_PATHCONV=1 adb shell "mkdir -p $REMOTE_APP_DIR"

# 上传应用文件
echo ""
echo "=== 上传应用文件 ==="
for file in "$APP_DIR"/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo "  上传: $filename"
        win_file=$(cygpath -w "$file" 2>/dev/null || echo "$file")
        MSYS_NO_PATHCONV=1 adb push "$win_file" "$REMOTE_APP_DIR/$filename"
    fi
done

# 上传自启动脚本
echo ""
echo "=== 配置自启动服务 ==="
win_service=$(cygpath -w "$SCRIPT_DIR/$SERVICE_NAME" 2>/dev/null || echo "$SCRIPT_DIR/$SERVICE_NAME")
MSYS_NO_PATHCONV=1 adb push "$win_service" "$REMOTE_INIT_DIR/$SERVICE_NAME"
MSYS_NO_PATHCONV=1 adb shell "chmod 755 $REMOTE_INIT_DIR/$SERVICE_NAME"
echo "自启动脚本已安装"

# 启动服务
echo ""
echo "=== 启动服务 ==="
MSYS_NO_PATHCONV=1 adb shell "$REMOTE_INIT_DIR/$SERVICE_NAME start"

# 验证
echo ""
echo "=== 验证部署 ==="
sleep 5
if MSYS_NO_PATHCONV=1 adb shell "$REMOTE_INIT_DIR/$SERVICE_NAME status" | grep -q "running"; then
    echo "部署成功！服务已在运行"
else
    echo "警告: 服务可能未正常启动，请检查日志:"
    echo "  adb shell cat $REMOTE_APP_DIR/app.log"
fi

echo ""
echo "=== 部署完成 ==="
echo "常用命令:"
echo "  查看日志:   adb shell cat $REMOTE_APP_DIR/app.log"
echo "  查看状态:   adb shell $REMOTE_INIT_DIR/$SERVICE_NAME status"
echo "  重启服务:   adb shell $REMOTE_INIT_DIR/$SERVICE_NAME restart"
echo "  停止服务:   adb shell $REMOTE_INIT_DIR/$SERVICE_NAME stop"
