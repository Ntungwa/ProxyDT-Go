#!/bin/bash

declare -A COLORS=(
    ["INFO"]="\033[1;36m"
    ["WARN"]="\033[1;33m"
    ["ERROR"]="\033[1;31m"
    ["SUCCESS"]="\033[1;32m"
    ["TITLE"]="\033[1;34m"
    ["PROMPT"]="\033[1;33m"
    ["RESET"]="\033[0m"
)

declare -A EMOJIS=(
    ["INFO"]="ℹ️"
    ["WARN"]="⚠️"
    ["ERROR"]="❌"
    ["SUCCESS"]="✅"
    ["TITLE"]="✨"
    ["PROMPT"]="👉"
    ["SSL"]="🔐"
    ["CERT"]="📄"
    ["SSH"]="🔒"
    ["LOG"]="📜"
    ["EXIT"]="👋"
)

readonly TOKEN_PATH="$HOME/.proxy_token"
readonly PROXY_EXECUTABLE="/usr/local/bin/proxy"
readonly LOG_PATH="/var/log"
readonly SYSTEMD_SERVICE_PATH="/etc/systemd/system"
readonly DEFAULT_BUFFER_SIZE=32768
readonly DEFAULT_HTTP_RESPONSE="@FirewallFalcon"
readonly MIN_PORT=1
readonly MAX_PORT=65535

print_message() {
    local type="$1"
    local message="$2"
    echo -e "${COLORS[$type]}${EMOJIS[$type]} $message${COLORS[RESET]}" >&2
}

format_prompt() {
    echo -e "${COLORS[PROMPT]}${EMOJIS[PROMPT]} $1${COLORS[RESET]}"
}

read_input() {
    local prompt_text="$1"
    local default_value="${2:-}"
    local value

    if [[ -n "$default_value" ]]; then
        read -rp "$(format_prompt "$prompt_text") [$default_value]: " value
        echo "${value:-$default_value}"
    else
        read -rp "$(format_prompt "$prompt_text"): " value
        echo "$value"
    fi
}

confirm_action() {
    local default_answer="${1:-n}"
    local question="$2"
    local answer

    while true; do
        read -rp "$question (y/n) [$default_answer]: " answer
        answer=${answer:-$default_answer}
        case "${answer,,}" in
        y | yes) return 0 ;;
        n | no) return 1 ;;
        *) print_message "ERROR" "Invalid response. Use 'y' for yes or 'n' for no." ;;
        esac
    done
}

wait_for_enter() {
    read -rp "$(format_prompt 'Press Enter to continue...')" _
}

get_service_name() {
    echo "proxy-$1"
}

get_service_file_path() {
    echo "$SYSTEMD_SERVICE_PATH/$(get_service_name "$1").service"
}

get_log_file_path() {
    echo "$LOG_PATH/proxy-$1.log"
}

is_valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] || return 1
    ((port >= MIN_PORT && port <= MAX_PORT))
}

is_port_in_use() {
    local port="$1"
    ss -tuln | grep -q ":$port "
}

is_service_running() {
    local service_name
    service_name=$(get_service_name "$1")
    systemctl is-active --quiet "$service_name"
}

read_token_from_file() {
    [[ -f "$TOKEN_PATH" ]] && cat "$TOKEN_PATH" || echo ""
}

validate_access_token() {
    "$PROXY_EXECUTABLE" --token "$1" --validate >/dev/null 2>&1
}

prompt_for_token_if_missing() {
    local token
    token=$(read_token_from_file)

    if [[ -z "$token" ]]; then
        clear
        print_message "WARN" "Access token not found."

        while true; do
            token=$(read_input "Please enter your token")
            if validate_access_token "$token"; then
                echo "$token" >"$TOKEN_PATH"
                print_message "SUCCESS" "Token saved to $TOKEN_PATH."
                return
            fi
            print_message "ERROR" "Invalid token. Please provide a valid token."
        done
    fi
}

ask_for_port() {
    local operation="$1"
    local port

    while true; do
        port=$(read_input "Port")

        if ! is_valid_port "$port"; then
            print_message "ERROR" "Invalid port. Must be between $MIN_PORT and $MAX_PORT."
            continue
        fi

        if [[ "$operation" == "start" ]] && is_port_in_use "$port"; then
            print_message "ERROR" "Port $port is already in use."
            continue
        fi

        if [[ "$operation" != "start" ]] && ! is_service_running "$port"; then
            print_message "ERROR" "No active service on port $port."
            continue
        fi

        echo "$port"
        return
    done
}

build_service_file() {
    local port="$1"
    local token="$2"
    local ssl_enabled="$3"
    local ssl_cert_path="$4"
    local ssh_only_flag="$5"
    local http_response="$6"
    local service_file_path

    service_file_path=$(get_service_file_path "$port")

    cat >"$service_file_path" <<EOF
[Unit]
Description=DTunnel Proxy Server on port $port

[Service]
ExecStart=$PROXY_EXECUTABLE --token=$token --port=$port$ssl_enabled $ssl_cert_path $ssh_only_flag --buffer-size=$DEFAULT_BUFFER_SIZE --response=$http_response --domain --log-file=$(get_log_file_path "$port")
Restart=always

[Install]
WantedBy=multi-user.target
EOF
}

