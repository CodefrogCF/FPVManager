// Explicit local smoke fixture only; production fetch behavior is unchanged.
(()=>{
 const original=window.fetch.bind(window),live=new URLSearchParams(location.search).has('liveLabels');
 window.fixtureLabelCalls=0;window.fixtureLabelsFail=false;
 window.fetch=(input,options)=>{
  const address=String(input);
  if(!address.startsWith('https://api3.geo.admin.ch/rest/services/ech/MapServer/identify?'))return original(input,options);
  window.fixtureLabelCalls++;
  if(window.fixtureLabelsFail)return Promise.resolve(new Response('',{status:503}));
  if(live)return original(input,options);
  const street=address.includes('amtliches-strassenverzeichnis'),layer=street?'ch.swisstopo.amtliches-strassenverzeichnis':'ch.swisstopo.swissnames3d';
  const values=street?[[7.4397,46.9485,'Bahnhofplatz'],[7.443,46.9473,'Bundesgasse']]:[[7.4416,46.9506,'Bern'],[7.445,46.953,'Altenberg']];
  return Promise.resolve(new Response(JSON.stringify({results:values.map(([lon,lat,text],i)=>({featureId:i,layerBodId:layer,
   geometry:{type:'Point',coordinates:[lon,lat]},properties:street?{stn_label:text,str_status:'bestehend'}:{name:text,objektklasse:'TLM_SIEDLUNGSNAME',objektart:'Ort'}}))}),{headers:{'content-type':'application/json'}}));
 };
})();
