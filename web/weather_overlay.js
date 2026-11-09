/* Bounded forecast samples; independent variables share one explicit valid time. */
(function(root){
    'use strict';
    const Credits=typeof module==='object'&&module.exports?require('./map_providers.js'):root.FPVMapProviders;
    const creditApi=Credits??{retainStaticCredit:(d,c)=>d?.addStaticCredit(c),releaseStaticCredit:(d,c)=>d?.removeStaticCredit(c),
        weatherCredits:C=>[new C.Credit('<a href="https://open-meteo.com/">Open-Meteo</a> · CC BY 4.0',true)]};
    const definitions={
        wind:{label:'Wind 10 m',units:'m/s',legend:'grün <3 · gelb 3–7 · orange 7–12 · rot ≥12'},
        precipitation:{label:'Niederschlagssumme 1 h',units:'mm',legend:'cyan <0.2 · blau 0.2–1 · violett 1–3 · purpur ≥3'},
        cloudCover:{label:'Bewölkung',units:'%',legend:'dunkel 0–25 · grau 25–75 · hell 75–100'},
        rain:{label:'Großräumige Regensumme 1 h',units:'mm',legend:'cyan <0.2 · blau 0.2–1 · violett 1–3 · purpur ≥3'},
        snowfall:{label:'Neuschneesumme 1 h',units:'cm',legend:'blau <0.2 · hellblau 0.2–1 · weiß ≥1'},
        snowDepth:{label:'Schneehöhe',units:'m',legend:'blau <0.1 · hellblau 0.1–1 · weiß ≥1'},
        temperature:{label:'Temperatur 2 m',units:'°C',legend:'blau <0 · türkis 0–10 · grün 10–20 · orange 20–30 · rot ≥30'}
    };
    function rgb(kind,value){
        if(kind==='wind'){if(value<3)return [50,161,114];if(value<7)return [248,196,73];if(value<12)return [237,132,45];return [205,64,65];}
        if(kind==='temperature'){if(value<0)return [66,116,210];if(value<10)return [58,174,192];if(value<20)return [93,173,105];if(value<30)return [235,160,65];return [207,65,60];}
        if(kind==='cloudCover'){if(value<25)return [75,89,101];if(value<75)return [158,169,178];return [229,235,240];}
        if(kind==='snowfall'||kind==='snowDepth'){if(value<(kind==='snowDepth'?.1:.2))return [72,141,194];if(value<1)return [154,205,235];return [235,244,250];}
        if(value<.2)return [72,160,194];if(value<1)return [52,116,218];if(value<3)return [99,76,193];return [157,67,177];
    }
    function validate(command){
        if(!command||!Object.hasOwn(definitions,command.kind)||!Array.isArray(command.cells)||command.cells.length>100||
            typeof command.source!=='string'||command.source.length>200||!Number.isFinite(Date.parse(command.timestampUtc))||![1000,5000].includes(command.gridSpacingMeters)||
            (command.units!=null&&command.units!==definitions[command.kind].units)||(command.opacity!=null&&(!Number.isFinite(command.opacity)||command.opacity<0||command.opacity>1))||
            (command.sourceType!=null&&command.sourceType!=='forecast')||(command.expiresAtUtc!=null&&!Number.isFinite(Date.parse(command.expiresAtUtc))))throw new Error('Invalid weather overlay metadata');
        for(const c of command.cells)if(![c.west,c.south,c.east,c.north,c.value].every(Number.isFinite)||c.west< -180||c.east>180||c.south< -90||c.north>90||c.west>=c.east||c.south>=c.north||
            (command.kind==='temperature'?(c.value< -100||c.value>70):c.value<0)||(command.kind==='cloudCover'&&c.value>100))throw new Error('Invalid weather grid sample');
    }
    function create(C,viewerFn,{now=()=>Date.now(),timers=globalThis}={}){
        const records=new Map();let disposed=false,previous=null,sourceCredits=[],creditViewer=null;
        const expired=c=>c.expiresAtUtc!=null&&Date.parse(c.expiresAtUtc)<=now();
        function syncCredits(viewer=viewerFn()){
            const needed=!disposed&&viewer&&[...records.values()].some(r=>r.viewer===viewer&&r.command&&!expired(r.command));
            if(creditViewer&&(!needed||creditViewer!==viewer)){
                for(const credit of sourceCredits)creditApi.releaseStaticCredit(creditViewer.cesiumWidget?.creditDisplay,credit);
                sourceCredits=[];creditViewer=null;
            }
            if(needed&&!creditViewer&&C.Credit){
                creditViewer=viewer;sourceCredits=creditApi.weatherCredits(C);
                for(const credit of sourceCredits)creditApi.retainStaticCredit(viewer.cesiumWidget?.creditDisplay,credit);
            }
        }
        function legend(){
            const element=typeof document==='undefined'?null:document.getElementById('weather-legend');if(!element)return;
            const commands=[...records.values()].map(r=>r.command).filter(Boolean);
            element.hidden=!commands.length;
            element.textContent=commands.length?'Open-Meteo · Prognoseraster · CC BY 4.0\n'+commands.map(c=>`${definitions[c.kind].label} (${definitions[c.kind].units}) · ${c.timestampUtc}${expired(c)?' · ABGELAUFEN, ausgeblendet':''}\n${definitions[c.kind].legend} · ${c.gridSpacingMeters/1000} km Stichproben; ${c.missingSamples??0} fehlend`).join('\n')+'\nModellpunkte, keine gemessenen 3D-Wolken oder native Rasterauflösung.':'';
            if(element.style){element.style.maxHeight='104px';element.style.overflow='auto';element.style.whiteSpace='pre-line';}
        }
        function clock(){for(const r of records.values())r.source.show=!!r.command&&!expired(r.command);syncCredits();legend();viewerFn()?.scene.requestRender();}
        const timer=timers.setInterval(clock,15000);timer?.unref?.();
        async function replace(command){
            validate(command);if(disposed)throw new Error('Weather overlay is disposed');
            for(const [kind,r]of records)if(kind!==command.kind&&r.command&&r.command.timestampUtc!==command.timestampUtc)throw new Error('Weather layers require a common forecast time');
            const viewer=viewerFn();if(!viewer)throw new Error('Globe is not ready');
            let record=records.get(command.kind);
            if(record&&record.viewer!==viewer){record.viewer.dataSources.remove(record.source,true);records.delete(command.kind);record=null;}
            if(!record){const source=new C.CustomDataSource(`Open-Meteo ${command.kind} forecast samples`);source.show=false;record={source,viewer,revision:0,command:null,ready:viewer.dataSources.add(source)};records.set(command.kind,record);}
            const operation=++record.revision;
            try{await record.ready;}catch(error){viewer.dataSources.remove(record.source,true);if(records.get(command.kind)===record)records.delete(command.kind);throw error;}
            if(disposed||record.viewer!==viewerFn()||records.get(command.kind)!==record){viewer.dataSources.remove(record.source,true);return {superseded:true};}
            if(operation!==record.revision)return {superseded:true};
            record.source.entities.removeAll();
            for(let i=0;i<command.cells.length;i++){
                const cell=command.cells[i],[r,g,b]=rgb(command.kind,cell.value);
                record.source.entities.add({id:`weather-${command.kind}-${i}`,name:`Open-Meteo · ${definitions[command.kind].label}`,
                    polygon:{hierarchy:C.Cartesian3.fromDegreesArray([cell.west,cell.south,cell.east,cell.south,cell.east,cell.north,cell.west,cell.north]),
                        material:C.Color.fromBytes(r,g,b,Math.round(255*(command.opacity??.4))),classificationType:C.ClassificationType.TERRAIN,heightReference:C.HeightReference.CLAMP_TO_GROUND,outline:false},
                    properties:{sampledValue:cell.value,sampledAtUtc:command.timestampUtc,sampledSource:command.source,units:definitions[command.kind].units,
                        gridLatitudeDegrees:command.gridSpacingLatitudeDegrees,gridLongitudeDegrees:command.gridSpacingLongitudeDegrees}});
            }
            record.command=command;previous=command;record.source.show=!expired(command);
            syncCredits(viewer);
            legend();viewer.scene.requestRender();return {sampleCount:record.source.entities.values.length};
        }
        function clear(kind){
            for(const [id,r]of records)if(kind==null||kind===id){r.revision++;r.command=null;r.source.entities.removeAll();r.source.show=false;}
            previous=[...records.values()].map(r=>r.command).filter(Boolean).at(-1)??null;syncCredits();legend();viewerFn()?.scene.requestRender();return {};
        }
        function dispose(){if(disposed)return;disposed=true;clear();timers.clearInterval(timer);for(const r of records.values())r.viewer.dataSources.remove(r.source,true);records.clear();}
        return {replace,clear,dispose,get current(){return previous;},get activeKinds(){return [...records].filter(([,r])=>r.command).map(([k])=>k);}};
    }
    root.FPVWeatherOverlay={create,validate,rgb,definitions};
})(typeof globalThis!=='undefined'?globalThis:this);
