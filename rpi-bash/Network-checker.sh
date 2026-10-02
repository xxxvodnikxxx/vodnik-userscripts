#!/usr/bin/env bash

## script for checking  network connectivity
# author xxxvodnikxxx & ChatGPT  ; https://github.com/xxxvodnikxxx

# --- Config ---

LOGFILE="/home/shared/monitoring/logs/dns_check.log"
JSONLOGFILE="/home/shared/monitoring/logs/dns_check.json"

ENABLE_TEXT_LOG=true
ENABLE_JSON_LOG=true

# mail notification configuration, ensure teh ssmtp is configured
ENABLE_EMAIL=true
EMAIL_TO="example1@domain1.1,example2@domain2.2"
EMAIL_SUBJECT="[RPI] - Network Checker: Errors detected on $(hostname)"


###     CZNIC ; google ; vodafone default ; vodafone default
## https://www.whatsmydns.net/dns
CUSTOM_DNS=(
  "CZ.NIC|193.17.47.1"
  "Google|8.8.8.8"
  "Vodafone 1|31.30.90.11"
  "Vodafone 2|31.30.90.12"
)
TEST_TARGETS=(
  "Seznam|seznam.cz|77.75.79.222"
  "Google|google.com|142.251.36.142"
  "Vodafone|vodafone.cz|217.77.163.138"
)

## for debug purposes
#CUSTOM_DNS=("31.30.90.11" "31.30.90.12")
#TEST_TARGETS=("Example|test.example|77.75.79.222" "Example 2|test.example2|217.77.163.138")


TEST_DEFAULT_DNS=false

VERBOSITY=1   # 0=quiet, 1=normal, 2=debug/full

timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

log() {
  local status="$1"
  local action="$2"
  local data="$3"
  local ts
  ts=$(timestamp)
  local line="${ts} [${status}] ${action} ${data}"

  if [ "$ENABLE_TEXT_LOG" = true ]; then
    if [ "$VERBOSITY" -ge 1 ]; then
      printf '%s\n' "$line" | tee -a "$LOGFILE"
    else
      printf '%s\n' "$line" >> "$LOGFILE"
    fi
  elif [ "$VERBOSITY" -ge 1 ]; then
    printf '%s\n' "$line"
  fi

  # Collect errors for email
  if [ "$status" = "ERR" ]; then
    error_messages+=("$line")
  fi
}

debug() {
  if [ "$VERBOSITY" -ge 2 ]; then
    echo "DEBUG: $*" >&2
  fi
}

add_json_entry() {
  local entry="$1"
  json_entries+=("$entry")
  debug "Added JSON entry: $entry"
}

run_cmd() {
  debug "Running command: $*"
  "$@"
}

do_ping() {
  local target_name=$1
  local ip=$2
  debug "Pinging ${target_name} at IP: ${ip} ..."
  local ping_out
  ping_out=$(run_cmd ping -c 1 -W 3 "$ip" 2>/dev/null)
  local success=$?
  if [ $success -eq 0 ]; then
    local time_ms
    time_ms=$(echo "$ping_out" | grep 'time=' | sed -E 's/.*time=([0-9.]+) ms.*/\1/')
    if [[ -z "$time_ms" ]]; then
      time_ms=null
    fi
    log "OK" "ping" "target=${target_name} IP=${ip} time=${time_ms}ms"
    if [[ "$time_ms" == "null" ]]; then
      add_json_entry "$(jq -cn --arg target_name "$target_name" --arg ip "$ip" '{status:"OK",action:"ping",target_name:$target_name,ip:$ip,time_ms:null}')"
    else
      add_json_entry "$(jq -cn --arg target_name "$target_name" --arg ip "$ip" --argjson time_ms "$time_ms" '{status:"OK",action:"ping",target_name:$target_name,ip:$ip,time_ms:$time_ms}')"
    fi
  else
    log "ERR" "ping" "target=${target_name} IP=${ip} unreachable"
    add_json_entry "$(jq -cn --arg target_name "$target_name" --arg ip "$ip" '{status:"ERR",action:"ping",target_name:$target_name,ip:$ip,error:"unreachable"}')"
  fi
}

