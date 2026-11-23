(function(root,factory){
    const api=factory(typeof module==='object'&&module.exports?require('./controller_input.js'):root.FPVControllerInput);
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVNavigationControls=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(controller){
    'use strict';
    const clamp=v=>Math.max(-1,Math.min(1,Number.isFinite(v)?v:0))||0;
    const {axis,gamepadFrame}=controller;
    function bindControls(agent,canvas,panel,host=window,doc=document,options={}){
        const cleanups=[],stick=panel.querySelector('[data-stick]'),thumb=panel.querySelector('[data-stick-thumb]');
        const lookStick=doc.getElementById?.('look-stick'),lookThumb=doc.getElementById?.('look-thumb');
        let left=null,look=null,drag=null,f=0,r=0,yaw=0,pitch=0,vertical=0;
        let focused=false,armed=false,lastDevice=null,previousReset=false,previousExit=false,native=null,nativeAt=-Infinity;
        let lastConfiguration=null,lastSource=null;
        let gapSince=null,gapExpired=false;
        let nativeEstablished=false;
        let touchVisible=true,lastMode=null;
        const recoveryWindowMs=750;
        const now=()=>host.performance?.now?.()??Date.now();
        const keys=new Set(),verticalReleases=[];
        const isFpv=()=>['angle','acro'].includes(agent.status().mode);
        function listen(target,type,fn){target?.addEventListener(type,fn);cleanups.push(()=>target?.removeEventListener(type,fn));}
        function showDevice(message){if(lastDevice!==message){lastDevice=message;options.onDevice?.(message);}}
        function interruption(reason){options.onInterruption?.(reason);}
        function freshInput(){
            if(gapSince!==null&&now()-gapSince>=recoveryWindowMs){
                if(!gapExpired)interruption('Controller input timed out');
                armed=false;
            }
            gapSince=null;gapExpired=false;
        }
        function disconnected(){
            armed=false;lastSource=null;gapSince=null;gapExpired=false;
            previousReset=previousExit=false;agent.clearKeys();applyStick();
            showDevice('Controller disconnected');interruption('Controller disconnected');
        }
        function applyStick(){if(!isFpv()){agent.stick(f,r);agent.vertical?.(vertical);}}
        function resetLook(){look=drag=null;yaw=pitch=0;if(lookThumb)lookThumb.style.transform='translate(0px, 0px)';}
        function resetLeft(){left=null;f=r=0;if(thumb)thumb.style.transform='translate(0px, 0px)';applyStick();}
        function releaseTouch(){resetLeft();resetLook();vertical=0;for(const release of verticalReleases)release();applyStick();}
        function syncTouch(){
            const state=agent.status();
            if(state.mode!==lastMode){releaseTouch();lastMode=state.mode;}
            panel.hidden=!state.active||!touchVisible;
            if(lookStick)lookStick.hidden=panel.hidden;
            const buttons=doc.getElementById?.('flight-buttons');if(buttons)buttons.hidden=panel.hidden||state.mode!=='gps';
        }
        function clear(){keys.clear();agent.clearKeys();resetLeft();resetLook();vertical=0;for(const release of verticalReleases)release();native=null;nativeAt=-Infinity;nativeEstablished=false;armed=false;lastSource=null;gapSince=null;gapExpired=false;previousReset=previousExit=false;applyStick();showDevice('');}
        function focus(value){if(focused===value)return;focused=value;if(!value){clear();interruption('View lost focus');}agent.pause?.(!value);options.onFocus?.(value);}
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
            if(!agent.status().active||event.button!==0||look||drag||event.pointerType==='touch'||event.pointerType==='pen'||isFpv())return;
            canvas.focus();focus(true);canvas.setPointerCapture(event.pointerId);
            drag={id:event.pointerId,x:event.clientX,y:event.clientY};
        });
        listen(canvas,'pointermove',event=>{
            if(drag?.id===event.pointerId){agent.look(event.clientX-drag.x,event.clientY-drag.y);drag.x=event.clientX;drag.y=event.clientY;}
        });
        for(const type of ['pointerup','pointercancel','lostpointercapture'])listen(canvas,type,event=>{
            if(drag?.id===event.pointerId)resetLook();
        });
        function moveLook(event){
            if(look!==event.pointerId)return;event.preventDefault();
            const rect=lookStick.getBoundingClientRect(),radius=Math.max(1,rect.width*.35);
            yaw=axis(clamp((event.clientX-rect.left-rect.width/2)/radius),.1);
            pitch=axis(clamp((event.clientY-rect.top-rect.height/2)/radius),.1);
            const norm=Math.max(1,Math.hypot(yaw,pitch));yaw/=norm;pitch/=norm;
            if(lookThumb)lookThumb.style.transform=`translate(${yaw*radius}px, ${pitch*radius}px)`;
        }
        listen(lookStick,'pointerdown',event=>{
            if(!touchVisible||!agent.status().active||event.button!==0||look!==null)return;
            event.preventDefault();canvas.focus();focus(true);look=event.pointerId;lookStick.setPointerCapture(event.pointerId);moveLook(event);
        });
        listen(lookStick,'pointermove',moveLook);
        for(const type of ['pointerup','pointercancel','lostpointercapture'])listen(lookStick,type,event=>{if(look===event.pointerId)resetLook();});
        function moveLeft(event){
            if(left!==event.pointerId)return;event.preventDefault();
            const rect=stick.getBoundingClientRect(),radius=Math.max(1,rect.width*.35);
            let x=(event.clientX-rect.left-rect.width/2)/radius,y=(event.clientY-rect.top-rect.height/2)/radius;
            const norm=Math.hypot(x,y);if(norm<.12)x=y=0;else{x*=Math.min(1,norm)/norm;y*=Math.min(1,norm)/norm;}
            f=-y;r=x;applyStick();if(thumb)thumb.style.transform=`translate(${x*radius}px, ${y*radius}px)`;
        }
        listen(stick,'pointerdown',event=>{
            if(!touchVisible||!agent.status().active||event.button!==0||left!=null)return;
            event.preventDefault();canvas.focus();focus(true);left=event.pointerId;stick.setPointerCapture(event.pointerId);moveLeft(event);
        });
        listen(stick,'pointermove',moveLeft);
        for(const type of ['pointerup','pointercancel','lostpointercapture'])listen(stick,type,event=>{if(left===event.pointerId)resetLeft();});
        for(const button of panel.querySelectorAll?.('[data-vertical]')??[]){
            let pointer=null;
            verticalReleases.push(()=>{pointer=null;});
            listen(button,'pointerdown',event=>{if(!touchVisible||!agent.status().active||agent.status().mode!=='gps'||pointer!=null||event.button!==0)return;
                event.preventDefault();canvas.focus();focus(true);pointer=event.pointerId;button.setPointerCapture(pointer);
                vertical=Number(button.dataset.vertical);applyStick();});
            for(const type of ['pointerup','pointercancel','lostpointercapture'])listen(button,type,event=>{
                if(pointer===event.pointerId){pointer=null;vertical=0;applyStick();}
            });
        }
        listen(host,'gamepaddisconnected',event=>{
            const source=event.gamepad&&`web:${event.gamepad.index}:${event.gamepad.id}`;
            if(!source||source===lastSource)disconnected();
        });
        // A delayed initial gamepadconnected event may follow an already valid
        // poll. Only a disconnection or a different source revokes that grant.
        const dispose=()=>{clear();agent.stop();for(const remove of cleanups)remove();options.onFocus?.(false);};
        dispose.reset=clear;
        dispose.sync=syncTouch;
        dispose.setVisible=value=>{if(touchVisible!==value)releaseTouch();touchVisible=value;syncTouch();};
        dispose.native=frame=>{
            if(!focused||!agent.status().active)return;
            const names=['forward','right','yaw','pitch','vertical'];
            if(!frame||!names.every(k=>Number.isFinite(frame[k])&&Math.abs(frame[k])<=1)||
                !['reset','exit','connected'].every(k=>typeof frame[k]==='boolean'))return;
            if(frame.axes!==undefined&&(!Array.isArray(frame.axes)||frame.axes.length>16||frame.axes.some(v=>!Number.isFinite(v)||Math.abs(v)>1)))return;
            if(frame.generation!==undefined&&(!Number.isSafeInteger(frame.generation)||frame.generation<0))return;
            if(frame.stale!==undefined&&typeof frame.stale!=='boolean')return;
            native={...frame};nativeAt=now();
            if(frame.connected)nativeEstablished=true;
            // Resolve a gap when valid data arrives, rather than on the next
            // render tick: rendering may itself have been delayed meanwhile.
            if(frame.connected&&!frame.stale&&lastSource==='native:'+String(frame.generation??0)&&
                !controller.nativeFrame(frame,lastConfiguration??controller.defaults,isFpv()).unsupported)freshInput();
            if(frame.connected===false){if(lastSource?.startsWith('native:'))disconnected();}
        };
        dispose.tick=seconds=>{
            syncTouch();
            if(!agent.status().active){clear();return;}
            if(doc.activeElement!==undefined)focus(!doc.hidden&&doc.activeElement===canvas&&(doc.hasFocus?.()??true));
            if(!focused)return;
            const fpv=isFpv(),c=agent.status().controller??controller.defaults;
            if(lastConfiguration!==c){
                if(lastConfiguration!==null)interruption('Controller settings changed');
                armed=false;lastConfiguration=c;gapSince=null;gapExpired=false;
            }
            let pad=null,source=null;
            if(native&&(native.connected||nativeEstablished)){
                // Keep the native transport selected during a stall. Switching
                // to the WebView's second copy creates false device changes.
                if(native.connected){
                    source='native:'+String(native.generation??0);
                    if(!native.stale&&now()-nativeAt<250)pad=controller.nativeFrame(native,c,fpv);
                }
            }
            else{try{
                const candidates=Array.from(host.navigator?.getGamepads?.()??[]).filter(p=>p?.connected);
                for(const device of candidates){const mapped=gamepadFrame(device,c,fpv);if(!mapped.unsupported){pad=mapped;source=`web:${device.index}:${device.id}`;break;}}
                if(!pad&&candidates.length)showDevice(c.layout==='radio'&&!fpv?'USB radio channels require Angle or Acro mode':'Unmapped controller: choose USB radio and assign its channels in flight settings');
            }catch(_){showDevice('Gamepad unavailable in this browser');}}
            if(pad?.unsupported){pad=null;showDevice(c.layout==='radio'&&!fpv?'USB radio channels require Angle or Acro mode':'Radio channels unavailable: check the channel assignment');}
            if(source!==null&&source!==lastSource){
                if(lastSource!==null)interruption('Controller device changed');
                armed=false;lastSource=source;gapSince=null;gapExpired=false;
            }
            if(pad){
                freshInput();
                const neutral=controller.neutral(pad,c,fpv);
                if(!armed&&neutral)armed=true;
                showDevice(armed?'Controller ready':fpv&&c.throttleZero==='bottom'?'Lower throttle fully and centre the other sticks to enable':'Centre controller sticks to enable');
                if(!armed)pad=null;
            }else if(lastSource!==null){
                if(gapSince===null){gapSince=now();interruption('Controller data temporarily unavailable');}
                if(now()-gapSince>=recoveryWindowMs){
                    if(!gapExpired)interruption('Controller input timed out');
                    armed=false;gapExpired=true;
                }
                showDevice(gapExpired?'Controller input timed out; waiting for fresh data':'Controller input paused; waiting for fresh data');
            }else{armed=false;}
            if(pad){
                if(pad.exit&&!previousExit)agent.stop();
                else if(pad.reset&&!previousReset)agent.reset?.();
                previousExit=!!pad.exit;previousReset=!!pad.reset;
            }else if(!armed){previousExit=previousReset=false;}
            const dt=Number.isFinite(seconds)?Math.max(0,Math.min(.1,seconds)):0;
            if(fpv){
                const collective=pad?controller.throttle(clamp(pad.forward+pad.vertical),c.throttleZero):0;
                const manual=left!==null||vertical!==0||keys.has('e')||keys.has('q');
                const gas=pad&&!manual?(agent.status().mode==='angle'?collective*2-1:collective):clamp(f+vertical);
                agent.flightInput({throttle:gas,
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
