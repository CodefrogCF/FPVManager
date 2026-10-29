const {test}=require('node:test'),assert=require('node:assert/strict');
const {create,maxSamples,maxSeconds}=require('../../web/flight_recording.js');
function setup(){
    let now=0,state={active:true,paused:false,position:{latitude:46.7,longitude:8.4},height:1040,agl:40};const events=[];
    const recorder=create({clock:()=>now,emit:(type,payload)=>events.push({type,...payload}),getState:()=>state});
    return {recorder,events,get state(){return state;},set state(s){state=s;},time:s=>now=s*1000,
        observe:(s)=>{state=s??state;recorder.observe(state);},control:action=>recorder.control({action,id:'flight-1'}),
        samples:()=>events.filter(e=>e.type==='flight-recording-sample').map(e=>e.sample)};
}
test('recording is opt-in and samples movement at 2Hz, retaining a final endpoint without changing state',()=>{
    const p=setup(),original=structuredClone(p.state);p.observe();assert.equal(p.events.length,0);
    p.control('start');assert.deepEqual(p.state,original);assert.equal(p.samples().length,1);
    for(let i=1;i<=120;i++){p.time(i/60);p.observe({...original,position:{latitude:46.7+i*.000001,longitude:8.4},height:1040+i});}
    assert.ok(p.samples().length<=5);p.time(2.1);p.observe({...p.state,height:1200,agl:null});p.control('stop');
    assert.equal(p.samples().at(-1)[5],1200);assert.equal(p.samples().at(-1)[6],null);
    assert.equal(p.recorder.status().phase,'stopped');assert.throws(()=>p.control('start'),/Review or discard/);
    p.time(3);p.observe();assert.equal(p.samples().at(-1)[5],1200);
});
test('manual pauses and view-focus gaps create separate continuous segments; reset ends capture',()=>{
    const p=setup();p.control('start');p.time(.8);p.observe({...p.state,height:1050});p.control('pause');
    const count=p.samples().length;p.time(2);p.observe({...p.state,height:1300});assert.equal(p.samples().length,count);
    p.control('resume');assert.equal(p.samples().at(-1)[1],1);
    p.time(3);p.observe({...p.state,paused:true});p.time(4);p.observe({...p.state,paused:false,height:1400});
    assert.equal(p.samples().at(-1)[1],2);
    p.observe({...p.state,active:false});assert.equal(p.recorder.status().phase,'stopped');
    p.time(5);p.observe({...p.state,active:true,height:5000});assert.equal(p.samples().at(-1)[5],1400);
});
test('wall time, sample limits, invalid positions and obsolete controls cannot silently extend capture',()=>{
    const p=setup();p.control('start');p.time(maxSeconds+1);p.observe();assert.equal(p.recorder.status().phase,'stopped');
    p.control('discard');p.time(0);p.control('start');p.observe({...p.state,height:NaN});assert.equal(p.recorder.status().phase,'stopped');
    assert.throws(()=>p.recorder.control({action:'discard',id:'old'}));
    p.recorder.control({action:'restore',id:'retained',count:123});assert.equal(p.recorder.status().count,123);
    assert.throws(()=>p.recorder.control({action:'restore',id:'x',count:maxSamples+1}));
    const q=setup();q.control('start');
    for(let i=1;i<maxSamples+10;i++){
        q.time(i*.1);q.observe({...q.state,height:1040+i*.01});q.control('pause');
        if(q.recorder.status().phase==='stopped')break;q.control('resume');
    }
    assert.equal(q.samples().length,maxSamples);assert.equal(q.recorder.status().phase,'stopped');
});
test('stationary capture is bounded, long frame gaps split paths and DOM controls send actions only',()=>{
    const p=setup();p.control('start');for(let i=1;i<=120;i++){p.time(i/60);p.observe();}assert.equal(p.samples().length,2);
    p.time(7);p.observe({...p.state,height:1100});assert.equal(p.samples().at(-1)[1],1);
    const nodes=new Map(),doc={getElementById:id=>{if(!nodes.has(id))nodes.set(id,{dataset:{},listeners:{},setAttribute(k,v){this[k]=v;},addEventListener(k,fn){this.listeners[k]=fn;}});return nodes.get(id);}};
    p.recorder.bind(doc);assert.equal(nodes.get('record-flight')['aria-pressed'],'true');
    let prevented=false;nodes.get('record-flight').listeners.pointerdown({preventDefault(){prevented=true;}});assert.equal(prevented,true);
    p.time(8);p.observe({...p.state,height:1110});assert.ok(nodes.get('flight-recording-status').textContent.includes(`${p.samples().length} samples`));
    nodes.get('record-flight').listeners.click();assert.equal(p.events.at(-1).action,'stop');assert.equal(p.recorder.status().phase,'recording');
    p.control('stop');assert.equal(nodes.get('record-flight').title,'Review flight recording');
    assert.equal(nodes.get('pause-recording').hidden,true);assert.equal(nodes.get('review-recording').hidden,false);
    p.recorder.control({action:'restore',id:'retained',count:45});assert.equal(nodes.get('record-flight').title,'Review flight recording');
});
