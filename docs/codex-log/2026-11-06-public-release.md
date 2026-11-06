# 2026-11-06 公开发布加固

## 目标

完成公开仓库的安装可复现性、CI、安全策略和发布收尾。

## 改动

- 将插件安装固定到提交 `76a1c611`。
- 让 CI 执行 Python 语法检查、PowerShell 解析和 55 项插件单元测试。
- 固定 GitHub Actions 到完整提交 SHA。
- 新增安全政策、Issue/PR 模板和 Dependabot 配置。
- 启用 Dependabot 安全更新、Secret Scanning、推送保护、私密漏洞报告和
  `main` 分支保护。
- 发布 `v1.0.0`。

## 验证

- 最新 `main` CI 成功。
- 工作区干净，`git fsck` 通过，当前文件和提交作者信息扫描未发现旧邮箱或本机路径。
- Release、私密漏洞报告和分支保护接口均已确认生效。

## 已知限制

- GitHub API 仍可通过旧提交 SHA 读取重写前对象；彻底清除需联系 GitHub Support。
- `secret_scanning_non_provider_patterns` 和 `secret_scanning_validity_checks`
  当前受账户或平台能力限制，无法启用。
