import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:lumide_api/lumide_api.dart';
import 'package:lumide_github_copilot/src/copilot_release_platform.dart';
import 'package:path/path.dart' as p;

class CopilotPlugin extends LumidePlugin {
  static const _releaseApiUrl =
      'https://api.github.com/repos/github/copilot-language-server-release/releases/latest';

  static const _providerId = 'copilot';
  static const _configPath = 'copilot.languageServerPath';
  static const _version = '1.0.0';

  bool _isActive = false;
  bool _providerReady = false;
  String _setupStatus = 'initializing';

  @override
  Future<void> onActivate(LumideContext context) async {
    _isActive = true;
    _providerReady = false;
    _setupStatus = 'initializing';
    await _registerSignInCommand(context);
    unawaited(_runLanguageServerSetup(context));
  }

  @override
  Future<void> onDeactivate() async {
    _isActive = false;
  }

  Future<void> _runLanguageServerSetup(LumideContext context) async {
    try {
      await _setupLanguageServer(context);
    } catch (error, stackTrace) {
      _providerReady = false;
      _setupStatus = 'error';
      log(
        '[Copilot] Language server setup failed: '
        '$error\n$stackTrace',
      );
      if (!_isActive) return;

      try {
        await context.window.showMessage(
          'Failed to set up Copilot Language Server.',
          type: MessageType.error,
        );
      } catch (messageError, messageStackTrace) {
        log(
          '[Copilot] Failed to show the setup error: '
          '$messageError\n$messageStackTrace',
        );
      }
    }
  }

