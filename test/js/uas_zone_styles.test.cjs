const test = require('node:test');
const assert = require('node:assert/strict');
const zoneStyles = require('../../web/uas_zone_styles.js');

test('only explicit CodeRestrictionType values receive recognised restriction categories', () => {
  assert.equal(zoneStyles.classify('PROHIBITED'), 'prohibited');
  assert.equal(zoneStyles.classify('REQ_AUTHORISATION'), 'authorisation');
  assert.equal(zoneStyles.classify('REQ_AUTHORISATION.MTOM_ALL'), 'authorisation');
  assert.equal(zoneStyles.classify('REQ_AUTHORISATION.MTOM_FROM'), 'authorisation');
  assert.equal(zoneStyles.classify('REQ_AUTHORISATION.CTR'), 'authorisation');
  assert.equal(zoneStyles.classify('REQ_AUTHORISATION.NEW_FUTURE_RULE'), 'unknown');
  assert.equal(zoneStyles.classify('COMMON'), 'unknown');
  assert.equal(zoneStyles.classify('REQ_AUTHORIZATION'), 'authorisation');
  assert.equal(zoneStyles.classify('CONDITIONAL'), 'conditional');
  assert.equal(zoneStyles.classify('NO_RESTRICTION'), 'informational');
  assert.equal(zoneStyles.classify('USPACE'), 'unknown');
  assert.equal(zoneStyles.classify(''), 'unknown');
  assert.equal(zoneStyles.colorFor('REQ_AUTHORISATION.MTOM_FROM'), '#b8860b');
  assert.equal(zoneStyles.colorFor('REQ_AUTHORISATION.CTR'), '#7b1fa2');
});

test('styles all overlapping entities independently while retaining selection fields', () => {
  const entities = [
    {polygon: {}, properties: {type: {getValue: () => 'COMMON'}, restriction: {getValue: () => 'REQ_AUTHORISATION.MTOM_ALL'}, identifier: 'a'}},
    {polygon: {}, properties: {type: {getValue: () => 'COMMON'}, restriction: {getValue: () => 'REQ_AUTHORISATION.MTOM_FROM'}, identifier: 'b'}},
    {polygon: {}, properties: {type: 'COMMON', restriction: 'UNKNOWN_CODE', identifier: 'c'}},
  ];
  const Cesium = {Color: {fromCssColorString: value => ({withAlpha: a => ({value, alpha: a})})}};
  const counts = zoneStyles.applyToDataSource({entities: {values: entities}}, Cesium, .2);
  assert.deepEqual(counts, {prohibited: 0, authorisation: 2, conditional: 0,
    informational: 0, unknown: 1});
  assert.equal(entities[0].polygon.material.value, '#ef6c00');
  assert.equal(entities[1].polygon.material.value, '#b8860b');
  assert.equal(entities[2].polygon.material.value, '#757575');
  assert.equal(entities[0].properties.identifier, 'a');
  assert.equal(entities[1].polygon.material.alpha, .2);
  assert.throws(() => zoneStyles.applyToDataSource({entities: {values: entities}}, Cesium, 1.5));
});


test('zone type COMMON never hides explicit restriction; unknown restriction is grey', () => {
  const entities = [
    {polygon:{}, properties:{type: 'COMMON', restriction: {getValue:()=> 'NO_RESTRICTION'}}},
    {polygon:{}, properties:{type: 'COMMON', restriction: {getValue:()=> 'PROHIBITED'}}},
    {polygon:{}, properties:{type: 'COMMON', restriction: 'REQ_AUTHORISATION.UNKNOWN_VARIANT'}},
    {polygon:{}, properties:{type: 'PROHIBITED', restriction: null}},
  ];
  const Cesium = {Color: {fromCssColorString: value => ({withAlpha: a => ({value, alpha: a})})}};
  const counts = zoneStyles.applyToDataSource({entities:{values:entities}}, Cesium, .4);
  assert.equal(counts.informational, 1);
  assert.equal(counts.prohibited, 1);
  assert.equal(counts.unknown, 2);
  assert.deepEqual(entities.map(e=>e.polygon.material.value),
    ['#1976d2','#d32f2f','#757575','#757575']);
  assert.equal(entities[0].polygon.material.alpha, .4);
});
