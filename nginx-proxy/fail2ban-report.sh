#!/usr/bin/env bash
set -Eeuo pipefail

# Show current fail2ban bans with timestamps from fail2ban logs.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_ACCESS_LOG="${NGINX_ACCESS_LOG:-$PROJECT_DIR/data/nginx/logs/access.log}"
RECENT_EVENTS="${RECENT_EVENTS:-20}"

SUDO=()
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  SUDO=(sudo -n)
fi

run_sudo() {
  "${SUDO[@]}" "$@"
}

log_stream() {
  run_sudo sh -c 'zcat -f /var/log/fail2ban.log* 2>/dev/null || true'
}

list_jails() {
  run_sudo fail2ban-client status |
    sed -n 's/.*Jail list:[[:space:]]*//p' |
    tr ',' '\n' |
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' |
    sed '/^$/d'
}

status_value() {
  local jail="$1"
  local label="$2"

  run_sudo fail2ban-client status "$jail" |
    awk -F: -v label="$label" '$0 ~ label {
      value = $2
      gsub(/^[ \t]+|[ \t]+$/, "", value)
      print value
      exit
    }'
}

banned_ips() {
  local jail="$1"

  status_value "$jail" "Banned IP list" |
    tr ' ' '\n' |
    sed '/^$/d'
}

last_event_time() {
  local jail="$1"
  local event="$2"
  local ip="$3"

  log_stream |
    awk -v jail="[$jail]" -v event="$event" -v ip="$ip" '
      index($0, jail) && $0 ~ (" " event " " ip "$") {
        ts = substr($0, 1, 19)
      }
      END {
        if (ts) print ts
      }'
}

found_count() {
  local jail="$1"
  local ip="$2"

  log_stream |
    awk -v jail="[$jail]" -v ip="$ip" '
      index($0, jail) && $0 ~ ("Found " ip " ") {
        count++
      }
      END { print count + 0 }'
}

reverse_dns() {
  local ip="$1"
  local name=""

  if command -v timeout >/dev/null 2>&1; then
    name="$(timeout 2 getent hosts "$ip" 2>/dev/null | awk 'NR == 1 { print $2 }' || true)"
  else
    name="$(getent hosts "$ip" 2>/dev/null | awk 'NR == 1 { print $2 }' || true)"
  fi

  [[ -n "$name" ]] && printf '%s' "$name" || printf '-'
}

last_nginx_request() {
  local ip="$1"

  if [[ -r "$NGINX_ACCESS_LOG" ]]; then
    awk -v ip="$ip" '$1 == ip { line = $0 } END { if (line) print line }' "$NGINX_ACCESS_LOG"
  elif [[ -e "$NGINX_ACCESS_LOG" ]]; then
    run_sudo awk -v ip="$ip" '$1 == ip { line = $0 } END { if (line) print line }' "$NGINX_ACCESS_LOG"
  fi
}

print_jail_summary() {
  local jail="$1"

  printf '%-18s failed=%-5s total_failed=%-5s banned=%-4s total_banned=%s\n' \
    "$jail" \
    "$(status_value "$jail" "Currently failed" || true)" \
    "$(status_value "$jail" "Total failed" || true)" \
    "$(status_value "$jail" "Currently banned" || true)" \
    "$(status_value "$jail" "Total banned" || true)"
}

print_current_bans() {
  local any=0
  local jail ip ban_at unban_at found rdns last_req

  printf '\nCurrent bans\n'
  printf '============\n'
  printf '%-16s %-15s %-19s %-19s %-7s %s\n' "JAIL" "IP" "BANNED_AT" "LAST_UNBAN" "FOUND" "RDNS"

  while IFS= read -r jail; do
    while IFS= read -r ip; do
      [[ -n "$ip" ]] || continue
      any=1
      ban_at="$(last_event_time "$jail" "Ban" "$ip")"
      unban_at="$(last_event_time "$jail" "Unban" "$ip")"
      if [[ -n "$ban_at" && -n "$unban_at" && "$unban_at" < "$ban_at" ]]; then
        unban_at=""
      fi
      found="$(found_count "$jail" "$ip")"
      rdns="$(reverse_dns "$ip")"

      printf '%-16s %-15s %-19s %-19s %-7s %s\n' \
        "$jail" "$ip" "${ban_at:-unknown}" "${unban_at:--}" "$found" "$rdns"

      last_req="$(last_nginx_request "$ip")"
      if [[ -n "$last_req" ]]; then
        printf '  last nginx request: %s\n' "$last_req"
      fi
    done < <(banned_ips "$jail")
  done < <(list_jails)

  if [[ "$any" -eq 0 ]]; then
    printf 'No active bans right now.\n'
  fi
}

print_recent_events() {
  printf '\nRecent ban/unban events\n'
  printf '=======================\n'
  log_stream |
    grep -E 'NOTICE[[:space:]]+\[[^]]+\] (Ban|Unban) ' |
    tail -n "$RECENT_EVENTS" ||
    true
}

main() {
  printf 'Fail2ban report for %s\n' "$(hostname)"
  printf 'Generated at: %s\n' "$(date -Is)"
  printf '\nJails\n'
  printf '=====\n'

  if ! run_sudo fail2ban-client ping >/dev/null 2>&1; then
    printf 'fail2ban server is not responding\n' >&2
    exit 1
  fi

  if ! list_jails | grep -q .; then
    printf 'No active jails found.\n'
    exit 0
  fi

  while IFS= read -r jail; do
    print_jail_summary "$jail"
  done < <(list_jails)

  print_current_bans
  print_recent_events
}

main "$@"
