const test=require('node:test'),assert=require('node:assert/strict');
const {advance,approachSpeed}=require('../../web/features/flight/physics/rescue_velocity.js');
test('rescue reaches attainable target speed under physical acceleration limits',()=>{
    let value={north:0,east:0},distance=0;
    for(let t=0;t<5;t+=.02){const updated=advance(value,{north:14,east:0},.02,7,5,20);
        assert.ok(Math.hypot(updated.next.north-value.north,updated.next.east-value.east)<=7*.02+1e-7);
        distance+=updated.travel.north;value=updated.next;}
    assert.ok(value.north>13.9);assert.ok(distance>50);
});
test('approach speed brakes smoothly and prevents overshooting the home point',()=>{
    assert.equal(approachSpeed(2,16,6),0);
    assert.ok(approachSpeed(4,16,6)<approachSpeed(40,16,6));
    assert.equal(approachSpeed(1000,16,6),16);
});
test('rescue direction reversal is acceleration-bounded without teleporting',()=>{
    const updated=advance({north:15,east:0},{north:-15,east:0},.025,8,6,20);
    assert.ok(updated.next.north>14.8&&updated.next.north<15);
    assert.ok(updated.travel.north>.3&&updated.travel.north<.4);
    assert.throws(()=>advance({north:0,east:0},{north:1,east:0},-1,8,6,20));
});
