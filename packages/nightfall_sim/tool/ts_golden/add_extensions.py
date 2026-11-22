"""Rewrites extensionless relative imports in a copied TS tree to explicit .ts paths."""
import os
import re
import sys

root = sys.argv[1]
for dp, _, fs in os.walk(root):
    for f in fs:
        if not f.endswith('.ts'):
            continue
        p = os.path.join(dp, f)
        src = open(p).read()

        def fix(m):
            spec = m.group(2)
            if not spec.startswith('.'):
                return m.group(0)
            spec = spec.replace('../src/sim/', './sim/')
            target = os.path.normpath(os.path.join(dp, spec))
            if os.path.isdir(target):
                spec = spec.rstrip('/') + '/index.ts'
            elif not spec.endswith('.ts'):
                spec += '.ts'
            return m.group(1) + spec + m.group(3)

        open(p, 'w').write(re.sub(r"(from ')([^']+)(')", fix, src))
