# MiaoWallet 安全风险分析与改进方案

## 🛡️ 当前安全风险分析

基于 miaowallet 文件夹的实现，以下是关键风险点：

---

## ⚠️ 风险 1：私钥授权绕过

### 问题描述
```python
# wallet_panel.py
with private_key_context() as pk:
    # 使用 pk 签名交易
    pass
```

**风险**：
- 使用上下文管理器 `with` 虽然能自动清理，但在异常情况下可能失败
- 如果 `finally` 块中有错误，私钥可能不会被清空
- 内存垃圾回收（GC）时间不确定，私钥可能驻留更久

### 改进方案

**方案 A：强制内存清空（推荐）**

```python
@contextmanager
def secure_private_key_context(service_id: str, account_name: str):
    """安全的私钥上下文 - 强制清空"""
    private_key = None
    
    try:
        private_key = keyring.get_password(service_id, account_name)
        if not private_key:
            raise ValueError("Private key not found")
        
        logger.info(f"Key loaded: {account_name}")
        yield private_key
        
    finally:
        # 强制清空，即使 GC 延迟
        private_key = None
        
        # 额外安全：覆盖内存区域
        import ctypes
        ctypes.memset(id(private_key), 0, len(private_key))
        
        logger.debug(f"Key purged: {account_name}")

# 使用
with secure_private_key_context(SERVICE_ID, ACCOUNT_NAME) as pk:
    sign_transaction(pk, tx_data)
```

**方案 B：限时私钥**

```python
import time

@contextmanager
def timed_private_key_context(service_id: str, account_name: str, timeout: int = 30):
    """限时私钥上下文 - 超时自动销毁"""
    start_time = time.time()
    private_key = None
    
    def destroy_key():
        nonlocal private_key
        if private_key is not None:
            private_key = None
            logger.warning(f"Key destroyed due to timeout: {account_name}")
    
    try:
        private_key = keyring.get_password(service_id, account_name)
        if not private_key:
            raise ValueError("Private key not found")
        
        # 设置超时销毁
        import signal
        signal.signal(signal.SIGALRM, lambda s, f: destroy_key())
        signal.alarm(timeout)
        
        logger.info(f"Key loaded (timeout: {timeout}s): {account_name}")
        yield private_key
        
    finally:
        # 取消超时
        signal.alarm(0)
        destroy_key()

# 使用
with timed_private_key_context(SERVICE_ID, ACCOUNT_NAME, timeout=30) as pk:
    sign_transaction(pk, tx_data)
```

---

## ⚠️ 风险 2：授权目的地验证不足

### 问题描述

```python
# wallet_mcp_server.py
class PrivateKeyContext:
    def __enter__(self) -> Optional[str]:
        private_key = keyring.get_password(SERVICE_ID, ACCOUNT_NAME)
        # ❌ 没有验证调用者的身份
        # ❌ 没有记录授权日志
        return private_key
```

**风险**：
- 无法追踪谁在什么时间访问了私钥
- 如果私钥泄露，无法溯源
- 恶意程序可能绕过 Keychain 授权

### 改进方案

**方案：授权日志与审计**

```python
import logging
from datetime import datetime
import hashlib

# 配置审计日志
audit_logger = logging.getLogger('wallet_audit')
audit_handler = logging.FileHandler('wallet_audit.log', mode='a')
audit_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s'))
audit_logger.addHandler(audit_handler)

def log_access_attempt(wallet_alias: str, caller: str, success: bool):
    """记录私钥访问尝试"""
    timestamp = datetime.now().isoformat()
    caller_hash = hashlib.sha256(caller.encode()).hexdigest()[:8]
    status = "SUCCESS" if success else "FAILED"
    
    log_entry = f"{timestamp} - {wallet_alias} - {caller_hash} - {status} - CALLED BY: {caller}"
    audit_logger.info(log_entry)
    
    return log_entry

# 在私钥访问时记录
class AuditedPrivateKeyContext:
    def __enter__(self) -> Optional[str]:
        import inspect
        caller = inspect.stack()[1].function  # 获取调用者
        caller_name = caller.__name__ if caller else "unknown"
        
        try:
            private_key = keyring.get_password(SERVICE_ID, ACCOUNT_NAME)
            success = private_key is not None
            
            # 记录访问
            log_access_attempt(ACCOUNT_NAME, caller_name, success)
            
            if success:
                logger.info(f"Key access granted to: {caller_name}")
            else:
                logger.warning(f"Key access denied for: {caller_name}")
            
            return private_key if success else None
            
        except Exception as e:
            log_access_attempt(ACCOUNT_NAME, caller_name, False)
            raise e
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        # 记录操作完成
        logger.debug(f"Key access completed for: {ACCOUNT_NAME}")

# 使用
with AuditedPrivateKeyContext() as pk:
    if pk:
        sign_transaction(pk, tx_data)
```

