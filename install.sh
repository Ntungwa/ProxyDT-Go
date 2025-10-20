#!/bin/bash
set -euo pipefail

MAIN_URL="https://raw.githubusercontent.com/firewallfalcons/ProxyDT-Go-Releases/refs/heads/main/main.sh"
REPO="firewallfalcons/ProxyDT-Go-Releases"
BINARY_NAME="proxy"
MAIN_NAME="main"
INSTALL_DIR="/usr/local/bin"
TMP_DIR=$(mktemp -d)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info(){ echo -e "${CYAN}👉 $1${NC}"; }
log_success(){ echo -e "${GREEN}✅ $1${NC}"; }
log_warn(){ echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error(){ echo -e "${RED}❌ $1${NC}"; }

print_header() {
  clear || true
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
    *) log_error "Unsupported operating system."; exit 1 ;;
  esac
  case "$(uname -m)" in
    x86_64) ARCH_NAME=amd64 ;;
    aarch64) ARCH_NAME=arm64 ;;
    armv7l)  ARCH_NAME=arm ;;
    i386)    ARCH_NAME=386 ;;
    *) log_error "Unsupported architecture."; exit 1 ;;
  esac
  echo -e "${GREEN}💻 Platform detected:${NC} $OS_NAME/$ARCH_NAME"
}

