#!/usr/bin/env python3
"""Silo stair model-specific collision/geometry regression checks."""
import json,struct,sys,hashlib
from pathlib import Path
import numpy as np
from build_collision import read_glb
from refine_ruedersdorf_r13 import get_accessor

S=16.023268178233355
R=.25/S


def cylinder_contacts(path,xy,zrange=(-1.98,-.02),radius=R):
    """Does an infinite line cylinder at XY intersect triangle faces in zrange?"""
    v,t=read_glb(path)
    p=v[t]
    center=np.asarray(xy,float)
    # Bounding box prefilter, with 25cm clearance.
    lo=p.min(axis=1);hi=p.max(axis=1)
    ok=(hi[:,2]>=zrange[0])&(lo[:,2]<=zrange[1])&(hi[:,0]>=center[0]-radius)&(lo[:,0]<=center[0]+radius)&(hi[:,1]>=center[1]-radius)&(lo[:,1]<=center[1]+radius)
    p=p[ok,:,:2].astype('f8')
    # Point-in-2D-triangle or distance to segment <= collision radius.
    a=p[:,0];b=p[:,1];c=p[:,2]
    ab=b-a;ac=c-a;ap=center-a
    d=ab[:,0]*ac[:,1]-ab[:,1]*ac[:,0]
    u=(ap[:,0]*ac[:,1]-ap[:,1]*ac[:,0])/np.where(np.abs(d)<1e-12,1,d)
    w=(ab[:,0]*ap[:,1]-ab[:,1]*ap[:,0])/np.where(np.abs(d)<1e-12,1,d)
    inside=(np.abs(d)>1e-12)&(u>=0)&(w>=0)&(u+w<=1)
    touches=inside.copy()
    for start,end in ((a,b),(b,c),(c,a)):
        delta=end-start
        length=np.einsum('ij,ij->i',delta,delta)
        fraction=np.clip(np.einsum('ij,ij->i',center-start,delta)/np.where(length>1e-20,length,1),0,1)
        closest=start+fraction[:,None]*delta
        touches|=(np.sum((closest-center)**2,axis=1)<=radius**2)
    return int(np.sum(touches))


def full_roof_original(source):
    raw=Path(source).read_bytes();jlen=struct.unpack_from('<I',raw,12)[0]
    j=json.loads(raw[20:20+jlen]);b=memoryview(raw)[28+jlen:]
    # source exterior platform retains full R14 long-hall roof.
    part=next(m for m in j['meshes'] if m.get('name','').startswith('R12 reference'))
    # always check raw attribute buffer hash for R14 long hall and chimney.
    return j,b,part


def main(before,after,fpc,catalog):
    original,bb,omesh=full_roof_original(before)
    revised,nb,nmesh=full_roof_original(after)
    assert len(omesh['primitives'])==len(nmesh['primitives'])
    # Long hall top roof and chimney are untouched by this revision.
    orig_roof=omesh['primitives'][0];new_roof=nmesh['primitives'][0]
    for key in orig_roof['attributes']:
        assert np.array_equal(get_accessor(original,bb,orig_roof['attributes'][key]),get_accessor(revised,nb,new_roof['attributes'][key]))
    assert np.array_equal(get_accessor(original,bb,orig_roof['indices']),get_accessor(revised,nb,new_roof['indices']))
    hole=(4.79,-2.202)
    original_contacts=cylinder_contacts(before,hole,(-.5,-.02))
    corrected_contacts=cylinder_contacts(after,hole,(-1.98,-.02))
    # Roof slab blocked former vertical dive. Now entire column is open.
    assert original_contacts>0, original_contacts
    assert corrected_contacts==0,corrected_contacts
    # Roof ring should remain solid away from the opening.
    ring_contacts=cylinder_contacts(after,(4.15,-2.20),(-.28,-.20))
    assert ring_contacts>0,ring_contacts
    # A direct vertical line through the center of the stairwell is free,
    # but a line near the outer stair treads hits the actual stairs.
    stair_contacts=cylinder_contacts(after,(4.79,-2.251),(-1.9,-.5))
    assert stair_contacts>0,stair_contacts
    fpcdata=Path(fpc).read_bytes()
    _,nv,nt,nn=struct.unpack_from('<4sIII',fpcdata)
    v,t=read_glb(after)
    assert len(v)==nv
    assert nt==len(np.unique(np.sort(t,axis=1),axis=0))
    cat=json.loads(Path(catalog).read_text())
    obj=next(s for s in cat['sceneries'] if s['id']=='de-bb-ruedersdorf-chemical-plant')
    h=hashlib.sha256(fpcdata).hexdigest()
    assert obj['terrainCertificate']['collisionSha256']==h
    assert len(obj['terrainCertificates'])==16
    assert all(c['collisionSha256']==h for c in obj['terrainCertificates'])
    print(json.dumps({'original_roof_still_intact':True,'vertical_dive_clear':True,'original_vertical_blockers':original_contacts,
                      'new_vertical_blockers':corrected_contacts,'roof_ring_contacts':ring_contacts,
                      'stair_tread_contacts':stair_contacts,'collision_faces':nt,'fpc_sha256':h,'certificates':16},indent=2))

if __name__=='__main__':main(*sys.argv[1:])
