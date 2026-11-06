# 剑网 3 QQ 群机器人

<p align="center">
  <img src="plugins/astrbot_plugin_jx3/logo.png" width="112" alt="剑网 3 QQ 群机器人图标">
</p>

<p align="center">
  面向剑网 3 玩家的 QQ 群机器人整合包
</p>

<p align="center">
  <a href="#快速开始">快速开始</a> ·
  <a href="#功能">功能</a> ·
  <a href="#配置">配置</a> ·
  <a href="#常见问题">常见问题</a> ·
  <a href="#参与贡献">参与贡献</a>
</p>

> 拉取仓库 → 双击 `install.cmd` → 填写 JX3API Token（LLM API Key 可选） →
> 用 QQ 小号扫码登录，即可在 QQ 群查询剑网 3 数据。

本项目把 **AstrBot**、剑网 3 查询插件和 **NapCat** 组合成一套可复现的
Windows 一键部署方案。

## 项目状态

| 平台 | 状态 | 入口 |
|---|---|---|
| Windows 10 / 11 x64 | **已实现**，仓库提供一键安装与运行脚本 | `install.cmd` |
| Linux 服务器 | **规划中**，尚未提供安装与运行脚本 | — |
| macOS | **规划中**，尚未验证协议端与自动化流程 | — |

当前发布版本面向 Windows 本机部署。Linux 和 macOS 的安装方式尚未经过
端到端验证，请勿将本 README 中的 Windows 命令直接套用到其它平台。
PS：如果你觉得该项目有用，希望能点一个Star~

## 功能

- **游戏数据查询**：角色名片、属性、装备、资历、成就、奇遇、物价、沙盘、
  配装、资讯等 100+ 条中文指令。
- **群内 AI 聊天（可选）**：由 AstrBot 自身提供模型和唤醒规则；本仓库不改插件
  来接管聊天消息。
- **逐条功能开关**：在插件管理页按官方分类（本地能力单独分组）启用或停用可配置
  指令；所有可配置指令默认开启，`功能`、`绑定区服`、`解绑区服` 始终可用。关闭
  查询指令后机器人不再响应，也不会消耗该指令对应的 JX3API 调用次数；实时事件
  推送由“事件推送”页的订阅单独控制。
- **小团体工具**：按 QQ 群隔离的团队报名、黑本和避雷记录。
- **本地数据**：团队、避雷、区服绑定等数据保存在本机，不依赖外部数据库。

