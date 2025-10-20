#!/bin/bash
set -e

MAIN_URL="https://raw.githubusercontent.com/firewallfalcons/ProxyDT-Go-Releases/refs/heads/main/main.sh"
REPO="firewallfalcons/ProxyDT-Go-Releases"
BINARY_NAME="proxy"
MAIN_NAME="main"
INSTALL_DIR="/usr/local/bin"
TMP_DIR=$(mktemp -d)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
  echo -e "${CYAN}👉 $1${NC}"
}

log_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
  echo -e "${RED}❌ $1${NC}"
}

print_header() {
  clear
  echo -e "${BLUE}╔═══════════════════════════════════════════════════╗"
  echo -e "║              DTunnel Proxy Installer              ║"
  echo -e "╠═══════════════════════════════════════════════════╣"
  echo -e "║ Repository: $(printf '%-36s' "$REPO") ║"
  echo -e "║ Binary:     $(printf '%-36s' "$BINARY_NAME") ║"
  echo -e "║ Install to: $(printf '%-36s' "$INSTALL_DIR") ║"
  echo -e "╚═══════════════════════════════════════════════════╝${NC}"
  echo
}

detect_platform() {
  case "$(uname -s)" in
  Linux*) OS_NAME=linux ;;
  *)
    log_error "Unsupported operating system."
    exit 1
    ;;
  esac

  case "$(uname -m)" in
  x86_64) ARCH_NAME=amd64 ;;
  aarch64) ARCH_NAME=arm64 ;;
  armv7l) ARCH_NAME=arm ;;
  i386) ARCH_NAME=386 ;;
  *)
    log_error "Unsupported architecture."
    exit 1
    ;;
  esac

  echo -e "${GREEN}💻 Detected platform:${NC} $OS_NAME/$ARCH_NAME"
}

fetch_tags() {
  TAGS_JSON=$(curl -s "https://api.github.com/repos/${REPO}/tags")

  if ! echo "$TAGS_JSON" | jq -e 'type == "array"' >/dev/null; then
    log_error "Error fetching tags from GitHub."
    echo "$TAGS_JSON"
    exit 1
  fi

  TAGS=($(echo "$TAGS_JSON" | jq -r '.[].name' | head -n 5))

  if [[ ${#TAGS[@]} -eq 0 ]]; then
    log_error "No versions found."
    exit 1
  fi
}

show_versions_and_select() {
  echo ""
  echo -e "${BLUE}📦 Available versions:${NC}"
  for i in "${!TAGS[@]}"; do
    printf " %d) %s\n" $((i + 1)) "${TAGS[$i]}"
  done

  echo ""
  while true; do
    read -p "Select a version: " choice
    if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && ((choice >= 1 && choice <= ${#TAGS[@]})); then
      VERSION="${TAGS[$((choice - 1))]}"
      log_success "Selected version: $VERSION"
      break
    else
      log_error "Invalid choice. Please try again."
    fi
  done
}

download_and_install() {
  FILENAME="${BINARY_NAME}-${OS_NAME}-${ARCH_NAME}"
  DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/${FILENAME}"
  SHA_URL="${DOWNLOAD_URL}.sha256"

  cd "$TMP_DIR"
  log_info "Downloading binary: $FILENAME"

  HTTP_STATUS=$(curl -s -w "%{http_code}" -L -o "$FILENAME" "$DOWNLOAD_URL")
  if [[ "$HTTP_STATUS" != "200" ]]; then
    log_error "Error downloading binary. HTTP code: $HTTP_STATUS"
    exit 1
  fi

  if curl -s -L -o "${FILENAME}.sha256" "$SHA_URL"; then
    log_info "Verifying integrity with SHA256..."
    sha256sum -c "${FILENAME}.sha256"
  else
    log_warn "SHA256 file not found. Skipping verification..."
  fi

  log_info "Installing binary to $INSTALL_DIR..."
  sudo mv "${BINARY_NAME}-${OS_NAME}-${ARCH_NAME}" "${INSTALL_DIR}/${BINARY_NAME}"
  sudo chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

  log_success "Binary installed successfully!"
}

install_main() {
  log_info "Downloading main.sh script..."

  MAIN_PATH="${INSTALL_DIR}/${MAIN_NAME}"
  if curl -s -L -o "$MAIN_PATH" "$MAIN_URL"; then
    chmod +x "$MAIN_PATH"
    log_success "main.sh installed at: $MAIN_PATH"
    log_success "To run the menu, execute: $RED$MAIN_NAME${NC}"
    return
  fi

  log_error "Error downloading main.sh script."
  exit 1
}

cleanup() {
  rm -rf "$TMP_DIR"
  log_info "Temporary files cleaned up."
}

main() {
  print_header
  detect_platform
  fetch_tags
  show_versions_and_select
  download_and_install
  install_main
  cleanup
}

main
