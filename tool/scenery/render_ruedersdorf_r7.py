import sys
from render_ruedersdorf_r3 import do
p,prefix=sys.argv[1:3]
do(p,[(prefix+'_east.png',(7.4,3.4,-.42),(4.85,2.03,-1.45),(0,0,1),50),(prefix+'_gallery.png',(6.5,-4.2,.5),(4.5,-1.2,-.8),(0,0,1),58),(prefix+'_vault.png',(-3.10,-5.94,-1.61),(.30,-5.94,-.8),(0,0,1),75),(prefix+'_courtyard.png',(-1,-.8,-.88),(-2.15,0,-2.03),(0,0,1),55)])
