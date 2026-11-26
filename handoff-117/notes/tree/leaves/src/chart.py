# The measured blade tilt of Norway maple by crown height, summer against September, as
# an inline SVG for the page (three small panels, one axis each, hover titles on points).
# Data: Chianucci et al. 2018 (Mendeley 4rmc7r8zvy v2), the Tõravere trees of Raabe et al.
# 2015. Usage: python chart.py lia-dataset_full.csv > ../img/tilt-chart.svg
import csv, sys
import numpy as np

rows = [r for r in csv.DictReader(open(sys.argv[1], encoding='latin1')) if (r['Genus'], r['Species']) == ('Acer', 'platanoides')]
SERIES = [('June and August', ('14-06-13', '01-08-13'), '#338ced'), ('13 September', ('13-09-13',), '#e76624')]
SECTORS = ['top', 'middle', 'bottom']
BIN = 5
bins = np.arange(0, 90 + BIN, BIN)

PW, PH, ML, MB, MT, GAP = 300, 170, 40, 34, 26, 34
W = ML + 3 * PW + 2 * GAP + 10
H = MT + PH + MB + 30
ink, muted, grid = '#d8d6d0', '#a8a6a0', '#2c2f34'
out = ['<svg viewBox="0 0 %d %d" width="100%%" role="img" aria-label="Norway maple blade tilt by crown height" style="max-width:%dpx;font:12px system-ui,sans-serif">' % (W, H, W)]
ymax = 40
for k, sec in enumerate(SECTORS):
    x0 = ML + k * (PW + GAP)
    out.append('<text x="%d" y="16" fill="%s" font-weight="600">%s of the crown</text>' % (x0, ink, sec.capitalize()))
    for g in (0, 10, 20, 30, 40):
        y = MT + PH - g / ymax * PH
        out.append('<line x1="%d" x2="%d" y1="%.1f" y2="%.1f" stroke="%s"/>' % (x0, x0 + PW, y, y, grid))
        if k == 0: out.append('<text x="%d" y="%.1f" fill="%s" text-anchor="end">%d %%</text>' % (x0 - 6, y + 4, muted, g))
    for t in (0, 15, 30, 45, 60, 75, 90):
        x = x0 + t / 90 * PW
        out.append('<text x="%.1f" y="%d" fill="%s" text-anchor="middle">%d°</text>' % (x, MT + PH + 16, muted, t))
    for name, dates, col in SERIES:
        a = np.array([float(r['Angle_degree']) for r in rows if r['Canopy_sector'] == sec + ' canopy' and r['Date'] in dates])
        h = np.histogram(a, bins)[0] / len(a) * 100
        pts = [(x0 + (bins[i] + BIN / 2) / 90 * PW, MT + PH - min(h[i], ymax) / ymax * PH) for i in range(len(h))]
        out.append('<polyline fill="none" stroke="%s" stroke-width="2" stroke-linejoin="round" points="%s"/>' % (col, ' '.join('%.1f,%.1f' % p for p in pts)))
        for i, p in enumerate(pts):
            out.append('<circle cx="%.1f" cy="%.1f" r="7" fill="transparent"><title>%s, %s: %d-%d°, %.0f %% of %d blades</title></circle>' % (p[0], p[1], sec, name, bins[i], bins[i] + BIN, h[i], len(a)))
        med = np.median(a)
        mx = x0 + med / 90 * PW
        out.append('<line x1="%.1f" x2="%.1f" y1="%d" y2="%d" stroke="%s" stroke-width="2" stroke-dasharray="3 3"/>' % (mx, mx, MT, MT + PH, col))
out.append('<text x="%d" y="%d" fill="%s">Blade tilt from level (5° bins); dashed: the median</text>' % (ML, H - 6, muted))
# the legend, with the series' marks beside text in the text ink
lx = ML + 3 * PW + 2 * GAP - 260
for i, (name, _, col) in enumerate(SERIES):
    out.append('<line x1="%d" x2="%d" y1="%d" y2="%d" stroke="%s" stroke-width="2"/>' % (lx + i * 140, lx + i * 140 + 18, H - 10, H - 10, col))
    out.append('<text x="%d" y="%d" fill="%s">%s</text>' % (lx + i * 140 + 24, H - 6, ink, name))
out.append('</svg>')
print('\n'.join(out))
