'use strict';
(async()=>{
 const $=id=>document.getElementById(id), status=$('status');
 try{
  const C=Cesium,A=FPVSceneryAlignment;
  const r=await fetch('report.json');if(!r.ok)throw Error('report.json '+r.status);const report=await r.json();
  // Both meshes are in the exact same model coordinate frame. Height is an
  // arbitrary reference for the isolated comparison; do not use for navigation.
  const cfg={...report.alignment,ellipsoidHeightM:100,opacity:1};
  const viewer=new C.Viewer('scene',{baseLayer:false,baseLayerPicker:false,geocoder:false,animation:false,timeline:false,homeButton:false,sceneModePicker:false,navigationHelpButton:false,fullscreenButton:false});
  viewer.scene.globe.show=false;viewer.scene.backgroundColor=C.Color.fromCssColorString('#18212b');viewer.scene.skyAtmosphere.show=false;
  const modelMatrix=A.modelMatrix(C,cfg);
  async function load(url){const model=await C.Model.fromGltfAsync({url,modelMatrix,scale:cfg.scale,allowPicking:false,enableCollision:false});viewer.scene.primitives.add(model);return model;}
  const [scan,dgm]=await Promise.all([load('../../../web/assets/scenery/local_reference.glb'),load('dgm_reference.glb')]);
  const target=C.Cartesian3.fromDegrees(cfg.longitude,cfg.latitude,cfg.ellipsoidHeightM);
  const view=(pitch,range)=>viewer.camera.lookAt(target,new C.HeadingPitchRange(0,C.Math.toRadians(pitch),range));
  $('top').onclick=()=>view(-90,480);$('oblique').onclick=()=>view(-35,520);view(-50,520);
  function sync(){scan.show=$('scan').checked;dgm.show=$('dgm').checked;scan.color=new C.Color(1,1,1,Number($('alpha').value));viewer.scene.requestRender();}
  for(const id of ['scan','dgm','alpha'])$(id).addEventListener('input',sync);sync();
  const start=performance.now();function check(){if(scan.ready&&dgm.ready){status.textContent='SUCCESS · Beide Referenzmodelle geladen.\nKein Terrain-Ersatz aktiv.';return;}if(performance.now()-start>60000){status.textContent='Zeitüberschreitung: Modell noch nicht bereit.';return;}requestAnimationFrame(check);}check();
 }catch(e){status.textContent='FEHLER: '+String(e?.message||e);console.error(e);}
})();