do_dns() {
  local dns_name=$1
  local dns=$2
  local domain=$3
  local target_name=$4
  debug "Running nslookup for ${target_name} (${domain}) with DNS server ${dns_name} (${dns})"

  local start=$(date +%s%3N)
  local lookup_output
  lookup_output=$(nslookup "$domain" "$dns" 2>&1)
  local success=$?
  local result
  result=$(printf '%s\n' "$lookup_output" | awk '/^Address: / {print $2}' | tail -n +2 | paste -sd "," -)
  local end=$(date +%s%3N)
  local duration_ms=$((end - start))

  if [ $success -eq 0 ] && [ -n "$result" ]; then
    log "OK" "dns_resolve" "target=${target_name} domain=${domain} DNS=${dns_name} (${dns}) time=${duration_ms}ms result=${result}"
    add_json_entry "$(jq -cn --arg target_name "$target_name" --arg dns_name "$dns_name" --arg dns "$dns" --arg domain "$domain" --arg result "$result" --argjson time_ms "$duration_ms" '{status:"OK",action:"dns_resolve",target_name:$target_name,dns_name:$dns_name,dns:$dns,domain:$domain,time_ms:$time_ms,result:$result}')"
  else
    local error_type="lookup_failed"
    if grep -qiE 'NXDOMAIN|non-existent domain' <<< "$lookup_output"; then
      error_type="NXDOMAIN"
    elif grep -qiE 'SERVFAIL|server failure' <<< "$lookup_output"; then
      error_type="SERVFAIL"
    elif grep -qiE 'REFUSED|query refused' <<< "$lookup_output"; then
      error_type="REFUSED"
    elif grep -qiE 'timed out|timeout|no servers could be reached' <<< "$lookup_output"; then
      error_type="timeout"
    elif grep -qi 'connection refused' <<< "$lookup_output"; then
      error_type="connection_refused"
    fi

    local details=${lookup_output//$'\n'/; }
    if [ -z "$details" ]; then
      details="nslookup returned no output"
    fi
    log "ERR" "dns_resolve" "target=${target_name} domain=${domain} DNS=${dns_name} (${dns}) error=${error_type} exit_code=${success} details=${details}"
    add_json_entry "$(jq -cn --arg target_name "$target_name" --arg dns_name "$dns_name" --arg dns "$dns" --arg domain "$domain" --arg error "$error_type" --arg details "$lookup_output" --argjson exit_code "$success" '{status:"ERR",action:"dns_resolve",target_name:$target_name,dns_name:$dns_name,dns:$dns,domain:$domain,error:$error,exit_code:$exit_code,details:$details}')"
  fi
}

send_error_email() {
  if [ "$ENABLE_EMAIL" = true ] && [ "${#error_messages[@]}" -gt 0 ]; then
    local recipients_formatted
    recipients_formatted=$(echo "$EMAIL_TO" | tr ',' ' ')

    local body_headers
    body_headers="To: ${EMAIL_TO}
Subject: ${EMAIL_SUBJECT}
"

    local body_content
    body_content=$(printf "%s\n\n" "${error_messages[@]}")
    body_content+="\n\n=== JSON log ===\n$json_output"

    local full_body
    full_body="${body_headers}${body_content}"

    # Console log — always visible
    log "INFO" "email" "Sending error email to ${EMAIL_TO}"
    log "INFO" "email" "Subject: ${EMAIL_SUBJECT}"

    # Send email
    echo -e "$full_body" | ssmtp $recipients_formatted

    log "INFO" "email" "Email sent successfully"
  fi
}


# --- Main ---

json_entries=()
error_messages=()

if [ "$ENABLE_TEXT_LOG" = true ] || [ "$ENABLE_JSON_LOG" = true ]; then
  if ! mkdir -p "$(dirname "$LOGFILE")" "$(dirname "$JSONLOGFILE")"; then
    printf 'Unable to create log directories.\n' >&2
    exit 1
  fi
fi

log "INFO" "run_start" "DNS and ping checks started"
log "INFO" "ping_checks" "Pinging target IP addresses"
for target in "${TEST_TARGETS[@]}"; do
  IFS='|' read -r target_name domain target_ip <<< "$target"
  do_ping "$target_name" "$target_ip"
done

log "INFO" "dns_checks" "Testing target domains on custom DNS servers"
for dns_server in "${CUSTOM_DNS[@]}"; do
  IFS='|' read -r dns_name dns_ip <<< "$dns_server"
  for target in "${TEST_TARGETS[@]}"; do
    IFS='|' read -r target_name domain target_ip <<< "$target"
    do_dns "$dns_name" "$dns_ip" "$domain" "$target_name"
  done
done

if [ "$TEST_DEFAULT_DNS" = true ]; then
  log "INFO" "dns_checks" "Testing target domains on system default DNS resolver"
  DEFAULT_DNS=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)
  if [ -n "$DEFAULT_DNS" ]; then
    for target in "${TEST_TARGETS[@]}"; do
      IFS='|' read -r target_name domain target_ip <<< "$target"
      do_dns "System default" "$DEFAULT_DNS" "$domain" "$target_name"
    done
  else
    log "ERR" "dns_resolve" "default_dns not found in /etc/resolv.conf"
    add_json_entry "{\"status\":\"ERR\",\"action\":\"dns_resolve\",\"dns\":\"default\",\"error\":\"not_found_in_resolv.conf\"}"
  fi
fi

log "INFO" "run_complete" "All checks completed"

timestamp_now=$(timestamp)
json_output=$(printf '%s\n' "${json_entries[@]}" | jq -s --arg ts "$timestamp_now" '{timestamp: $ts, results: .}')

# --- Update JSON log file as array ---

if [ "$ENABLE_JSON_LOG" = true ]; then
  if [ ! -s "$JSONLOGFILE" ]; then
    echo "[]" > "$JSONLOGFILE"
  fi

  tmpfile=$(mktemp)
  jq --argjson newEntry "$json_output" '. += [$newEntry]' "$JSONLOGFILE" > "$tmpfile" && mv "$tmpfile" "$JSONLOGFILE"

  if [ "$VERBOSITY" -eq 2 ]; then
    cat "$JSONLOGFILE" | jq '.'
  fi
fi

# --- Send email if errors occurred ---

send_error_email