  Future<void> _setupLanguageServer(LumideContext context) async {
    if (!_isActive) return;

    final binaryPath = await _ensureBinary(context);
    if (!_isActive) return;

    if (binaryPath == null) {
      _setupStatus = 'error';
      await context.window.showMessage(
        'Failed to download Copilot Language Server.',
        type: MessageType.error,
      );
      return;
    }

    _providerReady = true;
    try {
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
            'version': _version,
          },
        },
        checkStatus: () => _checkStatus(context),
        signIn: () => _signInFlow(context),
        signOut: () async {
          await context.languages.sendLspRequest(_providerId, 'signOut', {});
        },
      );
    } catch (error, stackTrace) {
      _providerReady = false;
      _setupStatus = 'error';
      log(
        '[Copilot] Failed to register the language server: '
        '$error\n$stackTrace',
      );
      await context.window.showMessage(
        'Failed to start Copilot Language Server.',
        type: MessageType.error,
      );
      return;
    }

    if (_isActive) unawaited(_setEditorInfo(context));
  }

  Future<void> _registerSignInCommand(LumideContext context) async {
    await context.commands.registerCommand(
      id: 'copilot.signIn',
      title: 'GitHub Copilot: Sign In',
      category: 'AI',
      callback: ([args]) async {
        if (!_providerReady) {
          final message = switch (_setupStatus) {
            'error' => 'Copilot Language Server setup failed.',
            _ => 'Copilot Language Server is still being set up.',
          };
          await context.window.showMessage(
            message,
            type: switch (_setupStatus) {
              'error' => MessageType.error,
              _ => MessageType.info,
            },
          );
          return;
        }

        final status = await _checkStatus(context);
        if (status == 'ok') {
          await context.window
              .showMessage('You are already signed in to GitHub Copilot.');
          return;
        }
        await _signInFlow(context);
      },
    );
  }

  Future<void> _setEditorInfo(LumideContext context) async {
    try {
      await context.languages.sendLspRequest(_providerId, 'setEditorInfo', {
        'editorInfo': {'name': 'Lumide', 'version': _version},
        'editorPluginInfo': {
          'name': 'lumide-github-copilot',
          'version': _version,
        },
      });
    } catch (error, stackTrace) {
      log('[Copilot] Failed to set editor info: $error\n$stackTrace');
    }
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
      if (await _probeBinary(context, customPath)) return customPath;
      log('[Copilot] Configured language server is not usable: $customPath');
    }

    final installDir = await _getInstallDir(context);
    if (installDir == null) {
      log('[Copilot] Cannot install the language server: home unavailable');
      return null;
    }

    final binaryName = io.Platform.isWindows
        ? 'copilot-language-server.exe'
        : 'copilot-language-server';
    final binaryPath = p.join(installDir, binaryName);

    if (await context.fs.exists(binaryPath)) {
      if (await _prepareManagedBinary(context, binaryPath)) return binaryPath;
      log('[Copilot] Existing language server is invalid; downloading again');
    }

    final downloadUrl = await _fetchLatestDownloadUrl(context);
    if (downloadUrl == null) return null;

    try {
      await context.fs.downloadFile(
        downloadUrl,
        installDir,
        label: 'GitHub Copilot',
        extract: true,
      );

      if (await context.fs.exists(binaryPath) &&
          await _prepareManagedBinary(context, binaryPath)) {
        return binaryPath;
      }
      log(
        '[Copilot] Download completed but no usable binary was extracted to '
        '$binaryPath',
      );
    } catch (error, stackTrace) {
      log(
        '[Copilot] Failed to download the language server: '
        '$error\n$stackTrace',
      );
    }

    return null;
  }

  Future<bool> _prepareManagedBinary(
    LumideContext context,
    String binaryPath,
  ) async {
    if (!io.Platform.isWindows) {
      try {
        final result = await context.shell.run('chmod', ['+x', binaryPath]);
        if (result.exitCode != 0) {
          log(
            '[Copilot] Failed to make the language server executable: '
            '${result.stderr}',
          );
          return false;
        }
      } catch (error, stackTrace) {
        log(
          '[Copilot] Failed to make the language server executable: '
          '$error\n$stackTrace',
        );
        return false;
      }
    }

    return _probeBinary(context, binaryPath);
  }

  Future<bool> _probeBinary(
    LumideContext context,
    String binaryPath,
  ) async {
    try {
      final result = await context.shell.run(binaryPath, const ['--version']);
      if (result.exitCode == 0) return true;

      log(
        '[Copilot] Language server probe failed with exit code '
        '${result.exitCode}: ${result.stderr}',
      );
    } catch (error, stackTrace) {
      log(
        '[Copilot] Language server probe failed: '
        '$error\n$stackTrace',
      );
    }
    return false;
  }

  Future<String?> _getInstallDir(LumideContext context) async {
    final home = io.Platform.environment['HOME'] ??
        io.Platform.environment['USERPROFILE'];
    if (home == null) return null;

    return p.join(home, '.sofluffy', 'lumide', 'ai_providers', 'copilot');
  }

  Future<String?> _fetchLatestDownloadUrl(LumideContext context) async {
    final platform = CopilotReleasePlatform.current();

    try {
      final response = await context.http.get(
        _releaseApiUrl,
        headers: {'User-Agent': 'lumide-github-copilot-plugin'},
      );
      if (response.statusCode != 200) {
        log(
          '[Copilot] Release API returned HTTP ${response.statusCode}',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final assets = data['assets'] as List<dynamic>?;
      if (assets == null) {
        log('[Copilot] Release API response did not contain assets');
        return null;
      }

      final downloadUrl = platform.findDownloadUrl(assets);
      if (downloadUrl != null) return downloadUrl;

      final availableAssets = assets
          .whereType<Map<String, dynamic>>()
          .map((asset) => asset['name'])
          .whereType<String>()
          .join(', ');
      log(
        '[Copilot] No release asset matched ${platform.assetPrefix}. '
        'Available assets: $availableAssets',
      );
    } catch (error, stackTrace) {
      log(
        '[Copilot] Failed to fetch the latest release: '
        '$error\n$stackTrace',
      );
    }
    return null;
  }
}
