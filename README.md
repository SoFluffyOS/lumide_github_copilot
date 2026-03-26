# lumide_github_copilot

[![pub package](https://img.shields.io/pub/v/lumide_github_copilot.svg)](https://pub.dev/packages/lumide_github_copilot) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![Powered by SoFluffy](https://img.shields.io/badge/Powered%20by-SoFluffy-orange)](https://sofluffy.io)

The official GitHub Copilot extension for [Lumide IDE](https://lumide.dev).

`lumide_github_copilot` brings world-class AI code completions directly to your Lumide workspace. It leverages the official `copilot-language-server` to provide high-quality completions, suggestions, and context-aware help.

## Features

### 🚀 AI-Powered Completions
- **Ghost Text**: Inline AI suggestions as you type.
- **Context Awareness**: Suggestions are tailored to your open files, language, and coding style.
- **Multilingual**: Supports hundreds of languages including Dart, Flutter, Python, TypeScript, and more.

### 🔐 Secure Authentication
- **OAuth2 Device Flow**: Log in securely using GitHub's native auth process.
- **Persistent Sessions**: Your session remains active across IDE restarts.

### ⚡ Automated Infrastructure
- **Zero Configuration**: lumide_github_copilot automatically downloads the required language server binaries for your OS (macOS, Windows, and Linux).
- **Silent Updates**: The plugin keeps the underlying LSP server updated seamlessly.

## Getting Started

Simply install the plugin in Lumide and follow the authentication prompt in the **Status Bar** or **AI Features** menu.

Alternatively, you can manually trigger the login flow from the **Command Palette**:
1. Open the Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`).
2. Type **"GitHub Copilot: Sign In"**.
3. Copy the 8-character code and follow the link to authorize Lumide.

## Configuration

Customize behavior in your `.sofluffy/lumide/settings.json` or Workspace Settings:

| Key | Default | Description |
|---|---|---|
| `copilot.languageServerPath` | `null` | Manual path to the Copilot binary (overrides automated download). |

## Requirements

- **Local Storage**: The plugin downloads approximately 20-50MB of binary data during initial activation.
- **Network**: Requires an active internet connection but works partially in offline mode for cached completions.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Built with ❤️ by [SoFluffy](https://sofluffy.io).

## Happy Coding 🦊
