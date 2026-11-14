'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {createTerrainShaderWarmup}=require('../../web/flight_rendering.js');

function fixture({parallel=true,failLink=false,timeoutMs=12000,abortAt=Infinity,logDepth=true}={}){
    let time=0,bound={id:'original'},reads=0;
    const initial=bound,programs=new Set(),shaders=new Set(),cached=new Map(),derived=new Map(),binds=[];
    const controller=new AbortController();
    const gl={VERTEX_SHADER:1,FRAGMENT_SHADER:2,LINK_STATUS:3,CURRENT_PROGRAM:4,
        getExtension:()=>parallel?{COMPLETION_STATUS_KHR:5}:null,
        createShader(type){const shader={type};shaders.add(shader);return shader;},
        createProgram(){const program={readyAt:time+10,sources:[]};programs.add(program);return program;},
        shaderSource(shader,source){shader.source=source;},compileShader(){},
        attachShader(program,shader){program.sources.push(shader.source);},bindAttribLocation(){},linkProgram(){},flush(){},
        getProgramParameter(program,kind){
            if(kind===5)return time>=program.readyAt;
            assert.ok(time>=program.readyAt,'LINK_STATUS must never wait for compilation');return !failLink;
        },
        getParameter:()=>bound,useProgram(value){bound=value;},
        deleteShader(shader){assert.ok(shaders.delete(shader));},deleteProgram(program){assert.ok(programs.delete(program));}};
    function shader(key){
        return {_vertexShaderText:'vertex '+key,_fragmentShaderText:'fragment '+key,_attributeLocations:{position:0},
            _bind(){
                if(parallel){
                    const warmed=[...programs].find(p=>p.sources.includes(this._fragmentShaderText));
                    assert.ok(warmed&&time>=warmed.readyAt,'Cesium initialization follows parallel completion');
                }
                binds.push(key);this._program={key};bound=this._program;
            }};
    }
    const set={getShaderProgram(options){
        const key=JSON.stringify([options.surfaceTile.renderedMesh.encoding.quantization,options.enableFog,
            options.showUndergroundColor,options.numberOfDayTextures,options.enableLighting]);
        if(!cached.has(key))cached.set(key,shader(key));return cached.get(key);
    }};
    const options={frameState:{mode:3,context:{_gl:gl}},surfaceTile:{renderedMesh:{encoding:{quantization:0}},surfaceShader:undefined},
        enableFog:false,showUndergroundColor:false,numberOfDayTextures:1,enableLighting:true,
        get applyBrightness(){reads++;return false;}};
    const C={SceneMode:{SCENE3D:3},TerrainQuantization:{NONE:0,BITS12:1},DrawCommand:class{constructor(value){Object.assign(this,value);}},
        DerivedCommand:{createLogDepthCommand(command){
            if(!derived.has(command.shaderProgram))derived.set(command.shaderProgram,shader('log '+command.shaderProgram._fragmentShaderText));
            return {command:{shaderProgram:derived.get(command.shaderProgram)}};
        }}};
    const scene={globe:{_surfaceShaderSet:set},logarithmicDepthBuffer:logDepth,isDestroyed:()=>false,requestRender(){}};
    const warmup=createTerrainShaderWarmup(C,{scene},{now:()=>time,timeoutMs,
        pause:async ms=>{time+=Math.max(1,ms);set.getShaderProgram(options);if(time>=abortAt)controller.abort();}});
    return {warmup,scene,set,options,controller,binds,programs,shaders,shader,initial,get bound(){return bound;},get reads(){return reads;}};
}

