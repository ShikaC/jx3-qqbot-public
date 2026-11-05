# 发布前检查

当前目录已经按公开仓库重新整理，不需要再从旧仓库生成新目录。发布前按顺序核对：

## 1. 代码与文档

- [ ] `README.md` 里的仓库地址和所有者已经是实际地址
- [ ] 根 `LICENSE`、插件 `LICENSE`、`THIRD_PARTY_NOTICES.md` 都在
- [ ] `plugins/astrbot_plugin_jx3/` 与 fork 的 `feature/feature-switch@76a1c611` 一致
- [ ] 文档中没有真实 Key、QQ 号、群号或本机绝对路径

## 2. 隐私与产物

运行下面命令，确认 `.env`、`.runtime/`、`.venv/`、`data/` 只处于忽略状态，没有进入提交：

```powershell
git status --short --ignored
git log --all --format='%H %an <%ae>'
```

提交作者邮箱只应保留你愿意公开的地址。正式公开前建议再运行一次专用密钥扫描工具。

## 3. 验证

- [ ] 用 Python 3.12 编译 `deploy/windows-native/configure_instance.py` 和 fork 插件快照
- [ ] 所有 `.ps1` 能通过 PowerShell 解析
- [ ] 在 `plugins/astrbot_plugin_jx3/` 下运行 `python -m unittest discover -s tests -v`
- [ ] 在干净 Windows 环境运行 `install.cmd`，或至少运行：`powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\setup.ps1 -CheckOnly`
- [ ] 安装时从 `ShikaC/astrbot_plugin_jx3` 的固定提交 `76a1c611` 下载修改版
- [ ] 功能开关默认全部开启，逐条关闭后对应指令不再注册
- [ ] 重新运行配置脚本后，已有 `features` 功能开关配置仍然保留
- [ ] 安装脚本会校验 NapCat v4.18.42 的 SHA-256，并校验 Python 安装器的数字签名

## 4. 发布

```powershell
git push -u origin main
```

发布稳定版本时打 tag：

```powershell
git tag v1.0.0
git push origin v1.0.0
```

公开仓库后建议启用：

- Dependabot alerts 与 security updates
- Secret scanning 与 push protection（若账户和仓库类型支持）
- `main` 分支保护，要求 CI 通过并禁止强推/删除分支

## 素材说明

插件模板目录中的门派、心法、奇遇、沙盘等图片按当前决定原样保留；如收到版权方删除要求，再移除对应素材。
