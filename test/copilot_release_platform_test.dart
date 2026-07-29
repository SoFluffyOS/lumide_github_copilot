import 'dart:ffi';

import 'package:lumide_github_copilot/src/copilot_release_platform.dart';
import 'package:test/test.dart';

void main() {
  group('CopilotReleasePlatform', () {
    final expectations = {
      Abi.macosArm64: 'copilot-language-server-darwin-arm64-',
      Abi.macosX64: 'copilot-language-server-darwin-x64-',
      Abi.windowsArm64: 'copilot-language-server-win32-arm64-',
      Abi.windowsX64: 'copilot-language-server-win32-x64-',
      Abi.linuxArm64: 'copilot-language-server-linux-arm64-',
      Abi.linuxX64: 'copilot-language-server-linux-x64-',
    };

    for (final MapEntry(key: abi, value: expectedPrefix)
        in expectations.entries) {
      test('uses the release asset name for $abi', () {
        final platform = CopilotReleasePlatform.fromAbi(abi);

        expect(platform.assetPrefix, expectedPrefix);
      });
    }

    test('rejects platforms without a native release asset', () {
      expect(
        () => CopilotReleasePlatform.fromAbi(Abi.windowsIA32),
        throwsUnsupportedError,
      );
    });

    test('finds the download URL for the current platform', () {
      const platform = CopilotReleasePlatform(
        osTag: 'darwin',
        archTag: 'arm64',
      );
      final downloadUrl = platform.findDownloadUrl([
        {
          'name': 'copilot-language-server-linux-x64-1.2.3.zip',
          'browser_download_url': 'https://example.com/linux.zip',
        },
        {
          'name': 'copilot-language-server-darwin-arm64-1.2.3.zip',
          'browser_download_url': 'https://example.com/macos.zip',
        },
      ]);

      expect(downloadUrl, 'https://example.com/macos.zip');
    });

    test('ignores malformed and incompatible assets', () {
      const platform = CopilotReleasePlatform(
        osTag: 'win32',
        archTag: 'x64',
      );

      expect(
        platform.findDownloadUrl([
          null,
          {'name': 42},
          {
            'name': 'copilot-language-server-win32-arm64-1.2.3.zip',
            'browser_download_url': 'https://example.com/windows.zip',
          },
        ]),
        isNull,
      );
    });
  });
}
