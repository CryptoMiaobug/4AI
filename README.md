# 🔐 MiaoWallet

**AI-Native Crypto Wallet with Hardware-Level Security**

MiaoWallet is a secure cryptocurrency wallet designed for AI agents (OpenClaw / MCP compatible). It leverages **macOS Keychain** for private key storage with per-access authorization prompts — your AI assistant can sign transactions, but **only with your explicit approval every single time**.

---

**AI 原生加密钱包，硬件级安全保护**

MiaoWallet 是专为 AI 代理（OpenClaw / MCP 兼容）设计的安全加密货币钱包。它利用 **macOS 钥匙串 (Keychain)** 存储私钥，每次访问都需要用户弹窗授权 —— AI 助手可以签名交易，但**每一次都必须经过你的明确批准**。

---

## 🛡️ Security Architecture / 安全架构

```
┌─────────────────────────────────────────────────────┐
│                   AI Agent (OpenClaw)                │
│                                                     │
│  "Send 0.01 SUI to 0x..."                          │
│         │                                           │
│         ▼                                           │
│  ┌─────────────────┐                                │
│  │  MiaoWallet MCP  │  ← Sign request               │
│  │     Server        │                               │
│  └────────┬─────────┘                                │
│           │                                          │
│           ▼                                          │
│  ┌─────────────────────────────────────┐             │
│  │     macOS Keychain (Encrypted)       │             │
│  │  ┌───────────────────────────────┐  │             │
│  │  │  🔒 Private Key (AES-256)     │  │             │
│  │  │  ACL: No trusted apps (-T "") │  │             │
│  │  └───────────────────────────────┘  │             │
│  └────────┬─────────────────────────────┘            │
│           │                                          │
│           ▼                                          │
│  ┌─────────────────────────┐                         │
│  │  🪟 macOS System Prompt  │ ← YOU approve here     │
│  │  "Allow access to        │                        │
│  │   openclaw_bot?"         │                        │
│  │                          │                        │
│  │  [Deny]  [Allow]         │ ← NEVER "Always Allow" │
│  └──────────────────────────┘                        │
│           │                                          │
│           ▼                                          │
│  ┌─────────────────┐                                 │
│  │  Sign Transaction │ → Broadcast to blockchain     │
│  └─────────────────┘                                 │
│           │                                          │
│           ▼                                          │
│     🗑️ Private key purged from memory                │
└─────────────────────────────────────────────────────┘
```

### 🔑 Key Security Features / 关键安全特性

| Feature | Description |
|---------|-------------|
| **Keychain Encryption** | Private keys stored in macOS Keychain with AES-256 encryption, protected by your login password / 私钥以 AES-256 加密存储在 macOS 钥匙串中，受登录密码保护 |
| **Per-Access Authorization** | Every private key access triggers a macOS system prompt — no silent access / 每次访问私钥都会触发系统弹窗 —— 没有静默访问 |
| **Zero Trust ACL** | Stored with `-T ""` flag: no application is pre-trusted / 使用 `-T ""` 存储：没有预信任的应用 |
| **Use-and-Purge** | Private key is immediately deleted from memory after signing / 签名后私钥立即从内存中清除 |
| **No Plaintext Storage** | Private keys never touch the filesystem as plaintext / 私钥永远不会以明文形式接触文件系统 |
| **No Chat Leakage** | Wallet addition via terminal UI (getpass) — keys never pass through AI chat / 通过终端 UI 添加钱包 —— 私钥永远不经过 AI 聊天 |
| **ACL Reset** | One-click reset if "Always Allow" was accidentally clicked / 一键重置误点"始终允许"的情况 |

### ⚠️ Security Rules for AI Agents / AI 代理安全规则

```
1. Use-and-forget: Obtain key → sign → purge immediately
2. Never print: Never display private keys in chat or logs
3. Never cache: Re-fetch from Keychain each time (requires user prompt)
4. Least privilege: Only request key when signing; never for balance checks
```

