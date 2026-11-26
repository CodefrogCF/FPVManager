'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {browser,runPage}=require('./support/scenery_browser.cjs'),repo=path.resolve(__dirname,'../..');
for(const {mobile,controlledFrames}of [{mobile:false},{mobile:true},{mobile:true,controlledFrames:true}])test('real Cesium editor supports numeric, mouse/touch, controls, views, selection and cancellation'+(mobile?' on a mobile viewport':'')+(controlledFrames?' with delayed frames and covered handles':''),
 {skip:browser?false:'Install Chromium or set FPV_CHROME',timeout:60000},async()=>{
 const server=http.createServer((req,res)=>{const name=new URL(req.url,'http://localhost').pathname,file=path.resolve(repo,'.'+decodeURIComponent(name));if(!file.startsWith(repo+path.sep)){res.writeHead(403).end();return;}
  fs.readFile(file,(error,data)=>{if(error){res.writeHead(404).end();return;}res.setHeader('Content-Type',name.endsWith('.js')?'application/javascript':name.endsWith('.css')?'text/css':name.endsWith('.wasm')?'application/wasm':name.endsWith('.png')?'image/png':'text/html');res.end(data);});});
 try{await new Promise(r=>server.listen(0,'127.0.0.1',r));const result=await runPage('http://127.0.0.1:'+server.address().port+'/test/web/scenery_editor_smoke.html'+(controlledFrames?'?manualFrames=1&coverHandle=1':''),{windowSize:mobile?{width:390,height:844}:undefined});assert.equal(result.status,'pass',JSON.stringify(result));assert.ok(result.checks.length>=25);if(controlledFrames){assert.equal(result.controlledFrames,true);assert.ok(result.checks.includes('a real GPU primitive overlaps the north handle'));}if(mobile){assert.equal(result.viewport.width,390);assert.ok(result.checks.some(x=>x.startsWith('mobile panel')));}console.log('Alignment browser:',JSON.stringify(result));}
 finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
});
