import sys

with open('coverage/lcov.info', 'r') as f:
    in_splash = False
    hit = 0
    found = 0
    for line in f:
        if line.startswith('SF:') and 'sensor_diagnostics_screen.dart' in line:
            in_splash = True
            continue
        if in_splash and line.startswith('end_of_record'):
            break
        if in_splash and line.startswith('DA:'):
            found += 1
            parts = line.strip().split(',')
            if int(parts[1]) > 0:
                hit += 1

print(f"sensor_diagnostics_screen coverage: {hit} / {found} ({hit/found*100:.2f}%)")
