(function(root,factory){
    const api=factory();
    if(typeof module==='object'&&module.exports)module.exports=api;
    else root.FPVControllerInput=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
    'use strict';
    const clamp=v=>Math.max(-1,Math.min(1,Number.isFinite(v)?v:0))||0;
    const functions=['roll','pitch','throttle','yaw'];
    const defaults=Object.freeze({layout:'gamepad',throttleZero:'center',rollAxis:0,pitchAxis:1,throttleAxis:2,yawAxis:3,
        invertRoll:false,invertPitch:false,invertThrottle:false,invertYaw:false});
    function configuration(value={}){
        if(!value||typeof value!=='object'||Array.isArray(value))throw Error('Invalid controller settings');
        const c={...defaults,...value};
        if(!['gamepad','radio'].includes(c.layout)||!['bottom','center'].includes(c.throttleZero))throw Error('Unknown controller layout or throttle zero');
        const axes=functions.map(f=>c[f+'Axis']);
        if(axes.some(a=>!Number.isInteger(a)||a<0||a>15)||new Set(axes).size!==4||
            functions.some(f=>typeof c['invert'+f[0].toUpperCase()+f.slice(1)]!=='boolean'))throw Error('Choose four different controller channels (1–16)');
        return Object.freeze(c);
    }
    function axis(v,zone=.15){v=clamp(v);return Math.abs(v)<=zone?0:Math.sign(v)*(Math.abs(v)-zone)/(1-zone);}
    function radioFrame(axes,c){
        if(!Array.isArray(axes)||axes.length>16||functions.some(f=>!Number.isFinite(axes[c[f+'Axis']])||Math.abs(axes[c[f+'Axis']])>1))return {unsupported:true};
        const read=f=>axes[c[f+'Axis']]*(c['invert'+f[0].toUpperCase()+f.slice(1)]?-1:1);
        return {forward:read('throttle'),right:axis(read('yaw'),.03),yaw:axis(read('roll'),.03),
            pitch:-axis(read('pitch'),.03),vertical:0,reset:false,exit:false};
    }
    function gamepadFrame(pad,c=defaults,fpv=true){
        if(!pad||!pad.connected)return null;
        if(c.layout==='radio')return fpv?radioFrame(pad.axes?.slice(0,16),c):{unsupported:true};
        if(pad.mapping!=='standard')return {unsupported:true};
        if(!Number.isFinite(pad.axes?.[1])||Math.abs(pad.axes[1])>1)return {unsupported:true};
        const button=i=>clamp(pad.buttons?.[i]?.value??0);
        return {forward:fpv&&c.throttleZero==='bottom'?-clamp(pad.axes?.[1]):-axis(pad.axes?.[1]),right:axis(pad.axes?.[0]),yaw:axis(pad.axes?.[2]),pitch:axis(pad.axes?.[3]),
            vertical:clamp(button(7)-button(6)+button(5)-button(4)),reset:button(0)>.5,exit:button(1)>.5};
    }
    function nativeFrame(frame,c=defaults,fpv=true){return c.layout==='radio'?(fpv?radioFrame(frame.axes,c):{unsupported:true}):frame;}
    function throttle(value,zero){
        if(!Number.isFinite(value))return 0;
        const result=zero==='bottom'?(clamp(value)+1)/2:Math.max(0,clamp(value));
        return result<.02?0:result;
    }
    function neutral(pad,c,fpv){
        const idle=fpv&&c.throttleZero==='bottom'?throttle(pad.forward,'bottom')===0:Math.abs(pad.forward)<.02;
        return idle&&['right','yaw','pitch','vertical'].every(k=>Math.abs(pad[k])<.02)&&!pad.reset&&!pad.exit;
    }
    function bindPanel(doc,onChanged){
        const layout=doc.getElementById('controller-layout'),zero=doc.getElementById('controller-zero');
        const channels=doc.getElementById('controller-channels');
        const fields=functions.map(f=>({axis:doc.getElementById('controller-'+f+'-axis'),invert:doc.getElementById('controller-'+f+'-reverse')}));
        let current=defaults;
        for(const field of fields)for(let i=0;i<16;i++){
            const option=doc.createElement('option');option.value=String(i);option.textContent=`Channel ${i+1}`;field.axis.appendChild(option);
        }
        function update(value){
            current=value??defaults;layout.value=current.layout;zero.value=current.throttleZero;
            channels.hidden=current.layout!=='radio';
            fields.forEach((field,i)=>{const f=functions[i];field.axis.value=String(current[f+'Axis']);field.invert.checked=current['invert'+f[0].toUpperCase()+f.slice(1)];});
        }
        function change(){
            const next={...current,layout:layout.value,throttleZero:zero.value};
            fields.forEach((field,i)=>{const f=functions[i];next[f+'Axis']=Number(field.axis.value);next['invert'+f[0].toUpperCase()+f.slice(1)]=field.invert.checked;});
            onChanged(configuration(next));
        }
        layout.addEventListener('change',()=>{zero.value=layout.value==='radio'?'bottom':'center';change();});
        zero.addEventListener('change',change);
        fields.forEach((field,i)=>{
            field.axis.addEventListener('change',()=>{
                const previous=current[functions[i]+'Axis'],selected=Number(field.axis.value);
                const other=fields.findIndex((f,n)=>n!==i&&Number(f.axis.value)===selected);
                if(other>=0)fields[other].axis.value=String(previous);
                change();
            });
            field.invert.addEventListener('change',change);
        });
        update(defaults);return {update};
    }
    return {defaults,configuration,axis,gamepadFrame,nativeFrame,throttle,neutral,functions,bindPanel};
});
