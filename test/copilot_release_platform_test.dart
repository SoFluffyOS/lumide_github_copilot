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
  });
}
