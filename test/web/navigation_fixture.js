// Explicit fixture-only diagnostics; no production messages or location logs.
(() => {
    const create=FPVRoadNavigation.create;
    FPVRoadNavigation.create=(C,viewer,...options)=>{
        const counts={terrain:0,camera:0,cameraMs:0,updateStart:0},height=viewer.scene.globe.getHeight.bind(viewer.scene.globe),look=viewer.camera.lookAt.bind(viewer.camera);
        const remove=viewer.scene.preUpdate.addEventListener(()=>counts.updateStart=performance.now());
        viewer.scene.globe.getHeight=(...args)=>{counts.terrain++;return height(...args);};
        viewer.camera.lookAt=(...args)=>{const start=performance.now();try{return look(...args);}finally{counts.camera++;counts.cameraMs+=performance.now()-start;}};
        const manager=create(C,viewer,...options);
        const dispose=manager.dispose;manager.dispose=()=>{remove();dispose.call(manager);};
        window.fixtureRoadNavigation=manager;window.fixtureNavigationCounts=counts;
        return manager;
    };
})();
