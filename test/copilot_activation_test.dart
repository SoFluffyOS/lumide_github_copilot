import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('initialization does not wait for the binary download', () async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'bin/main.dart'],
      workingDirectory: Directory.current.path,
    );
    final stderrLines = <String>[];
    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(stderrLines.add);
    final output = StreamIterator(
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .map((line) => jsonDecode(line) as Map<String, dynamic>),
    );

    addTearDown(() async {
      await process.stdin.close();
      await process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          process.kill();
          return process.exitCode;
        },
      );
      await output.cancel();
      await stderrSubscription.cancel();
    });

    process.stdin.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': 99,
        'method': 'initialize',
        'params': {
          'pluginId': 'lumide_github_copilot',
          'version': '1.0.0',
        },
      }),
    );

    final commandRequest = await _nextMessage(output);
    expect(commandRequest['method'], 'commands/register');
    process.stdin.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': commandRequest['id'],
        'result': null,
      }),
    );

    int? configurationRequestId;
    while (true) {
      final message = await _nextMessage(output);
      if (message['method'] == 'workspace/getConfiguration') {
        configurationRequestId = message['id'] as int;
        continue;
      }
      if (message['id'] == 99 && message.containsKey('result')) break;
    }

    expect(configurationRequestId, isNotNull);
    expect(stderrLines, contains('Plugin initialized'));

    process.stdin.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': configurationRequestId,
        'error': {
          'code': 500,
          'message': 'Configuration unavailable',
        },
      }),
    );

    final errorMessage = await _nextMessage(output);
    expect(errorMessage['method'], 'window/showMessage');

    process.stdin.writeln(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': 100,
        'method': 'getProcessInfo',
      }),
    );
    while (true) {
      final message = await _nextMessage(output);
      if (message['id'] == 100) {
        expect(message['result'], contains('rss'));
        break;
      }
    }
  });
}

Future<Map<String, dynamic>> _nextMessage(
  StreamIterator<Map<String, dynamic>> output,
) async {
  final hasNext = await output.moveNext().timeout(const Duration(seconds: 5));
  if (!hasNext) throw StateError('Plugin process closed unexpectedly');
  return output.current;
}
