# API Key 管理

## 获取 API Key

运行 `beike login` 打开登录页获取 API Key（链接自动携带当前平台来源）。

## 保存 API Key

### CLI 用户

```bash
beike auth <YOUR_API_KEY> --save
```

API Key 将保存到 `~/.beike/BEIKE_MCP_API_KEY`，后续自动使用。

### Skills 用户

Skills 安装器会自动安装 `beike` CLI。获取 API Key 后保存：

```bash
beike auth <YOUR_API_KEY> --save
```

如果只安装 Skill 定义、不希望自动安装 CLI，可给安装命令增加 `--no-cli`。安装器会自动识别 WorkBuddy、Claude Code、Codex 和 OpenClaw 的 Skill 目录，也可使用 `--skills-dir <目录>` 显式指定。

## 重置 API Key

### CLI 用户

```bash
beike auth <NEW_API_KEY> --save
```

### 手动重置

删除本地保存的 Key 文件：

```bash
rm ~/.beike/BEIKE_MCP_API_KEY
```

然后重新保存新的 Key。

## 安全建议

- 不要在代码或日志中暴露 API Key
- 定期更新 API Key
- 如有泄露，立即联系技术支持重置
