import sys

with open('coverage/lcov.info', 'r') as f:
    in_splash = False
    uncovered_lines = []
    for line in f:
        if line.startswith('SF:') and 'sensor_diagnostics_screen.dart' in line:
            in_splash = True
            continue
        if in_splash and line.startswith('end_of_record'):
            break
        if in_splash and line.startswith('DA:'):
            parts = line.strip().split(',')
            if int(parts[1]) == 0:
                uncovered_lines.append(parts[0].split(':')[1])

print(f"Uncovered lines: {', '.join(uncovered_lines)}")
