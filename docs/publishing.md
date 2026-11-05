# 发布前检查

本仓库已经是干净公开版，不需要再从旧仓库生成新目录。发布前按顺序核对：

## 1. 代码与文档

- [ ] `README.md` 里的仓库地址和所有者已替换为实际地址
- [ ] 根 `LICENSE`、插件 `LICENSE`、`THIRD_PARTY_NOTICES.md` 都在
- [ ] `plugins/astrbot_plugin_jx3/` 与上游 `main` 一致，没有本地扩展文件或改动
- [ ] 文档中没有真实 Key、QQ 号、群号或本机绝对路径

## 2. 隐私与产物

运行下面命令，确认 `.env`、`.runtime/`、`.venv/`、`data/` 只处于忽略状态，没有进入提交：

```powershell
git status --short --ignored
git log -p | Select-String -Pattern 'token|key|password|qq|群号'
```

## 3. 验证

- [ ] 用 Python 3.12 编译 `deploy/windows-native/configure_instance.py` 和上游插件快照
- [ ] 所有 `.ps1` 能通过 PowerShell 解析
- [ ] 在干净 Windows 环境运行 `install.cmd`，或至少运行：`powershell -ExecutionPolicy Bypass -File .\deploy\windows-native\setup.ps1 -CheckOnly`
- [ ] 安装时只下载上游原版剑三插件，没有调用插件同步脚本或写入额外插件配置
- [ ] 在 AstrBot 后台点一次「更新插件」，确认没有本地扩展页面或配置字段出现
- [ ] 安装脚本会校验 NapCat v4.18.42 的 SHA-256，并校验 Python 安装器的数字签名

## 4. 发布

```powershell
git remote add origin <你的仓库地址>
git push -u origin main
```

如需要可打 tag，例如：

```powershell
git tag v1.0.0
git push origin v1.0.0
```

## 素材说明

插件模板目录中的门派、心法、奇遇、沙盘等图片按当前决定原样保留；如收到版权方删除要求，再移除对应素材。
