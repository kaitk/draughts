# Task 117 round two: the light tuner's shots, run from the checkout's tools/.
S=C:/Users/kait/AppData/Local/Temp/claude/a30c35c551b90e0d/a0157c15-c8bd-4f2c-90d8-4251671e8887/scratchpad
X=../build/windows/light_tune.exe
V="--tree-draw all --size 1600x1000"
UP="--plan-eye 4.25,5.9,1.5 --plan-at 4.3,12,4.5"
OLD="--tree-elbows 1,2,30,50 --tree-gravity 1 --tree-shed 0.45,0.5 --tree-plates 1,2,1 --tree-tilt 1,2,8 --tree-bend 1,25"
NEW="--tree-elbows 1,2,30,50 --tree-gravity 1 --tree-shed 0.3,0.5 --tree-plates 1,3,1 --tree-tilt 1,2,8 --tree-bend 1,25 --tree-elbow-plane 1 --tree-limb-angle 1,90,90 --tree-hanging-twigs 1,-3,0.45,0"
shot() { out=$1; shift; GOOSE_GFX_HEADLESS=1 timeout 120 $X $V "$@" --shot $S/app/$out.png > $S/app/$out.txt 2>&1; }
shot up-off $UP
shot up-old $UP $OLD
shot up-new $UP $NEW
shot win-old $UP $OLD --season winter
shot win-new $UP $NEW --season winter
shot tw-off --view table-window
shot tw-old --view table-window $OLD
shot tw-new --view table-window $NEW
