const test=require('node:test');
const assert=require('node:assert/strict');
const collision=require('../../web/collision_response.js');
const {createSimulator,parameters,distance}=require('../../web/free_flight.js');
const origin={latitude:46.7,longitude:8.4};
const vector=(north,east,up)=>({north,east,up});
const norm=v=>Math.hypot(v.north,v.east,v.up);
const power=v=>v.north**2+v.east**2+v.up**2;
function setup(options={}){
    let floor=options.renderedHeight??(()=>1000);
    const model=createSimulator({sampleHeight:async()=>1000,renderedHeight:p=>floor(p),
        captureCamera:()=>({heading:0}),restoreCamera:()=>{},applyPose:()=>{},
        isTerrainReady:()=>true,onState:()=>{},...options});
    return {model};
}
async function start(page,settings={}){
    await page.model.start({...origin,agl:500,physicsModel:'advanced',flightMode:'acro',...settings},new AbortController().signal);
}
function advance(model,t=1,fps=60){for(let i=0;i<Math.round(t*fps);i++)model.tick(1/fps);}

test('collision presets validate and retain legacy settings compatibility',()=>{
    const cfg=collision.configuration();
    assert.equal(cfg.mode,'slide');assert.equal(parameters({}).physicsModel,'advanced');
    assert.deepEqual(parameters({}).collisionResponse,cfg);
    for(const options of [{mode:'unknown'},{restitution:-1},{friction:3},
        {hardStopNormalSpeedMs:0},{minimumReboundSpeedMs:Infinity},
        {terrainProbeMeters:.01}])assert.throws(()=>collision.configuration(options));
});
test('normal separation conserves tangential velocity in a frictionless glancing impact',()=>{
    const velocity=vector(32,-3,-1),normal=vector(0,1,0);
    const outcome=collision.resolve(velocity,normal,{mode:'slide',friction:0});
    assert.equal(outcome.mode,'slide');assert.deepEqual(outcome.velocity,vector(32,0,-1));
    assert.ok(power(outcome.velocity)<=power(velocity));
    assert.deepEqual(collision.resolve(velocity,normal,{mode:'hard-stop'}).velocity,vector(0,0,0));
});
test('head-on impacts remove substantially more momentum than grazing contacts',()=>{
    const normal=vector(0,0,1),config={mode:'rebound',restitution:.2,friction:.1};
    const frontal=collision.resolve(vector(0,0,-10),normal,config);
    const grazing=collision.resolve(vector(20,0,-1),normal,config);
    assert.ok(norm(frontal.velocity)<3);
    assert.ok(norm(grazing.velocity)>17);
    assert.ok(power(frontal.velocity)<=100&&power(grazing.velocity)<=401);
    assert.equal(frontal.mode,'rebound');
});
test('severe hits hard-stop, separating motion is untouched, tiny impacts cannot chatter',()=>{
    const cfg={mode:'rebound',restitution:.75,hardStopNormalSpeedMs:15,minimumReboundSpeedMs:1};
    assert.equal(collision.resolve(vector(3,0,-16),vector(0,0,1),cfg).mode,'hard-stop');
    assert.deepEqual(collision.resolve(vector(3,0,2),vector(0,0,1),cfg).velocity,vector(3,0,2));
    const small=collision.resolve(vector(5,0,-.1),vector(0,0,1),cfg);
    assert.equal(small.velocity.up,0);assert.equal(small.mode,'slide');
    for(let i=0;i<1000;i++){
        const r=collision.resolve(vector(5,0,-.08),vector(0,0,1),cfg);
        assert.ok(Number.isFinite(r.velocity.north));assert.equal(r.velocity.up,0);
    }
});
test('surface normals require complete finite rendered height samples',()=>{
    const point={...origin,height:1001},radius=6378137,rad=Math.PI/180;
    const move=(p,n,e)=>({latitude:p.latitude+n/radius/rad,
        longitude:p.longitude+e/(radius*Math.cos(p.latitude*rad))/rad});
    const heights=p=>1000+2*(p.latitude-origin.latitude)*rad*radius;
    const computed=collision.terrainNormal(point,heights,move,.6);
    assert.ok(computed.north<-.89&&computed.up>.44);
    assert.equal(collision.terrainNormal(point,()=>NaN,move),null);
    assert.equal(collision.terrainNormal(point,p=>1000+100*(p.latitude-origin.latitude)*rad*radius,move),null);
});
test('advanced unknown-normal model collisions remain hard stops and do not pass through',async()=>{
    let hits=0;
    const p=setup({modeledCollision:()=>{hits++;return 'bridge';}});
    await start(p,{agl:500});const before=p.model.status();
    p.model.flightInput({pitch:1,throttle:.7});advance(p.model,.1);
    const state=p.model.status();
    assert.equal(state.lastCollision?.mode,'hard-stop');
    assert.deepEqual(state.position,before.position);assert.equal(state.height,before.height);
    assert.ok(hits>0);assert.match(state.reason,/contact/);
});
test('missing rendered terrain never invents a ground normal or verified clearance',async()=>{
    const p=setup({renderedHeight:()=>NaN});
    await start(p,{agl:500});p.model.flightInput({throttle:0});advance(p.model,.2);
    const state=p.model.status();
    assert.equal(state.terrainVerification.state,'unavailable');
    assert.equal(state.agl,null);
    assert.match(state.reason,/unverified/);
});
test('legacy collision trajectory unaffected by advanced restitution settings',async()=>{
    const outputs=[];
    for(const collisionResponse of [{mode:'slide',friction:0},{mode:'rebound',restitution:.75}]){
        const p=setup({modeledCollision:()=> 'model'});
        await start(p,{physicsModel:'legacy',collisionResponse});
        p.model.flightInput({throttle:.6,pitch:.8});advance(p.model,.5);
        outputs.push(p.model.status());
    }
    assert.deepEqual(outputs[0].position,outputs[1].position);
    assert.equal(outputs[0].height,outputs[1].height);
    assert.equal(outputs[0].speed,0);
});
test('fixed physics ticks produce the same collision trajectory at 30/60/120 render FPS',async()=>{
    const results=[];
    for(const fps of [30,60,120]){
        const p=setup({renderedHeight:()=>1000});
        await start(p,{agl:1,flightMode:'acro',collisionResponse:{mode:'rebound',restitution:.15}});
        p.model.flightInput({throttle:0,pitch:0,roll:0});advance(p.model,2,fps);
        results.push(p.model.status());
    }
    for(const s of results.slice(1)){
        assert.deepEqual(s.position,results[0].position);
        assert.equal(s.height,results[0].height);
        assert.equal(s.speed,results[0].speed);
    }
});

