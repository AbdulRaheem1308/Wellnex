import sys
try:
    with open('coverage/lcov.info', 'r', encoding='utf-8') as f:
        lines = [l.strip() for l in f]
    start = -1
    for i, line in enumerate(lines):
        if line.startswith('SF:') and 'auth_provider.dart' in line:
            start = i
            break
    if start == -1:
        print("Not found")
        sys.exit(0)
    end = lines.index('end_of_record', start)
    total_lines = 0
    covered_lines = 0
    uncovered = []
    for line in lines[start:end]:
        if line.startswith('DA:'):
            parts = line.split(':')[1].split(',')
            ln = int(parts[0])
            hit = int(parts[1])
            total_lines += 1
            if hit > 0:
                covered_lines += 1
            else:
                uncovered.append(ln)
    print(f"Coverage: {covered_lines} / {total_lines} ({covered_lines/total_lines*100:.2f}%)")
    print(f"Uncovered lines: {uncovered}")
except Exception as e:
    print(f"Error: {e}")
