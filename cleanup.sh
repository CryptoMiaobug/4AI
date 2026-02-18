#!/bin/bash
# ============================================================
# OpenClaw Auto Cleanup
# 自动清理日记文件和巨型 Session，防止 context overflow
# 
# 用法: bash cleanup.sh
# 建议: 通过 cron 每天凌晨自动执行
# ============================================================

# ===== 配置 =====
# 填入你的 OpenClaw 实例路径
BOTS=(
  # "/Users/yourname/.openclaw-instance1"
  # "/Users/yourname/.openclaw-instance2"
)

# 阈值
MAX_DAILY_BYTES=51200      # 日记超过 50KB 触发截断
KEEP_LINES=300             # 截断后保留最后 N 行
MAX_SESSION_BYTES=512000   # Session 超过 500KB 触发清理
BAK_EXPIRE_DAYS=7          # 备份保留天数
ARCHIVE_EXPIRE_DAYS=7      # 日记归档保留天数

# ===== 检查配置 =====
if [ ${#BOTS[@]} -eq 0 ]; then
  echo "[error] BOTS 数组为空，请编辑脚本顶部填入 OpenClaw 实例路径"
  exit 1
fi

# ===== 1. 日记截断 =====
for BOT_DIR in "${BOTS[@]}"; do
  MEMORY_DIR="$BOT_DIR/workspace/memory"
  [ -d "$MEMORY_DIR" ] || continue
  BOT_NAME=$(basename "$BOT_DIR")
  echo "=== [$BOT_NAME] 日记检查 ==="

  for f in "$MEMORY_DIR"/????-??-??.md; do
    [ -f "$f" ] || continue
    size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
    if [ "$size" -gt "$MAX_DAILY_BYTES" ]; then
      bn=$(basename "$f")
      echo "[trim] $bn: ${size}B -> trimming to last ${KEEP_LINES} lines"
      # 归档完整版
      cp "$f" "${f}.archive"
      # 保留标题 + 最后 N 行
      head -5 "$f" > "${f}.tmp"
      echo "" >> "${f}.tmp"
      echo "---" >> "${f}.tmp"
      echo "*（旧内容已归档到 ${bn}.archive，以下为最近记录）*" >> "${f}.tmp"
      echo "" >> "${f}.tmp"
      tail -${KEEP_LINES} "$f" >> "${f}.tmp"
      mv "${f}.tmp" "$f"
      new_size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
      echo "[trim] $bn: ${size}B -> ${new_size}B"
    fi
  done

  # 3 天前的大日记也精简
  find "$MEMORY_DIR" -name "????-??-??.md" -mtime +3 -size +20k -exec sh -c '
    for f; do
      bn=$(basename "$f")
      echo "[old] $bn: trimming old large daily"
      head -5 "$f" > "${f}.tmp"
      echo -e "\n---\n*（旧日记已精简）*\n" >> "${f}.tmp"
      tail -200 "$f" >> "${f}.tmp"
      mv "${f}.tmp" "$f"
    done
  ' sh {} +

  # 清理过期归档
  find "$MEMORY_DIR" -name "*.archive" -mtime +${ARCHIVE_EXPIRE_DAYS} -delete 2>/dev/null
done

# ===== 2. Session 清理 =====
for BOT_DIR in "${BOTS[@]}"; do
  SESS_DIR="$BOT_DIR/agents/main/sessions"
  [ -d "$SESS_DIR" ] || continue
  BOT_NAME=$(basename "$BOT_DIR")
  echo "=== [$BOT_NAME] Session 检查 ==="

  for f in "$SESS_DIR"/*.jsonl; do
    [ -f "$f" ] || continue
    # 跳过 lock 文件
    [[ "$f" == *.lock ]] && continue
    size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
    if [ "$size" -gt "$MAX_SESSION_BYTES" ]; then
      bn=$(basename "$f")
      echo "[session] $bn: ${size}B (>$(( MAX_SESSION_BYTES / 1024 ))KB), truncating"
      # 备份
      cp "$f" "${f}.bak"
      # 只保留第一行（session 元数据）
      head -1 "$f" > "${f}.tmp"
      mv "${f}.tmp" "$f"
      new_size=$(stat -f%z "$f" 2>/dev/null || stat -c%s "$f" 2>/dev/null)
      echo "[session] $bn: ${size}B -> ${new_size}B"
    fi
  done

  # 清理过期备份
  find "$SESS_DIR" -name "*.bak" -mtime +${BAK_EXPIRE_DAYS} -delete 2>/dev/null
done

echo "[done] all bots cleanup complete at $(date '+%Y-%m-%d %H:%M:%S')"
