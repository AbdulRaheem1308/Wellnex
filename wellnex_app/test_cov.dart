import 'dart:io';

/// Usage: dart test_cov.dart [relative-lib-path]
/// Example: dart test_cov.dart lib/services/api_service.dart
void main(List<String> args) {
  final target = args.isNotEmpty ? args.first : 'lib/features/auth/presentation/screens/splash_screen.dart';
  final content = File('coverage/lcov.info').readAsStringSync();

  bool inTarget = false;
  int hits = 0;
  int misses = 0;
  List<int> missedLines = [];

  for (final line in content.split('\n')) {
    // Match both Windows and Unix path separators
    final normalized = line.replaceAll('\\', '/');
    final targetNorm = target.replaceAll('\\', '/');
    if (normalized.startsWith('SF:') && normalized.contains(targetNorm)) {
      inTarget = true;
      continue;
    }
    if (inTarget && line.trimRight() == 'end_of_record') {
      break;
    }

    if (inTarget && line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      final lineNum = int.parse(parts[0]);
      final count = int.parse(parts[1]);
      if (count > 0) {
        hits++;
      } else {
        misses++;
        missedLines.add(lineNum);
      }
    }
  }

  print('File: $target');
  print('Total lines: ${hits + misses}');
  print('Hits: $hits');
  print('Misses: $misses');
  if (misses > 0) {
    final pct = (hits / (hits + misses) * 100).toStringAsFixed(1);
    print('Coverage: $pct%');
  } else {
    print('Coverage: 100%');
  }
  print('Missed Lines: $missedLines');
}
