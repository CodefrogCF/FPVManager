(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVNavigationControls=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const clamp=v=>Math.max(-1,Math.min(1,Number.isFinite(v)?v:0))||0;
    function axis(v,zone=.15){v=clamp(v);return Math.abs(v)<=zone?0:Math.sign(v)*(Math.abs(v)-zone)/(1-zone);}
    function gamepadFrame(pad){
        if(!pad||!pad.connected)return null;
        if(pad.mapping!=='standard')return {unsupported:true};
        const button=i=>clamp(pad.buttons?.[i]?.value??0);
        return {forward:-axis(pad.axes?.[1]),right:axis(pad.axes?.[0]),
            yaw:axis(pad.axes?.[2]),pitch:axis(pad.axes?.[3]),
            vertical:clamp(button(7)-button(6)+button(5)-button(4)),
            reset:button(0)>.5,exit:button(1)>.5};
    }
    function bindControls(agent,canvas,panel,host=window,doc=document,options={}){
        const cleanups=[],stick=panel.querySelector('[data-stick]'),thumb=panel.querySelector('[data-stick-thumb]');
        const lookStick=doc.getElementById?.('look-stick'),lookThumb=doc.getElementById?.('look-thumb');
        let left=null,look=null,drag=null,f=0,r=0,yaw=0,pitch=0,vertical=0;
        let focused=false,armed=false,lastDevice=null,previousReset=false,previousExit=false,native=null,nativeAt=-Infinity;
        const now=()=>host.performance?.now?.()??Date.now();
        const keys=new Set(),verticalReleases=[];
        const isFpv=()=>['angle','acro'].includes(agent.status().mode);
        function listen(target,type,fn){target?.addEventListener(type,fn);cleanups.push(()=>target?.removeEventListener(type,fn));}
        function showDevice(message){if(lastDevice!==message){lastDevice=message;options.onDevice?.(message);}}
        function applyStick(){if(!isFpv()){agent.stick(f,r);agent.vertical?.(vertical);}}
        function resetLook(){look=drag=null;yaw=pitch=0;if(lookStick)lookStick.hidden=true;if(lookThumb)lookThumb.style.transform='translate(0px, 0px)';}
        function resetLeft(){left=null;f=r=0;if(thumb)thumb.style.transform='translate(0px, 0px)';applyStick();}
        function clear(){keys.clear();agent.clearKeys();resetLeft();resetLook();vertical=0;for(const release of verticalReleases)release();native=null;nativeAt=-Infinity;armed=false;previousReset=previousExit=false;applyStick();}
        function focus(value){if(focused===value)return;focused=value;if(!value)clear();agent.pause?.(!value);options.onFocus?.(value);}
        canvas.tabIndex=0;
        listen(canvas,'focus',()=>focus(true));listen(canvas,'blur',()=>focus(false));listen(host,'blur',()=>focus(false));
        listen(doc,'visibilitychange',()=>{if(doc.hidden){focus(false);agent.stop('View paused');}});
        listen(host,'pagehide',()=>agent.stop());
        const movement=new Set(['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','w','a','s','d','q','e']);
        listen(canvas,'keydown',event=>{
            if(!agent.status().active)return;
            const key=event.key.length===1?event.key.toLowerCase():event.key;
            if(movement.has(key)||['i','j','k','l'].includes(key)){event.preventDefault();keys.add(key);agent.key(key,true);}
            if(key==='Escape'){event.preventDefault();agent.stop();}
            if(key==='r'&&!event.repeat){event.preventDefault();agent.reset?.();}
        });
        listen(canvas,'keyup',event=>{
            const key=event.key.length===1?event.key.toLowerCase():event.key;
            if(movement.has(key)){event.preventDefault();}keys.delete(key);agent.key(key,false);
        });
        listen(canvas,'pointerdown',event=>{
            if(!agent.status().active||event.button!==0||look||drag)return;
            const rect=canvas.getBoundingClientRect();
            const touch=event.pointerType==='touch'||event.pointerType==='pen'||isFpv();
            if(touch&&event.clientX<rect.left+rect.width/2)return;
            canvas.focus();focus(true);canvas.setPointerCapture(event.pointerId);
            if(touch&&lookStick){
                event.preventDefault();look={id:event.pointerId,x:event.clientX,y:event.clientY};
                lookStick.style.left=`${event.clientX-rect.left-rect.width/2-50}px`;
                lookStick.style.top=`${event.clientY-rect.top-50}px`;lookStick.hidden=false;
            }else drag={id:event.pointerId,x:event.clientX,y:event.clientY};
        });
        listen(canvas,'pointermove',event=>{
            if(look?.id===event.pointerId){
                event.preventDefault();const x=clamp((event.clientX-look.x)/35),y=clamp((event.clientY-look.y)/35);
                yaw=axis(x,.1);pitch=axis(y,.1);const norm=Math.max(1,Math.hypot(yaw,pitch));yaw/=norm;pitch/=norm;
                if(lookThumb)lookThumb.style.transform=`translate(${yaw*35}px, ${pitch*35}px)`;
            }else if(drag?.id===event.pointerId){agent.look(event.clientX-drag.x,event.clientY-drag.y);drag.x=event.clientX;drag.y=event.clientY;}
        });
        for(const type of ['pointerup','pointercancel','lostpointercapture'])listen(canvas,type,event=>{
            if(look?.id===event.pointerId||drag?.id===event.pointerId)resetLook();
        });
        function moveLeft(event){
            if(left!==event.pointerId)return;event.preventDefault();
            const rect=stick.getBoundingClientRect(),radius=Math.max(1,rect.width*.35);
            let x=(event.clientX-rect.left-rect.width/2)/radius,y=(event.clientY-rect.top-rect.height/2)/radius;
            const norm=Math.hypot(x,y);if(norm<.12)x=y=0;else{x*=Math.min(1,norm)/norm;y*=Math.min(1,norm)/norm;}
            f=-y;r=x;applyStick();if(thumb)thumb.style.transform=`translate(${x*radius}px, ${y*radius}px)`;
        }
        listen(stick,'pointerdown',event=>{
            if(!agent.status().active||event.button!==0||left!=null)return;
            event.preventDefault();canvas.focus();focus(true);left=event.pointerId;stick.setPointerCapture(event.pointerId);moveLeft(event);
        });
        listen(stick,'pointermove',moveLeft);
        for(const type of ['pointerup','pointercancel','lostpointercapture'])listen(stick,type,event=>{if(left===event.pointerId)resetLeft();});
        for(const button of panel.querySelectorAll?.('[data-vertical]')??[]){
            let pointer=null;
            verticalReleases.push(()=>{pointer=null;});
            listen(button,'pointerdown',event=>{if(!agent.status().active||pointer!=null||event.button!==0)return;
                event.preventDefault();canvas.focus();focus(true);pointer=event.pointerId;button.setPointerCapture(pointer);
                vertical=Number(button.dataset.vertical);applyStick();});
            for(const type of ['pointerup','pointercancel','lostpointercapture'])listen(button,type,event=>{
                if(pointer===event.pointerId){pointer=null;vertical=0;applyStick();}
            });
        }
        listen(host,'gamepaddisconnected',()=>{armed=false;agent.clearKeys();applyStick();showDevice('Controller disconnected');});
        const dispose=()=>{clear();agent.stop();for(const remove of cleanups)remove();options.onFocus?.(false);};
        dispose.reset=clear;
        dispose.native=frame=>{
            if(!focused||!agent.status().active)return;
            const names=['forward','right','yaw','pitch','vertical'];
            if(!frame||!names.every(k=>Number.isFinite(frame[k])&&Math.abs(frame[k])<=1)||
                !['reset','exit','connected'].every(k=>typeof frame[k]==='boolean'))return;
            native={...frame};nativeAt=now();
            if(frame.connected===false){armed=false;agent.clearKeys();showDevice('Controller disconnected');}
        };
        dispose.tick=seconds=>{
            if(!agent.status().active){clear();return;}
            if(doc.activeElement!==undefined)focus(!doc.hidden&&doc.activeElement===canvas&&(doc.hasFocus?.()??true));
            if(!focused)return;
            let pad=null;
            if(now()-nativeAt<250)pad=native?.connected===false?null:native;
            else{try{pad=Array.from(host.navigator?.getGamepads?.()??[]).filter(p=>p?.connected).map(gamepadFrame).find(p=>!p.unsupported)??null;
                if(!pad&&Array.from(host.navigator?.getGamepads?.()??[]).some(p=>p?.connected))showDevice('Unmapped controller: standard mapping required');
            }catch(_){showDevice('Gamepad unavailable in this browser');}}
            if(pad){
                const neutral=['forward','right','yaw','pitch','vertical'].every(k=>Math.abs(pad[k])<.02)&&!pad.reset&&!pad.exit;
                if(!armed&&neutral)armed=true;
                showDevice(armed?'Controller ready':'Release controller sticks to enable');
                if(!armed)pad=null;
            }else{armed=false;}
            if(pad?.exit&&!previousExit)agent.stop();
            else if(pad?.reset&&!previousReset)agent.reset?.();
            previousExit=!!pad?.exit;previousReset=!!pad?.reset;
            const dt=Number.isFinite(seconds)?Math.max(0,Math.min(.1,seconds)):0;
            if(isFpv()){
                agent.flightInput({throttle:clamp(f+(pad?.forward??0)+vertical+(pad?.vertical??0)),
                    yaw:clamp(r+(pad?.right??0)),pitch:clamp(-pitch-(pad?.pitch??0)),roll:clamp(yaw+(pad?.yaw??0))});
                return;
            }
            agent.stick(clamp(f+(pad?.forward??0)),clamp(r+(pad?.right??0)));
            agent.vertical?.(clamp(vertical+(pad?.vertical??0)));
            const horizontal=yaw+(pad?.yaw??0)+Number(keys.has('l'))-Number(keys.has('j'));
            const elevation=pitch+(pad?.pitch??0)+Number(keys.has('k'))-Number(keys.has('i'));
            agent.look(clamp(horizontal)*dt*350,clamp(elevation)*dt*350);
        };
        return dispose;
    }
    return {bindControls,gamepadFrame,axis};
});
