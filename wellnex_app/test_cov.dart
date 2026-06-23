import 'dart:io';

void main() {
  final content = File('coverage/lcov.info').readAsStringSync();
  bool inTarget = false;
  int hits = 0;
  int misses = 0;
  List<int> missedLines = [];
  
  for (final line in content.split('\n')) {
    if (line.startsWith('SF:lib\\features\\auth\\presentation\\screens\\splash_screen.dart') ||
        line.startsWith('SF:lib/features/auth/presentation/screens/splash_screen.dart')) {
      inTarget = true;
      continue;
    }
    if (inTarget && line == 'end_of_record') {
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
  
  print('Total lines: ${hits + misses}');
  print('Hits: $hits');
  print('Misses: $misses');
  print('Missed Lines: $missedLines');
}
