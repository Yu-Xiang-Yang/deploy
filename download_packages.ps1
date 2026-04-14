#
# 根据 requirements.txt 自动下载 RK3588 离线 .whl 依赖包
#
# 用法: .\download_packages.ps1 [requirements_path]
#

param(
    [string]$RequirementsPath = ""
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AppDir = Join-Path $ScriptDir "app"
$PackagesDir = Join-Path $AppDir "packages"
if ($RequirementsPath -eq "") { $RequirementsPath = Join-Path $AppDir "requirements.txt" }

# 检查 requirements.txt
if (-not (Test-Path $RequirementsPath)) {
    Write-Host "错误: 未找到 $RequirementsPath" -ForegroundColor Red
    Write-Host "请在 app/ 目录下创建 requirements.txt"
    exit 1
}

# 创建 packages 目录
if (-not (Test-Path $PackagesDir)) {
    New-Item -ItemType Directory -Path $PackagesDir | Out-Null
}

Write-Host "=== 下载离线依赖包 ===" -ForegroundColor Cyan
Write-Host "  requirements: $RequirementsPath"
Write-Host "  目标平台: linux_aarch64 / Python 3.10"
Write-Host "  下载目录: $PackagesDir"
Write-Host ""

# 下载 whl 文件（尝试多个平台标签）
pip download -r $RequirementsPath `
    --platform manylinux2014_aarch64 `
    --platform manylinux_2_17_aarch64 `
    --platform linux_aarch64 `
    --python-version 310 `
    --only-binary=:all: `
    -d $PackagesDir

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=== 下载完成 ===" -ForegroundColor Green
    Write-Host "已下载的包:"
    Get-ChildItem -Path $PackagesDir -Filter "*.whl" | ForEach-Object {
        Write-Host "  $($_.Name)"
    }
    Write-Host ""
    Write-Host "运行 .\deploy.ps1 即可部署到设备"
} else {
    Write-Host ""
    Write-Host "=== 部分包下载失败 ===" -ForegroundColor Yellow
    Write-Host "可能原因: 该包没有 linux_aarch64 的预编译版本"
    Write-Host "解决方法: 从 https://pypi.org 手动下载对应 cp310-linux_aarch64 的 .whl 文件放入 app/packages/"
}
