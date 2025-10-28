# 🚀 Remnawave Ultimate Installer

Universal installer for Remnawave Panel and Node, combining best practices from [eGames](https://github.com/eGames-dev), [xxphantom](https://github.com/xxphantom), and [DigneZzZ](https://github.com/DigneZzZ).

[Русская версия](README.md) | English

## ✨ Features

- 🎯 **Modular Architecture** - Clean code separation into modules
- 🔄 **Reverse Proxy Choice** - NGINX or Caddy at your choice
- 🔒 **Flexible Security** - Basic / Cookie Auth / 2FA
- 🎨 **Beautiful UI** - Colorful design and easy navigation
- 🔌 **Integrations** - WARP, Beszel, Grafana, Prometheus, Netbird
- 💾 **Backup/Restore** - Automated backups
- 🌐 **Multilingual** - Russian and English support
- 📱 **Telegram** - System event notifications

## 📦 Installation Options

### 1. Panel Only

Install only the control panel:

- Remnawave Panel (Backend)
- PostgreSQL Database
- Redis/Valkey Cache
- Reverse Proxy (NGINX or Caddy)
- SSL Certificate

### 2. Node Only

Install only the node:

- Remnawave Node
- Optional: Xray-core
- Optional: Selfsteal (Caddy for Reality)

### 3. All-in-One

Full installation on one server:

- Panel + Node
- All components from both installations
- Optimized configuration

### 4. Selfsteal Only

Only Caddy for Xray Reality:

- Caddy with Reality support
- 11 ready-made HTML templates
- Template management

## 🚀 Quick Start

### Installation

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/DigneZzZ/remnawave-scripts/main/remnawave-ultimate-installer/install.sh | sudo bash
```

### Build from Source

```bash
# Clone repository
git clone https://github.com/DigneZzZ/remnawave-scripts.git
cd remnawave-scripts/remnawave-ultimate-installer

# Build installer
make build

# Run
sudo bash dist/remnawave-ultimate.sh
```

## 🎯 Reverse Proxy

### NGINX (from eGames)

- ✅ Unix socket for security (`/dev/shm/nginx.sock`)
- ✅ Cookie-based authentication
- ✅ Emergency port 8443
- ✅ High performance
- ✅ Ready integrations (WARP, Beszel, Grafana)

### Caddy (from xxphantom)

- ✅ Automatic Let's Encrypt SSL
- ✅ caddy-security for 2FA
- ✅ Simple configuration
- ✅ Automatic HTTPS redirects
- ✅ Better for beginners

## 🔒 Security Levels

### Basic

- No authentication
- Fast installation
- Suitable for internal networks

### Cookie Auth

- Cookie-based protection
- Random cookie keys
- Medium security level

### Full Auth (Caddy only)

- 2FA via caddy-security
- Maximum protection
- Local/LDAP authentication

## 🔌 Integrations

### WARP (Cloudflare)

Route traffic through Cloudflare WARP:

- Bypass blocks
- Enhanced privacy
- Integration from distillium project

### Beszel

Lightweight monitoring:

- Resource usage
- Container stats
- Simple installation

### Grafana + Prometheus

Advanced monitoring:

- Detailed metrics
- Beautiful dashboards
- Alerting

### Netbird

VPN for secure access:

- Peer-to-peer VPN
- Easy management
- WireGuard based

### CertWarden

SSL certificate management:

- Centralized cert management
- Auto-renewal
- Multiple domains

## 📁 Project Structure

```
remnawave-ultimate-installer/
├── install.sh              # Entry point
├── Makefile               # Build system
├── version.txt            # Version tracking
├── .env.example           # Configuration template
├── src/
│   ├── config.sh          # Global configuration
│   ├── main.sh            # Main menu
│   ├── core/              # Core modules
│   │   ├── colors.sh      # Color definitions
│   │   ├── display.sh     # UI functions
│   │   └── validation.sh  # Validation functions
│   ├── lib/               # Utility libraries
│   │   ├── crypto.sh      # Crypto utilities
│   │   ├── http.sh        # HTTP utilities
│   │   ├── input.sh       # Input handlers
│   │   ├── backup.sh      # Backup/restore
│   │   └── monitoring.sh  # Health checks
│   ├── providers/         # Reverse proxy providers
│   │   ├── nginx/         # NGINX implementation
│   │   └── caddy/         # Caddy implementation
│   ├── modules/           # Installation modules
│   │   ├── panel/         # Panel installation
│   │   ├── node/          # Node installation
│   │   ├── all-in-one/    # Combined installation
│   │   └── integrations/  # Third-party integrations
│   ├── templates/         # SNI/Selfsteal templates
│   └── lang/              # Language files
├── scripts/               # Management scripts
└── dist/                  # Built scripts
```

## 🛠️ Development

### Requirements

- Bash 4.0+
- Make
- ShellCheck (optional)

### Makefile Commands

```bash
make build      # Build installer
make clean      # Clean build
make test       # Run tests (shellcheck)
make install    # Install
make help       # Show help
```

### Adding New Module

1. Create file in `src/modules/`
2. Include in `src/main.sh`
3. Update `Makefile` if needed
4. Build: `make build`

## 📝 Configuration

All settings stored in `.env` file:

```bash
# Installation type
INSTALL_TYPE="panel"

# Reverse proxy
REVERSE_PROXY="caddy"

# Security level
SECURITY_LEVEL="basic"

# Domain
DOMAIN="example.com"

# SSL provider
SSL_PROVIDER="letsencrypt"

# And much more...
```

## 🔄 Post-Installation Management

### Management Scripts

After installation, commands available:

```bash
# Panel management
remnawave-manage status
remnawave-manage backup
remnawave-manage restore
remnawave-manage update

# Node management
remnanode-manage status
remnanode-manage logs
remnanode-manage update

# Selfsteal management
selfsteal-manage status
selfsteal-manage template
selfsteal-manage logs
```

## 📚 Documentation

- [Remnawave Docs](https://docs.remnawave.com)
- [GitHub Issues](https://github.com/DigneZzZ/remnawave-scripts/issues)
- [Changelog](CHANGELOG.md)

## 🤝 Acknowledgments

This project combines best practices from:

- **eGames** - NGINX configuration, Unix socket, integrations
- **xxphantom** - Modular architecture, Caddy solutions
- **DigneZzZ** - UI/UX, management scripts, selfsteal

## 📄 License

MIT License

## 🔗 Links

- [Remnawave GitHub](https://github.com/remnawave)
- [eGames Project](https://github.com/eGames-dev/remnawave-reverse-proxy)
- [xxphantom Project](https://github.com/xxphantom/remnawave-installer)
- [DigneZzZ Scripts](https://github.com/DigneZzZ/remnawave-scripts)

---

Made with ❤️ by DigneZzZ
