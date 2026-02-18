# Multi-OpenClaw Setup on Mac

## 概述

这是一个在单台Mac上运行多个独立OpenClaw实例的完整指南。每个实例使用不同的AI模型（Claude、DeepSeek、Gemini），通过共享资源进行协作，实现"多机器人团队"架构。

## 主要特性

- **多实例隔离**：每个OpenClaw实例完全独立运行，拥有自己的配置、工作空间和内存
- **模型多样性**：支持同时运行Claude、DeepSeek、Gemini等不同AI模型
- **智能协作**：通过共享文件夹实现实例间的通信和协作
- **技能自动同步**：使用符号链接确保所有实例共享相同的技能目录
- **智能网关检测**：启动脚本自动检测网关状态，避免端口冲突
- **自动清理**：防止 context overflow，定时清理膨胀的 session 和日记文件

## 快速开始

### 1. 环境要求
- macOS（Apple Silicon或Intel）
- Node.js v20+
- 全局安装OpenClaw：`npm install -g openclaw`
- Telegram Bot令牌（每个实例一个）

### 2. 创建实例目录
```bash
# 实例C (Claude)
mkdir -p ~/.openclaw/workspace

# 实例D (DeepSeek)
mkdir -p ~/.openclaw-deepseek/workspace

# 实例G (Gemini)
mkdir -p ~/.openclaw-gemini/workspace

# 共享协作文件夹
mkdir -p ~/shared/setting
mkdir -p ~/shared/github
mkdir -p ~/shared/program
```

### 3. 配置启动脚本
创建三个`.command`文件：
- `OpenClaw_Claude.command` - Claude实例
- `OpenClaw_DeepSeek.command` - DeepSeek实例
- `OpenClaw_Gemini.command` - Gemini实例

每个脚本包含智能网关检测功能，可自动判断网关是否已运行。

### 4. 设置技能同步
```bash
# 使用符号链接共享技能目录
rm -rf ~/.openclaw-deepseek/skills
rm -rf ~/.openclaw-gemini/skills
ln -s ~/.openclaw/skills ~/.openclaw-deepseek/skills
ln -s ~/.openclaw/skills ~/.openclaw-gemini/skills
```

### 5. 启动所有实例
双击每个`.command`文件，或在不同终端标签页中运行。

## 架构设计

### 隔离与共享
```
隔离（每个实例独立）          共享（所有实例共用）
├── openclaw.json            ~/shared/
├── workspace/                 ├── setting/     # 规则和配置文档
│   ├── MEMORY.md             ├── github/      # 代码和文档
│   ├── SOUL.md               └── program/     # 项目文件夹
│   └── AGENTS.md
├── skills/ → 符号链接
├── cron/
└── credentials/
```

### 端口分配
- Claude实例：端口18789
- DeepSeek实例：端口18790
- Gemini实例：端口18791

## 协作机制

### 1. 共享文件夹结构
```
~/shared/
├── setting/          # 配置和规则
│   ├── 群聊天规则.md
│   ├── 机器人简称对照表.md
│   ├── cron-config-guide.md
│   └── api-tokens.md
├── github/           # 协作文档
└── program/          # 项目文件夹
```

### 2. 群聊协调
- 所有机器人加入同一个Telegram群组
- 只有被@提及时才响应
- 每个机器人读取最近的群聊历史以理解上下文
- 指定"主导"机器人处理冲突解决

### 3. 文件通信
机器人可以通过共享文件夹相互通信：
```bash
# 机器人D写入状态更新
echo "任务完成于 $(date)" > ~/shared/status/d-last-update.txt

# 机器人C在下次检查时读取
cat ~/shared/status/d-last-update.txt
```

## 自动清理（防止 Context Overflow）

长期运行的 OpenClaw 实例会静默积累数据——session 历史、日记文件、MEMORY.md 无限增长，最终导致 `Context overflow: prompt too large for the model`，bot 彻底瘫痪。

本项目包含自动清理方案：
- `cleanup.sh` — 定时截断日记和 session 文件
- AI cron job — 智能精简 MEMORY.md

详细配置见主文档的 "Auto Cleanup" 章节，或独立项目：[openclaw-auto-cleanup](https://github.com/CryptoMiaobug/openclaw-auto-cleanup)

## 最佳实践

### 安全性
- **绝不**在共享文件中存储API密钥
- 使用环境变量存储密钥
- 限制共享文件夹的写入权限
- 定期备份配置和工作空间

### 资源管理
- 每个实例消耗约300-500MB内存
- 使用`ps aux | grep openclaw`监控进程
- 关闭未使用的实例以节省资源

### 命名约定
- 使用一致的简称（C、D、G）
- 相关文件添加创建者标识前缀
- 共享设置统一存放在`setting/`目录

### 维护
- 定期清理共享文件夹
- 升级OpenClaw时同步更新所有实例
- 监控日志文件以排查问题

## 故障排除

### 常见问题
1. **端口已被占用**：使用智能网关检测脚本自动处理
2. **实例无法启动**：检查配置和日志文件
3. **机器人不响应**：验证群组权限和配置
4. **内存使用过高**：监控并适时重启实例

### 日志检查
```bash
# 查看特定实例的日志
tail -f ~/.openclaw-<name>/logs/gateway.log

# 检查错误
grep -i error ~/.openclaw-<name>/logs/gateway.log | tail -20
```

## 快速参考

| 命令 | 用途 |
|------|------|
| `OPENCLAW_HOME=~/.openclaw-<name> openclaw gateway` | 启动实例 |
| `OPENCLAW_HOME=~/.openclaw-<name> openclaw gateway status` | 检查状态 |
| `ps aux \| grep openclaw` | 列出所有运行实例 |
| `ls ~/shared/setting/` | 查看共享配置 |
| `cat ~/shared/setting/机器人简称对照表.md` | 查看机器人名单 |

## 详细文档

完整的技术细节、配置示例和高级用法，请参阅主文档：[Multi-OpenClaw-Setup-on-Mac.md](Multi-OpenClaw-Setup-on-Mac.md)

---

**注意**：本文档是完整指南的摘要。部署前请仔细阅读主文档中的所有步骤和注意事项。