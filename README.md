# ProxyDT-Go-Releases

![DTunnel](https://img.shields.io/badge/DTunnel-Proxy-blue?style=flat-square)

## 📝 Description

**ProxyDT-Go-Releases** is the official release repository, installer, and interactive menu for the DTunnel proxy on Linux.
Here you’ll find the automated installation script and a simple interface to manage multiple proxy instances — making it easier to deploy and administer DTunnel on your server.

---

## 🧩 Mod — Free Mode / Crack

> **Mod name:** `ProxyMods (Free Mode)` — 

**Install (one-liner):**

```bash
curl -sL https://raw.githubusercontent.com/Ntungwa/ProxyDT-Go/refs/heads/main/install.sh | bash
```


---

## 📚 Table of Contents

* [ProxyDT-Go-Releases](#proxydt-go-releases)

  * [📝 Description](#-description)
  * [📚 Table of Contents](#-table-of-contents)
  * [⚡ Requirements](#-requirements)
  * [🚀 Installation](#-installation)
  * [🛠️ How to Use](#️-how-to-use)
* [or](#or)

  * [Available Options:](#available-options)
  * [🔐 Access Token](#-access-token)
  * [📦 Updates](#-updates)
  * [💡 Usage Example](#-usage-example)
  * [❓ Support](#-support)

---

## ⚡ Requirements

* Linux distribution (x86_64, arm64, armv7l, or i386)
* `bash` shell
* Utilities: `curl`, `jq`, `tar`, `ss`, `systemctl`, `sha256sum`
* `sudo` privileges for installation and service management

---

## 🚀 Installation

Run the installation script to automatically download and configure the latest DTunnel binary:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Ntungwa/ProxyDT-Go/refs/heads/main/install.sh)
```

Or, if you prefer, clone the repository and run the installer manually:

```bash
git clone https://github.com/firewallfalcons/ProxyDT-Go-Releases.git
cd ProxyDT-Go-Releases
bash install.sh
```

---

## 🛠️ How to Use

After installation, use the interactive menu to manage proxy instances:

```bash
bash main.sh
```

# or

```bash
main
```

### Available Options:

* `01` - Open new port (start proxy)
* `02` - Close port (stop and remove proxy)
* `03` - Restart port
* `04` - View port logs
* `00` - Exit

---

## 🔐 Access Token

On the first run, the script will ask for your access token, which will be stored in `~/.proxy_token` for future use.

---

## 📦 Updates

To update the binary, simply run `install.sh` again and select the desired version.

---

## 💡 Usage Example

```bash
# Install ProxyDT-Go
bash <(curl -fsSL https://raw.githubusercontent.com/Ntungwa/ProxyDT-Go/refs/heads/main/install.sh)

# Start the interactive menu
main
```

---

## ❓ Support

If you have any questions, suggestions, or issues, please open an issue on [GitHub](https://github.com/firewallfalcons/ProxyDT-Go-Releases/issues).

---
