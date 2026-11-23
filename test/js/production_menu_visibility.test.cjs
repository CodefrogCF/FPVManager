'use strict';

const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'../..');
const source=file=>fs.readFileSync(path.join(root,file),'utf8');

test('regular builds hide internal menu widgets behind one explicit opt-in flag',()=>{
  const flag=source('lib/core/ui/developer_menu_visibility.dart');
  assert.match(flag,/const bool kDeveloperMenusEnabled = bool\.fromEnvironment\(\s*'FPV_DEVELOPER_MENUS',\s*defaultValue: false/);
  const scenery=source('lib/features/globe/scenery_layers_section.dart');
  const structures=source('lib/features/globe/scene_layers_section.dart');
  const airspace=source('lib/features/globe/uas_map_layers_section.dart');
  const terrain=source('lib/features/globe/terrain_information_dialog.dart');
  for(const file of [scenery,structures,airspace,terrain])assert.match(file,/import '\.\.\/\.\.\/core\/ui\/developer_menu_visibility\.dart';/);
  for(const diagnostic of ['_replacement != null',"item['collisionState'] != null","item['lastHit'] is Map", "item['heightAlignmentMode'] == 'fixed'", "item['id'] == 'de-bb-ruedersdorf-chemical-plant'", "(item['buildingRegions'] as List?)", "(item['terrainRegions'] as List?)", '_editScenery(item, german)']){
    assert.ok(scenery.includes(diagnostic),`missing diagnostic control: ${diagnostic}`);
  }
  assert.match(scenery,/if \(kDeveloperMenusEnabled\)\s*TextButton\.icon\(\s*onPressed: enabled \? \(\) => _editScenery/);
  assert.match(structures,/if \(kDeveloperMenusEnabled\)\s*ExpansionTile\(\s*key: const PageStorageKey\('map-tunnel-data'\)/);
  assert.match(structures,/if \(kDeveloperMenusEnabled\)\s*TextButton\.icon\(\s*onPressed: enabled && !controller\.tunnelModelPending/);
  assert.match(airspace,/if \(kDeveloperMenusEnabled\)\s*TextButton\.icon\(\s*onPressed: controller\.isReady && controller\.canClearUasCache/);
  assert.match(terrain,/if \(kDeveloperMenusEnabled\)\s*Text\(\s*context\.localizedWithArgs\("Sampling: \{0\}"/);
});

test('safety notices, source licences and user simulator controls remain in ordinary menus',()=>{
  const scenery=source('lib/features/globe/scenery_layers_section.dart');
  const structures=source('lib/features/globe/scene_layers_section.dart');
  const airspace=source('lib/features/globe/uas_map_layers_section.dart');
  assert.match(scenery,/Experimentell: Kollisionsgeometrie aus Scan/);
  assert.match(scenery,/controller\.setSceneryEnabled\(/);
  assert.match(structures,/controller\.setTunnelInfrastructure\(autoModels: value\)/);
  assert.match(structures,/controller\.setSceneEnvironment\(\s*modelCollisions: value/);
  assert.match(structures,/controller\.scanTunnelRoutes\(\)/);
  assert.match(structures,/Originaldaten · keine Durchflugfreigabe/);
  assert.match(structures,/if \(!kDeveloperMenusEnabled &&\s*controller\.tunnelRoutes\.any\(/);
  assert.match(airspace,/source\.licenseName/);
  assert.match(airspace,/showAirspaceSafetyPanel\(context, controller\)/);
  assert.match(airspace,/Official validity/);
  assert.match(airspace,/Weitere Einschränkungen möglich/);
});
