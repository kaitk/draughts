# pick.py [--src MERGED] TARGETS OUT PASSED...: for each target puzzle, hardest first, the
# unused passed candidate (library.py passed) of the same theme and level nearest its
# difficulty. Writes OUT as `rate` output lines for library.py assemble, and prints what is
# left short and the band histograms.
import sys, glob, collections

# --src MERGED: prefer a trap kind's puzzle within TRAP_PULL of the difficulty.
a = sys.argv[1:]
src = {}
if a[0] == '--src':
    for l in open(a[1]):
        f = [x.strip() for x in l.split('|')]
        if len(f) >= 5:
            src[f[2]] = f[4]
    a = a[2:]
lost_path, out = a[0], a[1]
passed = a[2:]
TRAP_PULL = 150


def lib_rows(path):
    for l in open(path):
        s = l.strip()
        if not s or s.startswith('#') or s.startswith('variant'):
            continue
        yield [x.strip() for x in s.split('|')]


variant = next(l.strip() for l in open(passed[0]) if l.startswith('variant'))
cands = collections.defaultdict(list)
n_ok = 0
for p in passed:
    for f in lib_rows(p):
        cands[f[2]].append((int(f[1]), f))
        n_ok += 1
lost = sorted(lib_rows(lost_path), key=lambda f: -int(f[1]))
picked, short = [], collections.Counter()
for f in lost:
    pool = cands[f[2]]
    if not pool:
        short[f[2]] += 1
        continue
    d = int(f[1])
    trap = lambda j: TRAP_PULL if 'trap' in src.get(pool[j][1][4], '') else 0
    k = min(range(len(pool)), key=lambda j: (abs(pool[j][0] - d) - trap(j), pool[j][1][4]))
    picked.append((d, pool.pop(k)[1]))
with open(out, 'w') as o:
    o.write(variant + '\n')
    for _, f in picked:
        # difficulty | misses pattern | shape | theme level | goal | FEN | line | source
        o.write(' | '.join(f) + '\n')


def bands(ds):
    c = collections.Counter(min(d // 200 * 200, 1600) for d in ds)
    return ' '.join(f'{k}:{c[k]}' for k in range(0, 1800, 200) if c[k])


print(f'{n_ok} passed; picked {len(picked)} of {len(lost)}')
print('short', dict(short))
print('lost  ', bands(int(f[1]) for f in lost))
print('picked', bands(int(f[1]) for _, f in picked))
print('mean shift', sum(int(f[1]) - d for d, f in picked) / max(len(picked), 1))