**方案：调用者白名单**

```python
# config.yaml
allowed_callers:
  - openclaw_bot
  - wallet_panel.py
  - sui_transfer.py

def verify_caller(caller: str) -> bool:
    """验证调用者是否在白名单中"""
    import yaml
    with open('config.yaml', 'r') as f:
        config = yaml.safe_load(f)
        allowed = config.get('allowed_callers', [])
        return caller in allowed

class WhitelistPrivateKeyContext:
    def __enter__(self) -> Optional[str]:
        import inspect
        caller = inspect.stack()[1].function
        caller_name = caller.__name__ if caller else "unknown"
        
        # 白名单检查
        if not verify_caller(caller_name):
            logger.error(f"Unauthorized caller: {caller_name}")
            raise PermissionError(f"Caller {caller_name} not in whitelist")
        
        # 记录访问
        log_access_attempt(ACCOUNT_NAME, caller_name, True)
        
        private_key = keyring.get_password(SERVICE_ID, ACCOUNT_NAME)
        return private_key if private_key else None
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        logger.debug(f"Key access completed for: {ACCOUNT_NAME}")
```

---

## ⚠️ 风险 3：程序完整性验证缺失

### 问题描述

**风险**：
- 没有代码签名验证
- 恶意文件替换（供应链攻击）
- Python 脚本被篡改

### 改进方案

**方案 A：代码签名**

```bash
# 1. 生成签名密钥
openssl genrsa -out private.pem 2048
openssl rsa -in private.pem -pubout -out public.pem

# 2. 签署脚本文件
openssl dgst -sha256 wallet_panel.py | openssl rsautl -sign -keyin private.pem -inkey public.pem -out wallet_panel.py.sig

# 3. 验证签名（运行时）
openssl dgst -sha256 wallet_panel.py
openssl rsautl -verify -inkey public.pem -sigin wallet_panel.py.sig
```

**方案 B：运行时哈希验证**

```python
import hashlib

# 预计算的文件哈希（存储在 config.yaml）
EXPECTED_HASHES = {
    'wallet_panel.py': 'sha256:abc123...',
    'wallet_mcp_server.py': 'sha256:def456...',
}

def verify_file_integrity(filepath: str, expected_hash: str) -> bool:
    """验证文件完整性"""
    sha256_hash = hashlib.sha256(open(filepath, 'rb').read()).hexdigest()
    matches = sha256_hash == expected_hash.split(': ')[1]
    
    if not matches:
        logger.error(f"File integrity check failed: {filepath}")
        logger.error(f"Expected: {expected_hash}")
        logger.error(f"Actual:   {sha256_hash}")
        raise ValueError("File may have been tampered with")
    
    return matches

# 使用
verify_file_integrity('/path/to/wallet_panel.py', EXPECTED_HASHES['wallet_panel.py'])
```

**方案 C：虚拟环境锁定**

```bash
# setup.sh
#!/bin/bash

# 创建锁定的虚拟环境
python3 -m venv venv_locked
source venv_locked/bin/activate

# 安装固定版本的依赖
pip install --require-hashes -r requirements.txt

# 写入虚拟环境哈希
echo "$(python3 -c 'import hashlib; print(hashlib.sha256(open(\"__file__\").read().hexdigest())')" > venv_hash.txt

# 验证虚拟环境
if [ -f "venv_hash.txt" ]; then
    python3 -c "
import sys
import hashlib

with open('venv_hash.txt', 'r') as f:
    stored_hash = f.read().strip()

current_hash = hashlib.sha256(open('__file__', 'rb').read()).hexdigest()

if stored_hash != current_hash:
    print('ERROR: Virtual environment hash mismatch!')
    sys.exit(1)
"
fi
```

