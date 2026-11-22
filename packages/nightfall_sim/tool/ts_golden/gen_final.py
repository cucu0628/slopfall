"""Writes test/fixtures/ts_golden_final.dart (last fingerprint per scenario) from ts_golden.json.

Run from packages/nightfall_sim: python3 tool/ts_golden/gen_final.py
"""
import json

d = json.load(open('test/fixtures/ts_golden.json'))


def lit(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, str):
        return "'" + v.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"
    if isinstance(v, float):
        return repr(v)
    if isinstance(v, int):
        return str(v)
    if v is None:
        return 'null'
    if isinstance(v, list):
        return '[' + ', '.join(lit(x) for x in v) + ']'
    if isinstance(v, dict):
        return '{' + ', '.join(lit(k) + ': ' + lit(x) for k, x in v.items()) + '}'
    raise TypeError(v)


out = [
    '// GENERATED from ts_golden.json by tool/ts_golden/gen_final.py. Do not edit.',
    '// The last recorded fingerprint of every scenario, for platforms without file access (web).',
    '',
    'const goldenSample = %d;' % d['sample'],
    '',
    'const List<Map<String, Object?>> goldenScenarios = ' + lit(d['scenarios']) + ';',
    '',
    'const Map<String, List<Object?>> goldenFinal = {',
]
for k, v in d['rows'].items():
    out.append('  %s: %s,' % (lit(k), lit(v[-1])))
out.append('};')
open('test/fixtures/ts_golden_final.dart', 'w').write('\n'.join(out) + '\n')
