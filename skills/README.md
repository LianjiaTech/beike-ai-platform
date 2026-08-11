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
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/main/skills/install.sh | bash
```

### 安装指定 Skills

```bash
# 安装单个或多个 skill
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/main/skills/install.sh | bash -s -- beike-buy beike-rent

# 安装列表
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/main/skills/install.sh | bash -s -- beike-buy beike-market beike-policy
```

安装器会自动识别当前宿主的用户级 Skill 目录：WorkBuddy 使用 `~/.workbuddy/skills/`，Claude Code 使用 `~/.claude/skills/`，Codex 使用 `~/.codex/skills/`，OpenClaw 使用 `~/.openclaw/skills/`，Hermes 使用 `${HERMES_HOME:-~/.hermes}/skills/`；无法识别时回退到通用目录 `~/.agents/skills/`。

也可以通过 `--skills-dir` 或环境变量 `BEIKE_SKILLS_DIR` 指定目录：

```bash
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/main/skills/install.sh | bash -s -- --skills-dir "$HOME/.workbuddy/skills" beike-buy
```

安装器默认检测并安装 Skills 共用的 `beike` CLI；无论安装一个、多个还是全部 Skills，都只安装一次。已有 CLI 不会被覆盖。如只需要 Skill 定义，可增加 `--no-cli`：

```bash
curl -fsSL https://raw.githubusercontent.com/LianjiaTech/beike-ai-platform/main/skills/install.sh | bash -s -- --no-cli beike-buy
```

首次使用前，先运行 `beike login` 打开登录页获取 API Key（链接自动携带当前平台来源），然后执行：

```bash
beike auth <YOUR_API_KEY> --save
```

## 详细文档

详细使用指南请查看各 Skill 的文档：

- [beike-buy - 二手房购买助手](./beike-buy/SKILL.md)
- [beike-rent - 租房助手](./beike-rent/SKILL.md)
- [beike-market - 市场行情查询](./beike-market/SKILL.md)
- [beike-policy - 购房政策顾问](./beike-policy/SKILL.md)
- [beike-school - 学区查询](./beike-school/SKILL.md)
- [beike-sell - 卖房业主助手](./beike-sell/SKILL.md)
- [beike-decor - 装修助手](./beike-decor/SKILL.md)

## Skill 开发与发布

本目录是 Skill 的唯一源码，不需要再同步到其他仓库。

修改某个 Skill 时，同时编辑其 `SKILL.md` 和 `manifest.json`。只要内容变化，就必须提升该 Skill 自己的 `version`，然后提交源码：

```bash
git add skills/beike-buy/
git commit -m "feat: update beike-buy skill"
```

本地构建并校验全部 Skill：

```bash
./scripts/build-skills.sh
./scripts/test-skills.sh
```

产物生成在被 Git 忽略的 `.build/skills/`，不会修改已发布文件。

发布所有“版本号已变化”的 Skill：

```bash
./scripts/build-skills.sh --release
```

发布前要求本仓库处于干净、与远端一致的 `main`。脚本会为每个 Skill 创建不可覆盖的 `<skill>-v<version>` GitHub Release，上传 ZIP 和校验文件，更新 `skills/manifest.json`，最后提交并推送该清单。

Skill 与 CLI 独立发版；修改 Skill 不需要重新编译 CLI。

## 许可

贝壳内部使用。
