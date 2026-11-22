'use strict';
(async()=>{
 const $=id=>document.getElementById(id),status=$('status');
 try{
  const C=Cesium,A=FPVSceneryAlignment;
  const r=await fetch('height_calibration.json',{cache:'no-store'});if(!r.ok)throw Error('height_calibration.json '+r.status);
  const report=await r.json(),a=report.anchor;
  const rr=await fetch('../r9/report.json',{cache:'no-store'});if(!rr.ok)throw Error('R9 report.json '+rr.status);
  const base=(await rr.json()).alignment;
  const cfg={...base,ellipsoidHeightM:a.model_root_ellipsoid_m,opacity:1};
  const viewer=new C.Viewer('scene',{baseLayer:false,baseLayerPicker:false,geocoder:false,animation:false,timeline:false,homeButton:false,sceneModePicker:false,navigationHelpButton:false,fullscreenButton:false});
  viewer.scene.globe.show=false;viewer.scene.backgroundColor=C.Color.fromCssColorString('#18212b');viewer.scene.skyAtmosphere.show=false;
  const modelMatrix=A.modelMatrix(C,cfg);
  async function load(url){const m=await C.Model.fromGltfAsync({url,modelMatrix,scale:cfg.scale,allowPicking:false,enableCollision:false});viewer.scene.primitives.add(m);return m;}
  const [scan,dgm]=await Promise.all([load('../../../web/assets/scenery/local_reference.glb'),load('dgm_ellipsoid_reference.glb')]);
  const target=C.Cartesian3.fromDegrees(a.longitude,a.latitude,a.terrain_ellipsoid_m);
  const view=(pitch,range)=>viewer.camera.lookAt(target,new C.HeadingPitchRange(0,C.Math.toRadians(pitch),range));
  $('top').onclick=()=>view(-90,460);$('oblique').onclick=()=>view(-40,520);view(-45,520);
  function sync(){scan.show=$('scan').checked;dgm.show=$('dgm').checked;scan.color=new C.Color(1,1,1,Number($('alpha').value));viewer.scene.requestRender();}
  for(const id of ['scan','dgm','alpha'])$(id).addEventListener('input',sync);sync();
  const start=performance.now();function check(){if(scan.ready&&dgm.ready){status.textContent='Beide Referenzmodelle bereit. NHN: '+a.dgm_nhn_m.toFixed(3)+' m · GCG: '+a.gcg2016_anomaly_m.toFixed(3)+' m · Ellipsoid: '+a.terrain_ellipsoid_m.toFixed(3)+' m\nKeine Änderung an produktiver Modellposition oder Terrain-Maske.';return;}if(performance.now()-start>60000){status.textContent='Zeitüberschreitung: Modell nicht bereit.';return;}requestAnimationFrame(check);}check();
 }catch(e){status.textContent='FEHLER: '+String(e?.message||e);console.error(e);}
})();
