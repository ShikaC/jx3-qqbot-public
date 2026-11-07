# Windows 本机部署脚本说明

这个目录用于「QQ 登录端（NapCat）和 AstrBot 都跑在同一台 Windows 主机」的部署。
没有云主机、没有 SSH 隧道：NapCat 和 AstrBot 通过本机回环 `127.0.0.1:6199` 连接。

## 一键安装

普通用户不需要看本文件，直接双击项目根目录的 `install.cmd` 即可。
它按顺序做：

1. 找 / 装 Python 3.10+（没有就自动下载 3.12）
2. 建 `.venv` 并安装 AstrBot 与插件依赖
3. 初始化 AstrBot 实例（`.runtime\astrbot`）
4. 下载并安装 NapCat（`.runtime\napcat-installer`）
5. 生成 `deploy\windows-native\.env`
6. 从上游下载并安装固定版本剑三插件，写入 AstrBot / 插件 / LLM 配置
7. 启动 AstrBot 与 NapCat，并打开 NapCat 登录页

## 脚本一览

| 脚本 | 说明 |
|---|---|
| `setup.ps1` | 一键安装 / 重新配置；支持 `-CheckOnly` 只检查环境 |
| `configure_instance.py` | 纯本地写配置（不联网、不调 JX3API） |
| `setup-napcat.ps1` | 写 NapCat 的 `webui.json` / `onebot11.json` |
| `start.ps1` | 写配置 → 起 AstrBot → 起 NapCat，并打印两个 WebUI 地址 |
| `stop.ps1` | 只停本项目的 AstrBot / NapCat / QQ |
| `status.ps1` | 查看端口、进程与 WebUI 端口 |
| `install-plugin.ps1` | 从上游 `qsc20001102/astrbot_plugin_jx3` 的 `85c4752` 下载固定版本插件 |
| `install-fork-plugin.ps1` | 旧入口兼容包装器，转发到 `install-plugin.ps1` |
| `install-autostart.ps1` | 注册登录自启计划任务 |
| `uninstall-autostart.ps1` | 取消自启 |
| `watchdog-napcat.ps1` | NapCat 掉线看门狗（可选） |

## 常用命令

```powershell
# 只检查环境，不改任何文件
powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\setup.ps1 -CheckOnly

# 重新配置（换 Key / 换端口 / 重设后台密码）
powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\setup.ps1 -Reconfigure

# 只安装不启动
powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\setup.ps1 -NoStart

# 只重新安装固定版本插件
powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\install-plugin.ps1
```

## `.env` 字段

`deploy\windows-native\.env` 由安装脚本生成，**不要提交、不要截图**。

| 字段 | 说明 |
|---|---|
| `NAPCAT_ROOT` | NapCat Shell 目录（含 `NapCatWinBootMain.exe`） |
| `NAPCAT_WEBUI_TOKEN` | NapCat 登录页令牌 |
| `ONEBOT_WS_TOKEN` | NapCat 与 AstrBot 之间的连接令牌 |
| `ONEBOT_WS_PORT` | AstrBot 反向 WS 端口（默认 6199） |
| `ASTRBOT_ROOT` | AstrBot 实例目录（默认 `.runtime\astrbot`） |
| `ASTRBOT_DASHBOARD_PORT` | AstrBot 管理后台端口（默认 6185） |
| `ASTRBOT_DASHBOARD_PASSWORD` | 管理后台密码 |

## 注意事项

- 面向本机的 `.ps1` 必须保存为 **UTF-8 带 BOM**，否则 Windows PowerShell 5.1
  会把中文读成乱码并解析失败。
- 剑三插件从 `qsc20001102/astrbot_plugin_jx3` 的 `85c4752` 固定提交下载；
  原作者信息与 AGPL-3.0 许可证均保留。
- 改了 `ONEBOT_WS_TOKEN` 后，NapCat 需要重启才会用上新令牌。
- AstrBot 的「更新插件」可能升级到尚未验证的上游版本；需要恢复固定版本时运行
  `install-plugin.ps1`。已有的功能开关配置不会被安装脚本清除。