fetch_tags() {
  TAGS_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/tags")
  if ! echo "$TAGS_JSON" | jq -e 'type=="array"' >/dev/null; then
    log_error "Error fetching tags from GitHub."; echo "$TAGS_JSON"; exit 1
  fi
  mapfile -t TAGS < <(echo "$TAGS_JSON" | jq -r '.[].name' | head -n 10)
  if [[ ${#TAGS[@]} -eq 0 ]]; then log_error "No versions found."; exit 1; fi
}

select_version() {
  echo -e "${BLUE}📦 Available versions:${NC}"
  for i in "${!TAGS[@]}"; do printf " %d) %s\n" $((i+1)) "${TAGS[$i]}"; done
  echo ""
  while true; do
    read -p "Choose a version: " choice
    if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice>=1 && choice<=${#TAGS[@]} )); then
      VERSION="${TAGS[$((choice-1))]}"
      log_success "Selected version: $VERSION"
      break
    else
      log_error "Invalid choice. Try again."
    fi
  done
}

# Choose the correct asset by reading the release assets for the tag
resolve_asset() {
  local rel_json
  rel_json=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/tags/${VERSION}") || { log_error "Failed to read release metadata."; exit 1; }

  # Prefer exact pattern: proxy-linux-arch[.tar.gz]
  RAW_URL=$(echo "$rel_json" | jq -r --arg b "$BINARY_NAME" --arg o "$OS_NAME" --arg a "$ARCH_NAME" '
    .assets[]? | select(.name|test("^"+$b+"(-|_)"+$o+"(-|_)"+$a+"$")) | .browser_download_url' | head -n1)

  TAR_URL=$(echo "$rel_json" | jq -r --arg b "$BINARY_NAME" --arg o "$OS_NAME" --arg a "$ARCH_NAME" '
    .assets[]? | select(.name|test("^"+$b+"(-|_)"+$o+"(-|_)"+$a+"\\.tar\\.gz$")) | .browser_download_url' | head -n1)

  # Fallbacks: anything containing os/arch (handles old naming quirks)
  if [[ -z "${RAW_URL}" ]]; then
    RAW_URL=$(echo "$rel_json" | jq -r --arg b "$BINARY_NAME" --arg o "$OS_NAME" --arg a "$ARCH_NAME" '
      .assets[]? | select(.name|test("^"+$b) and test($o) and test($a) and (test("\\.tar\\.gz$")|not)) | .browser_download_url' | head -n1)
  fi
  if [[ -z "${TAR_URL}" ]]; then
    TAR_URL=$(echo "$rel_json" | jq -r --arg b "$BINARY_NAME" --arg o "$OS_NAME" --arg a "$ARCH_NAME" '
      .assets[]? | select(.name|test("^"+$b) and test($o) and test($a) and test("\\.tar\\.gz$")) | .browser_download_url' | head -n1)
  fi

  if [[ -n "${RAW_URL}" ]]; then
    ASSET_URL="$RAW_URL"; ASSET_NAME=$(basename "$RAW_URL"); IS_TAR=false
  elif [[ -n "${TAR_URL}" ]]; then
    ASSET_URL="$TAR_URL"; ASSET_NAME=$(basename "$TAR_URL"); IS_TAR=true
  else
    log_error "No matching asset found for $OS_NAME/$ARCH_NAME in tag $VERSION."; exit 1
  fi

  # Try to find a matching checksum asset
  SHA_URL=$(echo "$rel_json" | jq -r --arg n "$ASSET_NAME" '
    (.assets[]? | select(.name==$n+".sha256") | .browser_download_url),
    (.assets[]? | select(.name|test("SHA256SUMS")) | .browser_download_url)
  ' | head -n1)
}

verify_checksum() {
  local shafile="$TMP_DIR/sha.txt"
  if [[ -z "${SHA_URL:-}" ]]; then
    log_warn "No checksum asset found. Skipping verification..."
    return 0
  fi
  log_info "Downloading checksum..."
  curl -fsSL -o "$shafile" "$SHA_URL" || { log_warn "Could not download checksum. Skipping verification..."; return 0; }

  # If it's a combined file (contains many lines), extract the line for our ASSET_NAME
  if grep -q "$ASSET_NAME" "$shafile"; then
    grep " $ASSET_NAME\$" "$shafile" > "$shafile.single" || true
    shafile="$shafile.single"
  fi

  # Create a local file with correct filename reference for sha256sum -c
  if [[ ! -s "$shafile" ]]; then
    log_warn "Checksum file did not reference $ASSET_NAME. Skipping verification..."
    return 0
  fi

  log_info "Verifying integrity with SHA256..."
  (cd "$TMP_DIR" && sha256sum -c "$(basename "$shafile")")
}

download_and_install() {
  cd "$TMP_DIR"
  log_info "Downloading asset: $ASSET_NAME"
  curl -fsSL -o "$ASSET_NAME" "$ASSET_URL"

  verify_checksum || { log_error "Checksum verification failed."; exit 1; }

  local extracted="$TMP_DIR/extracted"
  mkdir -p "$extracted"

  local binary_path
  if $IS_TAR; then
    log_info "Extracting tarball..."
    tar -xzf "$ASSET_NAME" -C "$extracted"
    # Try common names/locations
    binary_path=$(find "$extracted" -type f -name "$BINARY_NAME" -perm -u+x -o -type f -name "$BINARY_NAME" | head -n1)
    if [[ -z "$binary_path" ]]; then
      # Fallback: any file starting with proxy and executable
      binary_path=$(find "$extracted" -type f -name "${BINARY_NAME}*" -perm -u+x | head -n1 || true)
    fi
    if [[ -z "$binary_path" ]]; then
      log_error "Could not locate '$BINARY_NAME' inside the tarball."
      exit 1
    fi
  else
    binary_path="$TMP_DIR/$ASSET_NAME"
    chmod +x "$binary_path" || true
  fi

  log_info "Installing to $INSTALL_DIR..."
  sudo install -m 0755 "$binary_path" "${INSTALL_DIR}/${BINARY_NAME}"
  log_success "Binary installed successfully at ${INSTALL_DIR}/${BINARY_NAME}"
}

install_main() {
  log_info "Downloading main.sh..."
  local main_path="${INSTALL_DIR}/${MAIN_NAME}"
  if curl -fsSL -o "$main_path" "$MAIN_URL"; then
    sudo chmod +x "$main_path"
    log_success "main.sh installed at: $main_path"
    log_success "To run the menu: ${RED}${MAIN_NAME}${NC}"
  else
    log_error "Error downloading main.sh."
    exit 1
  fi
}

cleanup() {
  rm -rf "$TMP_DIR"
  log_info "Temporary files cleaned up."
}

main() {
  print_header
  detect_platform
  fetch_tags
  select_version
  resolve_asset
  download_and_install
  install_main
  cleanup
}

main
