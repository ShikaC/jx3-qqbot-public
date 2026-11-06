# 当前任务

## 目标

维护 `jx3-qqbot-public` 的 Windows 一键部署包与公开仓库治理。

## 当前状态

- `main` 与 `origin/main` 同步，最新提交为 `bd646ff`。
- 已发布 `v1.0.0`；插件固定到提交 `76a1c611`。
- CI 在 Python 3.12 上执行语法检查、PowerShell 解析和 55 项插件单元测试。
- GitHub 已启用 Dependabot 安全更新、Secret Scanning、推送保护、私密漏洞报告和
  `main` 分支保护。

## 已知限制

- 当前只提供 Windows 安装与运行脚本。
- AstrBot 自带“更新插件”可能用上游版本覆盖修改版；更新后需重新运行
  `deploy/windows-native/install-fork-plugin.ps1`。
- 插件模板图片沿用上游素材，收到权利人删除要求时再处理。
- 历史提交对象中的旧邮箱地址可能需要 GitHub Support 才能彻底清除。

## 验证

本地默认 `python` 可能是旧版本；测试请显式使用 `py -3.12`，并按 README
安装插件测试依赖。
