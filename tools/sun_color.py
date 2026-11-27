# sun_color.py: the direct sun's colour by its height, rooms::SUN_COLORS: a 5778 K sun through a
# clear atmosphere (Rayleigh, an Angstrom aerosol, the ozone's Chappuis band) at Kasten and Young's
# air mass, CIE 1931 (Wyman, Sloan and Shirley's fit) to linear Rec.709 at luminance 1.
#
#   python3 tools/sun_color.py   # the table with each height's CCT, then the Goose arrays
import numpy as np, sys
lam = np.arange(380.0, 781.0, 1.0)
def g(x, mu, s1, s2): return np.exp(-0.5 * ((x - mu) / np.where(x < mu, s1, s2)) ** 2)
xb = 1.056*g(lam,599.8,37.9,31.0) + 0.362*g(lam,442.0,16.0,26.7) - 0.065*g(lam,501.1,20.4,26.2)
yb = 0.821*g(lam,568.8,46.9,40.5) + 0.286*g(lam,530.9,16.3,31.1)
zb = 1.217*g(lam,437.0,11.8,36.0) + 0.681*g(lam,459.0,26.0,13.8)
XYZ2RGB = np.array([[3.2406, -1.5372, -0.4986], [-0.9689, 1.8758, 0.0415], [0.0557, -0.2040, 1.0570]])
def planck(T):
    l = lam * 1e-9; return 1 / (l ** 5 * (np.exp(1.4388e-2 / (l * T)) - 1))
BETA, ALPHA, OZONE = 0.08, 1.3, 0.30   # aerosol at 1 um, Angstrom exponent, ozone (atm-cm)
def transmit(h):
    m = 1 / (np.sin(np.radians(h)) + 0.50572 * (h + 6.07995) ** -1.6364)
    um = lam / 1000
    tr = 0.008569 * um ** -4 * (1 + 0.0113 * um ** -2 + 0.00013 * um ** -4)
    ta = BETA * um ** -ALPHA
    to = OZONE * 0.12 * np.exp(-0.5 * ((lam - 600) / 55) ** 2)   # Chappuis, ~0.12 /cm at 600 nm
    return np.exp(-m * (tr + ta + to)), m
def xyz_of(spd): return np.array([(spd * c).sum() for c in (xb, yb, zb)])
def cct(X):
    x, y = X[0] / X.sum(), X[1] / X.sum(); n = (x - 0.3320) / (0.1858 - y)
    return 449 * n ** 3 + 3525 * n ** 2 + 6823.3 * n + 5520.33, x, y
def rgb_of(X): c = XYZ2RGB @ X; return c / (c @ [0.2126, 0.7152, 0.0722])
HEIGHTS = [3, 5, 7, 10, 13, 16, 20, 25, 30, 40, 50, 60, 75, 90]
if __name__ == '__main__':
    sun = planck(5778)
    rows = []
    for h in HEIGHTS:
        t, m = transmit(h)
        X = xyz_of(sun * t)
        c = np.maximum(rgb_of(X), 0)
        c = c / (c @ [0.2126, 0.7152, 0.0722])
        print(f'{h:3} degrees, air mass {m:5.2f}: {cct(X)[0]:5.0f} K')
        rows.append('float3 { %.4f, %.4f, %.4f }' % tuple(c))
    print('let SUN_HEIGHTS: f32[%d] = [%s];' % (len(HEIGHTS), ', '.join('%.1f' % h for h in HEIGHTS)))
    print('let SUN_COLORS: float3[%d] = [%s];' % (len(rows), ', '.join(rows)))
