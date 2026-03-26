import 'dart:convert';
import 'dart:io' as io;

import 'package:lumide_api/lumide_api.dart';
import 'package:path/path.dart' as p;

class CopilotPlugin extends LumidePlugin {
  static const _releaseApiUrl =
      'https://api.github.com/repos/github/copilot-language-server-release/releases/latest';

  static const _providerId = 'copilot';
  static const _configPath = 'copilot.languageServerPath';
  static const _version = '1.0.0';

  @override
  Future<void> onActivate(LumideContext context) async {
    final binaryPath = await _ensureBinary(context);
    if (binaryPath == null) {
      context.window.showMessage(
        'Failed to download Copilot Language Server.',
        type: MessageType.error,
      );
      return;
    }

    // Register the copilot-language-server as a standard LSP provider.
    await context.languages.registerLanguageServer(
      id: _providerId,
      displayName: 'GitHub Copilot',
      iconPath: 'assets/icon.svg',
      languageId: '*',
      fileExtensions: const [],
      command: binaryPath,
      args: const ['--stdio'],
      initializationOptions: {
        'editorInfo': {'name': 'Lumide', 'version': _version},
        'editorPluginInfo': {
          'name': 'lumide-github-copilot',
          'version': _version
        },
      },
      checkStatus: () => _checkStatus(context),
      signIn: () => _signInFlow(context),
      signOut: () async {
        await context.languages.sendLspRequest(_providerId, 'signOut', {});
      },
    );

    // Register a command to manually trigger sign in from Command Palette
    await context.commands.registerCommand(
      id: 'copilot.signIn',
      title: 'GitHub Copilot: Sign In',
      category: 'AI',
      callback: ([args]) async {
        final status = await _checkStatus(context);
        if (status == 'ok') {
          await context.window
              .showMessage('You are already signed in to GitHub Copilot.');
          return;
        }
        await _signInFlow(context);
      },
    );

    // Set editor info after initialization
    Future(() async {
      try {
        await context.languages.sendLspRequest(_providerId, 'setEditorInfo', {
          'editorInfo': {'name': 'Lumide', 'version': _version},
          'editorPluginInfo': {
            'name': 'lumide-github-copilot',
            'version': _version
          },
        });
      } catch (_) {}
    });
  }

  Future<String> _checkStatus(LumideContext context) async {
    try {
      final result = await context.languages.sendLspRequest(
        _providerId,
        'checkStatus',
        {},
      );
      final status = (result as Map<String, dynamic>?)?['status'] as String?;
      return switch (status) {
        'OK' => 'ok',
        'NotSignedIn' => 'notSignedIn',
        'NotAuthorized' => 'notAuthorized',
        _ => 'error',
      };
    } catch (_) {
      return 'initializing';
    }
  }

  Future<Map<String, dynamic>> _signInFlow(LumideContext context) async {
    try {
      final result = await context.languages.sendLspRequest(
        _providerId,
        'signIn',
        {},
      );
      final map = result as Map<String, dynamic>;

      final userCode = map['userCode'] as String? ?? '';
      final verificationUri = map['verificationUri'] as String? ?? '';

      if (verificationUri.isNotEmpty) {
        await context.window.showDeviceAuthDialog(
          userCode: userCode,
          verificationUri: verificationUri,
        );
      }

      return {
        'userCode': userCode,
        'verificationUri': verificationUri,
        'expiresIn': (map['expiresIn'] as num?)?.toInt() ?? 300,
      };
    } catch (e) {
      log('[Copilot] SignIn error: $e');
      return {'userCode': '', 'verificationUri': '', 'expiresIn': 0};
    }
  }

  Future<String?> _ensureBinary(LumideContext context) async {
    final customPath = await context.workspace.getConfiguration(_configPath);
    if (customPath is String && customPath.isNotEmpty) {
      if (await context.fs.exists(customPath)) return customPath;
    }

    final installDir = await _getInstallDir(context);
    if (installDir == null) return null;

    final binaryName = io.Platform.isWindows
        ? 'copilot-language-server.exe'
        : 'copilot-language-server';
    final binaryPath = p.join(installDir, binaryName);

    if (await context.fs.exists(binaryPath)) return binaryPath;

    final downloadUrl = await _fetchLatestDownloadUrl(context);
    if (downloadUrl == null) return null;

    try {
      await context.fs.downloadFile(
        downloadUrl,
        installDir,
        label: 'GitHub Copilot',
        extract: true,
      );

      if (await context.fs.exists(binaryPath)) {
        if (!io.Platform.isWindows) {
          try {
            await context.shell.run('chmod', ['+x', binaryPath]);
          } catch (_) {}
        }
        return binaryPath;
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _getInstallDir(LumideContext context) async {
    final home = io.Platform.environment['HOME'] ??
        io.Platform.environment['USERPROFILE'];
    if (home == null) return null;

    return p.join(home, '.sofluffy', 'lumide', 'ai_providers', 'copilot');
  }

  Future<String?> _fetchLatestDownloadUrl(LumideContext context) async {
    final os = _getOsTag();
    final arch = _getArchTag();
    final assetPrefix = 'copilot-language-server-$os-$arch-';

    try {
      final response = await context.http.get(
        _releaseApiUrl,
        headers: {'User-Agent': 'lumide-github-copilot-plugin'},
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final assets = data['assets'] as List<dynamic>?;
      if (assets == null) return null;

      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.startsWith(assetPrefix) && name.endsWith('.zip')) {
          return asset['browser_download_url'] as String?;
        }
      }
    } catch (e) {
      log('[Copilot] Failed to fetch latest release: $e');
    }
    return null;
  }

  String _getOsTag() {
    if (io.Platform.isMacOS) return 'macos';
    if (io.Platform.isWindows) return 'win';
    return 'linux';
  }

  String _getArchTag() {
    final arch = io.Platform.version.contains('arm') ||
            io.Platform.version.contains('aarch')
        ? 'arm64'
        : 'x64';
    return arch;
  }
}
