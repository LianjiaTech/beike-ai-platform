# 贝壳 AI Skill 定义

贝壳 AI 开放平台的 Skill（能力模块）定义集合，为 AI Agent 提供买房、租房、卖房、装修、市场行情、政策咨询、学区查询等专业顾问服务。

## 包含的 Skills

| Skill | 功能描述 |
|-------|--------|
| **beike-buy** | 二手房和新房购买助手，支持房源搜索、小区详情、价格行情、经纪人咨询 |
| **beike-rent** | 租房助手，支持租房搜索、租金走势、看房预约、经纪人联系 |
| **beike-market** | 市场行情和成交数据查询，支持买卖行情、历史成交、租赁行情分析 |
| **beike-policy** | 购房政策顾问，支持购房资格、首付贷款、税费、交易流程咨询 |
| **beike-school** | 学区和学校查询，支持学校信息、学区划片、学区房选择建议 |
| **beike-sell** | 卖房业主助手，支持查询名下挂牌房源、带看记录和调价动态 |
| **beike-decor** | 装修助手，支持查询装修门店和套餐报价 |

## 快速开始

### 安装全部 Skills

```bash
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/skills/install.sh | bash
```

### 安装指定 Skills

```bash
# 安装单个或多个 skill
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/skills/install.sh | bash -s -- beike-buy beike-rent

# 安装列表
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/skills/install.sh | bash -s -- beike-buy beike-market beike-policy
```

安装器会自动识别当前宿主的用户级 Skill 目录：WorkBuddy 使用 `~/.workbuddy/skills/`，Claude Code 使用 `~/.claude/skills/`，Codex 使用 `~/.codex/skills/`，OpenClaw 使用 `~/.openclaw/skills/`，Hermes 使用 `${HERMES_HOME:-~/.hermes}/skills/`；无法识别时回退到通用目录 `~/.agents/skills/`。

也可以通过 `--skills-dir` 或环境变量 `BEIKE_SKILLS_DIR` 指定目录：

```bash
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/skills/install.sh | bash -s -- --skills-dir "$HOME/.workbuddy/skills" beike-buy
```

安装器默认检测并安装 Skills 共用的 `beike` CLI；无论安装一个、多个还是全部 Skills，都只安装一次。已有 CLI 不会被覆盖。如只需要 Skill 定义，可增加 `--no-cli`：

```bash
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/master/skills/install.sh | bash -s -- --no-cli beike-buy
```

首次使用前，先运行 `beike login` 打开登录页获取 API Key（链接自动携带当前平台来源），然后执行：

```bash
beike auth <YOUR_API_KEY> --save
```

## 详细文档

各 Skill 的完整使用文档包含在安装包中，安装后可在对应 skills 目录查看（如 `~/.workbuddy/skills/beike-buy/SKILL.md`）。

## Skill 开发与发布

本仓库仅用于分发编译产物（CLI 二进制、Skill 打包 zip）与安装器，不包含 CLI 源码和 Skill 源码。

Skill 与 CLI 独立发版；修改 Skill 不需要重新编译 CLI。

## 许可

贝壳内部使用。
