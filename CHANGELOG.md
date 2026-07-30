# 1.0.1

### 🐛 Fixes

- Support GitHub Copilot's updated macOS asset tag (`macos` → `darwin`).
- Improve binary download, validation, recovery, and error reporting.
- Prevent activation timeouts and show setup status while Copilot initializes.

# 1.0.0

### 🚀 New Features

- **GitHub Copilot Integration**: Seamlessly experience AI-powered code completions within Lumide.
- **Automated Setup**: Automatic downloading and configuration of the `copilot-language-server` binaries.
- **Device Authentication**: Secure Login using the standard GitHub OAuth2 device flow via `window.showDeviceAuthDialog`.
- **LSP Provider**: Optimized Language Server Protocol (LSP) integration for high-performance completions.
- **Custom Configuration**: Support for manual binary paths via `copilot.languageServerPath` setting.
