#!/usr/bin/env bash

## script for checking  network connectivity
# author xxxvodnikxxx & ChatGPT  ; https://github.com/xxxvodnikxxx

# --- Config ---

LOGFILE="/home/shared/monitoring/logs/dns_check.log"
JSONLOGFILE="/home/shared/monitoring/logs/dns_check.json"

ENABLE_TEXT_LOG=false
ENABLE_JSON_LOG=true

# mail notification configuration, ensure teh ssmtp is configured
ENABLE_EMAIL=true
EMAIL_TO="example1@domain1.1,example2@domain2.2"
EMAIL_SUBJECT="[RPI] - Network Checker: Errors detected on $(hostname)"


###     CZNIC ; google ; vodafone default ; vodafone default
## https://www.whatsmydns.net/dns
CUSTOM_DNS=("193.17.47.1" "8.8.8.8" "31.30.90.11" "31.30.90.12")
TEST_DOMAINS=("seznam.cz" "google.com" "vodafone.cz")
TEST_IPS=("77.75.79.222" "142.251.36.142" "217.77.163.138")

## for debug purposes
#CUSTOM_DNS=("31.30.90.11" "31.30.90.12")
#TEST_DOMAINS=("test.example" , "test.example2")
#TEST_IPS=("77.75.79.222" "142.251.36.142" "217.77.163.138")


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

  if [ "$VERBOSITY" -ge 1 ]; then
    if [ "$ENABLE_TEXT_LOG" = true ]; then
      echo "$line" | tee -a "$LOGFILE"
    else
      echo "$line"
    fi
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
  local ip=$1
  debug "Pinging IP: $ip ..."
  local ping_out
  ping_out=$(run_cmd ping -c 1 -W 3 "$ip" 2>/dev/null)
  local success=$?
  if [ $success -eq 0 ]; then
    local time_ms
    time_ms=$(echo "$ping_out" | grep 'time=' | sed -E 's/.*time=([0-9.]+) ms.*/\1/')
    if [[ -z "$time_ms" ]]; then
      time_ms=null
    fi
    log "OK" "ping" "IP=${ip} time=${time_ms}ms"
    if [[ "$time_ms" == "null" ]]; then
      add_json_entry "{\"status\":\"OK\",\"action\":\"ping\",\"ip\":\"${ip}\",\"time_ms\":null}"
    else
      add_json_entry "{\"status\":\"OK\",\"action\":\"ping\",\"ip\":\"${ip}\",\"time_ms\":${time_ms}}"
    fi
  else
    log "ERR" "ping" "IP=${ip} unreachable"
    add_json_entry "{\"status\":\"ERR\",\"action\":\"ping\",\"ip\":\"${ip}\",\"error\":\"unreachable\"}"
  fi
}

do_dns() {
  local dns=$1
  local domain=$2
  debug "Running nslookup for domain '${domain}' with DNS server ${dns}"

  local start=$(date +%s%3N)
  local result
  result=$(nslookup "$domain" "$dns" 2>/dev/null | awk '/^Address: / {print $2}' | tail -n +2 | paste -sd "," -)
  local success=$?
  local end=$(date +%s%3N)
  local duration_ms=$((end - start))

  if [ $success -eq 0 ] && [ -n "$result" ]; then
    log "OK" "dns_resolve" "DNS=${dns} domain=${domain} time=${duration_ms}ms result=${result}"
    add_json_entry "{\"status\":\"OK\",\"action\":\"dns_resolve\",\"dns\":\"${dns}\",\"domain\":\"${domain}\",\"time_ms\":${duration_ms},\"result\":\"${result}\"}"
  else
    log "ERR" "dns_resolve" "DNS=${dns} domain=${domain} failed"
    add_json_entry "{\"status\":\"ERR\",\"action\":\"dns_resolve\",\"dns\":\"${dns}\",\"domain\":\"${domain}\",\"error\":\"failed\"}"
  fi
}

send_error_email() {
  if [ "$ENABLE_EMAIL" = true ] && [ "${#error_messages[@]}" -gt 0 ]; then
    local ts
    ts=$(timestamp)

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
    echo "[$ts] [INFO] Sending error email..."
    echo "[$ts] [INFO] Recipients: $EMAIL_TO"
    echo "[$ts] [INFO] Subject: $EMAIL_SUBJECT"

    # Send email
    echo -e "$full_body" | ssmtp $recipients_formatted

    echo "[$ts] [INFO] Email sent successfully."
  fi
}


# --- Main ---

json_entries=()
error_messages=()

echo "Starting DNS and ping checks..."
echo "-----------------------------------"

echo "Pinging IP addresses..."
for ip in "${TEST_IPS[@]}"; do
  do_ping "$ip"
done

echo "-----------------------------------"
echo "Testing DNS resolution for domains on custom DNS servers..."
for dns_server in "${CUSTOM_DNS[@]}"; do
  for domain in "${TEST_DOMAINS[@]}"; do
    do_dns "$dns_server" "$domain"
  done
done

echo "-----------------------------------"
if [ "$TEST_DEFAULT_DNS" = true ]; then
  echo "Testing system default DNS resolver..."
  DEFAULT_DNS=$(awk '/^nameserver/ {print $2; exit}' /etc/resolv.conf)
  if [ -n "$DEFAULT_DNS" ]; then
    for domain in "${TEST_DOMAINS[@]}"; do
      do_dns "$DEFAULT_DNS" "$domain"
    done
  else
    log "ERR" "dns_resolve" "default_dns not found in /etc/resolv.conf"
    add_json_entry "{\"status\":\"ERR\",\"action\":\"dns_resolve\",\"dns\":\"default\",\"error\":\"not_found_in_resolv.conf\"}"
  fi
  echo "-----------------------------------"
fi

echo "All checks completed."

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
