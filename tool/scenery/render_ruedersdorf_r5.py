import sys
from render_ruedersdorf_r3 import do
p,prefix=sys.argv[1:3]
views=[(prefix+'_tank_overview.png',(-4.94,-1.59,-.62),(-.2,-1.59,-1.66),(0,0,1),70),(prefix+'_tank_ground.png',(-3.78,-1.53,-1.68),(-1.45,-1.54,-1.25),(0,0,1),73),(prefix+'_back.png',(.1,.35,-.10),(.1,-1.59,-1.25),(0,0,1),88),(prefix+'_hall.png',(-1.2,-1.35,-1.55),(-4.8,-1.59,-.9),(0,0,1),73)]
do(p,views)
