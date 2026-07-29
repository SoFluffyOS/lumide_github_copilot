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
}
