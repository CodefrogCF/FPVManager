import json,struct,io,sys
import numpy as np
import vtk
from vtk.util.numpy_support import numpy_to_vtk,numpy_to_vtkIdTypeArray
from PIL import Image
from pathlib import Path
from build_collision import AXIS

def load(path,renderer):
 raw=Path(path).read_bytes();n=struct.unpack_from('<I',raw,12)[0];d=json.loads(raw[20:20+n]);buf=raw[28+n:]
 def get(i):
  a=d['accessors'][i];b=d['bufferViews'][a['bufferView']];dt=np.dtype({5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]);w={'SCALAR':1,'VEC3':3,'VEC2':2}[a['type']];return np.ndarray((a['count'],w),dtype=dt,buffer=buf,offset=b.get('byteOffset',0)+a.get('byteOffset',0),strides=(b.get('byteStride',w*dt.itemsize),dt.itemsize)).copy()
 textures=[]
 for tex in d['textures']:
  im=d['images'][tex['source']];b=d['bufferViews'][im['bufferView']];o=b['byteOffset'];img=np.array(Image.open(io.BytesIO(buf[o:o+b['byteLength']])).convert('RGB'))[::-1].copy();h,w=img.shape[:2];vd=vtk.vtkImageData();vd.SetDimensions(w,h,1);vd.GetPointData().SetScalars(numpy_to_vtk(img.reshape(-1,3),deep=True));tx=vtk.vtkTexture();tx.SetInputData(vd);tx.InterpolateOn();tx.RepeatOn();tx.MipmapOn();textures.append(tx)
 def walk(i,M):
  no=d['nodes'][i];M=M@np.asarray(no.get('matrix',np.eye(4).ravel().tolist())).reshape(4,4,order='F')
  if 'mesh'in no:
   for p in d['meshes'][no['mesh']]['primitives']:
    pos=((get(p['attributes']['POSITION'])@M[:3,:3].T+M[:3,3])@AXIS.T).astype('f4');nor=(get(p['attributes']['NORMAL'])@M[:3,:3].T@AXIS.T).astype('f4');uv=get(p['attributes']['TEXCOORD_0']);uv[:,1]=1-uv[:,1];t=get(p['indices']).ravel().astype('int64');pts=vtk.vtkPoints();pts.SetData(numpy_to_vtk(pos,deep=True));cells=vtk.vtkCellArray();cells.SetData(numpy_to_vtkIdTypeArray(np.arange(0,len(t)+1,3,dtype='int64'),deep=True),numpy_to_vtkIdTypeArray(t,deep=True));poly=vtk.vtkPolyData();poly.SetPoints(pts);poly.SetPolys(cells);poly.GetPointData().SetNormals(numpy_to_vtk(nor,deep=True));poly.GetPointData().SetTCoords(numpy_to_vtk(uv,deep=True));ma=vtk.vtkPolyDataMapper();ma.SetInputData(poly);actor=vtk.vtkActor();actor.SetMapper(ma);mat=d['materials'][p['material']];actor.SetTexture(textures[mat['pbrMetallicRoughness']['baseColorTexture']['index']]);pr=actor.GetProperty();pr.SetInterpolationToPhong();pr.SetBackfaceCulling(False)
    if 'KHR_materials_unlit' in mat.get('extensions',{}):pr.LightingOff()
    else:pr.SetAmbient(.43);pr.SetDiffuse(.57);pr.SetSpecular(.04)
    renderer.AddActor(actor)
  for ch in no.get('children',[]):walk(ch,M)
 for i in d['scenes'][d.get('scene',0)]['nodes']:walk(i,np.eye(4))

def do(path,views):
 renderer=vtk.vtkRenderer();renderer.SetBackground(.13,.16,.20);win=vtk.vtkRenderWindow();win.SetOffScreenRendering(1);win.AddRenderer(renderer);win.SetSize(1100,760);win.SetMultiSamples(0);load(path,renderer);renderer.AutomaticLightCreationOff();
 for pos,intensity in [((5,-8,12),.9),((-8,12,6),.4)]:
  l=vtk.vtkLight();l.SetLightTypeToSceneLight();l.SetPosition(*pos);l.SetFocalPoint(0,0,-1);l.SetIntensity(intensity);renderer.AddLight(l)
 cam=renderer.GetActiveCamera()
 for name,eye,target,up,fov in views:
  cam.SetPosition(*eye);cam.SetFocalPoint(*target);cam.SetViewUp(*up);cam.SetViewAngle(fov);cam.SetClippingRange(.015,100);win.Render();wf=vtk.vtkWindowToImageFilter();wf.SetInput(win);wf.ReadFrontBufferOff();wf.Update();wr=vtk.vtkPNGWriter();wr.SetFileName(name);wr.SetInputConnection(wf.GetOutputPort());wr.Write();print(name,flush=True)
 win.Finalize()

if __name__=='__main__':
 path=sys.argv[1];prefix=sys.argv[2];v=[(prefix+'_overview.png',(15,-21,15),(0,0,-1),(0,0,1),39)]
 if prefix.endswith('r2'):
  v += [(prefix+'_hall.png',(-4.77,-1.56,-1.48),(2.5,-1.56,-1.18),(0,0,1),70),(prefix+'_vault.png',(-3.08,-5.95,-1.46),(.35,-5.95,-.95),(0,0,1),77),(prefix+'_chimney.png',(-1.12,1.958,-1.35),(-.367,1.958,-1.65),(0,0,1),69),(prefix+'_chimney_inside.png',(-.367,1.958,-1.75),(-.365,1.958,.5),(0,1,0),65),(prefix+'_frame.png',(1.45,3.15,-.9),(1.45,3.9,-1.1),(0,0,1),64),(prefix+'_factory_frame.png',(3.65,1.77,-.27),(4.89,2.03,-1.45),(0,0,1),65)]
 do(path,v)