> 本项目默认安装 [ShikaC/astrbot_plugin_jx3](https://github.com/ShikaC/astrbot_plugin_jx3)
> 的 `feature/feature-switch` 修改版，并固定到已验证提交
> `76a1c611`；它基于上游 AGPL-3.0 项目，并保留原作者信息。

## 快速开始

### 准备

| 项目 | 要求 |
|---|---|
| 操作系统 | Windows 10 / 11 64 位 |
| 硬件 | 建议 4 核 CPU、8 GB 内存，并能长期开机 |
| 磁盘 | 预留 3–5 GB |
| QQ | 建议使用有正常使用记录的小号 |
| JX3API Token | **必填**，在 [JX3API 官网](https://www.jx3api.com/) 获取 |
| LLM API Key | 可选；留空时仅启用剑网 3 查询 |

### 安装

1. **获取项目**

   ```powershell
   git clone https://github.com/ShikaC/jx3-qqbot-public.git
   ```

   不使用 Git 时，可在 GitHub 页面选择 `Code` → `Download ZIP`，解压到路径中
   不含特殊符号的目录。

2. **运行安装脚本**

   双击根目录的 `install.cmd`。脚本会：

   - 查找 Python 3.10+，缺失时安装 Python 3.12；
   - 创建 `.venv` 并安装 AstrBot 4.29.4 与插件依赖；
   - 初始化 `.runtime/astrbot` 实例；
   - 下载并配置 NapCat；
   - 生成 `deploy/windows-native/.env`；
   - 下载并安装固定到 `76a1c611` 的 fork 修改版剑三插件；
   - 写入配置，并启动 AstrBot 与 NapCat。

   首次安装需要下载约 1–2 GB 依赖和 300–400 MB 协议端，耗时取决于网络。
   安装过程中请勿关闭窗口。

3. **填写密钥**

   按终端提示粘贴密钥。输入时字符不会显示，这是正常行为。

   | 密钥 | 必填 | 说明 |
   |---|---|---|
   | JX3API Token | 是 | 用于剑网 3 数据查询 |
   | LLM API Key | 否 | 默认 DeepSeek；直接回车表示不启用 AI 聊天 |

4. **登录 QQ**

   安装完成后，脚本会打开 NapCat 登录页。使用 QQ 小号扫码登录；登录态会保存在
   本机，后续启动通常无需重复扫码。

5. **绑定区服并开始使用**

   将机器人小号拉入测试群，在群内发送：

   ```text
   绑定区服 梦江南
   ```

   将 `梦江南` 替换为实际区服。之后可直接发送查询指令，或发送 `功能`
   查看速查表。

### 插件来源

安装脚本从
[ShikaC/astrbot_plugin_jx3](https://github.com/ShikaC/astrbot_plugin_jx3)
的 `feature/feature-switch` 分支下载固定提交 `76a1c611` 的修改版插件。
修改版新增了逐条功能开关，
默认全部开启；管理页中的“功能开关”位于“会话控制”之后、“事件推送”之前。

插件基于上游
[qsc20001102/astrbot_plugin_jx3](https://github.com/qsc20001102/astrbot_plugin_jx3)
修改，原作者、上游链接和 AGPL-3.0 许可证均保留。仓库中的
`plugins/astrbot_plugin_jx3/` 是修改版快照，与上述 fork 分支保持一致。

> **更新提示**：fork 的 `metadata.yaml` 仍指向上游仓库，AstrBot 自带的
> 「更新插件」可能用上游默认分支覆盖修改版。更新后若功能开关消失，请重新运行
> `install.cmd`，或单独运行 `deploy/windows-native/install-fork-plugin.ps1`。

### 常用指令

| 场景 | 指令示例 |
|---|---|
| 角色信息 | `角色 <区服> <角色名>` |
| 属性与装备 | `属性 <区服> <角色名>`、`装备 <区服> <角色名>` |
| 资历与成就 | `资历 <区服> <角色名>`、`成就 <区服> <角色名> <成就名>` |
| 奇遇 | `奇遇 <区服> <角色名>`、`未出 <区服> <角色名>` |
| 物价 | `物价 <物品名> [区服]` |
| 服务器 | `沙盘 <区服>`、`开服 <区服>` |
| 配装 | `配装 <心法> [类型]` |
| 本群设置 | `绑定区服 <区服名>`、`解绑区服` |
| 帮助 | `功能` |

完整指令参考见插件内置说明的[“指令参考”章节](plugins/astrbot_plugin_jx3/README.md#指令参考)；
日常使用示例见 [使用说明](docs/usage.md)，或直接在群内发送 `功能`。

## 日常运维

| 操作 | 方式 |
|---|---|
| 启动 | 双击 `start.cmd` |
| 停止 | 双击 `stop.cmd` |
| 查看状态 | 双击 `status.cmd` |
| 环境检查 | `powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\setup.ps1 -CheckOnly` |
| 重新配置 | `powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\setup.ps1 -Reconfigure` |
| 开机自启 | `powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\install-autostart.ps1` |

默认管理后台地址为 `http://127.0.0.1:6185`，NapCat 登录页默认位于
`http://127.0.0.1:6099`。端口被占用时，以安装脚本实际输出的地址为准。

## 配置

在 AstrBot 管理后台 → 插件 → **剑网三插件管理** 中，可以：

- 在“配置”里修改 JX3API Token、事件推送令牌和图片渲染设置；
- 在“功能开关”里按 JX3API 分类、分组或逐条指令开关功能，默认全部开启；
- 点击分类卡片可收起或展开；在大类或分组外勾选可全选该类指令。

重新运行 `install.cmd` 会重新安装 fork 修改版，并写入 JX3API Token 与图片渲染
默认值，但不会清除已经保存的 `features` 功能开关配置。

### 更换 LLM 服务

默认使用 DeepSeek。兼容 OpenAI 接口的服务可通过 PowerShell 配置：

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\setup.ps1 `
  -LlmApiKey "你的 Key" `
  -LlmBaseUrl "https://你的服务/v1" `
  -LlmModel "你的模型名" `
  -LlmProvider "openai" `
  -Reconfigure
```

NapCat WebUI、OneBot 和后台登录信息保存在 `deploy/windows-native/.env`；
JX3API Token 保存在 `.runtime/astrbot/data/config/astrbot_plugin_jx3_config.json`，
LLM Key 保存在 `.runtime/astrbot/data/cmd_config.json`。上述路径均已被
`.gitignore` 排除，不要上传、截图或提交这些文件。

## 架构

```text
QQ 客户端 / QQ 群
        │
        ▼
    NapCat（QQ 协议端）
        │  OneBot v11，本机回环 127.0.0.1:6199
        ▼
   AstrBot 4.29.4
        ├── 剑网 3 查询插件（fork 修改版，含逐条功能开关）
        └── LLM Provider（可选，由 AstrBot 自身配置）
```

### 目录

```text
jx3-qqbot-public/
├── install.cmd / start.cmd / stop.cmd / status.cmd
├── deploy/
│   ├── config/default-persona.txt
│   └── windows-native/           # Windows 安装、运行与维护脚本
├── docs/                         # 使用说明、FAQ 与发布检查
└── plugins/astrbot_plugin_jx3/   # fork 修改版快照（AGPL-3.0）
```

运行后会生成以下本地目录，它们不会进入 Git：

```text
.venv/                  # Python 虚拟环境
.runtime/astrbot/       # AstrBot 实例、配置与本地数据库
.runtime/napcat-installer/ # NapCat OneKey 解压与安装目录
deploy/windows-native/.env
```

NapCat 的实际运行目录以 `.env` 中的 `NAPCAT_ROOT` 为准，通常位于
`.runtime/napcat-installer/NapCat.x.x.Shell/`。

## 费用与风险

- **JX3API** 按调用次数计费；`维护`、`新闻` 等免费接口不消耗次数。
- **LLM** 按 token 计费，仅 AI 聊天会消耗；不填写 Key 时不会产生此项费用。
- **QQ 账号** 使用非官方协议端存在风控风险。建议使用有正常使用记录的小号，
  仅在小群中稳定使用，避免群发、主动加好友或高频操作。
- **数据与合规** 第三方接口的可用性、数据准确性和使用条款由各服务提供方决定。

费用档位和风控规则可能变化，请以各服务官网为准。更多说明见 [常见问题](docs/faq.md)。

## 常见问题

**安装很慢？**

首次安装需要下载 Python、AstrBot 依赖和 NapCat。脚本默认使用清华 PyPI 镜像，
失败时会自动改用官方源。

**机器人不回复？**

依次检查 NapCat 是否已登录、`status.cmd` 中后台端口 `6185` 与 OneBot 端口
`6199` 是否在监听，以及 AstrBot 后台的 `aiocqhttp` 平台是否已启用。

**查询失败？**

确认 JX3API Token 正确且剩余次数充足。可先发送免费的 `维护` 或 `新闻` 检查链路。

**如何卸载？**

先运行 `stop.cmd`，再删除项目目录。如注册过开机自启，先运行
`deploy/windows-native/uninstall-autostart.ps1`。

更多问题见 [常见问题](docs/faq.md) 与 [使用说明](docs/usage.md)。

## 参与贡献

欢迎提交 Issue 和 Pull Request。提交前请确保：

- 不提交 Token、QQ 登录态、运行日志或本机绝对路径；
- 修改插件功能时请同步更新 fork，并保持原作者信息与 AGPL-3.0 许可证；
- 不修改或重新打包 NapCat。

### 本地检查

修改部署脚本或文档后，至少执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\setup.ps1 -CheckOnly
git diff --check
py -3.12 -m compileall -q deploy/windows-native plugins/astrbot_plugin_jx3
Push-Location .\plugins\astrbot_plugin_jx3
py -3.12 -m unittest discover -s tests -v
Pop-Location
```

插件快照可通过 `deploy/windows-native/install-fork-plugin.ps1` 从固定提交恢复。
单元测试需要先安装 `plugins/astrbot_plugin_jx3/requirements.txt` 和 `jinja2`；
测试文件位于 `plugins/astrbot_plugin_jx3/tests/`。

## 第三方组件与许可证

| 组件 | 用途 | 许可证 |
|---|---|---|
| [AstrBot](https://github.com/AstrBotDevs/AstrBot) | 机器人框架 | AGPL-3.0 |
| [ShikaC/astrbot_plugin_jx3](https://github.com/ShikaC/astrbot_plugin_jx3) | 剑网 3 数据查询插件修改版（`feature/feature-switch@76a1c611`，基于上游） | AGPL-3.0 |
| [NapCatQQ](https://github.com/NapNeko/NapCatQQ) | QQ 协议端，按原样运行 | Limited Redistribution License |
| [JX3API](https://www.jx3api.com/) | 剑网 3 数据接口 | 服务方条款 |
| [JX3BOX](https://www.jx3box.com/) | 配装数据接口 | 服务方条款 |

本仓库按 **AGPL-3.0** 发布。再分发时请保留根目录 `LICENSE`、插件
`LICENSE` 及相关版权声明，并按 AGPL 提供对应源码。NapCat 不得修改或重新打包。
完整说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

安全问题请按 [SECURITY.md](SECURITY.md) 的私密渠道报告。

## 免责声明

本项目仅供个人学习与小群自用。使用非官方 QQ 协议端、第三方数据接口和 LLM
服务所产生的账号风险、费用及合规责任，由使用者自行承担。项目不对第三方服务的
可用性、数据准确性或账号安全作任何保证。
