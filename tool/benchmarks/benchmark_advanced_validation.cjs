'use strict';
const fs=require('node:fs'),os=require('node:os');
const {run,profiles,scenarios,maximumDifference}=require('./physics_validation/scenarios.cjs');
const {readCsv,compare}=require('./physics_validation/telemetry.cjs');
function args(argv){const out={};for(const x of argv){const m=/^--([a-z-]+)=(.+)$/.exec(x);if(!m||Object.hasOwn(out,m[1])||!['profile','scenario','model','fps','out','telemetry','offset'].includes(m[1]))throw Error(`Invalid argument: ${x}`);out[m[1]]=m[2];}return out;}
async function main(){const a=args(process.argv.slice(2)),single=Boolean(a.scenario);
    if(a.telemetry&&!single)throw Error('Use --scenario with --telemetry');
    if(!single&&(a.model||a.fps||a.offset))throw Error('Specify --scenario for model, FPS or alignment overrides');
    if(a.offset&&!a.telemetry)throw Error('Offset requires telemetry');
    const selected=a.profile?[a.profile]:Object.keys(profiles),results=[];
    if(single){const result=await run({profile:a.profile??'reference-7-inch',scenario:a.scenario,model:a.model??'advanced',fps:Number(a.fps??60),measure:true});results.push(result);}
    else for(const profile of selected){for(const scenario of Object.keys(scenarios)){
        const baseline=await run({profile,scenario,fps:60,measure:true});
        const differences={};for(const fps of [30,120])differences[fps]=maximumDifference(baseline,await run({profile,scenario,fps}));
        const legacy=await run({profile,scenario,model:'legacy',fps:60,measure:true});
        results.push({...baseline,frameRateDifferences:differences,legacy});
    }results.push(await run({profile,scenario:'cruise',fps:60,measure:true,stall:true}));}
    const report={schemaVersion:1,source:'synthetic-node-no-cesium',environment:{node:process.version,platform:os.platform(),arch:os.arch(),cpu:os.cpus()[0]?.model,logicalCpus:os.cpus().length},profiles:Object.fromEntries([...new Set(results.map(r=>r.profile))].map(k=>[k,profiles[k]])),results,
        ...(a.telemetry?{comparison:compare(results[0],readCsv(a.telemetry),{offsetSeconds:Number(a.offset??0)})}:{})};
    if(a.out){fs.writeFileSync(a.out,JSON.stringify(report,null,2)+'\n',{flag:'wx'});console.log(`Wrote ${a.out}`);}
    for(const r of results)console.log(`${r.profile} ${r.scenario} ${r.model}: ${r.performance.step.p95Ms?.toFixed(3)} ms step p95, ${r.diagnostics.droppedSeconds.toFixed(3)} s dropped, ${r.trace.at(-1).energy_wh?.toFixed(3)} Wh`);
    if(report.comparison)console.log(JSON.stringify(report.comparison,null,2));
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
