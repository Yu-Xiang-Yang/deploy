# RK3588 Auto-Deploy

一键部署 Python 应用到 RK3588 开发板，并配置开机自启动。

适用于 Buildroot 系统下基于 `init.d` 的 RK3588 设备。

## 项目结构

```
├── deploy.sh          # 一键部署脚本（Git Bash）
├── deploy.ps1         # 一键部署脚本（PowerShell）
├── S99rk3588app       # init.d 自启动服务脚本
├── README.md
└── app/
    └── main.py        # 应用程序（替换为你自己的）
```

## 前提条件

- RK3588 设备已通过 USB 连接，`adb devices` 可识别
- 设备上已安装 Python3（`/usr/bin/python3`）
- 主机环境为 Windows（PowerShell / Git Bash）或 Linux/macOS

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/<your-username>/rk3588-auto-deploy.git
cd rk3588-auto-deploy
```

### 2. 放入你的应用

将你的 Python 程序放到 `app/` 目录下，入口文件命名为 `main.py`。

示例 `app/main.py`：

```python
import time

while True:
    print("test", flush=True)
    time.sleep(10)
```

> **注意：** `print` 需要加 `flush=True`，否则后台运行时日志不会实时写入。

### 3. 部署

**PowerShell（推荐）：**

```powershell
.\deploy.ps1
```

> 如果提示脚本执行策略限制，先运行一次：
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
> ```

**Git Bash：**

```bash
bash deploy.sh
```

脚本会自动完成以下步骤：

1. 检查 ADB 连接
2. 停止旧服务
3. 上传 `app/` 下所有文件到设备 `/data/rk3588app/`
4. 安装自启动脚本到 `/etc/init.d/S99rk3588app`
5. 启动服务并验证

### 4. 验证

```bash
# 查看服务状态
adb shell /etc/init.d/S99rk3588app status

# 查看日志
adb shell cat /data/rk3588app/app.log
```

## 常用命令

| 操作 | 命令 |
|------|------|
| 启动服务 | `adb shell /etc/init.d/S99rk3588app start` |
| 停止服务 | `adb shell /etc/init.d/S99rk3588app stop` |
| 重启服务 | `adb shell /etc/init.d/S99rk3588app restart` |
| 查看状态 | `adb shell /etc/init.d/S99rk3588app status` |
| 查看日志 | `adb shell cat /data/rk3588app/app.log` |
| 清空日志 | `adb shell "> /data/rk3588app/app.log"` |

## 自定义配置

如需修改部署路径或服务名，编辑 `deploy.sh`（或 `deploy.ps1`）顶部的变量：

```bash
REMOTE_APP_DIR="/data/rk3588app"      # 设备上的应用目录
SERVICE_NAME="S99rk3588app"           # 服务脚本名称（数字越大启动越晚）
```

同时修改 `S99rk3588app` 中对应的路径。

## 原理说明

RK3588 Buildroot 系统使用 `init.d` 管理开机启动服务。`/etc/init.d/` 下以 `S` 开头的脚本会在系统启动时按编号顺序执行。本项目通过 `start-stop-daemon` 将 Python 程序以后台进程运行，并将 stdout/stderr 重定向到日志文件。

### 启动顺序

脚本名称中 `S` 后面的数字决定启动顺序，数字越小越先执行：

```
S00mountall.sh   → 挂载文件系统
S10udev          → 设备管理
S40network       → 网络
S50sshd          → SSH 服务
S99rk3588app     → 你的应用（最后启动）
```

`S99` 确保在网络、串口等系统服务就绪后才启动应用。如需更早启动，改小数字即可（如 `S50rk3588app`），但一般建议保持 `S99`。

## License

MIT
