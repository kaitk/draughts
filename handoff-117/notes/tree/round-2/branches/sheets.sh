# Task 117 round two: the dumps and sheets (run from the checkout with build/tree_dump.exe).
S=C:/Users/kait/AppData/Local/Temp/claude/a30c35c551b90e0d/a0157c15-c8bd-4f2c-90d8-4251671e8887/scratchpad
N=C:/Users/kait/projects/draughts/build/notes/tree; P=$N/branches/img; O=$N/round-2/branches
T=build/tree_dump.exe
E="--elbows 1,2,30,50 --elbow-plane 1"
A=$S/a; mkdir -p $A/g $A/a110g $A/a90g $A/a60g
$T $A/g --hangs 1 $E --gravity 1 >/dev/null
$T $A/a110g --hangs 1 $E --gravity 1 --limb-angle 1,110,80 >/dev/null
$T $A/a90g --hangs 1 $E --gravity 1 --limb-angle 1,90,90 >/dev/null
$T $A/a60g --hangs 1 $E --gravity 1 --limb-angle 1,90,60 >/dev/null
python $S/src/sheet.py $O/limb-angle.jpg "The limbs' angle off the trunk, Sapling's down angle (elbows 1-2 up and down, gravity 1)" $P/photo-whole.jpg front,side "Whole.limbs 62-28=$A/g" "aspen 110,80=$A/a110g" "japanese maple 90,90=$A/a90g" "90,60=$A/a60g"
H=$S/h; mkdir -p $H/0 $H/1 $H/2 $H/3
B="$E --gravity 1 --limb-angle 1,90,90"
$T $H/0 --hangs 1 $B >/dev/null
$T $H/1 --hangs 1 $B --hanging-twigs 1,-1.5,0.45,0.3 >/dev/null
$T $H/2 --hangs 1 $B --hanging-twigs 1,-3,0.45,0.3 >/dev/null
$T $H/3 --hangs 1 $B --hanging-twigs 1,-3,0.45,0 >/dev/null
python $S/src/sheet.py $O/hanging-twigs.jpg "Hanging twigs under level wood: Weber and Penn's AttractionUp by ez-tree's radius (elbows 1-2 up and down, gravity 1, limbs 90,90)" $P/photo-fan.jpg,$P/photo-limbs.jpg front,limb,fan "none=$H/0" "-1.5, offspring 0.3=$H/1" "-3, offspring 0.3=$H/2" "-3, offspring 0=$H/3"
D=$S/n; mkdir -p $D/old $D/r $D/s4
L="$B --hanging-twigs 1,-3,0.45,0 --tilt 1,2,8 --bend 1,25"
$T $D/old --hangs 1 $L --shed 0.45,0.5 --plates 1,2,1 | head -2
$T $D/s4 --hangs 1 $L --shed 0.45,0.5 --plates 1,4,1 | head -2
$T $D/r --hangs 1 $L --shed 0.3,0.5 --plates 1,3,1 | head -2
python $S/src/sheet.py $O/density.jpg "Density: shedding and short shoots (all of round two on, October)" $N/photos/tartu-maple-1.jpg,$N/photos/user-maple-gold.png leafy,crown "before step one=$S/d-off" "shed 0.45, spurs 2 (step two)=$D/old" "shed 0.45, spurs 4=$D/s4" "shed 0.3, spurs 3=$D/r"
