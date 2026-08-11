# 贝壳 CLI

命令行工具，提供房源搜索、价格查询、政策咨询等功能。

## 安装

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/cli/releases/install.sh | bash
```

### 指定版本

```bash
# 查看 releases/manifest.json 获取可用版本
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/cli/releases/install.sh | bash
```

## 初始化

首次使用前，先运行 `beike login` 打开登录页获取 API Key（链接自动携带当前平台来源），再保存：

```bash
beike auth <YOUR_API_KEY> --save
```

API Key 将保存到 `~/.beike/BEIKE_MCP_API_KEY`，后续自动使用。

## 使用示例

**查询二手房**
```bash
beike buy search -c 北京 -q "朝阳区 1000万以内 2居"
```

**查询租房**
```bash
beike rent search -c 北京 -q "望京 2000元以内 1居"
```

**查询学区**
```bash
beike buy school -c 北京 -q "西城区重点小学"
```

**查询购房政策**
```bash
beike policy search -c 北京 -q "非本地户籍购房资格"
```

**查询市场行情**
```bash
beike market search -c 北京 -q "朝阳区二手房"
```

## 获取帮助

```bash
beike --help              # 查看 CLI 帮助
beike <skill> --help      # 查看各 Skill 子命令帮助
```

## 许可

商业软件，仅限授权用户使用。
