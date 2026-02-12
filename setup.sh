#!/bin/bash
# MiaoWallet Quick Setup
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔐 Setting up MiaoWallet..."

# Create virtual environment
if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo "✅ Virtual environment created"
fi

source venv/bin/activate
pip install -q -r requirements.txt
echo "✅ Dependencies installed"

chmod +x miaowallet.command
echo "✅ MiaoWallet is ready!"
echo ""
echo "Double-click miaowallet.command to launch the control panel."
echo "Or run: source venv/bin/activate && python3 wallet_panel.py list"
