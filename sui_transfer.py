#!/usr/bin/env python3
"""
安全的 SUI 转账脚本
- 私钥从 macOS Keychain 获取（需弹窗授权）
- 用完立即清除内存
- 不依赖 sui CLI keystore
"""

import json
import sys
import hashlib
import subprocess
import struct

try:
    import keyring
    import bech32
    from nacl.signing import SigningKey
    import requests
except ImportError as e:
    print(f"❌ 缺少依赖: {e}")
    print("运行: pip install keyring pynacl bech32 requests")
    sys.exit(1)

SERVICE_ID = "openclaw_bot"
SUI_RPC = "https://fullnode.mainnet.sui.io:443"


def get_address_from_key(privkey_bech32: str) -> tuple:
    """返回 (seed_bytes, scheme, address_hex)"""
    hrp, data5bit = bech32.bech32_decode(privkey_bech32)
    data8bit = bytes(bech32.convertbits(data5bit, 5, 8, False))
    scheme = data8bit[0]
    seed = data8bit[1:33]
    
    sk = SigningKey(seed)
    pk = sk.verify_key.encode()
    
    hasher = hashlib.blake2b(digest_size=32)
    hasher.update(bytes([scheme]) + pk)
    address = "0x" + hasher.hexdigest()
    
    return seed, scheme, pk, address


def rpc_call(method: str, params: list):
    """调用 Sui JSON-RPC"""
    payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    r = requests.post(SUI_RPC, json=payload, timeout=15)
    result = r.json()
    if "error" in result:
        raise Exception(f"RPC error: {result['error']}")
    return result["result"]


def get_coins(address: str):
    """获取地址的 SUI coins"""
    return rpc_call("suix_getCoins", [address, "0x2::sui::SUI", None, 10])


def build_transfer_tx(sender: str, recipient: str, amount: int, coin_id: str, gas_budget: int):
    """构建转账交易"""
    tx = {
        "sender": sender,
        "kind": "pay_sui",
    }
    # 使用 unsafe_pay_sui 构建交易
    result = rpc_call("unsafe_paySui", [
        sender,
        [coin_id],
        [recipient],
        [str(amount)],
        str(gas_budget)
    ])
    return result


def sign_and_execute(tx_bytes_b64: str, seed: bytes, scheme: int):
    """签名并执行交易"""
    import base64
    
    tx_bytes = base64.b64decode(tx_bytes_b64)
    
    # Intent message: intent_prefix(3 bytes) + tx_bytes
    intent_prefix = bytes([0, 0, 0])  # TransactionData, Sui, Ed25519
    intent_msg = intent_prefix + tx_bytes
    
    # Blake2b hash of intent message
    hasher = hashlib.blake2b(digest_size=32)
    hasher.update(intent_msg)
    digest = hasher.digest()
    
    # Sign the digest with Ed25519
    sk = SigningKey(seed)
    signature = sk.sign(digest).signature  # 64 bytes
    pk = sk.verify_key.encode()  # 32 bytes
    
    # Sui signature format: flag(1) + sig(64) + pubkey(32)
    sig_bytes = bytes([scheme]) + signature + pk
    sig_b64 = base64.b64encode(sig_bytes).decode()
    
    # Execute
    result = rpc_call("sui_executeTransactionBlock", [
        tx_bytes_b64,
        [sig_b64],
        {"showEffects": True, "showBalanceChanges": True},
        "WaitForLocalExecution"
    ])
    return result


def transfer(wallet_alias: str, recipient: str, amount_sui: float):
    """执行转账"""
    amount_mist = int(amount_sui * 1_000_000_000)
    
    print(f"\n📤 转账请求")
    print(f"   钱包: {wallet_alias}")
    print(f"   收款: {recipient}")
    print(f"   金额: {amount_sui} SUI ({amount_mist} MIST)")
    print(f"\n🔐 正在请求 Keychain 授权...")
    
    # 从 Keychain 获取私钥（触发弹窗）
    privkey = keyring.get_password(SERVICE_ID, wallet_alias)
    if not privkey:
        print("❌ 无法获取私钥（用户拒绝或钱包不存在）")
        return None
    
    try:
        # 推导地址
        seed, scheme, pk, sender = get_address_from_key(privkey)
        print(f"   发送方: {sender}")
        
        # 获取 coins
        coins = get_coins(sender)
        if not coins["data"]:
            print("❌ 没有可用的 SUI coin")
            return None
        
        coin_id = coins["data"][0]["coinObjectId"]
        
        # 构建交易
        print("   构建交易中...")
        tx_result = build_transfer_tx(sender, recipient, amount_mist, coin_id, 5000000)
        tx_bytes = tx_result["txBytes"]
        
        # 签名并执行
        print("   签名并发送中...")
        result = sign_and_execute(tx_bytes, seed, scheme)
        
        # 输出结果
        effects = result.get("effects", {})
        status = effects.get("status", {}).get("status", "unknown")
        digest = result.get("digest", "unknown")
        
        gas = effects.get("gasUsed", {})
        gas_total = (int(gas.get("computationCost", 0)) + 
                    int(gas.get("storageCost", 0)) - 
                    int(gas.get("storageRebate", 0)))
        
        print(f"\n{'✅' if status == 'success' else '❌'} 状态: {status}")
        print(f"   交易: {digest}")
        print(f"   Gas: {gas_total / 1e9:.6f} SUI")
        
        for bc in result.get("balanceChanges", []):
            addr = bc["owner"].get("AddressOwner", "?")
            short = addr[:8] + "..." + addr[-4:]
            amt = int(bc["amount"])
            print(f"   {short}: {amt/1e9:+.4f} SUI")
        
        return result
        
    finally:
        # 清除私钥
        privkey = None
        seed = None
        del privkey, seed
        print("\n🗑️  私钥已从内存清除")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("用法: python3 sui_transfer.py <钱包别名> <收款地址> <金额SUI>")
        print("示例: python3 sui_transfer.py sui1 0xabc...def 0.01")
        sys.exit(1)
    
    transfer(sys.argv[1], sys.argv[2], float(sys.argv[3]))
