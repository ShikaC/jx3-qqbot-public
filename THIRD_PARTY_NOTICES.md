# 第三方组件与许可证

本项目（Windows 一键安装脚本、整合配置、默认人格等）按 **AGPL-3.0** 发布，
见根目录 `LICENSE`。

## 组件清单

| 组件 | 来源 | 许可证 | 本项目如何处理 |
|---|---|---|---|
| AstrBot | <https://github.com/AstrBotDevs/AstrBot> | AGPL-3.0 | 只安装官方 PyPI 包，不修改源码 |
| astrbot_plugin_jx3 | <https://github.com/ShikaC/astrbot_plugin_jx3>（基于 <https://github.com/qsc20001102/astrbot_plugin_jx3>） | AGPL-3.0 | 使用 `feature/feature-switch` 修改版；保留原作者、上游链接、`LICENSE` 与版权声明 |
| NapCatQQ | <https://github.com/NapNeko/NapCatQQ> | Limited Redistribution License（非开源） | **不修改**，只按原样运行 |
| JX3API | <https://www.jx3api.com/> | 按其官网条款 | 只调用接口，不复制数据 |
| JX3BOX | <https://www.jx3box.com/> | 按其官网条款 | 只调用接口 |
| DeepSeek API | <https://platform.deepseek.com/> | 按其官网条款 | 只调用接口 |

## 游戏素材与第三方资源

本仓库在 `plugins/astrbot_plugin_jx3/templates/` 下随插件保留了约 285 个门派、
心法、奇遇、沙盘、阵营等图片资源，主要位于：

- `templates/sect/`
- `templates/serendipity/`
- `templates/img/`（含 `sand/`）

这些资源来自上游 `qsc20001102/astrbot_plugin_jx3` 仓库，并随 fork 修改版保留，用于
渲染 JX3API / JX3BOX 返回的游戏数据查询结果。其中可能包含《剑网3》的游戏标识、
角色形象或界面素材，相关权利属于剑网3 的权利人；AGPL-3.0 并不当然授予这些美术
素材的再分发或商用权利。

公开分发前请自行确认这些素材的授权范围。如无法确认，应替换为自制素材、删除
对应资源，或明确将使用范围限制为非商用学习用途；收到版权方删除请求时应优先处理。

## 说明

- AstrBot 与 `astrbot_plugin_jx3` 都是 AGPL-3.0。再分发本仓库时，请保留
  根目录 `LICENSE`、`plugins/astrbot_plugin_jx3/LICENSE` 与相关版权声明，
  并按 AGPL 提供对应源码。`plugins/astrbot_plugin_jx3/` 是 fork 修改版快照，
  原作者信息与上游链接均保留；安装脚本从 fork 的 `feature/feature-switch` 下载。
- NapCat 采用 Limited Redistribution License，条款禁止修改（modification），
  只允许按原样使用 / 分发。请不要修改、patch 或重新打包 NapCat。
- JX3API、JX3BOX、LLM 服务的可用性、数据准确性与计费规则由各自提供方决定，
  本项目不对此负责。
