#!/usr/bin/env node
// Explicit live integration probe; regular regressions use synthetic providers.
'use strict';
const fs=require('node:fs'),path=require('node:path'),http=require('node:http');
const {runPage}=require('../../test/js/support/scenery_browser.cjs');
const repo=path.resolve(__dirname,'../..');
const args=new Map(process.argv.slice(2).map(arg=>{const i=arg.indexOf('=');return i<0?[arg,true]:[arg.slice(0,i),arg.slice(i+1)];}));
const endpoint=args.get('--url')||'https://isk.geobasis-bb.de/geodienste/lgb/3d_sentinel/3dmeshes/tileset.json';
if(new URL(endpoint).protocol!=='https:')throw Error('Use an HTTPS tileset endpoint');
const server=http.createServer((req,res)=>{
 const name=new URL(req.url,'http://localhost').pathname,file=path.resolve(repo,'.'+decodeURIComponent(name));
 if(!file.startsWith(repo+path.sep)){res.writeHead(403).end();return;}
 fs.readFile(file,(error,data)=>{if(error){res.writeHead(404).end();return;}res.setHeader('Content-Type',name.endsWith('.js')?'application/javascript':name.endsWith('.wasm')?'application/wasm':name.endsWith('.png')?'image/png':'text/html');res.end(data);});
});
(async()=>{
 try{
  await new Promise(r=>server.listen(0,'127.0.0.1',r));
  const query=new URLSearchParams({url:endpoint,longitude:args.get('--longitude')||'13.05',latitude:args.get('--latitude')||'52.4'});
  const result=await runPage('http://127.0.0.1:'+server.address().port+'/test/web/scenery_tileset_smoke.html?'+query,{timeoutMs:60000});
  console.log(JSON.stringify(result,null,2));if(result.status!=='pass')process.exitCode=1;
 }finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
})().catch(error=>{console.error(error);process.exitCode=1;});
