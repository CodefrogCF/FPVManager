# Cleanup helper for the directory-only web module refactor.
# Copy the ZIP overlay into the repository first, then run this script.
# Refuses to discard any locally edited source that differs from the baseline.
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$items = @(
    @{ Old = "web/autonomous_flight_control.js"; New = "web/features/flight/autonomous_flight_control.js"; Sha256 = "dcf3c0b9d43a42aa972ab167aad697f98e75b359f1a038b2bf38f5e2c836cac4" }
    @{ Old = "web/flight_recording.js"; New = "web/features/flight/flight_recording.js"; Sha256 = "101fac6e4dc90c8ec0731df78fc53adaaaaf68156f68a2de77516b4ebf68ec18" }
    @{ Old = "web/flight_rendering.js"; New = "web/features/flight/flight_rendering.js"; Sha256 = "5fb3f1091903f6cf11a72b642bec4fa14467269fedaad0daaa51306cd1d46eb7" }
    @{ Old = "web/free_flight.js"; New = "web/features/flight/free_flight.js"; Sha256 = "f64c199c3c2c9732795bcabdee21f07d16f251ab5691cdbd992902ac39be00ce" }
    @{ Old = "web/flight_hud.js"; New = "web/features/flight/hud/flight_hud.js"; Sha256 = "07a57b07d9fce09b04bd889781238019782c424d84bbd991fd94e0a76596f208" }
    @{ Old = "web/signal_hud.js"; New = "web/features/flight/hud/signal_hud.js"; Sha256 = "2b62c4595f2275bf518f2eb45238b26c192ad17230921fea02453a70d0b8432b" }
    @{ Old = "web/battery_chemistries.generated.js"; New = "web/features/flight/physics/battery_chemistries.generated.js"; Sha256 = "c3e4c7a18b8e0c9d49278f70cc2319f42a4a2a6f9a30b4c265013a7c4d52f0f1" }
    @{ Old = "web/battery_simulation.js"; New = "web/features/flight/physics/battery_simulation.js"; Sha256 = "54671d1a08ca9f576e8808b6145560382e7f6190d78977b7ed23c175144502fd" }
    @{ Old = "web/body_axis_aerodynamics.js"; New = "web/features/flight/physics/body_axis_aerodynamics.js"; Sha256 = "18084bb98a44bbbc7ad2fd5e8d9532d9a15f8b4f95bf25546e174fe706d26bb8" }
    @{ Old = "web/collision_response.js"; New = "web/features/flight/physics/collision_response.js"; Sha256 = "dfdf2d5f034190e3229315ef55040ca0bea366516d861f92de7721fe64d166ee" }
    @{ Old = "web/descent_aerodynamics.js"; New = "web/features/flight/physics/descent_aerodynamics.js"; Sha256 = "92f14676d42cb89b900f1be91a1f39c5a469ee4a50c1b32ec581fd1e29e6f1c8" }
    @{ Old = "web/electrical_propulsion.js"; New = "web/features/flight/physics/electrical_propulsion.js"; Sha256 = "7eaef2288878bb05b2bce4c93ada7419dcae93330f33fca893a2f452074d6bf9" }
    @{ Old = "web/flight_physics.js"; New = "web/features/flight/physics/flight_physics.js"; Sha256 = "422e3a993577c745d4edf850bbd021ac64567b51e86766b6a139a5db41407613" }
    @{ Old = "web/motor_propeller.js"; New = "web/features/flight/physics/motor_propeller.js"; Sha256 = "12c9417de55b701226648fb5a3f98d4ab0f2f1c9573fca14ab3f18f20fdd5078" }
    @{ Old = "web/rescue_velocity.js"; New = "web/features/flight/physics/rescue_velocity.js"; Sha256 = "9e4d8869ed310641b01b33a6fb55eefa578af3218bb2af1e5425d5710c50cfb1" }
    @{ Old = "web/rotational_dynamics.js"; New = "web/features/flight/physics/rotational_dynamics.js"; Sha256 = "ef01bc835a2661e41c4b70ab3bfb21d4a92da68e792eb7ca46ec30fe7d088195" }
    @{ Old = "web/bridge_source.js"; New = "web/features/infrastructure/bridge_source.js"; Sha256 = "966781184ad30c5fa9c7170f6524a7c6f33a81236fe8fff2aa831ad810ab2480" }
    @{ Old = "web/bridge_supports.js"; New = "web/features/infrastructure/bridge_supports.js"; Sha256 = "fc97227b7fa0aa3ff0f0970449bba88a1e2ccd670ea6336e764c2cd6713b2079" }
    @{ Old = "web/obstacle_layers.js"; New = "web/features/infrastructure/obstacle_layers.js"; Sha256 = "82af6917f2253caf6d4e8766ae734a95858c1984a4ec0f93dd5ded93c6f3de68" }
    @{ Old = "web/obstacle_models.js"; New = "web/features/infrastructure/obstacle_models.js"; Sha256 = "d76d9dce0039f425d8d9e3df919a335a7a1afed969c3c55e9c38870fc0de1fc0" }
    @{ Old = "web/tunnel_offline_index.js"; New = "web/features/infrastructure/tunnel_offline_index.js"; Sha256 = "6738f17b8bec40ce956f5b1100b0b5a1716363fbd5c5e4a4cf865bdf1a46d254" }
    @{ Old = "web/dated_imagery_overlay.js"; New = "web/features/map/dated_imagery_overlay.js"; Sha256 = "2545b4141d04b5207a018ddd8459f9c94c198d8010456e6601dc7def0ed19a00" }
    @{ Old = "web/map_compass.js"; New = "web/features/map/map_compass.js"; Sha256 = "e889ccd9e110944789a45c89edc3c500e4cdfbc0e74393efede00863b285ea81" }
    @{ Old = "web/map_labels.js"; New = "web/features/map/map_labels.js"; Sha256 = "37a68c043f9e4e326c0aa7bb93a8564acea3a796f9b82fd532c4e752d77a7c82" }
    @{ Old = "web/map_providers.js"; New = "web/features/map/map_providers.js"; Sha256 = "3f4dbd616e6b9ff539129c6d53d708763e10ded68485fe3d29af2a923460b29a" }
    @{ Old = "web/uas_zone_styles.js"; New = "web/features/map/uas_zone_styles.js"; Sha256 = "24d69bae6911a903e3edfe99934bf3bbefdac77c026a9193d56d9213edfd5107" }
    @{ Old = "web/controller_input.js"; New = "web/features/navigation/controller_input.js"; Sha256 = "e6dcc69f50c73199031237ef6465068cd809409cd9a8f49edc6e60ada8fb4142" }
    @{ Old = "web/ground_navigation.js"; New = "web/features/navigation/ground_navigation.js"; Sha256 = "9ab7e3fc45a4b1dea215ee02cafd1c3cb60cf780d625f5aa551fd405154a88b0" }
    @{ Old = "web/navigation_controls.js"; New = "web/features/navigation/navigation_controls.js"; Sha256 = "f02ef8f6de25faa1434f2a3d50a12f02939bfab6fbe618a3f509630cf6c1b8e7" }
    @{ Old = "web/road_navigation.js"; New = "web/features/navigation/road_navigation.js"; Sha256 = "82eb7c10ed2c34e4082b749dd44cfb10b2fb7ed0a19397ae23ef61ea5dab778c" }
    @{ Old = "web/route_editor.js"; New = "web/features/navigation/route_editor.js"; Sha256 = "b31b0aa305950e6782cbaf59f7b64aed1f7bcd85a0541b47dd0da736c658c7b5" }
    @{ Old = "web/offline_preparation_engine.js"; New = "web/features/offline/offline_preparation_engine.js"; Sha256 = "1cddcf7eb14487e6331b61d193c9245d6f0cecb8e084ae5337551f81bcd93e9c" }
    @{ Old = "web/offline_preparation_page.js"; New = "web/features/offline/offline_preparation_page.js"; Sha256 = "9762c259713ed7091274e703828a22a43cf4f74e97b9ce1f417b0aede0aae7fd" }
    @{ Old = "web/offline_preparation_storage.js"; New = "web/features/offline/offline_preparation_storage.js"; Sha256 = "485a8ca02e1a056bc6341c581955f0db5d8aed65640ea5b3c654487435b41a7c" }
    @{ Old = "web/situational_layers.js"; New = "web/features/overlays/situational_layers.js"; Sha256 = "94d74ea88947c8b3b9d88598ff9efb508f90d853e564681c0197e5557a3faff3" }
    @{ Old = "web/scene_environment.js"; New = "web/features/scene/scene_environment.js"; Sha256 = "2f3348eefe56d7b0ae4197415b3ba0c71cba7c671aeceb07417473f47e7f96e4" }
    @{ Old = "web/scene_tile_loading.js"; New = "web/features/scene/scene_tile_loading.js"; Sha256 = "35f9f9849e336ad11f259240366d5441b4bd2306deb362df278aefdd7a703288" }
    @{ Old = "web/scenery_alignment.js"; New = "web/features/scenery/scenery_alignment.js"; Sha256 = "7e7378bcbda89bb05c7eb45c0adb1631bf6f29e846767bc03f323c48f038eaf6" }
    @{ Old = "web/scenery_bridge_calibration.js"; New = "web/features/scenery/scenery_bridge_calibration.js"; Sha256 = "77edb08793e808d7b6448f427409e548fce0074f537f6643f3ee15dcc583c112" }
    @{ Old = "web/scenery_collision.js"; New = "web/features/scenery/scenery_collision.js"; Sha256 = "a2f5ee18f91b74388847b51003498d00f0cebc6d1b0045b2649e20a69dbb8869" }
    @{ Old = "web/scenery_manager.js"; New = "web/features/scenery/scenery_manager.js"; Sha256 = "8dc3a90c571a55cf13ec2c279760e830aeaf36190dbd5bcb6f7d8c3353984ef3" }
    @{ Old = "web/scenery_reference_preview.js"; New = "web/features/scenery/scenery_reference_preview.js"; Sha256 = "1380aa1554d69c7b14584e524d9c0d24bd2361a07852d0d75c04c0ca0bb927d7" }
    @{ Old = "web/live_radio.js"; New = "web/features/signal/live_radio.js"; Sha256 = "566fdded1510e615c449b6535e35b75e8d1cc8ef09ffea6f730cb4cbfef4884d" }
    @{ Old = "web/rf_estimation.js"; New = "web/features/signal/rf_estimation.js"; Sha256 = "1f84d1b5ad4d88f9d5531dd6d57947bac54fc8b55fddcf05ed5b01da20055a9c" }
    @{ Old = "web/signal_analysis.js"; New = "web/features/signal/signal_analysis.js"; Sha256 = "922c18a0672c5f3470702f6e2f04b914ec706740503a7de6198713e5d05fe475" }
    @{ Old = "web/simulated_failsafe.js"; New = "web/features/signal/simulated_failsafe.js"; Sha256 = "df4c2acd7ed2835ee4852266408152a22c41e2d372c8c5fbde3417028c230ca1" }
    @{ Old = "web/regional_3d.js"; New = "web/features/terrain/regional_3d.js"; Sha256 = "71102d311b91205d9297136fdcd629557c4096f382520c88e863e81829e573d9" }
    @{ Old = "web/terrain_service.js"; New = "web/features/terrain/terrain_service.js"; Sha256 = "f4b11413e53695373ac09a18a0f135fdd0d4e82371b1a0f3cc6947e689424bfe" }
    @{ Old = "web/forest_composition.js"; New = "web/features/vegetation/forest_composition.js"; Sha256 = "7d3a063178cc1e78a42d48e8c519f04feb97f0904b18b88fe02ae283b41b434d" }
    @{ Old = "web/vegetation_models.js"; New = "web/features/vegetation/vegetation_models.js"; Sha256 = "67c34cfd850df2fe505f50ba9e6ca912e37eab802ac9cb4e27f7bac562d9a52a" }
    @{ Old = "web/vegetation_shader_seed.js"; New = "web/features/vegetation/vegetation_shader_seed.js"; Sha256 = "4303d564b0eafd725c9ef4cc94681eecd9e8616eec6ef6eebc7d3fafd4d69cbe" }
    @{ Old = "web/environmental_wind.js"; New = "web/features/weather/environmental_wind.js"; Sha256 = "2b1e48b3ef7c70c11d22a831bed9ac63553cae5ebcc6ed66d187f4c839b7ef65" }
    @{ Old = "web/meteo_radar_overlay.js"; New = "web/features/weather/meteo_radar_overlay.js"; Sha256 = "57e96389015bb8a5251935562ba49c28c3a857ccc78b4f2c6ab4af967b2baf81" }
    @{ Old = "web/weather_overlay.js"; New = "web/features/weather/weather_overlay.js"; Sha256 = "a26f7cc05308763d1f3f1d443bb44585ae7002119e1d8e542234cc739734dea6" }
    @{ Old = "web/wind_field.js"; New = "web/features/weather/wind_field.js"; Sha256 = "0e5843a44e0bdb5d2d4490909cfe725483683196f038f9790dcc7856ffea7381" }
    @{ Old = "web/capture_mode.js"; New = "web/core/capture_mode.js"; Sha256 = "bad8f2d511a9583f6fb9f36ae8c15f1233f9c0179ae11896434945c15c33a12d" }
    @{ Old = "web/globe_bridge.js"; New = "web/core/globe_bridge.js"; Sha256 = "ef82a27a55361a0a79bf037d374345d67d9d68aff86b20aa9493cdfb37788c9e" }
    @{ Old = "web/globe_positions.js"; New = "web/core/globe_positions.js"; Sha256 = "e4e95dca857994969882ce385c50e2d99ee6e43af31d89536f862da9793d8a64" }
    @{ Old = "web/renderer_language.js"; New = "web/core/renderer_language.js"; Sha256 = "aa5631b8b279f3405265c3553fbec4fd7ddb2b46bbc5a0ac18320a18f0ad719a" }
    @{ Old = "web/scene_performance.js"; New = "web/core/scene_performance.js"; Sha256 = "e884e63a2f7be1b0a7e39ec35751823ffb600a7f186b9396b25bf45b08a923d1" }
    @{ Old = "web/flight_hud.css"; New = "web/features/flight/hud/flight_hud.css"; Sha256 = "6c3164c8711b9b5dffee10721a452302eafce2af1e9020a2d49c6a26c1439e37" }
)
foreach ($item in $items) {
    $newPath = Join-Path $repo $item.New
    $oldPath = Join-Path $repo $item.Old
    if (!(Test-Path -LiteralPath $newPath -PathType Leaf)) {
        throw "New web module is missing: $($item.New). Copy the ZIP into the project root first."
    }
    if (Test-Path -LiteralPath $oldPath -PathType Leaf) {
        $hash = (Get-FileHash -LiteralPath $oldPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $item.Sha256) {
            throw "Refusing to delete locally modified file: $($item.Old). Review changes and move them manually."
        }
    }
}
$removed = 0
foreach ($item in $items) {
    $oldPath = Join-Path $repo $item.Old
    if (Test-Path -LiteralPath $oldPath -PathType Leaf) {
        Remove-Item -LiteralPath $oldPath -Force
        $removed++
    }
}
Write-Output "Removed $removed obsolete web root files. The feature modules were not changed."
