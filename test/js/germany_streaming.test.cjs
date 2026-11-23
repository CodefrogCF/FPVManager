const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const R=require('../../web/features/terrain/regional_3d.js');
const root=path.join(__dirname,'../..');

const positions={
    Ruedersdorf:[13.79,52.48],Berlin:[13.405,52.52],Munich:[11.58,48.14],
    Hamburg:[10.0,53.55],Cologne:[6.96,50.94],Dresden:[13.73,51.05],
    Zurich:[8.54,47.37],Basel:[7.59,47.56],Vienna:[16.37,48.20],
    Prague:[14.42,50.08],Strasbourg:[7.75,48.58]
};
test('country geometry covers German cities, not nearby Swiss and foreign ones',()=>{
    for(const [name,[longitude,latitude]] of Object.entries(positions)){
        const expected=!['Zurich','Basel','Vienna','Prague','Strasbourg'].includes(name);
        assert.equal(R.inRegion({longitude,latitude,height:2000}),expected,name);
    }
    assert.ok(R.boundary.length>=50);
    assert.equal(R.inRegion({longitude:13.4,latitude:52.5,height:250000}),false);
    assert.equal(R.inRegion({longitude:13.4,latitude:52.5,height:2000}),true);
});

test('3D source is official BKG and points to test-only license',()=>{
    assert.match(R.terrainUrl,/gdz_basemapde_3d_gelaende\/dgm5_4326_mesh\/$/);
    assert.match(R.buildingsUrl,/gdz_basemapde_3d_gebaeude\/lod2_4326_dgm5\.json$/);
    assert.match(R.licenseUrl,/lizenz_basemapde_3d-testbetrieb\.pdf$/);
});

test('enabled callback controls requests without creating offline caches',async()=>{
    let allowed=false,current={longitude:13.405,latitude:52.52,height:1000};
    let terrainSwitches=0,requested=0,added=0,removed=0;
    const C={Credit:class{constructor(html,onScreen){this.html=html;this.showOnScreen=onScreen;}},
        Cartesian3:{fromDegrees(){}}};
    const listeners={addEventListener:()=>()=>{}};
    const display={addStaticCredit(){},removeStaticCredit(){}};
    const viewer={camera:{positionCartographic:{}},cesiumWidget:{creditDisplay:display},
        scene:{primitives:{add(){added++;},remove(){removed++;}},preUpdate:listeners,globe:{},requestRender(){}}};
    const tileset={destroy(){},isDestroyed(){return false;},show:true};
    const api=R.create(C,viewer,{enabled:()=>allowed,position:()=>current,
        online:()=>true,buildingsRequested:()=>true,onRegionChange:()=>terrainSwitches++,
        loadTiles:async()=>{requested++;return tileset;},setTimer:()=>123,clearTimer(){} });
    try{
        api.tick(true);assert.equal(api.region(),false);assert.equal(requested,0);
        allowed=true;api.tick(true);await new Promise(resolve=>setImmediate(resolve));
        assert.equal(api.region(),true);assert.equal(requested,1);assert.equal(added,1);
        current={longitude:8.54,latitude:47.37,height:1000};api.tick(true);
        assert.equal(api.region(),false);assert.equal(removed,1);
        assert.equal(terrainSwitches,2);
    }finally{api.dispose();}
    for(const filename of ['web/features/terrain/regional_3d.js','web/offline_service_worker.js']){
        const source=fs.readFileSync(path.join(root,filename),'utf8');
        assert.doesNotMatch(source,/caches\.put\([^)]*gdz_basemapde/);
    }
    const flutter=fs.readFileSync(path.join(root,'lib/features/globe/globe_controller.dart'),'utf8');
    assert.match(flutter,/bool _bkg3dTestEnabled/);
    assert.match(flutter,/setBkg3dTestEnabled/);
    const renderer=fs.readFileSync(path.join(root,'web/globe.js'),'utf8');
    assert.match(renderer,/case 'set-bkg-3d-test'/);
});


test('BKG 3D requests use no-store transport; other providers retain native loader',async()=>{
    let originalCalls=0,restrictedCalls=0,received;
    const original=()=>{originalCalls++;};
    const C={Resource:{_Implementations:{loadWithXhr:original}}};
    assert.equal(R.installRuntimeOnlyTransport(C),true);
    const wrapper=C.Resource._Implementations.loadWithXhr;
    assert.equal(R.installRuntimeOnlyTransport(C),true);
    assert.equal(wrapper,C.Resource._Implementations.loadWithXhr);
    wrapper('https://3d.geo.admin.ch/test','arraybuffer','GET',null,{},{});
    assert.equal(originalCalls,1);
    const prior=globalThis.fetch;
    globalThis.fetch=async (url,opts)=>{restrictedCalls++;received=opts;return {ok:true,status:200,
        arrayBuffer:async()=>new Uint8Array([1,2,3]).buffer};};
    try{
        let value;
        const xhr=wrapper(R.terrainUrl+'0/0/0.terrain','arraybuffer','GET',null,{},
            {resolve:x=>{value=x;},reject:e=>{throw e;}});
        await new Promise(resolve=>setImmediate(resolve));
        assert.equal(restrictedCalls,1);
        assert.equal(received.cache,'no-store');
        assert.equal(received.credentials,'omit');
        assert.deepEqual(Array.from(new Uint8Array(value)),[1,2,3]);
        assert.equal(typeof xhr.abort,'function');
    }finally{globalThis.fetch=prior;}
});


test('explicitly disabling test service immediately releases LoD2 even during navigation',async()=>{
    let enabled=true, busy=false,removed=0;
    const C={Credit:class{constructor(html){this.html=html;}},Cartesian3:{fromDegrees(){}}};
    const viewer={camera:{positionCartographic:{}},cesiumWidget:{creditDisplay:{addStaticCredit(){},removeStaticCredit(){}}},
        scene:{primitives:{add(){},remove(){removed++;}},preUpdate:{addEventListener(){return ()=>{};}},globe:{},requestRender(){}}};
    const tiles={isDestroyed(){return false;},destroy(){},show:true};
    const api=R.create(C,viewer,{enabled:()=>enabled,position:()=>({longitude:13.405,latitude:52.52,height:1000}),
        online:()=>true,navigationBusy:()=>busy,buildingsRequested:()=>true,
        loadTiles:async()=>tiles,setTimer:()=>1,clearTimer(){}});
    try {
        api.tick(true);
        await new Promise(resolve=>setImmediate(resolve));
        assert.equal(api.region(),true);
        busy=true;enabled=false;api.tick(true);
        assert.equal(api.region(),false);
        assert.equal(removed,1);
    }finally {api.dispose();}
});

test('standalone alignment workbench enables no-store transport for live LoD2',()=>{
    const content=fs.readFileSync(path.join(root,'tool/scenery/cesium_georeference_workbench.js'),'utf8');
    assert.match(content,/!R\.installRuntimeOnlyTransport\(C\)/);
    const server=fs.readFileSync(path.join(root,'tool/scenery/serve_workbench.py'),'utf8');
    assert.match(server,/Cache-Control.*no-store/);
    assert.doesNotMatch(server,/open\(.*["']wb["']/);
});
