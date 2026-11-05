# 使用说明

本文档面向第一次接触 QQ 机器人的用户。安装步骤见根目录 `README.md`。

本项目安装 [ShikaC/astrbot_plugin_jx3](https://github.com/ShikaC/astrbot_plugin_jx3)
的 `feature/feature-switch` 修改版。它基于上游 `qsc20001102/astrbot_plugin_jx3`
修改，新增逐条功能开关，并保留原作者与 AGPL-3.0 许可证。

## 1. 安装后发生了什么

安装脚本会在项目目录里生成这些内容（都已在 `.gitignore` 中，不会上传）：

```text
jx3-qqbot/
├─ .venv/                         # Python 虚拟环境（AstrBot 装在这里）
├─ .runtime/
│  ├─ astrbot/                    # AstrBot 实例：配置、会话、插件数据库
│  ├─ napcat-installer/           # NapCat OneKey 解压与安装目录
│  └─ downloads/                  # 安装包缓存
└─ deploy/windows-native/.env     # 端口、OneBot/WebUI 令牌、后台密码
```

## 2. 日常操作

| 操作 | 做法 |
|---|---|
| 启动 | 双击 `start.cmd` |
| 停止 | 双击 `stop.cmd`（可选，重启电脑后需要重新启动） |
| 查看状态 | `powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\status.ps1` |
| 修改配置 | 编辑 `deploy\windows-native\.env` 后重新 `start.cmd` |
| 重新配置 Key | 双击 `install.cmd`，脚本会检测到已有配置并询问是否复用 |

## 3. 修改两个 Key

两个 Key 保存在两个地方：

- JX3API Token：`AstrBot 实例\data\config\astrbot_plugin_jx3_config.json` 的
  `jx3api_token`
- LLM API Key：`AstrBot 实例\data\cmd_config.json` 的 `provider_sources` 里

更推荐直接重新运行 `install.cmd`，按提示粘贴新的 Key，脚本会自动写入正确位置。

也可以直接在网页里改：打开 AstrBot 管理后台（`http://127.0.0.1:6185`）→
插件 → **剑网三插件管理** → **配置**，修改 JX3API Token；LLM API Key 在
AstrBot 的模型服务配置中修改。插件配置表单和功能开关都在插件管理页中。

### 换用其它 LLM

默认使用 DeepSeek。要用其它 OpenAI 兼容服务（如阿里云百炼、硅基流动、
自建 One-API 等），在 PowerShell 里运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\setup.ps1 `
  -LlmApiKey "你的Key" `
  -LlmBaseUrl "https://你的服务/v1" `
  -LlmModel "你的模型名" `
  -LlmProvider "openai" `
  -Reconfigure
```

## 4. 在群里怎么用

### 剑三查询

第一次使用先在群里绑定区服：

```text
绑定区服 梦江南
```

之后直接发指令，例如：

```text
功能
角色 梦江南 某某角色
属性 梦江南 某某角色
资历 梦江南 某某角色
奇遇 梦江南 某某角色
物价 五行石 梦江南
沙盘 梦江南
新闻
```

### AI 聊天

是否让 AI 回话由 AstrBot 自己的唤醒规则和模型配置决定。插件不会接管聊天消息。
可在 AstrBot 管理后台设置唤醒前缀、会话开关，或只允许群内
`@机器人` 时触发对话。

机器人的人格（说话风格）可以在 `deploy/config/default-persona.txt` 里修改，
安装后重新运行 `install.cmd` 即可写入；也可以直接在 AstrBot 管理后台里改。

## 5. 管理后台

浏览器打开 `http://127.0.0.1:6185`（默认端口；被占用时以安装结束时打印的地址为准），
用安装结束时打印的账号密码登录，可以：

- 查看/修改模型与人格
- 查看会话、日志、插件状态
- 停用/启用插件
- 进入「插件 → 剑网三插件管理」，在“配置”中调整 Token 等设置
- 在“功能开关”中按分类、分组或逐条指令启停功能；默认全部开启

密码保存在 `deploy\windows-native\.env` 的 `ASTRBOT_DASHBOARD_PASSWORD`。

## 6. 常见问题

### 安装很慢

首次要下载 Python、AstrBot 依赖（1~2 GB）、NapCat 与 QQ（约 300~400 MB）。
脚本默认使用清华 PyPI 镜像，下载失败会自动改用官方源。

### 扫码后机器人不在线

1. 确认 NapCat 窗口 / 进程在运行。
2. 运行 `status.ps1`，确认 `6185` 和 `6199` 两个端口在监听。
3. 在 AstrBot 后台确认 `aiocqhttp` 平台是启用状态。

### 查询提示失败

- 确认 JX3API Token 正确、剩余次数足够。
- 免费接口（如 `新闻`、`维护`）不消耗次数，可以先用它测试链路。
- 网络不稳定时脚本会自动重试；仍失败可稍后再试。

### 想让机器人少说话 / 多说话

AI 是否回话由 AstrBot 的唤醒规则决定。如果觉得频繁，可以在 AstrBot 后台调整
唤醒前缀或关闭对应群会话的 AI 能力，只保留剑三查询。

### 如何彻底卸载

1. 运行 `stop.cmd`。
2. 删除项目目录（包含 `.venv`、`.runtime`）。
3. 如需清理自启任务：`powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\uninstall-autostart.ps1`

## 7. 如何更新剑三插件

打开 AstrBot 管理后台 → 插件 → **剑网三插件管理**，使用 AstrBot 自带的
「更新插件」可能用上游默认分支覆盖修改版，导致功能开关消失。更新后请运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\install-fork-plugin.ps1
```

该脚本会恢复 fork 的 `feature/feature-switch` 修改版，不会清除已有的功能开关配置。
