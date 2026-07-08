# Local Web Monitor

Windows 桌面悬浮工具，用来实时查看本机正在运行的本地网页/API 入口。

## 功能

- 默认中文界面，支持中英文切换
- 无黑框启动
- 置顶悬浮显示
- 自动扫描本地 HTTP 入口
- 网页入口显示网站图标，API/JSON 入口显示 API 图标
- 一键打开对应本地地址
- 可安装桌面快捷方式和高清图标

## 使用

直接启动：

```bat
start-floating.bat
```

推荐安装桌面快捷方式：

```bat
install-shortcut.bat
```

安装后桌面会出现 `本地网页监听`，双击即可启动。

## 文件说明

- `floating-panel.ps1`: 主程序
- `start-floating.vbs`: 无黑框启动入口
- `start-floating.bat`: 备用启动入口
- `install-shortcut.ps1`: 创建桌面快捷方式
- `install-shortcut.bat`: 双击安装快捷方式
- `assets/`: 图标资源

## 系统要求

- Windows
- Windows PowerShell 5+
- .NET/WPF 桌面组件
