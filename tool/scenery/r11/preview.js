'use strict';
(async()=>{
 const $=id=>document.getElementById(id),label=$('status');
 try{
  const C=Cesium,A=FPVSceneryAlignment;
  const r=await fetch('underlay_report.json',{cache:'no-store'});if(!r.ok)throw Error('R11 report HTTP '+r.status);
  const report=await r.json(),root=report.terrainGroundRootEllipsoidM;
  const cfg={...report.alignment,ellipsoidHeightM:root,opacity:1};
  const viewer=new C.Viewer('scene',{baseLayer:false,baseLayerPicker:false,geocoder:false,animation:false,timeline:false,homeButton:false,sceneModePicker:false,navigationHelpButton:false,fullscreenButton:false});
  viewer.scene.globe.show=false;viewer.scene.skyAtmosphere.show=false;viewer.scene.backgroundColor=C.Color.fromCssColorString('#18212b');
  const matrix=A.modelMatrix(C,cfg);
  async function add(url){const model=await C.Model.fromGltfAsync({url,modelMatrix:matrix,scale:cfg.scale,enableCollision:false,allowPicking:false});viewer.scene.primitives.add(model);return model;}
  const [scan,ground]=await Promise.all([add('../../../web/assets/scenery/local_reference.glb'),add('../../../web/assets/scenery/ruedersdorf_r11_ground.glb')]);
  const target=C.Cartesian3.fromDegrees(cfg.longitude,cfg.latitude,report.terrainAnchorEllipsoidM);
  function view(pitch,range){viewer.camera.lookAt(target,new C.HeadingPitchRange(0,C.Math.toRadians(pitch),range));}
  $('top').onclick=()=>view(-90,440);$('oblique').onclick=()=>view(-43,510);view(-43,510);
  function sync(){scan.show=$('scan').checked;ground.show=$('dgm').checked;scan.color=new C.Color(1,1,1,Number($('alpha').value));viewer.scene.requestRender();}
  for(const x of ['scan','dgm','alpha'])$(x).addEventListener('input',sync);sync();
  const start=performance.now();(function ready(){if(scan.ready&&ground.ready){label.textContent='Beide Modelle bereit · '+report.geometry.triangles.toLocaleString('de-DE')+' zusätzliche DGM-Dreiecke · reine lokale Vorschau, ohne Geländeersatz';return;}
   if(performance.now()-start>60000){label.textContent='Zeitüberschreitung beim Laden der GLB-Dateien';return;}requestAnimationFrame(ready);
  })();
 }catch(error){label.textContent='FEHLER: '+String(error?.message||error);console.error(error);}
})();
