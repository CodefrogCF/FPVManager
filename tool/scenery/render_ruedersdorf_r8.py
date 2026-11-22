#!/usr/bin/env python3
"""Render a true orthographic model view, then overlay the certified XY coverage."""
import sys,json
from pathlib import Path
import numpy as np
from PIL import Image
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import vtk
from vtk.util.numpy_support import vtk_to_numpy
from render_ruedersdorf_r3 import load

def render(p):
    renderer=vtk.vtkRenderer();renderer.SetBackground(.12,.14,.17);win=vtk.vtkRenderWindow();win.SetOffScreenRendering(1);win.AddRenderer(renderer);win.SetSize(1200,1200);win.SetMultiSamples(0);load(p,renderer);renderer.AutomaticLightCreationOff()
    for position,intensity in [((5,-8,12),.9),((-8,12,6),.4)]:
        l=vtk.vtkLight();l.SetLightTypeToSceneLight();l.SetPosition(*position);l.SetFocalPoint(0,0,-1);l.SetIntensity(intensity);renderer.AddLight(l)
    cam=renderer.GetActiveCamera();cam.SetPosition(0,0,30);cam.SetFocalPoint(0,0,0);cam.SetViewUp(0,1,0);cam.ParallelProjectionOn();cam.SetParallelScale(9.3);cam.SetClippingRange(.1,80);win.Render();w=vtk.vtkWindowToImageFilter();w.SetInput(win);w.ReadFrontBufferOff();w.Update();im=vtk_to_numpy(w.GetOutput().GetPointData().GetScalars()).reshape(1200,1200,-1)[::-1].copy();win.Finalize();return im

if __name__=='__main__':
    glb,report,dst=sys.argv[1:];r=json.loads(Path(report).read_text());im=render(glb);fig,ax=plt.subplots(figsize=(10,10),facecolor='#18212a');ax.imshow(im,extent=[-9.3,9.3,-9.3,9.3]);
    for i,c in enumerate(r['terrain_certificates']):
        x,y,X,Y=c['localBounds'];ax.add_patch(Rectangle((x,y),X-x,Y-y,facecolor='#5ee0a3',alpha=.24,edgecolor='#9df6c8',lw=1.2));ax.text((x+X)/2,(y+Y)/2,str(i+1),color='white',fontsize=9,weight='bold',ha='center',va='center',bbox=dict(facecolor='#204b38',edgecolor='none',pad=1.5,alpha=.85))
    ax.set_xlim(-9,9);ax.set_ylim(-8.8,8.8);ax.set_title('R8 · Geometrisch belegte Boden-Ersatzflächen',color='white',fontsize=17,weight='bold',pad=14);ax.set_xlabel('Lokale Modellkoordinaten (1 Einheit ≈ 16,02 m)',color='#dce4eb');ax.set_ylabel('Lokale Modellkoordinaten',color='#dce4eb');ax.tick_params(colors='#dce4eb');fig.text(.5,.03,'16 Flächen · 8.035 m² Vereinigungsfläche · Live-Höhenprüfung vor Aktivierung erforderlich',ha='center',fontsize=11,color='white');fig.subplots_adjust(left=.10,right=.98,top=.92,bottom=.10);fig.savefig(dst,dpi=140,facecolor=fig.get_facecolor());plt.close(fig)