---

## 📦 Installation / 安装

```bash
git clone https://github.com/CryptoMiaobug/4AI.git
cd 4AI/MiaoWallet
bash setup.sh
```

### Requirements / 依赖

- **macOS** (Keychain required)
- **Python 3.10+**
- Dependencies: `keyring`, `pynacl`, `bech32`, `requests`, `cryptography`

---

## 🚀 Usage / 使用

### Control Panel / 控制面板

Double-click `miaowallet.command` or run:

```bash
source venv/bin/activate
python3 wallet_panel.py list
```

**Menu (auto-detects language / 自动检测语言):**

```
🔐 MiaoWallet Control Panel          🔐 MiaoWallet 控制面板
==============================        ========================
  1. List wallets                       1. 列出钱包
  2. Add wallet                         2. 添加钱包
  3. Remove wallet                      3. 删除钱包
  4. Test wallet                        4. 测试钱包
  5. Reset ACL                          5. 重置授权
  6. Export config                      6. 导出配置
  7. Language [English]                 7. 切换语言 [中文]
  0. Exit                               0. 退出
```

### Add a Wallet / 添加钱包

**Always use the terminal UI** — never paste private keys in chat!

```bash
# Via menu (double-click miaowallet.command, select 2)
# Or directly:
python3 wallet_panel.py add
```

The private key input is hidden (getpass) and stored directly to Keychain with strict ACL.

### Transfer SUI / 转账 SUI

```bash
python3 sui_transfer.py <wallet_alias> <recipient_address> <amount_sui>

# Example:
python3 sui_transfer.py sui1 0xabc...def 0.01
```

This will:
1. 🔐 Trigger Keychain authorization prompt
2. 📤 Build and sign the transaction
3. 🗑️ Purge the private key from memory

### MCP Server (for OpenClaw/AI agents)

```bash
python3 wallet_mcp_server.py
```

Provides 3 tools via MCP:
- `list_wallets` — List registered wallets and addresses
- `wallet_status` — Check wallet details
- `sign_or_use_key` — Access private key for signing (triggers Keychain prompt)

### Reset ACL / 重置授权

If you accidentally clicked "Always Allow" on the Keychain prompt:

```bash
python3 wallet_panel.py reset-acl <wallet_alias>
```

This removes all trusted applications and restores per-access prompts.

---

## 📁 File Structure / 文件结构

```
MiaoWallet/
├── README.md              # This file / 本文件
├── setup.sh               # Quick setup script / 快速安装脚本
├── requirements.txt       # Python dependencies / Python 依赖
├── miaowallet.command     # macOS launcher (double-click) / macOS 启动器
├── wallet_panel.py        # Control panel CLI / 控制面板 CLI
├── wallet_mcp_server.py   # MCP server for AI agents / AI 代理 MCP 服务器
└── sui_transfer.py        # Secure SUI transfer script / 安全 SUI 转账脚本
```

---

## 🔗 Supported Chains / 支持的链

| Chain | Address Derivation | Status |
|-------|--------------------|--------|
| **Sui** | Ed25519 + Blake2b | ✅ Full support (transfer + signing) |
| **EVM** | secp256k1 + Keccak | 🔧 Address derivation only |
| **Solana** | Ed25519 | 📋 Planned |

---

## 🤝 Integration with OpenClaw / 与 OpenClaw 集成

MiaoWallet is designed as an [OpenClaw](https://github.com/openclaw/openclaw) skill. To register the MCP server:

```bash
# Via mcporter or OpenClaw config
mcporter add miao-wallet --stdio "python3 /path/to/wallet_mcp_server.py"
```

The AI agent can then:
1. List wallets (no authorization needed)
2. Check balances (no authorization needed)
3. Sign transactions (**requires your Keychain approval**)

**You stay in control. Always.**

---

## ⚖️ License

MIT

---

*Built with 🐱 by [CryptoMiaobug](https://github.com/CryptoMiaobug)*
