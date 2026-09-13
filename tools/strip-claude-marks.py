#!/usr/bin/env python3
"""Remove the review markers Claude leaves around its own changes.

Claude wraps each region it changes in a source file with two line comments:

    // >>> Claude 2026-09-02 start
    ...the changed lines...
    // <<< Claude 2026-09-02 end

Run this from the repository root once a set of changes has been reviewed and
accepted. It deletes the marker lines and leaves the code untouched.

    python3 tools/strip-claude-marks.py             all dates, every tracked source file
    python3 tools/strip-claude-marks.py 2026-09-02  one date only
    python3 tools/strip-claude-marks.py --list      show what is marked, change nothing
"""
import io, os, re, sys

PATTERN = r'^[ \t]*//[ \t]*(>>>|<<<)[ \t]*Claude[ \t]+(\d{4}-\d{2}-\d{2})[ \t]+(start|end)[ \t]*$'
EXTENSIONS = ('.pas', '.lpr', '.inc')

def sources(root):
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in ('.git', 'lib', 'backup', '_to_delete', 'docs')]
        for name in files:
            if name.endswith(EXTENSIONS):
                yield os.path.join(base, name)

def main():
    args = [a for a in sys.argv[1:]]
    listing = '--list' in args
    args = [a for a in args if a != '--list']
    wanted = args[0] if args else None

    rx = re.compile(PATTERN)
    total = 0
    for path in sorted(sources('.')):
        lines = io.open(path, encoding='utf-8', newline='').read().split('\n')
        keep, hits = [], 0
        for line in lines:
            m = rx.match(line)
            if m and (wanted is None or m.group(2) == wanted):
                hits += 1
                if listing:
                    keep.append(line)
                continue
            keep.append(line)
        if hits:
            total += hits
            print('%-28s %3d marker lines%s' % (path, hits, ' (not removed)' if listing else ''))
            if not listing:
                io.open(path, 'w', encoding='utf-8', newline='').write('\n'.join(keep))
    if total == 0:
        print('no markers found')
    else:
        print('%d marker lines %s' % (total, 'found' if listing else 'removed'))

if __name__ == '__main__':
    main()
