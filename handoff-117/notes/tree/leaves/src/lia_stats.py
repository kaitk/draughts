# Leaf inclination angles of Norway maple from Chianucci et al. 2018 (Mendeley 4rmc7r8zvy v2),
# by canopy sector and date, with a few species beside it. Usage: python lia_stats.py dataset_full.csv
import csv, sys, collections, json
import numpy as np
rows = list(csv.DictReader(open(sys.argv[1], encoding='latin1')))
out = {}
def stats(a):
    a = np.array(a)
    return dict(n=len(a), mean=round(a.mean(), 1), median=round(float(np.median(a)), 1),
                under15=round(100 * (a < 15).mean()), under30=round(100 * (a < 30).mean()),
                over60=round(100 * (a > 60).mean()))
g = collections.defaultdict(list)
for r in rows:
    if (r['Genus'], r['Species']) == ('Acer', 'platanoides'):
        g[(r['Canopy_sector'], r['Date'])].append(float(r['Angle_degree']))
for k in sorted(g):
    s = stats(g[k]); out['%s %s' % k] = s; print(k, s)
allp = sum(g.values(), [])
print('all', stats(allp)); out['all'] = stats(allp)
hist = np.histogram(allp, bins=18, range=(0, 90))[0]
out['hist_all'] = hist.tolist()
for sec in ['top', 'middle', 'bottom']:
    v = sum((g[k] for k in g if k[0] == sec), [])
    if v: out['hist_' + sec] = np.histogram(v, bins=18, range=(0, 90))[0].tolist(); print(sec, stats(v))
for sp in [('Acer', 'pseudoplatanus'), ('Acer', 'campestre'), ('Acer', 'saccharinum'), ('Acer', 'rubrum'),
           ('Tilia', 'cordata'), ('Betula', 'pendula'), ('Fagus', 'sylvatica'), ('Quercus', 'robur')]:
    b = [float(r['Angle_degree']) for r in rows if (r['Genus'], r['Species']) == sp]
    if b: print(sp, stats(b)); out[' '.join(sp)] = stats(b)
json.dump(out, open('lia_platanoides.json', 'w'), indent=1)
