import sys
from render_ruedersdorf_r3 import do
p,prefix=sys.argv[1:3]
views=[(prefix+'_overview.png',(12,-13,11),(0,0,-1),(0,0,1),45),(prefix+'_vault_gable.png',(2.55,-7.55,.1),(-1.0,-5.94,-1.1),(0,0,1),59),(prefix+'_vault_inside.png',(-3.10,-5.94,-1.61),(.30,-5.94,-.8),(0,0,1),75),(prefix+'_silo.png',(1.45,8.0,.25),(1.4,3.86,-1.19),(0,0,1),54),(prefix+'_east.png',(7.6,3.45,-.20),(4.85,2.03,-1.45),(0,0,1),58),(prefix+'_west.png',(-3.5,.0,-.15),(-3.45,2.60,-1.3),(0,0,1),65),(prefix+'_gangway.png',(3.45,-3.12,.20),(3.72,-1.58,-.46),(0,0,1),57),(prefix+'_gangway_top.png',(3.7,-1.58,1.25),(3.7,-1.58,-.5),(0,1,0),47),(prefix+'_six_gallery.png',(6.5,-4.2,.5),(4.5,-1.2,-.8),(0,0,1),58)]
do(p,views)
