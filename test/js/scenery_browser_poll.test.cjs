'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {pollPage}=require('./support/scenery_browser.cjs');
const url='http://127.0.0.1:12345/test',timeout=()=>Object.assign(Error('DevTools command timed out: Runtime.evaluate'),{code:'CDP_TIMEOUT'}),wrap=value=>({result:{value}});
function clock(){let t=0;return {now:()=>t,pause:async ms=>{t+=ms;},advance:ms=>{t+=ms;}};}
test('CDP status polling recovers after a bounded transient timeout without accepting pending status',async()=>{
 const c=clock();let calls=0;
 const result=await pollPage(async(expression,ms)=>{
  assert.ok(!expression.includes('innerText'));calls++;
  if(calls===1){c.advance(ms);throw timeout();}
  if(calls===2)return wrap({status:'pending',progress:'rendering'});
  return wrap({status:'pass',result:JSON.stringify({status:'pass',checks:['real pick']})});
 },url,10000,c);
 assert.equal(calls,3);assert.deepEqual(result,{status:'pass',checks:['real pick']});
});
test('persistent CDP timeout stays within total deadline and includes last progress',async()=>{
 const c=clock();let calls=0;
 await assert.rejects(pollPage(async(_,ms)=>{
  calls++;if(calls===1)return wrap({status:'pending',progress:'source selection'});
  c.advance(ms);throw timeout();
 },url,6500,c),/Runtime timed out:.*source selection.*"pollTimeouts":2/);
 assert.equal(c.now(),6500);assert.equal(calls,3);
});
test('CDP poll preserves explicit browser failures and does not retry unrelated protocol errors',async()=>{
 const c=clock();const failure={status:'fail',message:'bad pick'};
 assert.deepEqual(await pollPage(async()=>wrap({status:'fail',result:JSON.stringify(failure)}),url,1000,c),failure);
 await assert.rejects(pollPage(async()=>{throw Error('target closed');},url,1000,c),/target closed/);
 await assert.rejects(pollPage(async()=>wrap({status:'pass',result:JSON.stringify(failure)}),url,1000,c),/status must agree/);
});
