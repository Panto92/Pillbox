#!/usr/bin/env python3
"""Compile a gettext .po file into a .mo file (no gettext tools needed).
Usage: po2mo.py input.po output.mo      SPDX-License-Identifier: MIT"""
import ast, struct, sys

def parse(path):
    entries, cur, key = {}, {}, None
    def flush():
        if 'msgid' in cur:
            mid = cur['msgid'] + ('\0' + cur['msgid_plural'] if 'msgid_plural' in cur else '')
            strs = [cur[k] for k in sorted(k for k in cur if k.startswith('msgstr'))]
            if any(strs) or mid == '':
                entries[mid] = '\0'.join(strs)
        cur.clear()
    for raw in open(path, encoding='utf-8'):
        line = raw.strip()
        if not line or line.startswith('#'):
            if not line: flush()
            continue
        if line.startswith('"'):
            cur[key] += ast.literal_eval(line); continue
        key, _, val = line.partition(' ')
        key = key.replace('[', '').replace(']', '')
        cur[key] = ast.literal_eval(val)
    flush()
    return entries

def write(entries, out):
    keys = sorted(entries)
    ids = b''.join(k.encode() + b'\0' for k in keys)
    strs = b''.join(entries[k].encode() + b'\0' for k in keys)
    n = len(keys); ofs_ids = 28; ofs_strs = ofs_ids + n * 8; data = ofs_strs + n * 8
    table_ids, table_strs, pos = [], [], 0
    for k in keys:
        b = k.encode(); table_ids += [len(b), data + pos]; pos += len(b) + 1
    for k in keys:
        b = entries[k].encode(); table_strs += [len(b), data + len(ids) + (sum(len(entries[x].encode()) + 1 for x in keys[:keys.index(k)]))]
    with open(out, 'wb') as f:
        f.write(struct.pack('<7I', 0x950412de, 0, n, ofs_ids, ofs_strs, 0, 0))
        f.write(struct.pack('<%dI' % (2 * n), *table_ids)); f.write(struct.pack('<%dI' % (2 * n), *table_strs))
        f.write(ids); f.write(strs)

if __name__ == '__main__':
    write(parse(sys.argv[1]), sys.argv[2])