test('swept oblique model contact preserves along-wall motion without crossing collision plane',async()=>{
    const rad=Math.PI/180,R=6378137;
    const east=p=>(p.longitude-origin.longitude)*rad*R*Math.cos(origin.latitude*rad);
    const north=p=>(p.latitude-origin.latitude)*rad*R;
    let sweeps=0;
    const p=setup({sampleWind:()=>({available:true,north:14,east:8,up:0}),
        modeledCollision:(from,to)=>{
            sweeps++;
            if(east(from)<2&&east(to)>=2)return {kind:'bridge',
                normal:vector(0,-1,0),fraction:(2-east(from))/(east(to)-east(from))};
            return false;
        }});
    await start(p,{collisionResponse:{mode:'slide',friction:.1}});
    advance(p.model,3);const after=p.model.status();
    advance(p.model,3);const later=p.model.status();
    assert.ok(Math.abs(east(later.position)-2)<.015);
    assert.ok(north(later.position)>north(after.position)+10,'Contact must slide, not freeze');
    assert.ok(later.horizontalSpeed>1);
    assert.equal(later.lastCollision?.mode,'slide');
    assert.ok(sweeps<2500,'Contact sweeps remain bounded');
});
test('severe vertical impact on known flat terrain stops without embedding below rotor clearance',async()=>{
    const p=setup();await start(p,{agl:35,
        collisionResponse:{mode:'rebound',restitution:.7,hardStopNormalSpeedMs:12}});
    let severe=false;
    for(let i=0;i<900;i++){
        p.model.tick(1/120);const s=p.model.status();
        assert.ok(s.height>=1000.5-1e-7,'Known ground cannot be penetrated');
        if(s.lastCollision?.mode==='hard-stop'&&s.lastCollision.normalSpeedMs>=12){severe=true;break;}
    }
    assert.ok(severe,'High-energy impact activates severe hard stop');
    assert.equal(p.model.status().speed,0);
});
test('repeated ground contact remains bounded in slide mode and does not create rebound energy',async()=>{
    const p=setup({sampleWind:()=>({available:true,north:0,east:6,up:0})});
    await start(p,{agl:1,collisionResponse:{mode:'slide',friction:0}});
    advance(p.model,5);
    const state=p.model.status();
    assert.ok(state.height>=1000.5&&state.height<1001);
    assert.ok(state.position.longitude>origin.longitude);
    assert.ok(state.horizontalSpeed>0);
    assert.ok(Number.isFinite(state.speed)&&state.speed<10);
});

test('unknown terrain with a positive swept hit hard-stops instead of fabricating a normal',async()=>{
    const p=setup({renderedHeight:()=>NaN,terrainCollision:()=>true});
    await start(p,{agl:80,collisionResponse:{mode:'rebound',restitution:.7}});
    const before=p.model.status();
    advance(p.model,.2);
    const state=p.model.status();
    assert.deepEqual(state.position,before.position);
    assert.equal(state.height,before.height);
    assert.equal(state.lastCollision?.mode,'hard-stop');
    assert.equal(state.terrainVerification.state,'unavailable');
    assert.match(state.reason,/normal unavailable/);
});