test('flight preparation primes the Sun, Moon and bloom programs before the first upward maneuver',async()=>{
    const fixtureScene=fixture();
    const {scene,shader,warmup,controller,binds}=fixtureScene;
    const sunTexture={owner:{_commands:{}}};
    sunTexture.owner._commands.computeCommand=sunTexture;
    scene._environmentState={
        sunDrawCommand:{shaderProgram:shader('sun')},
        moonCommand:{shaderProgram:shader('moon')},
        sunComputeCommand:sunTexture,
    };
    scene.sunBloom=true;scene.sun={show:true};
    scene._view={passState:{viewport:{width:1440,height:900}}};
    let updates=0,computes=0;
    const bloom={_command:{shaderProgram:shader('bloom')}};
    scene._sunPostProcess={
        update(pass){assert.equal(pass,scene._view.passState);updates++;},
        _stages:{length:1,get:()=>bloom},
    };
    scene._computeEngine={execute(command){
        assert.equal(command,sunTexture);
        assert.ok(binds.includes('sun')&&binds.includes('moon')&&binds.includes('bloom'));
        command.owner._commands.computeCommand=undefined;computes++;
    }};
    await warmup.prepare(controller.signal);
    assert.equal(warmup.status().completed,43);
    assert.equal(updates,1);assert.equal(computes,1);
    await warmup.prepare(controller.signal);
    assert.equal(computes,1,'A consumed Sun texture command is not executed again');
});

test('terrain shaders finish before flight and retain exact bindings without first-use status waits',async()=>{
    const f=fixture();
    const progress=[];await f.warmup.prepare(f.controller.signal,p=>progress.push(p));
    assert.equal(f.warmup.status().completed,40);assert.equal(f.warmup.status().total,40);
    assert.ok(f.binds.every(key=>key.startsWith('log ')),'Log-depth derived programs are warmed, as used by the renderer');
    assert.equal(f.bound,f.initial);assert.equal(f.programs.size,0);assert.equal(f.shaders.size,0);
    assert.deepEqual(progress.at(-1),{completed:40,total:40});
    const count=f.binds.length;await f.warmup.prepare(f.controller.signal);
    assert.equal(f.binds.length,count,'Repeat flights reuse Cesium programs');
});

test('the instanced model render program is prepared before terrain variants',async()=>{
    const f=fixture();
    const command={shaderProgram:f.shader('vegetation')};
    await f.warmup.prepare(f.controller.signal,undefined,async signal=>{
        assert.equal(signal.aborted,false);
        return [command];
    });
    assert.equal(f.warmup.status().completed,41);
    assert.equal(f.binds[0],'log fragment vegetation');
});

test('a stalled local model seed obeys the same preparation deadline',async()=>{
    const f=fixture({timeoutMs:35});
    let signal;
    await f.warmup.prepare(f.controller.signal,undefined,abort=>{
        signal=abort;
        return new Promise(()=>{});
    });
    assert.equal(signal.aborted,true);
    assert.equal(f.warmup.status().preparing,false);
});

test('observing resident tiles does not copy shader options on every frame or change source options',()=>{
    const f=fixture();f.set.getShaderProgram(f.options);const reads=f.reads;
    for(let i=0;i<10000;i++)f.set.getShaderProgram(f.options);
    assert.equal(f.reads,reads,'No repeated per-tile option snapshot allocation');
    assert.equal(f.options.surfaceTile.renderedMesh.encoding.quantization,0);
    assert.equal(f.options.numberOfDayTextures,1);
});

test('cancelling preparation releases every pending GL object and never activates a partial program',async()=>{
    const f=fixture({abortAt:11});
    await assert.rejects(f.warmup.prepare(f.controller.signal),{name:'AbortError'});
    assert.equal(f.warmup.status().preparing,false);assert.equal(f.programs.size,0);assert.equal(f.shaders.size,0);
    assert.equal(f.bound,f.initial);
});

test('a time budget or failed speculative shader link leaves ordinary Cesium compilation available',async()=>{
    for(const options of [{timeoutMs:6},{failLink:true}]){
        const f=fixture(options);await f.warmup.prepare(f.controller.signal);
        assert.equal(f.binds.length,0);assert.equal(f.programs.size,0);assert.equal(f.shaders.size,0);
        assert.equal(f.warmup.status().preparing,false);assert.equal(f.bound,f.initial);
    }
});

test('runtimes without parallel compilation still prepare before control; unsupported renderers keep working',async()=>{
    const f=fixture({parallel:false,logDepth:false});await f.warmup.prepare(f.controller.signal);
    assert.equal(f.warmup.status().completed,40);assert.equal(f.bound,f.initial);
    const unsupported=createTerrainShaderWarmup({}, {scene:{globe:{}}});
    await unsupported.prepare();assert.equal(unsupported.status().supported,false);
});
