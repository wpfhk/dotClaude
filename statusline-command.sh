#!/bin/sh
# Claude Code status line — 세션 사용량 및 유용한 정보 표시
input=$(cat)

# --- 컨텍스트 사용량 ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# --- 모델 ---
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- 현재 디렉토리 (basename) ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
dir=$(basename "$cwd")

# --- Rate limit (claude.ai 구독자용, 없으면 생략) ---
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# --- 토큰 합산 (K 단위) ---
total_tokens=$(( total_in + total_out ))
if [ "$total_tokens" -ge 1000 ]; then
  tokens_display="$(printf '%.1f' "$(echo "$total_tokens 1000" | awk '{printf "%.1f", $1/$2}')")k"
else
  tokens_display="${total_tokens}"
fi

# --- 출력 조립 ---
parts=""

# 디렉토리
[ -n "$dir" ] && parts="${dir}"

# 모델
[ -n "$model" ] && parts="${parts} | ${model}"

# 컨텍스트 사용량
if [ -n "$used_pct" ]; then
  ctx=$(printf "%.0f" "$used_pct")
  parts="${parts} | ctx:${ctx}%"
fi

# 누적 토큰
[ "$total_tokens" -gt 0 ] && parts="${parts} | tokens:${tokens_display}"

# Rate limit (5h)
if [ -n "$five_pct" ]; then
  five=$(printf "%.0f" "$five_pct")
  parts="${parts} | 5h:${five}%"
fi

printf "%s" "$parts"