start_proxy_service() {
    local port ssl_enabled="" ssl_cert_path="" ssh_only_flag="" http_response token

    port=$(ask_for_port "start") || return
    token=$(read_token_from_file)

    if confirm_action "n" "$(format_prompt "${EMOJIS[SSL]} Do you want to enable SSL?")"; then
        ssl_enabled=":ssl"
        if ! confirm_action "y" "$(format_prompt "${EMOJIS[CERT]} Use internal certificate?")"; then
            ssl_cert_path=$(read_input "SSL certificate path")
            [[ -n "$ssl_cert_path" ]] && ssl_cert_path="--cert=$ssl_cert_path"
        fi
    fi

    http_response=$(read_input "Default HTTP response" "$DEFAULT_HTTP_RESPONSE")

    if confirm_action "n" "$(format_prompt "${EMOJIS[SSH]} Enable SSH-only mode?")"; then
        ssh_only_flag="--ssh-only"
    fi

    build_service_file "$port" "$token" "$ssl_enabled" "$ssl_cert_path" "$ssh_only_flag" "$http_response"

    systemctl daemon-reload
    systemctl start "$(get_service_name "$port")"
    systemctl enable "$(get_service_name "$port")"

    print_message "SUCCESS" "Proxy started on port $port."
    wait_for_enter
}

restart_proxy_service() {
    local port service_name
    port=$(ask_for_port) || return
    service_name=$(get_service_name "$port")
    systemctl restart "$service_name"

    print_message "SUCCESS" "Proxy on port $port restarted."
    wait_for_enter
}

stop_proxy_service() {
    local port service_name service_file_path
    port=$(ask_for_port) || return
    service_name=$(get_service_name "$port")
    service_file_path=$(get_service_file_path "$port")

    systemctl stop "$service_name"
    systemctl disable "$service_name"
    rm -f "$service_file_path"
    systemctl daemon-reload

    print_message "SUCCESS" "Proxy on port $port has been stopped."
    wait_for_enter
}

show_proxy_logs() {
    local port proxy_log_file
    port=$(ask_for_port) || return
    proxy_log_file=$(get_log_file_path "$port")

    if [[ ! -f "$proxy_log_file" ]]; then
        print_message "ERROR" "Log file not found."
        wait_for_enter
        return
    fi

    trap 'break' INT
    while :; do
        clear
        cat "$proxy_log_file"
        echo -e "\nPress ${COLORS[WARN]}Ctrl+C${COLORS[RESET]} to return to the menu."
        sleep 1
    done
    trap - INT
}

list_active_proxies() {
    systemctl list-units --type=service --state=running | grep -oE 'proxy-[0-9]+' | cut -d'-' -f2 | tr '\n' ' '
}

display_menu() {
    local active_ports
    echo -e "${COLORS[TITLE]}╔═════════════════════════════╗${COLORS[RESET]}"
    echo -e "${COLORS[TITLE]}║${COLORS[SUCCESS]}      DTunnel Proxy Menu     ${COLORS[RESET]}${COLORS[TITLE]}║${COLORS[RESET]}"
    echo -e "${COLORS[TITLE]}║═════════════════════════════║${COLORS[RESET]}"

    active_ports=$(list_active_proxies)
    if [[ -n "$active_ports" ]]; then
        echo -e "${COLORS[TITLE]}║${COLORS[SUCCESS]}Active:${COLORS[WARN]} $(printf "%-20s ${COLORS[TITLE]}║" "$active_ports")${COLORS[RESET]}"
        echo -e "${COLORS[TITLE]}║═════════════════════════════║${COLORS[RESET]}"
    fi

    echo -e "${COLORS[TITLE]}║${COLORS[INFO]}[${COLORS[SUCCESS]}01${COLORS[INFO]}] ${COLORS[SUCCESS]}• ${COLORS[ERROR]}OPEN PORT            ${COLORS[TITLE]}║${COLORS[RESET]}"
    echo -e "${COLORS[TITLE]}║${COLORS[INFO]}[${COLORS[SUCCESS]}02${COLORS[INFO]}] ${COLORS[SUCCESS]}• ${COLORS[ERROR]}CLOSE PORT           ${COLORS[TITLE]}║${COLORS[RESET]}"
    echo -e "${COLORS[TITLE]}║${COLORS[INFO]}[${COLORS[SUCCESS]}03${COLORS[INFO]}] ${COLORS[SUCCESS]}• ${COLORS[ERROR]}RESTART PORT         ${COLORS[TITLE]}║${COLORS[RESET]}"
    echo -e "${COLORS[TITLE]}║${COLORS[INFO]}[${COLORS[SUCCESS]}04${COLORS[INFO]}] ${COLORS[SUCCESS]}• ${COLORS[ERROR]}VIEW PORT LOG        ${COLORS[TITLE]}║${COLORS[RESET]}"
    echo -e "${COLORS[TITLE]}║${COLORS[INFO]}[${COLORS[SUCCESS]}00${COLORS[INFO]}] ${COLORS[ERROR]}• ${COLORS[WARN]}EXIT                 ${COLORS[TITLE]}║${COLORS[RESET]}"
    echo -e "${COLORS[TITLE]}╚═════════════════════════════╝${COLORS[RESET]}"
}

main() {
    prompt_for_token_if_missing

    while true; do
        clear
        display_menu
        local choice
        choice=$(read_input "Enter your option")

        case "$choice" in
        1 | 01) start_proxy_service ;;
        2 | 02) stop_proxy_service ;;
        3 | 03) restart_proxy_service ;;
        4 | 04) show_proxy_logs ;;
        0 | 00)
            print_message "EXIT" "Exiting. Goodbye!"
            exit 0
            ;;
        *)
            print_message "ERROR" "Invalid option."
            wait_for_enter
            ;;
        esac
    done
}

main
