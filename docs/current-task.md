# 当前任务

## 目标

维护 `jx3-qqbot-public` 的 Windows 一键部署包与公开仓库治理。

## 当前状态

- `main` 与 `origin/main` 保持同步，以最新提交为准。
- 发布版本以 GitHub Releases 为准；插件使用上游 v3.5.5，并固定到提交 `85c4752`。
- CI 在 Python 3.12 上执行语法检查、PowerShell 解析、插件单元测试和 WebUI 测试。
- GitHub 已启用 Dependabot 安全更新、Secret Scanning、推送保护、私密漏洞报告和
  `main` 分支保护。

## 已知限制

- 当前只提供 Windows 安装与运行脚本。
- AstrBot 自带“更新插件”可能升级到尚未验证的上游版本；需要恢复固定版本时运行
  `deploy/windows-native/install-plugin.ps1`。
- 插件模板图片沿用上游素材，收到权利人删除要求时再处理。
- 历史提交对象中的旧邮箱地址可能需要 GitHub Support 才能彻底清除。

## 验证

本地默认 `python` 可能是旧版本；测试请显式使用 `py -3.12`，并按 README
安装插件测试依赖。WebUI 测试需要 Node.js 18+。
