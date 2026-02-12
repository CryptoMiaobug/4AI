#!/bin/bash
# MiaoWallet Control Panel
cd ~/.openclaw/skills/miao-wallet
source venv/bin/activate

LANG_FILE="$HOME/.openclaw/skills/miao-wallet/.lang"

# Load saved language or detect from system
if [[ -f "$LANG_FILE" ]]; then
    MW_LANG=$(cat "$LANG_FILE")
else
    SYSLANG="${LANG:-${LC_ALL:-en}}"
    [[ "$SYSLANG" == zh* ]] && MW_LANG="zh" || MW_LANG="en"
fi

show_menu() {
    echo ""
    if [[ "$MW_LANG" == "zh" ]]; then
        echo "🔐 MiaoWallet 控制面板"
        echo "========================"
        echo "  1. 列出钱包    (list)"
        echo "  2. 添加钱包    (add)"
        echo "  3. 删除钱包    (remove)"
        echo "  4. 测试钱包    (test)"
        echo "  5. 重置授权    (reset-acl)"
        echo "  6. 导出配置    (export-config)"
        echo "  7. 切换语言    (language) [当前: 中文]"
        echo "  0. 退出"
    else
        echo "🔐 MiaoWallet Control Panel"
        echo "=============================="
        echo "  1. List wallets"
        echo "  2. Add wallet"
        echo "  3. Remove wallet"
        echo "  4. Test wallet"
        echo "  5. Reset ACL"
        echo "  6. Export config"
        echo "  7. Language      [Current: English]"
        echo "  0. Exit"
    fi
    echo ""
}

prompt_alias() {
    if [[ "$MW_LANG" == "zh" ]]; then
        read -p "钱包别名: " name
    else
        read -p "Wallet alias: " name
    fi
}

switch_lang() {
    echo ""
    echo "  1. 中文"
    echo "  2. English"
    echo ""
    read -p "> " lang_choice
    case $lang_choice in
        1) MW_LANG="zh"; echo "zh" > "$LANG_FILE"; echo "✅ 已切换到中文" ;;
        2) MW_LANG="en"; echo "en" > "$LANG_FILE"; echo "✅ Switched to English" ;;
        *) [[ "$MW_LANG" == "zh" ]] && echo "无效选择" || echo "Invalid choice" ;;
    esac
}

show_menu

while true; do
    if [[ "$MW_LANG" == "zh" ]]; then
        read -p "选择操作 (0-7): " choice
    else
        read -p "Select (0-7): " choice
    fi
    case $choice in
        1) python3 wallet_panel.py list ;;
        2) python3 wallet_panel.py add ;;
        3) prompt_alias; python3 wallet_panel.py remove "$name" ;;
        4) prompt_alias; python3 wallet_panel.py test "$name" ;;
        5) prompt_alias; python3 wallet_panel.py reset-acl "$name" ;;
        6) python3 wallet_panel.py export-config ;;
        7) switch_lang; show_menu ;;
        0) [[ "$MW_LANG" == "zh" ]] && echo "👋 再见" || echo "👋 Bye"; break ;;
        *) [[ "$MW_LANG" == "zh" ]] && echo "无效选择" || echo "Invalid choice" ;;
    esac
    echo ""
done
