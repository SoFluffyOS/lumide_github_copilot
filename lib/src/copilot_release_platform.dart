import 'dart:ffi';

class CopilotReleasePlatform {
  const CopilotReleasePlatform({
    required this.osTag,
    required this.archTag,
  });

  factory CopilotReleasePlatform.current() {
    return CopilotReleasePlatform.fromAbi(Abi.current());
  }

  factory CopilotReleasePlatform.fromAbi(Abi abi) {
    return switch (abi) {
      Abi.macosArm64 => const CopilotReleasePlatform(
          osTag: 'darwin',
          archTag: 'arm64',
        ),
      Abi.macosX64 => const CopilotReleasePlatform(
          osTag: 'darwin',
          archTag: 'x64',
        ),
      Abi.windowsArm64 => const CopilotReleasePlatform(
          osTag: 'win32',
          archTag: 'arm64',
        ),
      Abi.windowsX64 => const CopilotReleasePlatform(
          osTag: 'win32',
          archTag: 'x64',
        ),
      Abi.linuxArm64 => const CopilotReleasePlatform(
          osTag: 'linux',
          archTag: 'arm64',
        ),
      Abi.linuxX64 => const CopilotReleasePlatform(
          osTag: 'linux',
          archTag: 'x64',
        ),
      _ => throw UnsupportedError(
          'Unsupported Copilot Language Server platform: $abi',
        ),
    };
  }

  final String osTag;
  final String archTag;

  String get assetPrefix => 'copilot-language-server-$osTag-$archTag-';

  String? findDownloadUrl(List<dynamic> assets) {
    for (final asset in assets.whereType<Map<String, dynamic>>()) {
      final name = asset['name'];
      final downloadUrl = asset['browser_download_url'];
      if (name is! String || downloadUrl is! String) continue;
      if (name.startsWith(assetPrefix) && name.endsWith('.zip')) {
        return downloadUrl;
      }
    }
    return null;
  }
}