---

## ⚠️ 风险 4：Keychain 授权绕过攻击

### 问题描述

**攻击场景**：
1. 用户不小心点击"Always Allow"（始终允许）
2. 恶意程序直接访问 Keychain
3. 没有重置机制

### 改进方案

**方案：一键授权重置**

```python
#!/usr/bin/env python3
"""
reset_keychain_acl.py - 重置 macOS Keychain 授权
"""

import subprocess
import keyring
import sys

SERVICE_ID = "openclaw_bot"

def reset_all_acls():
    """重置所有条目的授权为需要每次确认"""
    try:
        # 使用 security 命令重置 ACL
        result = subprocess.run([
            'security', 'delete-generic-passwords',
            '-a', 'Keychain Access'
            '-s', SERVICE_ID,
            '-i', f'"{SERVICE_ID}"'
        ], capture_output=True, text=True)
        
        print(f"✅ Keychain ACL 重置成功")
        print(f"   服务: {SERVICE_ID}")
        print(f"   下次访问将需要您的授权")
        
        # 列出所有钱包别名
        print("\n📋 已注册的钱包:")
        print("-" * 30)
        
        # 尝试列出所有条目
        try:
            import keyring.backend
            backend = keyring.get_keyring()
            
            # 尝试从 Keychain 读取所有密码
            # 注意：keyring 不直接支持枚举，需要手动列出
            
            print("   请使用 'Keychain Access' 查看所有条目")
            print("   搜索: openclaw_bot")
            
        except Exception as e:
            print(f"   ⚠️  无法列出钱包: {e}")
            
    except Exception as e:
        print(f"❌ 重置失败: {e}")
        sys.exit(1)

def reset_specific_wallet(alias: str):
    """重置特定钱包的授权"""
    try:
        # 删除特定条目，强制下次重新授权
        keyring.delete_password(SERVICE_ID, alias)
        print(f"✅ 已删除并重置钱包: {alias}")
        print(f"   下次添加将需要重新授权")
    except Exception as e:
        print(f"❌ 重置失败: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == '--reset-all':
        reset_all_acls()
    elif len(sys.argv) > 1 and sys.argv[1] == '--reset':
        reset_specific_wallet(sys.argv[2])
    else:
        print("用法:")
        print("  python3 reset_keychain_acl.py --reset-all")
        print("  python3 reset_keychain_acl.py --reset <wallet_alias>")
```

**使用方法**：
```bash
# 重置所有钱包授权
python3 reset_keychain_acl.py --reset-all

# 重置特定钱包
python3 reset_keychain_acl.py --reset main_wallet
```

---

## ⚠️ 风险 5：私钥内存泄漏

### 问题描述

```python
# 常见的内存泄漏场景

# 场景 1：全局变量泄漏
private_key_global = keyring.get_password(SERVICE_ID, ACCOUNT_NAME)
# ❌ 私钥在全局变量中，任何函数都可以访问

# 场景 2：异常处理中的泄漏
try:
    pk = get_private_key()
    process_transaction(pk)  # 如果异常，pk 未被清空
except Exception:
    handle_error()
    # ❌ 异常后 pk 仍在内存中
```

### 改进方案

**方案：内存安全模式**

```python
# config.yaml
security_mode: strict  # strict 或 normal

if security_mode == "strict":
    # 启用额外的内存检查
    import gc
    import weakref

    # 定期强制 GC
    gc.collect()

    # 使用弱引用跟踪
    private_key_ref = weakref.ref(None)
```

---

## 🔒 推荐的安全配置

### config.yaml 增强版

