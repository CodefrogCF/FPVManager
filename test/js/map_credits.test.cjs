'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const C=require('../../web/cesium/index.cjs');
const P=require('../../web/features/map/map_providers.js');
function display(){
    const credits=[],removed=[];
    return {credits,removed,addStaticCredit(c){
        if(!credits.some(existing=>C.Credit.equals(existing,c)))credits.push(c);
    },removeStaticCredit(c){removed.push(c);const i=credits.indexOf(c);if(i>=0)credits.splice(i,1);}};
}
test('equal layer credits stay registered until the last owner releases them',()=>{
    const d=display(),a=new C.Credit('© swisstopo',false),b=new C.Credit('© swisstopo',false);
    P.retainStaticCredit(d,a);P.retainStaticCredit(d,b);P.retainStaticCredit(d,b);
    assert.equal(d.credits.length,1);P.releaseStaticCredit(d,a);
    assert.equal(d.credits.length,1,'hiding labels cannot remove the active 3D layer source');
    P.releaseStaticCredit(d,b);assert.equal(d.credits.length,0);assert.equal(d.removed.length,1);
    P.releaseStaticCredit(d,b);assert.equal(d.removed.length,1);
    P.retainStaticCredit(d,b);assert.equal(d.credits[0],b);P.releaseStaticCredit(d,b);
});
test('screen requirements and separate viewers are not merged with collapsible credits',()=>{
    const d=display(),other=display(),inline=new C.Credit('Provider',true),popup=new C.Credit('Provider',false);
    P.retainStaticCredit(d,inline);P.retainStaticCredit(d,popup);P.retainStaticCredit(other,popup);
    assert.equal(d.credits.length,2);P.releaseStaticCredit(d,popup);
    assert.equal(d.credits[0].showOnScreen,true);assert.equal(other.credits.length,1);
    P.releaseStaticCredit(d,inline);P.releaseStaticCredit(other,popup);
});
test('optional renderer branding changes only in the direct-provider setup',()=>{
    const old=new C.Credit('Optional renderer logo',true);
    const api={Credit:C.Credit,CreditDisplay:{cesiumCredit:old}};
    assert.equal(P.prepareCredits(api,{usesIon:true}),false);assert.equal(api.CreditDisplay.cesiumCredit,old);
    assert.equal(P.prepareCredits(api),true);assert.equal(api.CreditDisplay.cesiumCredit.html,'');
});
test('sources use the native accessible dialog and leave mandatory provider credits alone',()=>{
    const d=display(),attributes=new Map(),expand={textContent:'Data attribution',setAttribute:(k,v)=>attributes.set(k,v)};
    const title={},close={setAttribute(){}},dialog={setAttribute(){},querySelector:s=>s.includes('title')?title:close};
    d.container={querySelector:()=>expand};d.viewport={querySelector:()=>dialog};
    let opened=0;d.showLightbox=()=>opened++;
    const mandatory=new C.Credit('Mandatory fixture provider',true);d.addStaticCredit(mandatory);
    const controls=P.configureCredits(C,{cesiumWidget:{creditDisplay:d}});
    assert.equal(expand.textContent,'Quellen');assert.equal(attributes.get('aria-label'),'Quellen und Lizenzen');
    assert.equal(title.textContent,'Quellen und Lizenzen');assert.equal(mandatory.showOnScreen,true);
    assert.equal(P.configureCredits(C,{creditDisplay:d}),controls,'no duplicate acknowledgment or listeners');
    controls.open();assert.equal(opened,1);controls.dispose();controls.dispose();controls.open();
    assert.equal(opened,1);assert.deepEqual(d.credits,[mandatory]);
});
test('weather credits keep source visible and license plus processing notice in details',()=>{
    const [inline,details]=P.weatherCredits(C);
    assert.equal(inline.showOnScreen,true);assert.match(inline.html,/Open-Meteo/);
    assert.equal(details.showOnScreen,false);assert.match(details.html,/creativecommons.org\/licenses\/by\/4.0/);
    assert.match(details.html,/interpoliert/);
});

test('credit height updates only on real resize and is removed on dispose',()=>{
    const values=new Map();let writes=0,h=24,callback,disconnected=false;
    const container={ownerDocument:{documentElement:{style:{setProperty(k,v){writes++;values.set(k,v);},removeProperty:k=>values.delete(k)}}},getBoundingClientRect:()=>({height:h})};
    class Observer{constructor(cb){callback=cb;}observe(node){assert.equal(node,container);}disconnect(){disconnected=true;}}
    const stop=P.observeCreditHeight(container,Observer);
    assert.equal(values.get('--fpv-credit-height'),'24px');callback();assert.equal(writes,1);
    h=51.5;callback();assert.equal(values.get('--fpv-credit-height'),'52px');
    stop();assert.equal(disconnected,true);assert.equal(values.size,0);
});
test('bundled scan has short capture attribution and full linked non-commercial provenance',()=>{
    const M=require('../../web/features/scenery/scenery_manager.js');
    const item=require('../../web/assets/scenery/catalog.json').sceneries[0];
    const [inline,details]=M.sceneryCredits(C,{...item,attribution:`${item.author} · ${item.license}`});
    assert.equal(inline.showOnScreen,true);assert.equal(details.showOnScreen,false);
    assert.match(inline.html,/Spognetta/);assert.match(inline.html,/verändert/);
    assert.match(details.html,/Andrea Spognetta/);assert.match(details.html,/RAWscan/);
    assert.match(details.html,/creativecommons.org\/licenses\/by-nc\/4.0/);assert.match(details.html,/non-commercial/);
    assert.ok(inline.html.length<details.html.length);
    const custom=M.sceneryCredits(C,{...item,attribution:'Mandatory third-party notice <fixture>'});
    assert.equal(custom.length,1);assert.equal(custom[0].showOnScreen,true);assert.match(custom[0].html,/Mandatory third-party notice &lt;fixture&gt;/);
    const generic=M.sceneryCredits(C,{...item,id:'custom',attribution:`${item.author} · ${item.license}`})[0];
    assert.equal(generic.showOnScreen,true);assert.equal(generic.html.match(/Andrea Spognetta/g).length,1);
});
