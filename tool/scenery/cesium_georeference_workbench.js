'use strict';
(async () => {
    const C = window.Cesium;
    const A = window.FPVSceneryAlignment;
    const P = window.FPVMapProviders;
    const $ = id => document.getElementById(id);
    const status = (message, code = 'info') => { $('status').textContent = message; $('status').dataset.code = code; };
    let config = A.DEFAULT;
    let referenceDefault = A.DEFAULT;
    let viewer = null;
    let model = null;
    let regionalLayers = [];
    let visible = true;
    let mapMode = 'navigate';
    let ruler = [];
    let measuredM = null;
    let measurementEntities = [];
    let generation = 0;
    let pairs=[], sourcePoint=null, fitPrevious=null, controlEntities=[], regionEntities=[], draft=[], regionKind=null;
    let buildingRegions=[],terrainRegions=[], betaTiles=null,betaCredit=null,betaWanted=false,betaRevision=0;
    function showModelForMode(){for(const e of controlEntities)e.show=mapMode!=='source'&&mapMode!=='target';for(const e of regionEntities)e.show=mapMode!=='source'&&mapMode!=='target';if(betaTiles)betaTiles.show=!['source','region'].includes(mapMode);if(!model)return;model.show=mapMode==='source'?true:['target','region'].includes(mapMode)?false:visible;
        model.color=new C.Color(1,1,1,mapMode==='source'?1:config.opacity);viewer.scene.requestRender();}
    function pairText(extra=''){ $('pairStatus').textContent=`${pairs.length} Punktpaare${extra?' · '+extra:''}`; }
    function regionText(){ $('regionStatus').textContent=`Gebäude: ${buildingRegions.length} · Gelände: ${terrainRegions.length} · Entwurf: ${draft.length} Punkte`; }
    function redrawRegions(){
        for(const e of regionEntities)viewer.entities.remove(e);regionEntities=[];
        for(const [polys,color] of [[buildingRegions,C.Color.ORANGE],[terrainRegions,C.Color.CYAN],[draft.length?[draft]:[],C.Color.YELLOW]]){
            for(const poly of polys){if(!poly.length)continue;const points=poly.map(p=>C.Cartesian3.fromDegrees(p[0],p[1],0));
                if(points.length>1)regionEntities.push(viewer.entities.add({polyline:{positions:[...points,...(poly===draft?[]:[points[0]])],width:3,material:color,depthFailMaterial:color}}));
                for(const position of points)regionEntities.push(viewer.entities.add({position,point:{pixelSize:5,color,disableDepthTestDistance:Number.POSITIVE_INFINITY}}));
            }
        }
        regionText();viewer.scene.requestRender();
    }
    function redrawControls(){
        for(const e of controlEntities)viewer.entities.remove(e);controlEntities=[];
        for(const [i,p] of pairs.entries()){
            const position=C.Cartesian3.fromDegrees(p.target.longitude,p.target.latitude,0);
            controlEntities.push(viewer.entities.add({position,point:{pixelSize:7,color:C.Color.LIME,disableDepthTestDistance:Number.POSITIVE_INFINITY},label:{text:String(i+1),font:'12px sans-serif',pixelOffset:new C.Cartesian2(8,-12),disableDepthTestDistance:Number.POSITIVE_INFINITY}}));
        }
    }
    function exportEdit(){return A.normalizeEdit({alignment:{...config,opacity:1},buildingRegions,terrainRegions,heightOffsetM:Number($('heightOffsetM').value),replaceBuildings:$('replaceBuildings').checked,clipTerrain:$('clipTerrain').checked},config);}
    function exitCapture(){mapMode='navigate';sourcePoint=null;regionKind=null;draft=[];showModelForMode();redrawRegions();}
    function getSource(pixel){
        if(!viewer.scene.pickPositionSupported)throw Error('Depth picking unavailable; use numeric alignment');
        const hit=viewer.scene.pick(pixel);
        if(hit?.primitive!==model)throw Error('Bitte eine sichtbare Scan-Oberfläche anklicken');
        const world=viewer.scene.pickPosition(pixel);if(!world)throw Error('No depth position');
        // modelMatrix does not include Model.scale. Cesium has already applied
        // the glTF axis correction; invert only the geographic placement.
        const inverse=C.Matrix4.inverseTransformation(model.modelMatrix,new C.Matrix4());
        const local=C.Matrix4.multiplyByPoint(inverse,world,new C.Cartesian3());
        return {x:local.x/config.scale,y:local.y/config.scale};
    }
    function getTarget(pixel){
        if(betaTiles?.show&&viewer.scene.pickPositionSupported){
            const hit=viewer.scene.pick(pixel);
            if(hit?.primitive===betaTiles||hit?.tileset===betaTiles){const world=viewer.scene.pickPosition(pixel);if(world){const c=C.Cartographic.fromCartesian(world);return {longitude:C.Math.toDegrees(c.longitude),latitude:C.Math.toDegrees(c.latitude)};}}
        }
        return pickGround(pixel);
    }
    async function toggleBeta(){
        betaWanted=!betaWanted;const rev=++betaRevision;
        if(!betaWanted){
            if(betaTiles){viewer.scene.primitives.remove(betaTiles);betaTiles=null;}
            if(betaCredit){viewer.cesiumWidget.creditDisplay.removeStaticCredit(betaCredit);betaCredit=null;}
            $('betaBuildings').textContent='LoD2 (Beta-Test) einblenden';
            return;
        }
        const R=window.FPVRegional3D;
        if(!R.installRuntimeOnlyTransport(C)) {
            betaWanted=false;status('BKG-Laden abgebrochen: HTTP-No-Store-Schutz nicht verfügbar','error');return;
        }
        const url=R.buildingsFlatUrl;
        const useRelay=new URLSearchParams(window.location.search).get('lod2')==='relay';
        const requestUrl=useRelay?new URL('/__bkg_lod2__/lod2_4326_null.json',window.location.origin).href:url;
        $('betaBuildings').textContent='LoD2-Laden abbrechen / ausblenden';
        status('LoD2 (Höhe Null) wird geladen …'+(useRelay?' · lokaler Test-Relay':''),'loading');
        let t=null;
        try{
            t=await C.Cesium3DTileset.fromUrl(requestUrl,{enableCollision:false,maximumScreenSpaceError:8,showCreditsOnScreen:true});
            if(rev!==betaRevision){t.destroy();return;}
            viewer.scene.primitives.add(t);
            betaTiles=t;t.show=!['source','region'].includes(mapMode);
            let reportedTileError=false;
            t.tileFailed?.addEventListener?.(failure=>{
                if(rev!==betaRevision||reportedTileError)return;
                reportedTileError=true;
                console.error('LoD2 content request failed',failure);
                status('LoD2: einzelne Kachel fehlgeschlagen · '+R.describeRequestError(failure,failure.url||requestUrl),'error');
            });
            betaCredit=new C.Credit('© GeoBasis-DE/BKG 2026 · combined with other sources · test only',true);
            viewer.cesiumWidget.creditDisplay.addStaticCredit(betaCredit);
            $('betaBuildings').textContent='LoD2 (Beta-Test) ausblenden';
            status('LoD2-Tileset geladen (Höhe Null) · Kacheln werden nachgeladen · © GeoBasis-DE/BKG 2026','info');
        }catch(e){
            if(rev!==betaRevision)return;
            betaWanted=false;
            if(betaTiles){viewer.scene.primitives.remove(betaTiles);betaTiles=null;}
            else if(t&&!t.isDestroyed?.())t.destroy();
            if(betaCredit){viewer.cesiumWidget.creditDisplay.removeStaticCredit(betaCredit);betaCredit=null;}
            $('betaBuildings').textContent='LoD2 (Beta-Test) erneut versuchen';
            console.error('LoD2 root request failed',requestUrl,e);
            status('LoD2 nicht verfügbar · '+R.describeRequestError(e,requestUrl)+(useRelay?' · Relay-Konsole prüfen':' · optional lokalen Relay verwenden (?lod2=relay)')+' · Orthofoto-Ausrichtung weiterhin möglich','error');
        }
    }
    const editable = ['longitude', 'latitude', 'ellipsoidHeightM', 'scale', 'rotationDeg'];
    const saveLocal = () => { try { localStorage.setItem(A.STORAGE_KEY, JSON.stringify(A.exportDocument(config))); } catch (_) {} };
    const showInputs = () => {
        for (const key of editable) $(key).value = String(config[key]);
        $('opacity').value = String(config.opacity);
        $('scaleSlider').value = String(Math.min(30, Math.max(0.5, config.scale)));
        $('rotationSlider').value = String(Math.min(180, Math.max(-180, config.rotationDeg)));
    };
    function apply(next, {save = true} = {}) {
        config = A.normalize(next);
        showInputs();
        if (model) { A.apply(C, model, config); showModelForMode(); }
        if (save) saveLocal();
    }
    function reportError(error) { status('FEHLER: ' + String(error?.message || error), 'error'); console.error(error); }
    function mode(next) {
        sourcePoint=null;draft=[];regionKind=null;mapMode = mapMode === next ? 'navigate' : next;showModelForMode();redrawRegions();
        $('anchorMode').classList.toggle('active', mapMode === 'anchor');
        $('rulerMode').classList.toggle('active', mapMode === 'ruler');
        $('anchorMode').textContent = `Anker setzen: ${mapMode === 'anchor' ? 'An' : 'Aus'}`;
        $('rulerMode').textContent = `Strecke messen: ${mapMode === 'ruler' ? 'An' : 'Aus'}`;
        $('maphint').textContent = mapMode === 'anchor' ? 'Jetzt auf den gewünschten Modell-Ankerpunkt im Orthofoto klicken.'
            : mapMode === 'ruler' ? 'Zwei Punkte auf dem Orthofoto anklicken, um die Bodenentfernung zu messen.'
            : 'Mausrad: Zoomen · Ziehen: Kamera bewegen · Pfeiltasten: Modell verschieben.';
    }
    function clearMeasurement() {
        ruler = []; measuredM = null; $('applyRuler').disabled = true;
        $('measurement').textContent = 'Noch keine Strecke gemessen.';
        for (const e of measurementEntities) viewer?.entities.remove(e);
        measurementEntities = [];
    }
    function view(top) {
        const target = C.Cartesian3.fromDegrees(config.longitude, config.latitude, 0);
        viewer.camera.lookAt(target, new C.HeadingPitchRange(0,
            C.Math.toRadians(top ? -89.9 : -45), top ? 360 : 450));
        viewer.camera.lookAtTransform(C.Matrix4.IDENTITY);
    }
    function setLayers(style) {
        for (const layer of regionalLayers) viewer.imageryLayers.remove(layer, true);
        regionalLayers = [];
        try {
            const providers = P.createAdapters(C);
            for (const provider of providers.regionalImagery(style)) {
                const layer = viewer.imageryLayers.addImageryProvider(provider);
                regionalLayers.push(layer);
                provider.errorEvent?.addEventListener?.(e => console.warn('Regional WMS error', e));
            }
        } catch (error) { reportError(error); }
        viewer.scene.requestRender();
    }
    function pickGround(pixel) {
        const ray = viewer.camera.getPickRay(pixel);
        const point = ray && viewer.scene.globe.pick(ray, viewer.scene);
        if (!point) return null;
        const cart = C.Cartographic.fromCartesian(point);
        return {longitude:C.Math.toDegrees(cart.longitude),latitude:C.Math.toDegrees(cart.latitude)};
    }
    function addMeasurePoint(pt) {
        if (ruler.length === 2) clearMeasurement();
        ruler.push(pt);
        measurementEntities.push(viewer.entities.add({position:C.Cartesian3.fromDegrees(pt.longitude,pt.latitude,0),
            point:{pixelSize:9,color:C.Color.CYAN,outlineWidth:1,outlineColor:C.Color.BLACK,disableDepthTestDistance:Number.POSITIVE_INFINITY}}));
        if (ruler.length === 2) {
            const geo = new C.EllipsoidGeodesic(C.Cartographic.fromDegrees(ruler[0].longitude,ruler[0].latitude),
                C.Cartographic.fromDegrees(ruler[1].longitude,ruler[1].latitude));
            measuredM = geo.surfaceDistance;
            measurementEntities.push(viewer.entities.add({polyline:{positions:ruler.map(p=>C.Cartesian3.fromDegrees(p.longitude,p.latitude,0)),width:2,
                material:C.Color.CYAN,clampToGround:false}}));
            $('measurement').textContent = `Strecke: ${measuredM.toFixed(2)} m\n` +
                `Richtwert Maßstab: ${(measuredM / 16.8).toFixed(3)} (nur bei passender Scan-Hauptachse)`;
            $('applyRuler').disabled = false;
        } else $('measurement').textContent = 'Erster Punkt gesetzt. Zweiten Kartenpunkt anklicken.';
    }
    try {
        if (!C || !A || !P) throw Error('Cesium oder FPV-Kartenmodule fehlen');
        const canvas = document.createElement('canvas');
        if (!canvas.getContext('webgl2') && !canvas.getContext('webgl')) throw Error('WebGL ist nicht verfügbar');
        try {
            const response=await fetch('../../web/assets/scenery/catalog.json',{cache:'no-store'});
            if(response.ok){
                const catalog=await response.json();
                const item=catalog.sceneries?.find(s=>s.id==='de-bb-ruedersdorf-chemical-plant');
                if(item?.alignment){
                    config=A.normalize({...item.alignment,opacity:0.62});
                    const edit=A.normalizeEdit(item,config);
                    buildingRegions=edit.buildingRegions;terrainRegions=edit.terrainRegions;
                    $('replaceBuildings').checked=edit.replaceBuildings;
                    $('clipTerrain').checked=edit.clipTerrain;
                    $('heightOffsetM').value=edit.heightOffsetM;
                }
            }
        }catch(e){console.warn('Reference alignment unavailable; using fallback',e);}
        // The Workbench intentionally uses a flat ellipsoid and the LoD2
        // _null buildings; its 34.25-m visual anchor is NOT the ellipsoid
        // height of the production scene on BKG DGM5 terrain. Keep the two
        // reference frames separate rather than silently copying either one.
        try {
            const response=await fetch('../../web/assets/scenery/reference_alignment.json',{cache:'no-store'});
            if(response.ok){
                const preview=await response.json();
                config=A.normalize({...preview,opacity:0.62});
            }
        }catch(e){console.warn('Flat-ellipsoid preview alignment unavailable',e);}
        referenceDefault = config;
        try { const saved = localStorage.getItem(A.STORAGE_KEY); if (saved) config = A.normalize(JSON.parse(saved)); }
        catch (e) { console.warn('Local alignment could not be restored',e); }
        viewer = new C.Viewer('scene', {animation:false,timeline:false,baseLayerPicker:false,geocoder:false,
            homeButton:false,sceneModePicker:false,navigationHelpButton:false,infoBox:false,selectionIndicator:false,
            terrainProvider:new C.EllipsoidTerrainProvider(), baseLayer:false, requestRenderMode:false});
        // Diagnostic alignment against a flat WGS84 ellipsoid. Do not use a
        // Swiss-only terrain provider outside its spatial coverage.
        viewer.scene.globe.depthTestAgainstTerrain = false;
        viewer.scene.globe.baseColor = C.Color.DARKGRAY;
        P.prepareCredits?.(C);
        P.configureCredits?.(C,viewer);
        setLayers('satellite');
        if (!regionalLayers.length) status('Amtliche Online-Karte konnte nicht aktiviert werden (Netzwerk/Provider prüfen)', 'error');
        apply(config, {save:false});
        redrawRegions();
        view(true);
        const loadGeneration = ++generation;
        status('Brandenburg-Orthofoto aktiviert · lokales GLB wird geladen …', 'loading');
        model = await C.Model.fromGltfAsync({
            url:'./local_reference.glb', modelMatrix:A.modelMatrix(C,config), scale:config.scale,
            allowPicking:true, shadows:C.ShadowMode.DISABLED
        });
        if (generation !== loadGeneration) return;
        viewer.scene.primitives.add(model);
        A.apply(C,model,config);
        const started = performance.now();
        while (!model.ready) {
            if (performance.now() - started > 45000) throw Error('GLB rendering initialization timed out');
            await new Promise(resolve=>requestAnimationFrame(resolve));
        }
        status('GLB gerendert · Position, Maßstab und Rotation sind noch NICHT geodätisch verifiziert.', 'success');
        for (const key of editable) $(key).addEventListener('change', event => {
            try { apply({...config,[key]:Number(event.target.value)}); } catch (e) { reportError(e); showInputs(); }
        });
        for (const [id,key] of [['scaleSlider','scale'],['rotationSlider','rotationDeg'],['opacity','opacity']])
            $(id).addEventListener('input', event => { try { apply({...config,[key]:Number(event.target.value)}); } catch (e) {reportError(e);} });
        document.querySelectorAll('[data-nudge]').forEach(button => button.addEventListener('click', () => {
            const [east,north]=button.dataset.nudge.split(',').map(Number);
            try { apply(A.nudge(config,east,north)); } catch(e){reportError(e);}
        }));
        document.addEventListener('keydown', event => {
            if (event.target.closest('input,select,textarea') || event.altKey || event.metaKey) return;
            const dirs={ArrowUp:[0,1],ArrowDown:[0,-1],ArrowLeft:[-1,0],ArrowRight:[1,0]};
            const d=dirs[event.key]; if (!d) return;
            event.preventDefault();
            const step=event.shiftKey?0.1:event.ctrlKey?5:1;
            try { apply(A.nudge(config,d[0]*step,d[1]*step)); } catch(e){reportError(e);}
        });
        $('style').addEventListener('change', e => setLayers(e.target.value));
        $('top').addEventListener('click', () => view(true));
        $('oblique').addEventListener('click', () => view(false));
        $('modelToggle').addEventListener('click', () => {
            exitCapture();visible = !visible; showModelForMode();if(betaTiles)betaTiles.show=!['source','region'].includes(mapMode);
            $('modelToggle').textContent=visible?'Modell ausblenden':'Modell einblenden';
            $('modelToggle').setAttribute('aria-pressed',String(visible));
        });
        $('anchorMode').addEventListener('click',()=>mode('anchor'));
        $('rulerMode').addEventListener('click',()=>mode('ruler'));
        $('clearRuler').addEventListener('click',clearMeasurement);
        $('applyRuler').addEventListener('click',()=>{
            if (measuredM == null) return;
            try { apply({...config,scale:Math.min(1000,Math.max(.01,measuredM/16.8))}); }
            catch(e){reportError(e);}
        });
        $('pairStart').addEventListener('click',()=>{exitCapture();mapMode='source';if(betaTiles)betaTiles.show=false;showModelForMode();pairText('Scan-Punkt anklicken');});
        $('pairUndo').addEventListener('click',()=>{exitCapture();pairs.pop();redrawControls();pairText();if(betaTiles)betaTiles.show=!['source','region'].includes(mapMode);});
        $('pairClear').addEventListener('click',()=>{exitCapture();pairs=[];redrawControls();pairText();if(betaTiles)betaTiles.show=!['source','region'].includes(mapMode);});
        $('pairFit').addEventListener('click',()=>{try{const fit=A.fitControlPoints(config,pairs);exitCapture();fitPrevious=config;apply(fit.alignment);if(betaTiles)betaTiles.show=!['source','region'].includes(mapMode);pairText(`RMS ${fit.rmsM.toFixed(2)} m · Max ${fit.maxM.toFixed(2)} m · Paare: ${fit.residualsM.map(v=>v.toFixed(2)).join(', ')} m`);}catch(e){reportError(e);}});
        $('undoFit').addEventListener('click',()=>{if(fitPrevious){apply(fitPrevious);fitPrevious=null;pairText('Berechnung rückgängig');}});
        $('betaBuildings').addEventListener('click',toggleBeta);
        for(const [id,kind] of [['drawBuildings','building'],['drawTerrain','terrain']])$(id).addEventListener('click',()=>{exitCapture();view(true);mapMode='region';regionKind=kind;showModelForMode();if(betaTiles)betaTiles.show=false;regionText();status('Polygonpunkte nacheinander anklicken, anschließend abschließen');});
        $('finishRegion').addEventListener('click',()=>{try{if(!regionKind)throw Error('Bitte zuerst ein Polygon beginnen');const list=regionKind==='building'?buildingRegions:terrainRegions;
            const next=A.normalizeRegions([...list,draft],config);if(regionKind==='building')buildingRegions=next;else terrainRegions=next;exitCapture();if(betaTiles)betaTiles.show=!['source','region'].includes(mapMode);}catch(e){reportError(e);}});
        $('clearRegions').addEventListener('click',()=>{buildingRegions=[];terrainRegions=[];exitCapture();if(betaTiles)betaTiles.show=!['source','region'].includes(mapMode);});
        $('draftBuildings').addEventListener('click',async()=>{try{
            const r=await fetch('../../web/assets/scenery/catalog.json',{cache:'no-store'});if(!r.ok)throw Error('Scenery catalog unavailable');
            const catalog=await r.json();const item=catalog.sceneries.find(s=>s.id==='de-bb-ruedersdorf-chemical-plant');
            if(!item?.draftBuildingFootprintLocal)throw Error('No local footprint proposal');
            buildingRegions=[A.projectFootprint(item.draftBuildingFootprintLocal,config)];$('replaceBuildings').checked=false;exitCapture();
            status('Scan-Umriss als Entwurf geladen. Abdeckung prüfen, erst danach Gebäude-Ersatz aktivieren.','info');
        }catch(e){reportError(e);}});
        $('copyEdit').addEventListener('click',async()=>{try{await navigator.clipboard.writeText(JSON.stringify(exportEdit(),null,2));status('Scenery-Konfiguration kopiert','success');}catch(e){reportError(e);}});
        $('downloadEdit').addEventListener('click',()=>{try{const url=URL.createObjectURL(new Blob([JSON.stringify(exportEdit(),null,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='scenery_edit.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}catch(e){reportError(e);}});
        viewer.screenSpaceEventHandler.setInputAction(event => {
            if(mapMode==='navigate') return;
            if(mapMode==='source'){try{sourcePoint=getSource(event.position);mapMode='target';if(betaTiles)betaTiles.show=!['source','region'].includes(mapMode);showModelForMode();pairText('Denselben Kartenpunkt anklicken');}catch(e){reportError(e);}return;}
            if(mapMode==='target'){try{const target=getTarget(event.position);if(!target)throw Error('Kein Kartenpunkt');if(pairs.length>=64)throw Error('Maximum 64 point pairs');pairs.push({source:sourcePoint,target});exitCapture();redrawControls();pairText('Paar gespeichert');}catch(e){reportError(e);}return;}
            if(mapMode==='region'){const pt=pickGround(event.position);if(pt&&draft.length<64){draft.push([pt.longitude,pt.latitude]);redrawRegions();}return;}
            const ground=pickGround(event.position);
            if(!ground){status('Kein Orthofoto-/Ellipsoidpunkt unter dem Cursor gefunden','error');return;}
            if(mapMode==='anchor'){try {apply({...config,...ground});} catch(e){reportError(e);} mode('anchor');}
            else if(mapMode==='ruler') addMeasurePoint(ground);
        }, C.ScreenSpaceEventType.LEFT_CLICK);
        $('copyJson').addEventListener('click',async()=>{
            try { await navigator.clipboard.writeText(JSON.stringify(A.exportDocument(config),null,2)); status('Alignment-JSON in Zwischenablage kopiert', 'success'); }
            catch(e){ reportError(e); }
        });
        $('downloadJson').addEventListener('click',()=>{
            const blob = new Blob([JSON.stringify(A.exportDocument(config),null,2)+'\n'],{type:'application/json'});
            const url=URL.createObjectURL(blob); const link=document.createElement('a');
            link.href=url;link.download='reference_alignment.json';document.body.appendChild(link);link.click();link.remove();
            setTimeout(()=>URL.revokeObjectURL(url),2000);
            status('reference_alignment.json gespeichert · kein Vermessungsnachweis', 'success');
        });
        $('loadJson').addEventListener('click',()=>$('jsonFile').click());
        $('jsonFile').addEventListener('change',async e=>{
            const file=e.target.files?.[0]; if(!file)return;
            try{if(file.size>128*1024)throw Error('JSON-Datei zu groß'); const raw=JSON.parse(await file.text());if(raw.alignment){const edit=A.normalizeEdit(raw,config);apply(edit.alignment);buildingRegions=edit.buildingRegions;terrainRegions=edit.terrainRegions;$('replaceBuildings').checked=edit.replaceBuildings;$('clipTerrain').checked=edit.clipTerrain;$('heightOffsetM').value=edit.heightOffsetM;exitCapture();}else apply(A.normalize(raw));pairs=[];redrawControls();pairText();status('Alignment-JSON importiert', 'success');}
            catch(err){reportError(err);}finally{e.target.value='';}
        });
        $('reset').addEventListener('click',()=>{
            apply(referenceDefault);clearMeasurement();status('Zurückgesetzt · experimentelle Referenzausrichtung', 'info');
        });
    } catch(error) {reportError(error);}
})();
