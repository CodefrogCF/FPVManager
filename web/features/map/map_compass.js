(function(root,factory){
    if(typeof module==='object'&&module.exports)module.exports=factory();
    else root.FPVMapCompass=factory();
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    function north(C,viewer){
        const camera=viewer.camera,scene=viewer.scene,canvas=scene.canvas;
        camera.cancelFlight();
        const ray=camera.getPickRay(new C.Cartesian2(canvas.clientWidth/2,canvas.clientHeight/2));
        const target=ray&&scene.globe.pick(ray,scene);
        if(target){
            const range=C.Cartesian3.distance(camera.positionWC,target);
            camera.lookAt(target,new C.HeadingPitchRange(0,camera.pitch,range));
            camera.lookAtTransform(C.Matrix4.IDENTITY);
        }else{
            camera.setView({orientation:{heading:0,pitch:camera.pitch,roll:0}});
        }
        scene.requestRender();
    }
    function create(C,viewer,button,{navigation,isEnabled=()=>true,language}={}){
        const needle=button.querySelector('[data-compass-needle]');
        let lastHeading,lastLabel,northSelected=false;
        function update(){
            const hidden=!isEnabled(),heading=viewer.camera.heading;
            if(button.hidden!==hidden)button.hidden=hidden;
            if(lastHeading===undefined||Math.abs(heading-lastHeading)>.001){
                needle.style.transform=`rotate(${-heading}rad)`;lastHeading=heading;
            }
            if(!navigation?.active||navigation.following)northSelected=false;
            const source=navigation?.active&&northSelected?'Standort verfolgen':'Nach Norden ausrichten';
            const label=language?.translate(source)??source;
            if(label!==lastLabel){button.title=label;button.setAttribute('aria-label',label);lastLabel=label;}
        }
        function click(){
            if(!isEnabled())return;
            if(navigation?.active){
                if(northSelected&&!navigation.following){
                    navigation.toggleFollow();northSelected=false;
                }else{
                    if(navigation.following)navigation.toggleFollow();
                    north(C,viewer);northSelected=true;
                }
            }else north(C,viewer);
            update();
        }
        button.addEventListener('click',click);
        const remove=viewer.scene.postRender.addEventListener(update);update();
        const removeLanguage=language?.onChange(update);
        return {dispose(){remove();removeLanguage?.();button.removeEventListener('click',click);}};
    }
    return {create,north};
});
