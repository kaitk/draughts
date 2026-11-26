# Writes ../index.html: the leaf notes, with the chart inlined. Run after variants.py,
# shoot.py and chart.py.
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
svg = open(os.path.join(ROOT, 'img', 'tilt-chart.svg'), encoding='utf8').read()
st = json.load(open(os.path.join(ROOT, 'img', 'shoot-stats.json')))
pct = lambda x: '%d %%' % round(100 * x)

html = r'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Maple leaves</title><style>
:root { color-scheme: dark; }
body { background: #16181b; color: #d8d6d0; font: 15px/1.5 -apple-system, system-ui, sans-serif; margin: 0 auto; max-width: 1500px; padding: 16px; }
h1 { font-size: 22px; } h2 { font-size: 18px; margin-top: 32px; border-top: 1px solid #333; padding-top: 16px; }
h3 { font-size: 16px; margin-top: 24px; }
code { color: #e8c98a; } a { color: #8fb8e8; }
.row { display: flex; flex-wrap: wrap; gap: 12px; } figure { margin: 0; flex: 1 1 240px; min-width: 0; }
img { width: 100%; height: auto; display: block; border: 1px solid #333; }
figcaption { font-size: 13px; color: #a8a6a0; margin-top: 4px; }
table { border-collapse: collapse; margin-top: 8px; } td, th { border: 1px solid #3a3a3a; padding: 4px 10px; text-align: left; vertical-align: top; }
th { background: #22252a; } td.n { text-align: right; }
.note { background: #22252a; border-left: 3px solid #e8c98a; padding: 8px 12px; }
.none { background: #2a2224; border-left: 3px solid #e87a6a; padding: 8px 12px; }
.wrap { overflow-x: auto; }
@media (max-width: 700px) { table { font-size: 12px; } td, th { padding: 2px 4px; } }
</style></head><body>
<h1>The maple's leaves: which ones sag, how they sit in plates, and how to draw them bent</h1>
<p>Task 117, 2026-11-26, branch <code>room-light</code>. Research and CPU prototypes only; nothing in <code>src/</code> changed.
The scripts are in <code>src/</code>: <code>leaf.py</code> (the atlas's leaf as a mesh, and the bends), <code>raster.py</code>
(a small rasterizer with the game's leaf light), <code>variants.py</code>, <code>shoot.py</code>, <code>chart.py</code>,
<code>lia_stats.py</code> and this page's <code>page.py</code>. The leaf shape is the game's own atlas
(<code>../branches/dump/atlas-shape.rgba</code>), cut at alpha 0.5 as the shader cuts it.</p>

<p class="note"><b>In short.</b>
(1) Measured Norway maple blades are mostly near level: in summer the top of the crown has the <i>flattest</i> blades
(median 15° from level, 86 % within 30°), and the middle and bottom are steeper (median 22-23°). So "the sagging leaves are at
the crown's edge" is <b>not</b> what the data show for summer. In autumn it changes: the top's blades turn steeper first, as they
age (median 22° in September, 42° in an October sample). The game's tree is an autumn tree, so steeper and sagging blades at the
top and outside fit it. Nobody measured how curved Norway maple blades are by position; for beech, sun leaves are <i>more</i>
curved (folded) than shade leaves.
(2) On a level shoot the lower leaf of a pair has the longer stalk and the larger blade (Weisse 1895, measured on Norway maple),
and long stalks (5-20 cm) let the blades spread into one layer. Placed that way and nudged apart, the prototype's blades overlap
''' + pct(st['overlap_after_mosaic']) + r''' in plan, against ''' + pct(st['now_overlap']) + r''' for the game's present rule on the same branch.
(3) Draw a bent leaf as a small fan mesh that hugs the outline (21 vertices on the high tier), bent at startup into six template
shapes; each leaf picks a template, an amount and a twist, packed into a field the card already has. The fan also cuts the alpha-cut
area: the blade covers 45 % of it against 27 % of the card. The standard tier gets a card cut in four rows (10 vertices), bent along
its midrib only; phones keep the flat card.</p>

<h2>1. The photos</h2>
<div class="row">
<figure><img src="img/photo-tartu-edge.jpg"><figcaption><b>tartu-maple-1</b>, the crown's edge from below, autumn. Plates of 2-6
leaves at the shoot tips, sky between them. Many blades are seen edge-on or steep, lobes hanging: from below, a level blade is seen
whole, so these are tilted or bent.</figcaption></figure>
<figure><img src="img/photo-tartu-plates.jpg"><figcaption><b>tartu-maple-1</b>, higher in the crown. The plates read as layers;
most blades are seen nearly whole (near level), a few on edge.</figcaption></figure>
<figure><img src="img/photo-tartu-inner.jpg"><figcaption><b>tartu-maple-1</b>, inside the crown: a closed layer of blades
over each branch, very little sky.</figcaption></figure>
</div>
<div class="row">
<figure><img src="img/photo-ai-side.jpg"><figcaption><b>ai-branch-canopy</b> (made, not photographed). From the side: long red
stalks, blades level or tilted out; some cupped with the lobes up, a few hanging.</figcaption></figure>
<figure><img src="img/photo-flat-sun.jpg"><figcaption>Sun leaves against the light (tree-gravity photo <code>lYKGL…</code>):
blades flat and level; some lobe tips and edges turn <b>up</b> (upper left, where the pale underside shows).</figcaption></figure>
<figure><img src="img/photo-sag-shade.jpg"><figcaption>Shade leaves inside a crown (<code>kk7lp…</code>): large blades
tilted down steeply, each lobe folded down along its vein like a tent.</figcaption></figure>
</div>
<div class="row">
<figure><img src="img/photo-flat-stalks.jpg"><figcaption><code>8J6fZ…</code>: two leaves on long stalks that arch up and then
over, the blades flat.</figcaption></figure>
<figure><img src="img/photo-backlit.jpg"><figcaption><b>maple-leaf-backlit-summer</b>: a leaf hanging from its stalk, flat,
lit through.</figcaption></figure>
<figure><img src="img/photo-autumn-hanging.jpg"><figcaption><code>V1gQc…</code>, autumn: old leaves hang on their stalks, some
nearly upright, lobes curled.</figcaption></figure>
</div>
<p>What the photos say together: flat and level is common; cupped-up blades show in sun; drooping, tented blades show in shade and in
autumn. Photos can't tell which is more common where; the measurements below can, for tilt.</p>

<h2>2. Which leaves sag: what the papers say</h2>

<h3>2.1 Blade tilt in Norway maple, by height and season (measured)</h3>
<p><a href="https://doi.org/10.1016/j.agrformet.2015.07.008">Raabe, Pisek, Sonnentag and Annuk 2015</a> photographed the tilt of
Norway maple blades (with a levelled camera, about 100 blades a sample) at the top, middle and bottom of open-grown trees at
Tõravere, Estonia, from May to September 2013. The values are public in
<a href="https://data.mendeley.com/datasets/4rmc7r8zvy/2">Chianucci et al. 2018</a> (138 species; the paper:
<a href="https://doi.org/10.1007/s13595-018-0730-x">Ann. For. Sci. 75:50</a>), which also holds an October 2011 sample from
<a href="https://doi.org/10.1016/j.agrformet.2012.10.011">Pisek et al. 2013</a>. Kairi Adamson's (née Raabe)
<a href="https://dspace.ut.ee/bitstreams/6db24ff9-e2f7-4186-8028-6e5edc4bdd68/download">2024 thesis</a> sums up the 2015
paper: Norway maple "exhibited a strong planophile distribution throughout most of the growing season, with notable differences at
the canopy top during spring and autumn. The leaves emerged oriented downward and became more horizontally oriented when fully
expanded … The canopy remained planophile until late summer, when senescence begins at the canopy top, leading to a shift back to
plagiophile." Planophile means mostly level; plagiophile, mostly at 30-60°.</p>
<div class="wrap">''' + svg + r'''</div>
<table>
<tr><th>Norway maple, Tõravere</th><th>blades</th><th>median tilt</th><th>within 15°</th><th>within 30°</th></tr>
<tr><td>top, June and August</td><td class="n">197</td><td class="n">15°</td><td class="n">50 %</td><td class="n">86 %</td></tr>
<tr><td>middle, June and August</td><td class="n">194</td><td class="n">22°</td><td class="n">30 %</td><td class="n">67 %</td></tr>
<tr><td>bottom, June and August</td><td class="n">182</td><td class="n">23°</td><td class="n">29 %</td><td class="n">66 %</td></tr>
<tr><td>top, 15 May (unfolding)</td><td class="n">101</td><td class="n">38°</td><td class="n">3 %</td><td class="n">26 %</td></tr>
<tr><td>top, 13 September</td><td class="n">100</td><td class="n">22°</td><td class="n">27 %</td><td class="n">69 %</td></tr>
<tr><td>middle, 13 September</td><td class="n">100</td><td class="n">26°</td><td class="n">23 %</td><td class="n">63 %</td></tr>
<tr><td>bottom, 13 September</td><td class="n">100</td><td class="n">24°</td><td class="n">26 %</td><td class="n">65 %</td></tr>
<tr><td>whole crown, 11 October 2011</td><td class="n">100</td><td class="n">42°</td><td class="n">7 %</td><td class="n">25 %</td></tr>
</table>
<p>For comparison in the same data: beech median 14°, sycamore 32°, field maple 51°, silver birch 58°. Norway maple is one of the
flattest. Computed by <code>src/lia_stats.py</code> and <code>src/chart.py</code>.</p>
<ul>
<li><b>The top is the flattest in summer.</b> This is the reverse of the usual rule (sun leaves steeper), which the same group found
in silver birch grown in a forest; they read Norway maple as a shade-tolerant species that keeps its leaves level everywhere.</li>
<li><b>Autumn steepens the top first.</b> From August to September the top's median goes from 18° to 22° and the share within 15°
falls from 47 % to 27 %; the October 2011 sample has a median of 42°, 15 % past 60°. The thesis puts the autumn change down to
senescence; it adds that longer stalks and heavier, older blades steepen leaves late in summer (citing Gordon and Promnitz 1976, Hamerlynck and Knapp 1996).</li>
<li><b>Caveat:</b> tilt is measured as if each blade were flat; it says nothing about curvature. The trees were open-grown, so
"top" is the sunniest; the sides of the crown were not measured apart.</li>
</ul>

<h3>2.2 Curved blades and light (other species)</h3>
<ul>
<li><a href="https://doi.org/10.1093/treephys/23.9.577">Fleck, Niinemets, Cescatti and Tenhunen 2003</a> (beech, <i>Fagus
sylvatica</i> and <i>F. orientalis</i>): "the leaves were not entirely flat anywhere in the canopy"; the angle between the blade's
two halves went from 170° in the most shaded leaves to 90-100° at the top: <b>sun leaves are folded far more</b>, and both branch
and blade tilt rose with light. The abstract doesn't say which way the halves fold.</li>
<li><a href="https://doi.org/10.1071/FP08051">Chambelland et al. 2008</a> (young beech, laser-scanned): midrib curvature, twist and
curvature across the blade measured; "a more bent shape in well-lit leaves"; bent leaves caught 4-10 % less light than flat ones.</li>
<li><a href="https://doi.org/10.1007/s00442-002-0902-z">Niinemets and Fleck 2002</a> (tulip tree, beam theory): blade and stalk tilt
rose with light, but the blade's tilt followed the stalk's; stalks and blades got stiffer as their loads grew, "such that the lamina
vertical displacement was only weakly related to" light. Up to 30 % of a leaf's mass goes into its stalk and big veins to hold
the blade where it is.</li>
<li><a href="https://doi.org/10.1007/s004680050173">Niinemets 1998</a> (aspen, small-leaved lime): differences in leaf tilt came
mainly from stalk length; the shade-tolerant lime kept blades more level.</li>
<li>Niinemets's <a href="https://dspace.ut.ee/bitstreams/90022290-cc8e-4e60-8ad8-f9b13d40edab/download">1996 thesis</a> (Norway
maple saplings among others): shade leaves have less mass per area (thinner); Norway maple changes this least with light of the
species studied.</li>
<li>Water: <a href="https://doi.org/10.3390/f13050728">Junttila et al. 2022</a> found branches lower and rise with the leaves'
water potential (R² 0.86 and 0.75 in two trees; up to 20 cm at night). Nothing found at the scale of a maple leaf.</li>
</ul>

<h3>2.3 What this means for the user's guess</h3>
<p class="none"><b>Where there is no evidence.</b> I found no study that measures the curvature (droop along the midrib, edges
curling, lobes bending, twist) of Norway maple blades by position in the crown, by light, or by water. No study separates the
crown's sides from its top. The upward cup is shown in photos and in beech (as folding), not measured in Norway maple.</p>
<ul>
<li><b>Sagging at the crown's edge in summer: not supported.</b> The sunniest blades (the top of open trees) are the flattest
measured; the shaded middle and bottom are steeper. Shade leaves are thinner and larger, and the shade photo above shows them
tented down, so <i>more</i> sag inside and low is the better guess, weakly supported.</li>
<li><b>In autumn: supported for the top.</b> The top's blades steepen first as they age, and old leaves hang (photo above).
In the game's autumn tree the outer, upper leaves, which already turn colour first (<code>add_cards</code>'s
<code>twig_tint</code>), should also be the steeper and the more bent.</li>
<li><b>Cupped or folded blades in sun: supported in beech</b> (Fleck 2003, Chambelland 2008), seen in the sun photo, not measured
in Norway maple.</li>
<li><b>Most blades flat: supported.</b> Norway maple is planophile; half the summer top blades are within 15° of level.</li>
</ul>

<h2>3. Leaves in plates at the shoot tips</h2>
<ul>
<li><b>Opposite pairs, each a quarter turn from the last</b> (decussate), as all maples.</li>
<li><b>The lower leaf of a pair is larger and has the longer stalk.</b> <a href="https://www.zobodat.at/pdf/Ber-Deutschen-Bot-Ges_13_0376-0389.pdf">Weisse 1895</a>,
"Zur Kenntniss der Anisophyllie von <i>Acer platanoides</i>", measured it on an old Norway maple in Berlin: on side shoots "the leaves
pointing down exceed the upper ones in size and weight, while the side ones lie between", and the lower leaves' stalks are often
also relatively longer. On level one-year twigs the stalks of a pair differed about 1:1.5 (up and down leaves) to 1:2-3 (the leaves
toward and away from the mother shoot; the outer one longer), the blades 1:1.1 to 1:2; the difference fades on older twigs. He
measured stalks from 42 to 230 mm. He cites Kerner's <i>Pflanzenleben</i>, which shows Norway maple as the example of a leaf mosaic,
and says the stalks' relative length is what builds the mosaic.</li>
<li><b>Long stalks make one layer.</b> Niinemets (1996 thesis): Norway maple's stalks are 5-20 cm (pedunculate oak's 0.5-2 cm); "long
petioles allow considerable flexibility in horizontal arrangement of leaves", a "functional monolayer" (Horn 1971) whatever the point
of attachment.</li>
<li><b>Stalk length is how trees avoid shading their own leaves</b>: Takenaka 1994, Yamada and Suzuki 1996, Takahashi and Mikami
2008 (in other species, as cited by <a href="https://doi.org/10.1007/s10265-024-01524-5">Aoyagi, Nakabayashi and Yamada 2024</a>, J Plant Res 137:203-213). I found no
measured mosaic of Norway maple beyond Weisse's ratios.</li>
</ul>

<h3>3.1 The prototype branch</h3>
<p>A small branch (''' + str(st['segments']) + ''' segments, ''' + str(st['tips']) + ''' tips) grown by <code>shoot.py</code>: level annual shoots
forking in opposite pairs, side shoots lying flat, the buds above and below the shoot mostly asleep. Three leaf rules on the same
wood, autumn colours:</p>
<ul>
<li><b>now</b>: the game's <code>add_cards</code>: four pairs along each twig's outer four fifths, stalks rising, each blade turned
by a random ball of 0.9 about "out and up". ''' + str(st['now_leaves']) + ''' leaves.</li>
<li><b>tips, flat</b>: only each tip's current shoot: the tip pair and one pair a quarter turn below; the lower leaf of a
pair larger (up to 1.22) on a longer stalk (up to 1.45), the outer of a side pair longer (1.15); blades level, tilted by a value
drawn from the measured September top-of-crown tilts; then the mosaic step: each blade turns about its node (at most 35°) and its
stalk changes (0.7-1.5 of its own) away from the blades it covers, the lower one moving more. ''' + str(st['proposed_leaves']) + ''' leaves.
Plan overlap ''' + pct(st['overlap_before_mosaic']) + ''' before the mosaic step, ''' + pct(st['overlap_after_mosaic']) + ''' after
(<code>now</code>: ''' + pct(st['now_overlap']) + ''', measured the same way on blade discs).</li>
<li><b>tips, bent</b>: the same, each blade bent by the rule in section 5 (here ''' + ', '.join('%d %s' % (v, k) for k, v in st['bends'].items()) + ''').</li>
</ul>
<div class="row">
<figure><img src="img/photo-tartu-plates.jpg"><figcaption>Photo, from below.</figcaption></figure>
<figure><img src="img/shoot-now-below.png"><figcaption>now, from below: a ball of leaves around every twig, no gaps.</figcaption></figure>
<figure><img src="img/shoot-flat-below.png"><figcaption>tips, flat: rosettes of four at the tips, sky between them.</figcaption></figure>
<figure><img src="img/shoot-proposed-below.png"><figcaption>tips, bent: the same from below; the bends show only in the light.</figcaption></figure>
</div>
<div class="row">
<figure><img src="img/photo-ai-side.jpg"><figcaption>Photo (made), from the side.</figcaption></figure>
<figure><img src="img/shoot-now-side.png"><figcaption>now, from the side: blades at all angles.</figcaption></figure>
<figure><img src="img/shoot-flat-side.png"><figcaption>tips, flat: thin level plates.</figcaption></figure>
<figure><img src="img/shoot-proposed-side.png"><figcaption>tips, bent: the plates break up a little; some blades droop.</figcaption></figure>
</div>
<div class="row">
<figure><img src="img/photo-flat-sun.jpg"><figcaption>Photo, against the light.</figcaption></figure>
<figure><img src="img/shoot-now-light.png"><figcaption>now, against the light.</figcaption></figure>
<figure><img src="img/shoot-flat-light.png"><figcaption>tips, flat.</figcaption></figure>
<figure><img src="img/shoot-proposed-light.png"><figcaption>tips, bent.</figcaption></figure>
</div>
<h3>3.2 One plate, close</h3>
<div class="row">
<figure><img src="img/plate-flat-below.png"><figcaption>Flat, from below.</figcaption></figure>
<figure><img src="img/plate-flat-side.png"><figcaption>Flat, from the side and a little below.</figcaption></figure>
<figure><img src="img/plate-flat-light.png"><figcaption>Flat, against the light.</figcaption></figure>
</div>
<div class="row">
<figure><img src="img/plate-proposed-below.png"><figcaption>Bent, from below: nearly the same outline.</figcaption></figure>
<figure><img src="img/plate-proposed-side.png"><figcaption>Bent, from the side: cups and droops break the level line.</figcaption></figure>
<figure><img src="img/plate-proposed-light.png"><figcaption>Bent, against the light: the light changes across each blade.</figcaption></figure>
</div>
<p>The prototype's wood is simple (<code>grow_branch</code>), not the branch work of <code>../branches/</code>; only the leaves
are the point here. The stalks are drawn as curves that rise from the twig and arrive along the blade; the game draws only the
stalk's top on the card.</p>

<h2>4. The bent leaves</h2>
<p>A palmate leaf's main veins run out from the foot along five rays (the atlas puts them at 0°, ±56° and ±110°). So each
bend is one rule: every point lies on a ray from the foot, and each ray bends as an arc whose angle grows along it to a chosen angle
at the lobe's tip; each lobe has its own angle, and a ray between lobes blends theirs. A curl across each lobe's vein and a twist
about the midrib are added. Bending as arcs keeps lengths, so the outline doesn't stretch; the sinuses between lobes take up the
little stretch a cup would need. From <code>leaf.py</code> (angles at the lobe tips, middle, big lobes, small lobes):</p>
<table>
<tr><th>Variant</th><th>lobe tips</th><th>starts</th><th>curl</th><th>twist</th><th>seen in</th></tr>
<tr><td>flat</td><td>0</td><td></td><td></td><td></td><td>most blades (Raabe 2015)</td></tr>
<tr><td>cup up</td><td>+14°, +20°, +22°</td><td>at the foot</td><td>+0.10 (edges up)</td><td></td><td>sun photo, AI branch; beech sun leaves</td></tr>
<tr><td>midrib droop</td><td>−38°, −12°, −4°</td><td>at the foot</td><td></td><td></td><td>hanging and old leaves</td></tr>
<tr><td>edges down</td><td>−10°, −28°, −34°</td><td>at the foot</td><td>−0.22 (tented lobes)</td><td></td><td>shade photo</td></tr>
<tr><td>lobe tips</td><td>−30°, −35°/−14°, −40°/−8°</td><td>55 % out</td><td></td><td></td><td>Tartu edge, AI branch</td></tr>
<tr><td>sag + twist</td><td>−30°, −24°/−30°, −30°/−26°</td><td>at the foot</td><td>−0.15</td><td>−22°</td><td>autumn leaves</td></tr>
</table>
<div class="row"><figure><img src="img/variants.png"><figcaption>The variants on the game's leaf 1, gold, from below (lit through
by the sun above), three-quarter from above, from the side, and against the light. From below they all look alike: from the
windows, which look out and a little up, bending shows mostly as light changing across the blade and as blades breaking the level
line, not as a new outline.</figcaption></figure></div>

<h3>4.1 Meshes</h3>
<div class="row"><figure><img src="img/meshes.png"><figcaption>The game's card and three fans that hug the outline (one ray along
each lobe and one down the stalk, the widest gaps halved; rings out along the rays; a thin strip for the stalk's top). "Covers":
the share of the mesh the blade fills; the rest is cut by alpha and costs fragments for nothing. Averaged over the eight leaves:
card 27 %, fan 8 × 2: 45 %, 12 × 2: 53 %, 16 × 3: 58 %.</figcaption></figure></div>
<div class="row"><figure><img src="img/tiers.png"><figcaption>"sag + twist" on each mesh. The card cut in four rows (one at the foot)
can only bend along its midrib (the lobes' mean angle) and twist; the lower lobes stay in plane. Fan 8 × 2 already looks like the
finer fans at the window's distance.</figcaption></figure></div>

<h2>5. Proposed way to draw them</h2>
<ol>
<li><b>Templates at startup.</b> One fan mesh per tier (its vertices in the leaf's frame and their atlas texel), bent into K = 6
templates (the variants above at full amount), each vertex's offset and normal kept: 6 × 21 × 6 floats, about 3 KB, a uniform
buffer or constants in the shader. The index list is shared.</li>
<li><b>Per leaf, at growth</b> (<code>add_cards</code>): a template, an amount 0..1 and a twist −1..1, packed with the atlas kind
into <code>Card</code>'s <code>face.w</code> (kind 3 bits, template 3, amount 6, twist 6: 18 bits, exact in an f32). The card
stays 4 vec4s.</li>
<li><b>In <code>TREE_LEAF_VERT</code></b>: the vertex is <code>mix(flat, template, amount)</code>, turned about the midrib by the
twist times its distance up the blade, then placed as now (<code>across</code>, <code>along</code>, <code>face</code>, size and
width); the normal is mixed the same way and normalized. Drawn with <code>gfx::draw_indexed_instanced</code> over the fan's indices
(the pieces already draw that way) in place of <code>draw_instanced(6, …)</code>. <code>TREE_FLUTTER</code> turns the bent leaf
about its stalk as now; <code>tree_leaf_move</code> moves it by its middle as now.</li>
<li><b>The rule</b>, per leaf, from the evidence:
<table>
<tr><th>Choice</th><th>Rule</th><th>Why</th></tr>
<tr><td>blade tilt</td><td>drawn from the measured histogram for its height in the crown (top, middle, bottom) and the season (summer,
September; October for late autumn), in place of today's <code>roll_ball * 0.9</code></td><td>Raabe 2015 data</td></tr>
<tr><td>flat</td><td>what is left, about half</td><td>planophile</td></tr>
<tr><td>cup up</td><td>chance 0.10 + 0.10 × exposure</td><td>beech sun leaves fold more; sun photo</td></tr>
<tr><td>sag (droop, edges down, lobe tips, sag + twist)</td><td>chance 0.15 + 0.15 × autumn + 0.25 × (size / mean − 1) + 0.2 × shade</td><td>shade
leaves thinner and larger; old leaves steepen; photos</td></tr>
<tr><td>amount</td><td>0.3..1 at random, a few degrees of noise on every lobe, twist's sign at random</td><td>no two alike</td></tr>
</table>
"Exposure" and "shade" are what <code>add_cards</code> already has (<code>outer</code>, <code>height_share</code>,
<code>deep</code>); "autumn" follows the leaf's tint past gold.</li>
<li><b>The shadow</b> (<code>keep_leaf</code>): a bent leaf's outline seen by the sun is a little shorter; each template's
foreshortening can scale <code>tip</code> and <code>side</code>. Small; optional. <code>shaders/light.goose</code> and
<code>WIND_FN</code> need no change.</li>
</ol>
<h3>5.1 Cost</h3>
<p>About 26 500 leaves are drawn after culling (the dumps in <code>../branches/dump</code>; <code>MAX_CARDS</code> is 160 000).</p>
<table>
<tr><th>Tier</th><th>Mesh</th><th>vertices</th><th>triangles</th><th>blade covers</th><th>vertices a frame</th><th>triangles a frame</th><th>alpha-cut area against now</th></tr>
<tr><td>phone</td><td>card, flat (now)</td><td class="n">4 (6 drawn)</td><td class="n">2</td><td class="n">27 %</td><td class="n">159 k</td><td class="n">53 k</td><td class="n">1.0</td></tr>
<tr><td>standard (tablet)</td><td>card in 4 rows, midrib bend and twist</td><td class="n">10</td><td class="n">8</td><td class="n">27 %</td><td class="n">265 k</td><td class="n">212 k</td><td class="n">1.0</td></tr>
<tr><td>high</td><td>fan 8 × 2</td><td class="n">21</td><td class="n">26</td><td class="n">45 %</td><td class="n">557 k</td><td class="n">689 k</td><td class="n">0.6</td></tr>
<tr><td>(not needed)</td><td>fan 12 × 2</td><td class="n">29</td><td class="n">38</td><td class="n">53 %</td><td class="n">769 k</td><td class="n">1.0 M</td><td class="n">0.51</td></tr>
<tr><td>(not needed)</td><td>fan 16 × 3</td><td class="n">53</td><td class="n">82</td><td class="n">58 %</td><td class="n">1.4 M</td><td class="n">2.2 M</td><td class="n">0.46</td></tr>
</table>
<p>Vertices a frame count each unique vertex once (indexed, with the post-transform cache). These are counts, not times: the tablet
is already at about 27-32 ms a frame with the tree, so the standard tier's change must be measured there before it is kept, and the
flat fan (no bend, fewer cut fragments) is worth timing on its own as a possible gain.</p>

<h2>6. Open questions for the user</h2>
<ol>
<li>The data say the top's blades are the flattest in summer and the steepest in autumn. Which season is the game's tree, always
autumn, or does it follow <code>--tree-tint</code>? The tilt and sag rules follow that choice.</li>
<li>Task 117's criterion says "blades level and facing up within about 15°". Measured: half the summer top blades are within 15°,
86 % within 30°; in September only 27 % are within 15°. Change the criterion to "tilts drawn from the measured Norway maple
histogram by height and season"?</li>
<li>Should the inside of the crown (shade) sag more than the outside, as the shade photo and the thinner shade leaves suggest,
though nothing measures it in Norway maple?</li>
<li>Is the standard tier's midrib-only bend (card in 4 rows) worth its cost on the tablet, or should the tablet keep flat cards and
take only the new placement and tilts?</li>
<li>The mosaic step (blades nudged apart in plan) costs growth time: about n² per plate's neighbours. Keep it, or place by
Weisse's ratios alone (44 % overlap here, against 10 %)?</li>
</ol>
<h2>7. Sources</h2>
<ul>
<li>Raabe K, Pisek J, Sonnentag O, Annuk K (2015) Variations of leaf inclination angle distribution with height over the growing season and light exposure for eight broadleaf tree species. Agric For Meteorol 214-215:2-11. <a href="https://doi.org/10.1016/j.agrformet.2015.07.008">doi</a></li>
<li>Chianucci F, Pisek J, Raabe K, Marchino L, Ferrara C, Corona P (2018) A dataset of leaf inclination angles for temperate and boreal broadleaf woody species. Ann For Sci 75:50. <a href="https://doi.org/10.1007/s13595-018-0730-x">doi</a>, <a href="https://data.mendeley.com/datasets/4rmc7r8zvy/2">data</a> (copied to <code>src/lia-dataset_full.csv</code>)</li>
<li>Pisek J, Sonnentag O, Richardson AD, Mõttus M (2013) Is the spherical leaf inclination angle distribution a valid assumption for temperate and boreal broadleaf tree species? Agric For Meteorol 169:186-194. <a href="https://doi.org/10.1016/j.agrformet.2012.10.011">doi</a></li>
<li>Adamson K (2024) Applicability of digital photography in monitoring changes of leaf inclination and foliage clumping with time. PhD thesis, University of Tartu. <a href="https://dspace.ut.ee/bitstreams/6db24ff9-e2f7-4186-8028-6e5edc4bdd68/download">pdf</a></li>
<li>Fleck S, Niinemets Ü, Cescatti A, Tenhunen JD (2003) Three-dimensional lamina architecture alters light-harvesting efficiency in Fagus: a leaf-scale analysis. Tree Physiol 23:577-589. <a href="https://doi.org/10.1093/treephys/23.9.577">doi</a></li>
<li>Chambelland JC et al. (2008) A double-digitising method for building 3D virtual trees with non-planar leaves: application to the morphology and light-capture properties of young beech trees. Funct Plant Biol 35:1059-1069. <a href="https://doi.org/10.1071/FP08051">doi</a></li>
<li>Niinemets Ü, Fleck S (2002) Petiole mechanics, leaf inclination, morphology, and investment in support in relation to light availability in the canopy of Liriodendron tulipifera. Oecologia 132:21-33. <a href="https://doi.org/10.1007/s00442-002-0902-z">doi</a></li>
<li>Niinemets Ü (1998) Adjustment of foliage structure and function to a canopy light gradient in two co-existing deciduous trees. Variability in leaf inclination angles in relation to petiole morphology. Trees 12:446-451. <a href="https://doi.org/10.1007/s004680050173">doi</a></li>
<li>Niinemets Ü (1996) Importance of structural features of leaves and canopy in determining species shade-tolerance in temperate deciduous woody taxa. PhD thesis, University of Tartu. <a href="https://dspace.ut.ee/bitstreams/90022290-cc8e-4e60-8ad8-f9b13d40edab/download">pdf</a></li>
<li>Weisse A (1895) Zur Kenntniss der Anisophyllie von Acer platanoides. Ber Dtsch Bot Ges 13:376-389. <a href="https://www.zobodat.at/pdf/Ber-Deutschen-Bot-Ges_13_0376-0389.pdf">pdf</a></li>
<li>Junttila S et al. (2022) Tree water status affects tree branch position. Forests 13:728. <a href="https://doi.org/10.3390/f13050728">doi</a></li>
<li>Louf JF et al. (2018) How wind drives the correlation between leaf shape and mechanical properties. Sci Rep 8:16314. <a href="https://doi.org/10.1038/s41598-018-34588-0">doi</a> (stalks bend about 4 times harder than they twist; not about droop)</li>
<li>The gravity brief in <code>../../tree-gravity/tree-gravity-brief.md</code> (section 2) and Stava et al. 2014 (<code>spkcmdb-ipmot-14.pdf</code>, about branches, not leaves).</li>
</ul>
</body></html>
'''
open(os.path.join(ROOT, 'index.html'), 'w', encoding='utf8').write(html)
print('ok')
