#
# 一键部署脚本（PowerShell 版）：将应用部署到 RK3588 并配置自启动
#
# 用法: .\deploy.ps1 [app_dir]
#   app_dir: 要部署的应用目录，默认为脚本同级的 app 目录
#

param(
    [string]$AppDir = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($AppDir -eq "") { $AppDir = Join-Path $ScriptDir "app" }
$RemoteAppDir = "/data/rk3588app"
$RemoteInitDir = "/etc/init.d"
$ServiceName = "S99rk3588app"

# 检查 adb 连接
Write-Host "=== 检查 ADB 连接 ===" -ForegroundColor Cyan
$devices = (adb devices 2>&1) -join "`n"
if ($devices -notmatch "\tdevice") {
    Write-Host "错误: 未检测到 ADB 设备，请检查连接" -ForegroundColor Red
    exit 1
}
Write-Host "ADB 设备已连接"

# 检查应用目录
if (-not (Test-Path $AppDir)) {
    Write-Host "错误: 应用目录不存在: $AppDir" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path (Join-Path $AppDir "main.py"))) {
    Write-Host "错误: 应用目录中缺少 main.py" -ForegroundColor Red
    exit 1
}

# 停止旧服务
Write-Host ""
Write-Host "=== 停止旧服务 ===" -ForegroundColor Cyan
adb shell "$RemoteInitDir/$ServiceName stop" 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "旧服务未运行，跳过" }

# 创建远程目录
Write-Host ""
Write-Host "=== 创建远程目录 ===" -ForegroundColor Cyan
adb shell "mkdir -p $RemoteAppDir"

# 上传应用文件
Write-Host ""
Write-Host "=== 上传应用文件 ===" -ForegroundColor Cyan
Get-ChildItem -Path $AppDir -File | ForEach-Object {
    Write-Host "  上传: $($_.Name)"
    adb push $_.FullName "${RemoteAppDir}/$($_.Name)"
}

# 上传并安装离线依赖包
$PackagesDir = Join-Path $AppDir "packages"
if ((Test-Path $PackagesDir) -and (Get-ChildItem -Path $PackagesDir -Filter "*.whl" -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "=== 安装离线依赖 ===" -ForegroundColor Cyan
    $RemotePkgDir = "$RemoteAppDir/packages"
    adb shell "mkdir -p $RemotePkgDir"
    Get-ChildItem -Path $PackagesDir -Filter "*.whl" | ForEach-Object {
        Write-Host "  上传: $($_.Name)"
        adb push $_.FullName "${RemotePkgDir}/$($_.Name)"
    }
    Write-Host "  安装依赖包..."
    adb shell "pip3 install --no-deps ${RemotePkgDir}/*.whl"
    Write-Host "  依赖安装完成"
}

# 上传自启动脚本
Write-Host ""
Write-Host "=== 配置自启动服务 ===" -ForegroundColor Cyan
$servicePath = Join-Path $ScriptDir $ServiceName
adb push $servicePath "${RemoteInitDir}/${ServiceName}"
adb shell "chmod 755 $RemoteInitDir/$ServiceName"
Write-Host "自启动脚本已安装"

# 启动服务
Write-Host ""
Write-Host "=== 启动服务 ===" -ForegroundColor Cyan
adb shell "$RemoteInitDir/$ServiceName start"

# 验证
Write-Host ""
Write-Host "=== 验证部署 ===" -ForegroundColor Cyan
Start-Sleep -Seconds 5
$status = adb shell "$RemoteInitDir/$ServiceName status"
if ($status -match "running") {
    Write-Host "部署成功！服务已在运行" -ForegroundColor Green
} else {
    Write-Host "警告: 服务可能未正常启动，请检查日志:" -ForegroundColor Yellow
    Write-Host "  adb shell cat $RemoteAppDir/app.log"
}

Write-Host ""
Write-Host "=== 部署完成 ===" -ForegroundColor Cyan
Write-Host "常用命令:"
Write-Host "  查看日志:   adb shell cat $RemoteAppDir/app.log"
Write-Host "  查看状态:   adb shell $RemoteInitDir/$ServiceName status"
Write-Host "  重启服务:   adb shell $RemoteInitDir/$ServiceName restart"
Write-Host "  停止服务:   adb shell $RemoteInitDir/$ServiceName stop"
