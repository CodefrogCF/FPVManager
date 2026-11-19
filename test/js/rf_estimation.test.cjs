const test=require('node:test'),assert=require('node:assert/strict');
const rf=require('../../web/rf_estimation.js');
const a={latitude:47,longitude:8},b={latitude:47,longitude:8.005};
const geometry=visibility=>({source:'sampledTerrain',confidence:'approximate',visibility,
    minimumClearanceMeters:visibility==='obstructed'?-20:10,minimumFresnelMarginMeters:visibility==='fresnelIntrusion'?-4:8});
test('default CE reference bands and model assumptions are explicit and separately configurable',()=>{
    assert.equal(rf.defaults.video.frequencyMhz,5800);assert.equal(rf.defaults.control.frequencyMhz,868);
    assert.equal(rf.defaults.video.eirpDbm,14);assert.equal(rf.defaults.control.eirpDbm,14);
    assert.equal(rf.configuration({video:{eirpDbm:12}}).control.eirpDbm,14);
    assert.throws(()=>rf.configuration({control:{frequencyMhz:Infinity}}),/Invalid/);
    assert.throws(()=>rf.configuration({enabled:'true'}),/Invalid/);
});
test('clear and obstructed links are not binary RF assertions; video and RC are independent',()=>{
    const clear=rf.assess(geometry('clear'),a,b);
    const partial=rf.assess(geometry('fresnelIntrusion'),a,b);
    const blocked=rf.assess(geometry('obstructed'),a,b);
    assert.equal(clear.controlLink.source,'rfModel');assert.equal(clear.videoLink.source,'rfModel');
    assert.ok(clear.videoLink.quality>partial.videoLink.quality);
    assert.ok(partial.videoLink.quality>=blocked.videoLink.quality);
    assert.ok(blocked.controlLink.quality>=blocked.videoLink.quality);
    assert.ok(clear.videoLink.marginDb>blocked.videoLink.marginDb);
    assert.equal(clear.videoLink.estimated,true);
});
test('custom equipment and missing elevation stay conservative',()=>{
    const basic=rf.assess(geometry('clear'),a,b);
    const custom=rf.assess(geometry('clear'),a,b,{video:{eirpDbm:30}});
    assert.ok(custom.videoLink.quality>=basic.videoLink.quality);
    assert.equal(custom.controlLink.quality,basic.controlLink.quality);
    for(const invalid of [null,{...geometry('clear'),source:'unavailable'},geometry('unknown')]){
        assert.equal(rf.assess(invalid,a,b).videoLink,'unknown');
        assert.equal(rf.assess(invalid,a,b).controlLink,'unknown');
    }
    assert.equal(rf.assess(geometry('clear'),a,b,{enabled:false}).videoLink,'unknown');
    assert.equal(rf.assess(geometry('clear'),a,{latitude:NaN,longitude:8}).videoLink,'unknown');
});
test('distance and path loss reduce signal smoothly; even severe modeled loss is not measured telemetry',()=>{
    const near=rf.assess(geometry('clear'),a,{latitude:47,longitude:8.0005});
    const far=rf.assess(geometry('clear'),a,{latitude:47,longitude:8.02});
    assert.ok(near.videoLink.quality>=far.videoLink.quality);
    assert.equal(near.videoLink.detail,'approximateLinkBudget');
});

test('link budget exposes reproducible FSPL, receive power, 0 dB ideal range and modeled margin',()=>{
    const p=rf.defaults.video;
    const fspl=rf.freeSpaceLossDb(1000,p.frequencyMhz);
    const range=rf.theoreticalRangeMeters(p);
    assert.ok(Number.isFinite(range)&&range>1);
    assert.ok(Math.abs(rf.freeSpaceLossDb(range,p.frequencyMhz)-(p.eirpDbm-p.receiverThresholdDbm-p.fadeMarginDb))<1e-9);
    const km=rf.assess(geometry('clear'),a,{latitude:47,longitude:8.01318}).videoLink;
    assert.ok(Math.abs(km.freeSpaceLossDb-fspl)<1.5);
    assert.ok(Math.abs(km.estimatedRxPowerDbm-(p.eirpDbm-km.freeSpaceLossDb))<.11);
    assert.ok(Math.abs(km.linkMarginDb-(km.estimatedRxPowerDbm-p.receiverThresholdDbm-p.fadeMarginDb))<.21);
    assert.equal(km.estimatedTerrainLossDb,0);
    assert.equal(km.confidence,'assumptionBased');
    assert.equal(km.marginDb,km.linkMarginDb);
    assert.ok(km.estimatedMaxRangeM>0);
    assert.equal(km.source,'rfModel');
});
test('video and RC ranges respond independently to frequency, power and fade assumptions',()=>{
    const base=rf.assess(geometry('clear'),a,b);
    const video=rf.assess(geometry('clear'),a,b,{video:{eirpDbm:20}});
    assert.ok(video.videoLink.estimatedMaxRangeM>base.videoLink.estimatedMaxRangeM);
    assert.equal(video.controlLink.estimatedMaxRangeM,base.controlLink.estimatedMaxRangeM);
    const worse=rf.assess(geometry('clear'),a,b,{control:{fadeMarginDb:20}});
    assert.ok(worse.controlLink.estimatedMaxRangeM<base.controlLink.estimatedMaxRangeM);
    assert.equal(worse.videoLink.estimatedMaxRangeM,base.videoLink.estimatedMaxRangeM);
    assert.throws(()=>rf.theoreticalRangeMeters(base.videoLink,-1),/Invalid/);
});
test('terrain attenuation shortens the scenario range and link quality declines smoothly with distance',()=>{
    const clear=rf.assess(geometry('clear'),a,b).videoLink;
    const blocked=rf.assess(geometry('obstructed'),a,b).videoLink;
    assert.ok(blocked.estimatedTerrainLossDb>clear.estimatedTerrainLossDb);
    assert.ok(blocked.estimatedTerrainScenarioRangeM<clear.estimatedTerrainScenarioRangeM);
    assert.equal(blocked.estimatedMaxRangeM,clear.estimatedMaxRangeM);
    let quality=1;
    for(const distance of [.001,.01,.03,.05,.07,.11]){
        const current=rf.assess(geometry('clear'),a,{latitude:47,longitude:8+distance}).videoLink;
        assert.ok(current.quality<=quality);
        quality=current.quality;
    }
    const low=rf.assess(geometry('clear'),a,b,{video:{eirpDbm:-10}}).videoLink;
    assert.ok(low.quality<=clear.quality);
});
test('3D slant range uses known heights without pretending to know absent terrain',()=>{
    const ground=rf.distanceMeters(a,b);
    const air=rf.distanceMeters({...a,height:500},{...b,height:1500});
    assert.ok(air>ground);
    assert.equal(rf.distanceMeters(a,{latitude:91,longitude:8}),null);
    assert.equal(rf.freeSpaceLossDb(0,5800),null);
    assert.equal(rf.assess({source:'unavailable',visibility:'clear',confidence:'unavailable'},a,b).videoLink,'unknown');
});
