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

> 拉取仓库 → 双击 `install.cmd` → 填写 JX3API Token 与 LLM API Key →
> 用 QQ 小号扫码登录，即可在 QQ 群查询剑网 3 数据，并 @ 机器人聊天。

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
- **小团体工具**：按 QQ 群隔离的团队报名、黑本和避雷记录。
- **本地数据**：团队、避雷、区服绑定等数据保存在本机，不依赖外部数据库。

> 剑三插件始终安装上游原版，不包含本仓库额外添加的功能页面或插件源码改动。

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
   - 从上游下载并安装未修改的剑三插件，后续可直接在 AstrBot 中更新；
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

   将 `梦江南` 替换为实际区服。之后可直接发送查询指令，或发送 `指令 剑三`
   查看速查表。

### 插件来源

安装脚本只从上游
[qsc20001102/astrbot_plugin_jx3](https://github.com/qsc20001102/astrbot_plugin_jx3)
的 `main` 分支下载原版插件，不在安装后写入额外功能或替换插件文件。因此可以
直接在 AstrBot 后台点「更新插件」，不需要重新运行本项目安装脚本，也不会产生
本仓库添加的页面、配置字段或额外功能。

仓库中的 `plugins/astrbot_plugin_jx3/` 是同一上游版本的未修改快照，仅用于保留
许可证、图标和源码审阅，不是本仓库维护的二次开发分支。

### 常用指令

| 场景 | 指令示例 |
|---|---|
| 角色信息 | `信息 [区服] <角色名>` |
| 属性与装备 | `属性 [区服] <角色名>`、`装备 [区服] <角色名>` |
| 资历与成就 | `资历 [区服] <角色名>`、`成就 [区服] <角色名> <成就名>` |
| 奇遇 | `奇遇 [区服] <角色名>`、`未出 [区服] <角色名>` |
| 物价 | `物价 <物品名> [区服]` |
| 服务器 | `沙盘 [区服]`、`开服 [区服]` |
| 配装 | `配装 <心法> [类型] [资料片]` |
| 本群设置 | `绑定区服 <区服名>`、`解绑区服` |
| 帮助 | `指令 剑三 [关键词]`、`功能` |

完整指令列表见 [使用说明](docs/usage.md)，或直接在群内发送 `指令 剑三`。

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

剑三插件使用上游自带的 AstrBot 插件配置页，本仓库没有额外的配置向导或功能
开关页面。需要更换 JX3API Token、事件推送令牌或图片渲染设置时，可在
AstrBot 管理后台 → 插件 → **剑网三插件管理** → **配置** 中修改。

如果重新运行 `install.cmd`，脚本仍会从上游重新安装原版插件，并写入本项目需要的
JX3API Token 和图片渲染默认值；这些操作不会修改插件源码。

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

本机凭据保存在 `deploy/windows-native/.env`，该文件已被 `.gitignore` 排除。
不要上传、截图或提交该文件。

## 架构

```text
QQ 客户端 / QQ 群
        │
        ▼
    NapCat（QQ 协议端）
        │  OneBot v11，本机回环 127.0.0.1:6199
        ▼
   AstrBot 4.29.4
        ├── 剑网 3 查询插件（上游原版 astrbot_plugin_jx3）
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
└── plugins/astrbot_plugin_jx3/   # 上游原版未修改快照（AGPL-3.0）
```

运行后会生成以下本地目录，它们不会进入 Git：

```text
.venv/                  # Python 虚拟环境
.runtime/astrbot/       # AstrBot 实例、配置与本地数据库
.runtime/onekey-install/# NapCat 与 QQ 协议端
deploy/windows-native/.env
```

## 费用与风险

- **JX3API** 按调用次数计费；新闻公告等免费接口不消耗次数。
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

确认 JX3API Token 正确且剩余次数充足。可先发送免费的 `新闻公告` 检查链路。

**如何卸载？**

先运行 `stop.cmd`，再删除项目目录。如注册过开机自启，先运行
`deploy/windows-native/uninstall-autostart.ps1`。

更多问题见 [常见问题](docs/faq.md) 与 [使用说明](docs/usage.md)。

## 参与贡献

欢迎提交 Issue 和 Pull Request。提交前请确保：

- 不提交 Token、QQ 登录态、运行日志或本机绝对路径；
- 不修改 `plugins/astrbot_plugin_jx3/`；插件功能问题请反馈给上游仓库；
- 不修改或重新打包 NapCat。

### 本地检查

修改部署脚本或文档后，至少执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\setup.ps1 -CheckOnly
git diff --check
```

本仓库不维护插件二次开发版本，因此不再提供插件同步或插件单元测试流程。

## 第三方组件与许可证

| 组件 | 用途 | 许可证 |
|---|---|---|
| [AstrBot](https://github.com/AstrBotDevs/AstrBot) | 机器人框架 | AGPL-3.0 |
| [astrbot_plugin_jx3](https://github.com/qsc20001102/astrbot_plugin_jx3) | 剑网 3 数据查询插件（上游原版，不修改） | AGPL-3.0 |
| [NapCatQQ](https://github.com/NapNeko/NapCatQQ) | QQ 协议端，按原样运行 | Limited Redistribution License |
| [JX3API](https://www.jx3api.com/) | 剑网 3 数据接口 | 服务方条款 |
| [JX3BOX](https://www.jx3box.com/) | 配装数据接口 | 服务方条款 |

本仓库按 **AGPL-3.0** 发布。再分发时请保留根目录 `LICENSE`、插件
`LICENSE` 及相关版权声明，并按 AGPL 提供对应源码。NapCat 不得修改或重新打包。
完整说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 免责声明

本项目仅供个人学习与小群自用。使用非官方 QQ 协议端、第三方数据接口和 LLM
服务所产生的账号风险、费用及合规责任，由使用者自行承担。项目不对第三方服务的
可用性、数据准确性或账号安全作任何保证。