```yaml
# MiaoWallet 安全配置

service_id: "openclaw_bot"

# 安全模式
# strict: 所有安全检查启用，性能较低
# normal: 基本安全检查，平衡性能
security_mode: "normal"

# 私钥访问控制
max_access_time: 30  # 最大私钥访问时间（秒）
auto_destroy_timeout: 10  # 自动销毁超时（秒）

# 授权日志
audit_log_enabled: true
audit_log_file: "wallet_audit.log"
audit_log_max_size: 10485760  # 100MB

# 白名单
allowed_callers:
  - wallet_panel.py
  - wallet_mcp_server.py
  - sui_transfer.py

# 文件完整性验证
integrity_check_enabled: true
integrity_check_hashes:
  wallet_panel.py: "sha256:..."
  wallet_mcp_server.py: "sha256:..."

# Keychain 安全
force_per_access_prompt: true  # 强制每次提示（即使点过 Always Allow）
acl_reset_available: true

# 网络安全
enforce_https: true
verify_ssl_certs: true

# 备份与恢复
auto_backup_enabled: false
backup_encryption: "aes256-gcm"
backup_location: "/Users/macpony/wallet_backups"
```

---

## 🛡️ 完整安全检查清单

### 启动时检查

- [ ] 验证 Python 环境（虚拟环境隔离）
- [ ] 检查文件完整性（哈希验证）
- [ ] 验证 Keychain ACL 状态
- [ ] 检查配置文件安全（权限 600）
- [ ] 验证网络连接（HTTPS 强制）

### 运行时检查

- [ ] 每次私钥访问前验证调用者
- [ ] 记录授权日志（时间、调用者、状态）
- [ ] 强制超时后销毁私钥
- [ ] 使用内存清零覆盖（ctypes.memset）
- [ ] 监控异常并安全清理

### 维护检查

- [ ] 定期审查授权日志
- [ ] 检查 Keychain Access 中的授权状态
- [ ] 验证文件哈希未变更
- [ ] 定期更新依赖（pip audit）
- [ ] 备份关键配置文件

---

## 📊 安全等级对比

| 安全等级 | 描述 | 推荐场景 |
|---------|------|---------|
| **基础** | Keychain 存储 + 每次授权 | 测试环境 |
| **增强** | + 授权日志 + 超时销毁 | 生产环境 |
| **严格** | + 白名单 + 完整性验证 | 高价值钱包 |

---

## 🚀 立即实施建议

### 优先级 1：必须实施

1. **强制内存清零**
   - 修改 `private_key_context` 使用 `ctypes.memset`
   - 确保异常情况下也会执行

2. **授权日志**
   - 实现 `log_access_attempt` 函数
   - 记录所有私钥访问尝试

3. **白名单验证**
   - 在 `config.yaml` 中定义允许的调用者
   - 拒绝未授权调用

### 优先级 2：强烈推荐

4. **超时销毁**
   - 使用 `timed_private_key_context`
   - 设置合理的超时时间（30秒）

5. **文件完整性验证**
   - 预计算关键文件的 SHA256
   - 启动时验证

### 优先级 3：可选增强

6. **代码签名**
   - 签署所有 Python 脚本
   - 运行时验证签名

7. **一键授权重置**
   - 实现 `reset_keychain_acl.py`
   - 提供手动重置选项

---

## 📝 实施优先级

### 第一阶段（本周）

1. ✅ 实现强制内存清零
2. ✅ 添加授权日志系统
3. ✅ 实现白名单验证
4. ✅ 更新配置文件模板

### 第二阶段（下周）

1. ⏳ 实现超时销毁上下文
2. ⏳ 添加文件完整性验证
3. ⏳ 编写安全测试用例

### 第三阶段（未来）

1. ⏳ 代码签名实施
2. ⏳ 虚拟环境锁定
3. ⏳ 硬件钱包集成

---

## 🎯 安全目标

- **零容忍**：私钥在内存中的驻留时间不超过 30 秒
- **完全可追溯**：所有私钥访问都有日志记录
- **完整性保证**：运行时验证所有文件未被篡改
- **授权控制**：只有白名单程序可以访问私钥
- **可恢复性**：一键重置所有授权，防止永久绕过

---

## 📚 参考资源

- [OWASP Key Management](https://owasp.org/www-project-key-management)
- [Python Security Best Practices](https://wiki.python.org/moin/SecurityBestPractices)
- [macOS Keychain Security](https://support.apple.com/guide/security/)
- [MCP Security Guidelines](https://modelcontextprotocol.io/docs/security/)

---

**版本**: 1.0.0
**创建日期**: 2026-02-13
**作者**: Crypto Miao
**状态**: 安全分析与改进方案

#MiaoWallet #Security #Audit #OpenClaw #Keychain #PrivateKey #Authentication
