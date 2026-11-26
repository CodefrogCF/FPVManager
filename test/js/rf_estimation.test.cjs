const test=require('node:test'),assert=require('node:assert/strict');
const rf=require('../../web/features/signal/rf_estimation.js');
const a={latitude:47,longitude:8},b={latitude:47,longitude:8.005};
const geometry=visibility=>({source:'sampledTerrain',confidence:'approximate',visibility,
    minimumClearanceMeters:visibility==='obstructed'?-20:10,minimumFresnelMarginMeters:visibility==='fresnelIntrusion'?-4:8});
test('default CE reference bands and model assumptions are explicit and separately configurable',()=>{
    assert.equal(rf.defaults.video.frequencyMhz,5800);assert.equal(rf.defaults.control.frequencyMhz,868);
    assert.equal(rf.defaults.video.eirpDbm,13.9);assert.equal(rf.defaults.control.eirpDbm,14);
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

test('EU/CE and FCC reference scenarios change only the selected band and preserve custom numbers',()=>{
    assert.equal(rf.presets.video.eu.frequencyMhz,5800);
    assert.equal(rf.presets.video.fcc.eirpDbm,32.9);
    assert.equal(rf.presets.control.eu.frequencyMhz,868);
    assert.equal(rf.presets.control.fcc.frequencyMhz,915);
    const fcc=rf.configuration({videoScenario:'fcc',controlScenario:'eu',
        video:rf.presets.video.fcc,control:rf.presets.control.eu});
    assert.equal(fcc.video.eirpDbm,32.9);
    assert.equal(fcc.control.frequencyMhz,868);
    const override=rf.configuration({videoScenario:'custom',video:{frequencyMhz:5700,eirpDbm:25}});
    assert.equal(override.video.eirpDbm,25);
    assert.equal(override.video.frequencyMhz,5700);
    assert.throws(()=>rf.configuration({videoScenario:'other'}),/Invalid/);
    const euRange=rf.theoreticalRangeMeters(rf.presets.video.eu);
    const fccRange=rf.theoreticalRangeMeters(rf.presets.video.fcc);
    assert.ok(euRange>6000&&euRange<11000,'EU illustrative open-air calibration');
    assert.ok(fccRange>11000&&fccRange<18000,'FCC illustrative open-air calibration');
});


test('11 km limited terrain: a sampled ridge may drive estimated video/RC loss, but sparse clear paths cannot',()=>{
    const station={latitude:47,longitude:8,height:1000};
    const drone={latitude:47,longitude:8.15,height:1150};
    const ridge={source:'sampledTerrain',confidence:'limited',visibility:'obstructed',
        sampleCount:160,maximumSampleGapMeters:420,
        minimumClearanceMeters:-40,minimumFresnelMarginMeters:-70};
    const estimate=rf.assess(ridge,station,drone);
    assert.equal(estimate.videoLink.source,'rfModel');
    assert.equal(estimate.controlLink.source,'rfModel');
    assert.equal(estimate.controlLink.detail,'sampledObstructionOnly');
    assert.equal(estimate.controlLink.confidence,'limitedTerrainAssumption');
    assert.ok(estimate.controlLink.quality<=.2);
    assert.ok(estimate.videoLink.quality<=.2);
    // Sampled obstruction is evidence, but incomplete samples do NOT prove a clear path.
    for(const incomplete of [
        {...ridge,visibility:'clear'},
        {...ridge,visibility:'fresnelIntrusion'},
        {...ridge,minimumClearanceMeters:0},
        {...ridge,minimumClearanceMeters:null},
        {...ridge,sampleCount:2},
        {...ridge,source:'unavailable'},
        {...ridge,confidence:'unavailable'}
    ]){
        const unknown=rf.assess(incomplete,station,drone);
        assert.equal(unknown.controlLink,'unknown');
        assert.equal(unknown.videoLink,'unknown');
    }
    assert.equal(rf.assess(ridge,station,drone,{enabled:false}).controlLink,'unknown');
    const preview=rf.freeSpacePreview(rf.distanceMeters(station,drone));
    assert.equal(preview.control.estimatedTerrainLossDb,undefined,
        'free-space preview never incorporates inferred terrain or drives failsafe');
});

test('scenery estimates affect separate band budgets without summing potentially overlapping terrain loss',()=>{
 const scene={control:{lossDb:10},video:{lossDb:60}};
 const clear=rf.assess(geometry('clear'),a,b,rf.defaults,scene);
 assert.equal(clear.controlLink.estimatedSceneryLossDb,10);assert.equal(clear.videoLink.estimatedSceneryLossDb,60);
 const both=rf.assess(geometry('obstructed'),a,b,rf.defaults,scene);
 for(const [key,loss] of [['controlLink',10],['videoLink',60]])assert.equal(both[key].estimatedCombinedLossDb,Math.max(both[key].estimatedTerrainLossDb,loss));
 assert.equal(rf.assess(geometry('unknown'),a,b,rf.defaults,scene).controlLink,'unknown');
});
