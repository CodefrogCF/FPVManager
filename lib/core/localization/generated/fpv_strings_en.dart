// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'fpv_strings.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class FpvStringsEn extends FpvStrings {
  FpvStringsEn([String locale = 'en']) : super(locale);

  @override
  String get airspaceAbsenceOfAMatch3e743a0d =>
      'Absence of a match does not establish unrestricted airspace. Source coverage is not independently verified.';

  @override
  String get airspaceAirspaceFlightSafetyfe71cada => 'Airspace & flight safety';

  @override
  String get airspaceAirspaceIntersectionsb23b9966 => 'Airspace intersections';

  @override
  String airspaceAllSourceAttributes5a87df81(String arg0) {
    return 'All source attributes ($arg0)';
  }

  @override
  String get airspaceApiAccessFreeServicesa6e68dbd =>
      'API access (free services only)';

  @override
  String get airspaceApiKeycf678cab => 'API key';

  @override
  String get airspaceAutomaticDabsNotamAvailability2968fe7b =>
      'Automatic DABS/NOTAM availability: not connected. No assertion is made that temporary restrictions have been retrieved or checked.';

  @override
  String get airspaceBazlUasGeographicalZones729ad95f =>
      'BAZL UAS geographical zones';

  @override
  String get airspaceCheckTheLatestDabsf5c81052 =>
      'Check the latest DABS and original NOTAM immediately before flying. DABS is a periodic snapshot.';

  @override
  String get airspaceCloseAirspaceCheckeac0670c => 'Close airspace check';

  @override
  String get airspaceCloseDetails433da6d1 => 'Close details';

  @override
  String get airspaceCloseSafetyPanelc70c84b5 => 'Close safety panel';

  @override
  String get airspaceCloseZoneInspection127a12af => 'Close zone inspection';

  @override
  String get airspaceColorsDescribeSourceRestrictionsc0980bc9 =>
      'Colors describe source restrictions. Blue is not flight clearance; check every overlapping zone and its conditions.';

  @override
  String get airspaceCopyOfficialLink14342de0 => 'Copy official link';

  @override
  String get airspaceCouldNotOpenBrowserfceaf72a =>
      'Could not open browser. Copy the URL instead.';

  @override
  String airspaceDataLimitation1a823833(String arg0) {
    return 'Data limitation: $arg0';
  }

  @override
  String get airspaceDatasetCacheIsStale23d0712d =>
      'Dataset cache is stale or its clock is inconsistent.';

  @override
  String get airspaceEachLimitRetainsIts3b9913eb =>
      'Each limit retains its own source unit and vertical reference.';

  @override
  String airspaceFeatures98bdf3c0(String arg0, String arg1) {
    return '$arg0: $arg1 features';
  }

  @override
  String get airspaceFlightSafetyCurrentOfficiala1a04e11 =>
      'Flight safety & current official publications';

  @override
  String get airspaceGetFreeApiKeyb5c8a05f => 'Get free API key';

  @override
  String get airspaceInspectRestrictionsdfa16e61 => 'Inspect restrictions';

  @override
  String airspaceIntersectingZones8134036b(String arg0) {
    return 'Intersecting zones: $arg0';
  }

  @override
  String get airspaceKeyConfigured61737de7 => 'Key configured';

  @override
  String get airspaceKeysAreKeptFor409824c9 =>
      'Keys are kept for this browser session only and disappear after reload.';

  @override
  String airspaceLastRefreshFailed7971e026(String arg0) {
    return 'Last refresh failed: $arg0';
  }

  @override
  String get airspaceLeaveExistingKeyUnchanged814b9fe9 =>
      'Leave existing key unchanged by keeping this empty';

  @override
  String get airspaceLoadingUasDataAndddfb5ec6 =>
      'Loading UAS data and checking geometry…';

  @override
  String airspaceLower082a2966(String arg0) {
    return 'Lower: $arg0';
  }

  @override
  String get airspaceManualPreflightChecklistb4d4bf28 =>
      'Manual preflight checklist';

  @override
  String get airspaceNextZone6c44893a => 'Next zone';

  @override
  String get airspaceNoHorizontalIntersectionsFound318ee27f =>
      'No horizontal intersections found in the checked data.';

  @override
  String get airspaceNoKeyConfigured697416d1 => 'No key configured';

  @override
  String get airspaceNoSupportedAirspaceProviderdcf17faa =>
      'No supported airspace provider currently needs a freely obtainable API key. BAZL works without one; Skyguide NOTAM access is not verified as free.';

  @override
  String get airspaceOpenOfficialSource47aa309c => 'Open official source';

  @override
  String airspacePolygonFeaturesChecked0b14a2bb(String arg0) {
    return '$arg0 polygon features checked';
  }

  @override
  String get airspacePreflightInformationOnlyFpvmanager3ddafa1c =>
      'Preflight information only. FPVManager cannot issue a flight authorisation or guarantee that a flight is legal or safe.';

  @override
  String get airspacePreviousZoneb179c069 => 'Previous zone';

  @override
  String get airspaceReadTheLatestDabs49e90175 =>
      '2. Read the latest DABS and original NOTAM for the entire flight period and route.';

  @override
  String get airspaceRecheckImmediatelyBeforeTake68acccbc =>
      '4. Recheck immediately before take-off; a recent download or an empty intersection result is not proof of permission.';

  @override
  String get airspaceRefreshSourceDatae31028f4 => 'Refresh source data';

  @override
  String get airspaceRestrictionLegendCesiumMap50513b33 =>
      'Restriction legend (Cesium map)';

  @override
  String get airspaceRestrictionNotProvided55e0f3ad =>
      'Restriction not provided';

  @override
  String get airspaceRestrictionNotProvidedBy569286af =>
      'Restriction not provided by source';

  @override
  String get airspaceRetryWithFreshData71969c16 => 'Retry with fresh data';

  @override
  String airspaceRouteSnapshotWaypointsAll292bb6c5(String arg0) {
    return 'Route snapshot · $arg0 waypoints · all connecting segments';
  }

  @override
  String get airspaceTemporaryTimeDependentInformation90a7f86a =>
      'Temporary / time-dependent information';

  @override
  String get airspaceTimesAndOffsetsAred587335b =>
      'Times and offsets are shown as supplied; applicability is not calculated.';

  @override
  String get airspaceUasDataQuality1458ab06 => 'UAS data quality';

  @override
  String airspaceWaypointsSegments6fa17a75(String arg0, String arg1) {
    return 'Waypoints: $arg0 · Segments: $arg1';
  }

  @override
  String airspaceZoneOfAtThiscce172f2(String arg0, String arg1) {
    return 'Zone $arg0 of $arg1 at this position';
  }

  @override
  String avalancheAbrufPruefung87671789(String arg0) {
    return 'Search/audit: $arg0';
  }

  @override
  String get avalancheDarstellungDerPubliziertenTagesabschnitte07920ee4 =>
      'Presentation of the published daily sections';

  @override
  String avalancheErneutAktualisierenInSed2b6e00(String arg0) {
    return 'Update again in $arg0 s';
  }

  @override
  String get avalancheFruehererTagesabschnittbbaf5db6 => 'Previous day';

  @override
  String get avalancheGefahrenstufenRegionaleUbersicht44dc4622 =>
      'Levels of danger · regional overview';

  @override
  String get avalancheGrauUnbekanntOderVeralteter1feb3e46 =>
      'Grey: unknown or outdated / unconfirmed status. Expired areas are hidden. A missing bulletin is not a warning.';

  @override
  String avalancheGueltigkeita66abbe1(String arg0, String arg1) {
    return 'Validity: $arg0 – $arg1';
  }

  @override
  String get avalancheLawinenbulletinSlfe00b361e => 'Avalanche bulletin · SLF';

  @override
  String avalanchePublikation0e56fdd8(String arg0) {
    return 'Publication: $arg0';
  }

  @override
  String get avalancheSlfBulletinAktualisieren6cedce41 => 'Update SLF Bulletin';

  @override
  String get avalancheSpaetererTagesabschnitte6b59639 => 'Later part of day';

  @override
  String get avalancheTagesuebersicht6ec1173c => 'Daily overview';

  @override
  String get avalancheUnbekanntAlterStandaba56b7e => 'Unknown / old state';

  @override
  String get batteriesAddBattery418deef8 => 'Add battery';

  @override
  String get batteriesAddPackFromTypea7df2842 => 'Add pack from type';

  @override
  String get batteriesAddType937e2dfc => 'Add type';

  @override
  String get batteriesAssociatedFlightPlans1c957aa1 =>
      'Associated flight plans';

  @override
  String get batteriesAvailability681b5b5a => 'Availability';

  @override
  String get batteriesBatteryDetails139e0037 => 'Battery details';

  @override
  String get batteriesBatteryInventory01b473c6 => 'Battery inventory';

  @override
  String get batteriesBatteryTypeReusableTemplate7a43b0a1 =>
      'Battery type · reusable template';

  @override
  String batteriesBatterycc97f71f(String arg0, String arg1) {
    return '$arg0 battery$arg1';
  }

  @override
  String batteriesCalculatedNominalEnergyWh30e6efe0(String arg0) {
    return 'Calculated nominal energy: $arg0 Wh (capacity × nominal voltage)';
  }

  @override
  String get batteriesConditionAvailability033503de =>
      'Condition & availability';

  @override
  String get batteriesCopyTypeSpecifications02a95788 =>
      'Copy type specifications';

  @override
  String batteriesDeleteBattery7407e336(String arg0) {
    return 'Delete battery$arg0?';
  }

  @override
  String get batteriesEditBattery29162bfe => 'Edit battery';

  @override
  String get batteriesIndividualBattery211df7bd => 'Individual battery';

  @override
  String get batteriesNoBatteryTypesYetc908d855 =>
      'No battery types yet. Add a reusable specification template.';

  @override
  String get batteriesNoDroneProfilesYet036373ca => 'No drone profiles yet.';

  @override
  String get batteriesNoIndividualBatteriesYet2f6f284a =>
      'No individual batteries yet. Add a pack to your inventory.';

  @override
  String get batteriesNoSavedFlightPlans0eb9aef8 =>
      'No saved flight plans yet.';

  @override
  String get batteriesNoTypeTemplate58240414 => 'No type template';

  @override
  String get batteriesOptional0c6c4102 => 'Optional';

  @override
  String get batteriesPacksKeepIndependentSpecificationa8fd26d6 =>
      'Packs keep independent specification copies. Later type edits do not change them.';

  @override
  String get batteriesRemovedType24f2204a => 'Removed type';

  @override
  String get batteriesRetryLoadingOptions99cf637e => 'Retry loading options';

  @override
  String get batteriesTheAssignedTypeWas57b002ba =>
      'The assigned type was removed. Select a type or no template.';

  @override
  String get batteriesThisBatteryNoLongere1b6ecdf =>
      'This battery no longer exists.';

  @override
  String get batteriesTypeTemplateOptionalbafc4970 =>
      'Type template (optional)';

  @override
  String get batteriesUnableToLoadBattery8a3276bc =>
      'Unable to load battery inventory.';

  @override
  String get batteriesUnableToLoadThis46eed388 =>
      'Unable to load this battery.';

  @override
  String get batteriesUnableToLoadTypesc7010120 =>
      'Unable to load types and assignments.';

  @override
  String get commonAPlanningRadiusIse6a1033a =>
      'A planning radius is not a VLOS limit. Visibility, aircraft orientation, observers, people, pilot qualifications, local restrictions and approvals require manual verification.';

  @override
  String get commonAbbrechen07af7cb3 => 'Cancel';

  @override
  String get commonAbrufzeitIstNichtVeroeffentlichungszeit8d993e52 =>
      'Retrieving time is not publication time. Valid from/until describes the specified period; a fresh download does not prove that the entire content is up-to-date. Missing time information is not added.';

  @override
  String get commonAbsoluteSourceHeightsLn1571b147 =>
      'Absolute source heights: LN02. Elevated display: CHGeo2004 + HTRANS to the ETRS89 ellipsoid, used as a WGS84 approximation. Unknown line/area elevations are shown only as a ground marker at their first source vertex. Isolated point obstacles with an official AGL height are displayed at that exact height above the currently rendered terrain; their visualized absolute top may differ from the surveyed LN02 top. Extra KML label points on lines/polygons are not drawn as obstacles. Cable vertices matching published masts follow the same terrain-adjusted mast tops, with interpolated display corrections between supports. Other geometry retains source absolute elevations. Cable sag is not reconstructed; route checks use original source geometry.';

  @override
  String get commonAdd61cc55aa => 'Add';

  @override
  String get commonAglIsADistance519675fb =>
      'AGL is a distance above this ground point, not a sea-level height.';

  @override
  String get commonAirframe2149a671 => 'Airframe';

  @override
  String get commonAirspaceStatusNotCheckedfcc694aa =>
      'Airspace status: NOT CHECKED by this weather assessment. Consult current UAS zones, DABS and NOTAM separately.';

  @override
  String get commonAirspaceb3cb9fb5 => 'Airspace';

  @override
  String get commonAktivitaetsprofileUndArbeitsbereiched4c2fe93 =>
      'Activity profiles and work areas';

  @override
  String get commonAktivitaetsprofilee88c0015 => 'Activity profiles';

  @override
  String get commonAktualisierungFehlgeschlagenGespeicherteDatene03c0f00 =>
      'Update failed: saved data, current status unknown.';

  @override
  String get commonAktuelleBazlKarteDabs491537fb =>
      'Check current BAZL card, DABS and original NOTAM for flight time and route as well as local rules. DABS is a periodic bulletin; NOTAM can change between issues. Automatic DABS/NOTAM callup is currently not connected. Also check weather, obstacles and altitude cover and re-verify immediately before departure.';

  @override
  String get commonAlle4c7a986f => 'All';

  @override
  String get commonAlleSekundenSolangeDie8b77bd0f =>
      'Every 60 seconds, as long as the navigation is active. In the background, the retrieval pauses.';

  @override
  String get commonAlleZonenPruefen026c7d8e => 'Check all zones';

  @override
  String get commonAnbieterbedingungenUndBerechtigungenGeltenff0efbff =>
      'Provider conditions and permissions apply per source. Use ASTRA token of the appropriate product, not token hash or OJP token. Android uses the existing secure key storage; keys do not belong in simple settings or in backups. Web access remains within the previously supported limits. No public proxys pass on private keys.';

  @override
  String get commonAngleAcroEQ41fdac85 =>
      'Angle/Acro: E/Q Gas, A/D Yaw, W/S Pitch, left/right arrows Roll; IJKL also controls the location. GPS/Ego: WASD/arrows move, drag or IJKL look around; GPS uses E/Q for height. Escape ends the view. For controllers after focus loss or real separation take the appropriate resting position. Gas zero point and channel assignment remain their own controller settings.';

  @override
  String get commonAngleAcroLinksGas98d5063f =>
      'Angle/Acro: left gas and Yaw, right pitch and roll. GPS: left movement, right direction of view, separate buttons for climbing/sinking. Both touch sticks are stuck. They can hide the quick settings; keyboard and external controllers remain usable.';

  @override
  String get commonAngleAcroNullUntena9ccc141 =>
      'Angle/Acro uses the full stick range when zero throttle is at the bottom. With zero at the centre it uses the upper half. Set zero throttle and centre the other sticks before connecting or resuming.';

  @override
  String get commonAngleStabilisiertDieLage6d00e2df =>
      'Angle stabilizes the position, Acro gives rotation rates, GPS brakes and keeps the height. \"Flight settings\" bundles camera/display, graphics/light, controller, wind and radio preview. Long pauses are not made as a big flight step. Physics, terrain and model contacts remain approximations; buildings, trees and cables do not form a complete collision world. Settings outside of a flight prepare the next simulation.';

  @override
  String get commonAnwendenb18093c4 => 'Apply';

  @override
  String get commonApproximateGreatCircleDistances7eb1a34f =>
      'Approximate great-circle distances and constant airspeed per segment. No acceleration, hovering, manoeuvre time or gusts are included. The aircraft must be able to achieve the planned speed and climb rate.';

  @override
  String get commonApproximateMetricDistancesUse2ad8d0c4 =>
      'Approximate metric distances use the Swiss LV95 projection. 3D values use original source elevations converted to the terrain ellipsoid reference, not adjusted display geometry. The 30 m AGL preview is never a checked altitude.';

  @override
  String get commonAssessModeledBridgesSupports6afd1bbd =>
      'Assess modeled bridges, supports and tunnel walls';

  @override
  String get commonAssociatedDrones0b96fd82 => 'Associated drones';

  @override
  String get commonAstraVdpBestEffort6d0423b7 =>
      'ASTRA / VDP · Best-Effort measurement data, no confirmed traffic forecast.';

  @override
  String commonAtMGroundAltitude06f0de9e(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return 'At $arg0 m: ground $arg1, altitude $arg2, AGL $arg3.';
  }

  @override
  String get commonAus6997e3eb => 'Off';

  @override
  String get commonAusgewaehlteAufnahmenSindHistorische73e77349 =>
      'Selected recordings are historical or delayed published image data. No live observation. Only small STAC metadata are stored, no raw image files. Clouds, shadows and missing image coverage are not empty areas.';

  @override
  String get commonAvailable7c62a142 => 'Available';

  @override
  String commonAverageAirspeedMS071139b2(String arg0, String arg1) {
    return 'Average airspeed: $arg0 m/s · maximum $arg1 m/s';
  }

  @override
  String commonAverageGroundSpeedM20c0470a(String arg0, String arg1) {
    return 'Average ground speed: $arg0 m/s · maximum $arg1 m/s';
  }

  @override
  String commonAverageSpeedMSabf80b70(String arg0, String arg1, String arg2) {
    return 'Average $arg0 speed: $arg1 m/s · maximum $arg2 m/s';
  }

  @override
  String get commonBackupsSchuetzenSpotsBilder26ad5793 =>
      'Backups protect spots, images, equipment and planning regardless of the card cache. Optional password protects the export; unprotected backups are readable. API keys and public card/OSINT caches do not belong to the personal backup. Browsers can delete local memory; additional backups of important data.';

  @override
  String get commonBafuLiveWerteSind2d1baf8b =>
      'FOEN live values are uncorrected. 10 minutes means contain the unit provided and the available release status; unknown references remain unknown. Fresh local snapshots and age of a single measurement are separate data. Observations do not evaluate an activity as safe or replace official warnings. Retrieves are done consciously, at limited intervals; local measurement snapshots can be opened even without a net.';

  @override
  String get commonBaustellee9cf26e7 => 'Construction site';

  @override
  String get commonBazlAuthorisationSubtypesSame4c054fce =>
      'BAZL authorisation subtypes (same category, different applicable conditions):';

  @override
  String get commonBazlWmsZeigtKombiniertee1af0170 =>
      'BAZL-WMS shows combined raster images; categories and heights are not individually selectable. Vector data provide details as far as the source contains them. Unknown heights remain unknown. Especially cable connections and simple mast/crane models are approximations, no exact building image.';

  @override
  String get commonBeimAbrufWerdenDiecd3b9e12 =>
      'The selected map coordinates are sent to Open-Meteo during retrieval. \"Currently, model values are not live measurements on site. Data and selection are valid for this session.';

  @override
  String get commonBeobachtungen9156ea0e => 'Observations';

  @override
  String get commonBereichBisKmRadiusfecda995 =>
      'Prepare up to 25 km radius directly on this device: topography, SWISSIMAGE satellite images, neutral relief and 3D sites from official download sources. In the web version, the whole of Switzerland can also be selected.';

  @override
  String get commonBereicheVorbereiten1c921757 => 'Prepare areas';

  @override
  String get commonBeschleunigungMS1457d0c3 => 'Acceleration (m/s²)';

  @override
  String get commonBevorzugteEbenenSindSchnellzugriffe2eb52776 =>
      'Preferred levels are quick access to existing layer controllers. A profile does not enable data source, location sharing, API connection, or automatic update. Source settings and permissions remain independent. Profiles do not store access data or personal locations.';

  @override
  String get commonBewoelkung3dac517c => 'Clouds';

  @override
  String get commonBewoelkungModellbedeckungKeineGemessenencfb37c6a =>
      'Cloud: 0–100% model cover, no measured 3D clouds. Temperature: °C at 2 m height. All visible grids use the same forecast time.';

  @override
  String get commonBewoelkungNiederschlagRegenNeuschnee33c03591 =>
      'Clouds, precipitation, rain, new snow, snow height and temperature are separate model forecasts with common time. Sums are valid for one hour; snow height is independent of this. This sample grid is no weather radar and no measured 3D cloud. The weather area offers separately published MeteoSwiss radar images: Select time, load or play. Radar is an observation; missing images or pixels do not mean dry weather.';

  @override
  String commonBezugb64247b0(String arg0, String arg1, String arg2) {
    return 'Reference: $arg0 · $arg1, $arg2';
  }

  @override
  String get commonBodenansicht66b19097 => 'Ground View';

  @override
  String get commonBodenroutenfc34e044 => 'Ground routes';

  @override
  String get commonBremswirkungMSaca7620a => 'Braking (m/s²)';

  @override
  String get commonCalibrationOutsideIsNot45f5bb20 =>
      'Calibration outside 0.25–4× is not applied. Check units, sensors and flight conditions.';

  @override
  String get commonCampsites7c38c052 => 'Campsites';

  @override
  String get commonCancel77dfd213 => 'Cancel';

  @override
  String get commonChSwisstopoSpezialbefliegungen7d9cb953 =>
      'Specialised flying operations';

  @override
  String get commonChSwisstopoSwisseoS9f4a6c16 =>
      'ch.swisstopo.swisseo_s2-sr_v200';

  @override
  String get commonChannelBandwidth0c1b6ee1 => 'Channel bandwidth';

  @override
  String get commonChargeCyclesAndCondition2b6f03c0 =>
      'Charge, cycles and condition are recorded manually.';

  @override
  String get commonCheckAltitudeReferencesLocal541cb086 =>
      '3. Check altitude references, local/cantonal rules, aerodrome procedures, weather and obstacles.';

  @override
  String get commonCheckCurrentOfficialZonesb6eb2aee =>
      'Check current official zones, DABS/NOTAM, zone validity and height references, aircraft class and mass, pilot qualifications, people and property, permissions and local rules. These checks cannot be completed from the route alone.';

  @override
  String get commonClearOverlay89f8488e => 'Clear overlay';

  @override
  String get commonCloseNavigationMenu53cad4d7 => 'Close navigation menu';

  @override
  String get commonClosebbfa773e => 'Close';

  @override
  String get commonCodefrogRibbitCodefrogCh4326d9c5 =>
      'Codefrog · ribbit@codefrog.ch. The full privacy policy is linked under Offline & personal data.';

  @override
  String get commonCombinedRasterSymbolsNo01f2553a =>
      'Combined raster symbols: no category filters, object selection or precise 3D heights.';

  @override
  String get commonCommaSeparatedUpTo0410e8b5 =>
      'Comma separated · up to 10 tags, 32 characters each';

  @override
  String get commonCommunicationProfileUnavailableSelect22f9df96 =>
      'Communication profile unavailable. Select the path again to retry.';

  @override
  String get commonConnectingToDTerrain33c3d51a =>
      'Connecting to 3D terrain. Flat map shown.';

  @override
  String get commonContinue2e026239 => 'Continue';

  @override
  String get commonCruisePowere01cb967 => 'Cruise power';

  @override
  String get commonCruiseSpeed806d91ba => 'Cruise speed';

  @override
  String get commonDBauwerkeff58c166 => '3D structures';

  @override
  String get commonDGebaeudee0eaa628 => '3D buildings';

  @override
  String get commonDLichtEnthaeltGebaeude1ba3ed81 =>
      '\"3D & Light\" contains buildings, vegetation, buildings, automatic 3D tunnels and lighting. Tunnels and bridge pillars are schematic. Tunnel walls, floor and ceiling have geometric contact checks; the optional testing of foreign 3D models is only an approximation of charged surfaces. Missing objects are not added. Streaming 3D and labels are not complete offline levels. \"Sources\" opens the full active information.';

  @override
  String get commonDTerrainUnavailableFlatc09ad4e3 =>
      '3D terrain unavailable. Flat map shown; terrain heights are disabled.';

  @override
  String get commonDUndQuellen2d9ae897 => '3D and Sources';

  @override
  String get commonDVegetation7f361b72 => '3D vegetation';

  @override
  String get commonDatenquelleBundesamtFuerEnergieb3a50654 =>
      'Data source: Federal Office of Energy (SFOE), charging points Electromobility, geo.admin.ch · O-By-Ask. Use with source; commercial use only with prior permission of the data owner.';

  @override
  String get commonDatenquellen3253fdfe => 'Data sources';

  @override
  String commonDatensaetzeNichtSicherZugeordnet393f5548(String arg0) {
    return '$arg0 datasets not safely assigned / not weighted. Lack of road identification, direction, location resolution or validity remain unknown.';
  }

  @override
  String get commonDatenschutzUndApiZugaenge303f9be7 =>
      'Data protection and API access';

  @override
  String get commonDatenschutzkontakteec0b69d => 'Privacy contact';

  @override
  String get commonDatenstandUndVerfuegbarkeit0ff67f1d =>
      'Data level and availability';

  @override
  String get commonDefaultsMAntennaMhz63828140 =>
      'Defaults: 2 m antenna, 5800 MHz and 60% first-zone radius. Set the actual control or video frequency for each analysis.';

  @override
  String get commonDeletef6fdbe48 => 'Delete';

  @override
  String get commonDerGewaehlteAusschnittWird46b1cc5d =>
      'The selected section is sent to geo.admin.ch. Spatial extract, no complete accessibility check.';

  @override
  String get commonDerKompassRichtetDie15ee98a3 =>
      'The compass directs the map to the north. \"My location is only looking for taps. Long press opens accuracy and tracking; map movements end the pursuit. The search accepts coordinates, places and roads.';

  @override
  String get commonDieKantoneErlassenDiea929ec2f =>
      'The cantons adopt the binding rules. A hazard level alone does not justify a fire ban. Lack of, outdated or incomplete data does not mean no warning.';

  @override
  String get commonDieTagesuebersichtZeigtDie3e26c236 =>
      'The daily overview shows the highest published regional level. Altitudes, exposures and avalanche problems are described in the description when tapping. The colour does not apply to every slope.';

  @override
  String get commonDisabledf4f4473d => 'Disabled';

  @override
  String get commonDocumentation9e9cf322 => 'Documentation';

  @override
  String get commonDonee9b450d1 => 'Done';

  @override
  String get commonDrinkingWaterc9176049 => 'Drinking water';

  @override
  String get commonDrivingRouteToAn298a4f2a =>
      'Driving route to an address, coordinates or saved spot. Times are OSRM baseline estimates. Available traffic can help compare alternatives. Verify parking, private roads and the final approach locally.';

  @override
  String get commonDrohnenprofileNichtVerfuegbarManuelle5ff33edb =>
      'Drone profiles are unavailable. Manual settings are still available.';

  @override
  String get commonDurchflugNichtVerfuegbarAngaben4931f578 =>
      'Fly-through unavailable. Check the entry, elevation profile or terrain cutouts.';

  @override
  String get commonEbenenUndDatenschutze913d2a4 => 'Levels and data protection';

  @override
  String get commonEbenenc8f2bacd => 'Levels';

  @override
  String get commonEigeneSpotsFotosAusruestunga83357cb =>
      'Private spots, photos, equipment, routes and checklists are already local. Downloaded UAS zones, vector barriers and SLF bulletins remain available as dated snapshots. Update these levels in the map side if necessary. WMS images, streamed buildings/trees, traffic, flight movements and ongoing weather data are not promised as complete offline data sets.';

  @override
  String get commonEin3b564e70 => 'On';

  @override
  String get commonEinLaptopIstFuer32903d0e =>
      'A laptop is not required for processing. Already created .fpvregion packages up to 64 MiB can still be imported. Source gaps, national borders and the selected level of detail limit the coverage.';

  @override
  String get commonEineModellprognoseIstKeineae457c8d =>
      'A model forecast is not a local wind measurement at the flight point. The 3D arrows follow the air flow, not the meteorological direction of origin. Colors: green <3, yellow 3–7, orange 7–12, red from 12 m/s. Missing or expired values do not remain available.';

  @override
  String get commonEineUasZoneIst43501474 =>
      'Restrictions vary by UAS zone. Check every overlapping restriction, the authority responsible, times, heights and authorisation requirements. Colours reflect supported source attributes. Blue does not grant flight clearance. Spatial checks cover geometry and cannot replace a legal assessment.';

  @override
  String get commonEingabeInDerZeitzone41488cc9 =>
      'Enter the date and time in the device\'s time zone. The app stores them in UTC. This previews lighting only. Weather and flight authorisation are unchecked.';

  @override
  String get commonEingabed3a77fb1 => 'Input';

  @override
  String get commonEn094b0fe0 => 's';

  @override
  String get commonEnableddf174a3f => 'Enabled';

  @override
  String get commonEndgeschwindigkeitImFreienFall86d01f28 =>
      'Free-fall terminal velocity (m/s)';

  @override
  String get commonErneutVersuchen3234b7ec => 'Try again';

  @override
  String get commonEstimatedae64c7cf => 'Estimated';

  @override
  String get commonEstimatesAreNotGuarantees31122c9b =>
      'Estimates are not guarantees. Scenarios scale consumption; they are not statistical confidence intervals. Validate the model against measured flights. Battery condition, temperature and voltage sag can reduce usable energy.';

  @override
  String get commonExperimentellGeladeneModelloberflaechenKeine5d6ce860 =>
      'Experimental · approximate contact with loaded model surfaces.';

  @override
  String get commonExpoLinearWeich280777be => 'Expo (0 linear, 1 soft)';

  @override
  String get commonFahrplanIstNichtGarantiertc1ec8079 =>
      'Timetable is not guaranteed. Forecasts only if available from the data supplier. Stored data is never live.';

  @override
  String get commonFehlenImAkkuDie64009d59 =>
      'If starting charge is unknown, 100% is used as an editable assumption. Estimating voltage requires the drone profile to specify hover power, cruise power and cruise speed.';

  @override
  String commonFirstCoordinateWgsbca0344d(String arg0, String arg1) {
    return 'First coordinate: $arg0, $arg1 · WGS84';
  }

  @override
  String get commonFlugBedienung59a0edfe => 'Flight & controls';

  @override
  String get commonFlugaufzeichnung0cfe3bb1 => 'Flight recording';

  @override
  String get commonFlugeigenschaften5e125e21 => 'Flight characteristics';

  @override
  String get commonFlugeinstellungen51e6bd4a => 'Flight settings';

  @override
  String get commonFlugrouten39801473 => 'Flight routes';

  @override
  String get commonFpvPlannedVerifyObservera86fbfbe =>
      'FPV planned: verify observer requirements, direct visual contact and communication.';

  @override
  String get commonFpvmanagerCsvVTime07c740c7 =>
      'FPVManager CSV v1: time_s,airspeed_m_s,voltage_v,current_a (groundspeed_m_s is also accepted).\nEdgeTX: Date, Time, GSpd(kmh/km/h/m/s/kts), Curr(A), VFAS(V) or Bat(V).\nUse a single voltage and speed column. UTF-8, decimal dot, 2–20000 rows, up to 4 MiB, gaps ≤30 s. Missing measurements are rejected. See docs/preflight.md for an example.';

  @override
  String get commonFpvmanagerSpeichertPersoenlicheEintraegea3c540bd =>
      'FPVManager stores personal records on the device. iOS can include them in device backups. Online tiles can reveal your location area when you center or follow. FOSSGIS logs route requests. Open-Meteo says it deletes logs after 90 days.';

  @override
  String get commonFrequency89836a87 => 'Frequency';

  @override
  String get commonFreshInnerhalbDerAbrufrichtlinie329c6fa9 =>
      'Fresh: within the Retrieval Policy. Stale/expired: outdated or expired. Unavailable: no usable data level. Refresh failed: the update failed; a previous status can still be displayed. Source status and warnings remain with the respective tool. No display guarantees a safe or allowed flight.';

  @override
  String get commonFuerDiesesEinsatzproduktIst01b0accb =>
      'No georeferenced, limited readable RGB geoTIFF with confirmed projection is stored for this application product. No map image invented.';

  @override
  String commonGebietKmMaximalDetektoren3b49fe28(String arg0, String arg1) {
    return 'Area: $arg0, $arg1 · 30 km · maximum 100 detectors';
  }

  @override
  String get commonGefahr7a20fb89 => 'Danger';

  @override
  String get commonGelaendehoehe77ccc7f0 => 'Terrain elevation';

  @override
  String get commonGelaendehoeheAbfragencba121dc => 'Check terrain height';

  @override
  String get commonGemesseneWerte1e2beb80 => 'Values measured';

  @override
  String get commonGeometricVisibilityAndFresnelcc5d61f4 =>
      'Geometric visibility and Fresnel clearance are approximations, not measured signal quality or a guaranteed communication range.';

  @override
  String get commonGewaesserUndAktualitaet3be29a45 => 'Waters and timeliness';

  @override
  String get commonGrafikLichtfef9954a => 'Graphics & lighting';

  @override
  String get commonGrafikTageszeitac9c3755 => 'Graphics & time of day';

  @override
  String get commonGrenzend6f52947 => 'Boundaries';

  @override
  String commonGroesstePublizierteVerzoegerungMinc0ec7c7c(String arg0) {
    return 'Largest published delay: $arg0 min · Comparable value, not added to arrival time';
  }

  @override
  String get commonHeightConversionChgeoHtranscc1a7473 =>
      'Height conversion: CHGeo2004 + HTRANS → ETRS89 ellipsoid (WGS84 approximation). For single Point obstacles with valid AGL, the rendered marker and height stem use local Cesium terrain + source AGL; the source top AMSL remains listed above and may differ. Cable vertices that match a unique published mast (within 2 m horizontally and 5 m in source top elevation) follow its displayed top; offsets between matched supports are interpolated. This is an approximate display correction, not surveyed cable geometry. Unmatched sections retain source heights. Route checks use original source elevations.';

  @override
  String get commonHilfeHinweise1f11bc49 => 'Help & information';

  @override
  String get commonHilfeZurKarte2a98c570 => 'Map help';

  @override
  String get commonHindernisseUndFunkabschattunga9ce1773 =>
      'Obstacles and wireless shading';

  @override
  String get commonHinzufuegenf0d37b9d => 'Add';

  @override
  String get commonHoechstgeschwindigkeitMS7904c398 => 'Maximum speed (m/s)';

  @override
  String get commonHoehenbezug920e5815 => 'Height reference';

  @override
  String commonHorizontalDAirspeedM069070e6(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
  ) {
    return '$arg0 horizontal · $arg1 3D\nAirspeed $arg2 m/s · $arg3 · clearance $arg4';
  }

  @override
  String get commonHorizontalWgsGeometryOnly45382b9e =>
      'Horizontal WGS84 geometry only, including boundary contact. Route segments are straight between waypoints. Height limits, activation times and legal applicability are not evaluated. This check is not flight authorization.';

  @override
  String get commonHorizontalesSichtfeldae3aaf25 =>
      'Horizontal field of view (°)';

  @override
  String get commonHoverPowerbaf23552 => 'Hover power';

  @override
  String get commonImBereichBodenroutenWaehlstf1272516 =>
      'In the area of ground routes, you explicitly select \"On foot\" or \"Velo\". After your consent, start and destination are sent to the corresponding FOSSGIS/OSRM profiles. Calculated and imported routes remain available as own local datasets even without a network and are backed up with the personal backup. GPX receives the activity mode and existing source heights without generating AGL heights. Unknown GPX types require the selected import mode; additional or unsupported information is reported. A stored line history does not confirm any current opening. The area provides planning and exchange; the previous autonavigation is independent.';

  @override
  String get commonImportLocallycfc01f3f => 'Import locally';

  @override
  String get commonImportieren7d4a3f2a => 'Import';

  @override
  String get commonIncompleteCheckGeometryCandidate8ab13e83 =>
      'Incomplete check: geometry, candidate or calculation limits were reached. Some obstacles were not evaluated.';

  @override
  String get commonJpegPngOrWebpe13c3bbf =>
      'JPEG, PNG or WebP · up to 12 MiB and 16 MP each. Photos are resized and stored locally.';

  @override
  String get commonJsonMitEpsgQuellef95a2fe5 =>
      'JSON with EPSG:4979, source and separate collision mesh. GLB/IFC are not supported directly.';

  @override
  String get commonKacory5617237a => 'kacory';

  @override
  String get commonKameraAnzeige6c89d080 => 'Camera & display';

  @override
  String get commonKameraHudd79e87be => 'Camera & HUD';

  @override
  String get commonKameraneigung4c3e596e => 'Camera tilt';

  @override
  String get commonKameraneigungNachOben943b5e57 => 'Upward camera tilt (°)';

  @override
  String get commonKarteAnsichtBuendeltKarte719d6808 =>
      '\"Map & View\" bundles map, airspace, obstacles and OSINT. Satellite, topo and relief are background maps; streets, labels and saved spots can be switched independently. Labels show a limited selection of Swiss local and street names. Rare tools and metadata can be opened if necessary; current errors and data gaps remain visible.';

  @override
  String get commonKarteAnsichtb4cd1571 => 'Map & view';

  @override
  String get commonKarteUndBeschriftungen20474dfe => 'Map and labels';

  @override
  String get commonKarteUndLaufendeAktivitaeten4df7dcc2 =>
      'Map and current activities';

  @override
  String get commonKarteZuruecksetzend562ce9b => 'Reset map';

  @override
  String get commonKartenbewegungBeendetDieVerfolgung79535231 =>
      'Moving the map stops location following.';

  @override
  String get commonKartenebenen83ea2698 => 'Sides';

  @override
  String get commonKartenpunktOrtOderRoute53c79c56 =>
      'Select map point, location or route';

  @override
  String get commonKartenstartwerteGeltenBeimApp3fbf4f32 =>
      'Card start values are valid for the app start, activate or save the active profile. Later changes on the map remain until the next activation or restart. During ground view, simulation, navigation or paused renderer, start values are reset and applied only afterwards. Camera, selection, running control, forms and personal records are not reset when switching. Without profile, the current map is retained.';

  @override
  String get commonKeinOnlineNachladenFuer3b0d241a =>
      'Base map and terrain stay cache-only after restart. Live data can still use the network.';

  @override
  String get commonKeine3ce60e74 => 'None';

  @override
  String get commonKeineTrefferBedeutenNicht4cb792ac =>
      'No hits don\'t mean there are no charging stations.';

  @override
  String get commonKeineTrefferBedeutenNichtdf8f1b9e =>
      'No hits do not mean that there is no attachment.';

  @override
  String get commonKeysAreStoredLocally5e3f356a =>
      'Keys are stored locally using encrypted OS-backed storage, not app preferences.';

  @override
  String get commonKoordinatenOrtOderStrasseed101593 =>
      'Coordinates, place or street';

  @override
  String get commonKoordinatenUndHoehene15ceca0 => 'Coordinates and heights';

  @override
  String get commonKritischeZellspannungVc0450582 =>
      'Critical voltage (V/cell)';

  @override
  String get commonLatitudeLongitudeHeightM29549b09 =>
      'latitude,longitude,height_m_agl,radius_m,kind,source\nKinds: building, vegetation, other. Up to 100 observations. Heights 0–1000 m AGL, radius 1–1000 m.';

  @override
  String get commonLawineninformationen505b7525 => 'Lawineninformationen';

  @override
  String get commonLeaveUnknownValuesEmptyc1fa72a7 =>
      'Leave unknown values empty. Identify each entered value as measured, estimated or source not specified. Editing a number resets its previous source.';

  @override
  String get commonLinksBewegungRechtsBlickf668a7b3 =>
      'Left: movement · Right: look · E/Q: altitude';

  @override
  String get commonLinksGasYawRechtsd7f829e1 =>
      'Left: throttle / yaw · Right: pitch / roll';

  @override
  String get commonLoading33ce4174 => 'Loading…';

  @override
  String get commonLoeschenffa5a8a7 => 'Delete';

  @override
  String get commonLokalUndOnline5fe8b49a => 'Local and online';

  @override
  String get commonLuftfahrthindernissef4bb6756 => 'Air traffic barriers';

  @override
  String get commonLuftraumUndFlugvorbereitung28d1eda6 =>
      'Airspace and flight preparation';

  @override
  String get commonManualAssumptionNotAn31019e80 =>
      'Manual assumption, not an automatically verified forecast.';

  @override
  String get commonMapLayerse2967959 => 'Map Layers';

  @override
  String get commonMapLayersfdee4317 => 'Map layers';

  @override
  String get commonMapOrangePotentialObstructionbe96635a =>
      'Map: orange = potential obstruction, purple = Fresnel intrusion, cyan = no sampled obstruction, gray = unknown. The selected path shows the configured Fresnel envelope.';

  @override
  String get commonMarkiertePufferUmVeroeffentlichte170a2673 =>
      'Marked buffers around published points/lines are planning aids. They do not define legal distance nor vertical free-access. Funk-LOS/Fresnel checks supported terrain data and assumptions; buildings, vegetation and undetected objects can continue to shade. Missing obstacles or free geometry are not a security evidence.';

  @override
  String get commonMaximalerSchubGewichtbf903e1b =>
      'Maximum thrust-to-weight ratio';

  @override
  String get commonMaximumClimbRate97079473 => 'Maximum climb rate';

  @override
  String get commonMaximumPower96af2765 => 'Maximum power';

  @override
  String get commonMaximumSpeedb02bf3de => 'Maximum speed';

  @override
  String get commonMaximumTransmitterPower654a8d01 =>
      'Maximum transmitter power';

  @override
  String get commonMeasured9550373e => 'Measured';

  @override
  String get commonMeasuredHourlyStationAverages6b75bd38 =>
      'Measured hourly station averages (No/m³, pollen grains per cubic metre); not a forecast or an exposure estimate at the selected spot.';

  @override
  String get commonMeinStandort98425c52 => 'My location';

  @override
  String get commonMessstationenf5f4587a => 'Measuring stations';

  @override
  String get commonMeteoswissStationswerteSindMessungen2c9d236f =>
      'MeteoSwiss station values are measurements at a single location; wind and gusts are in the source format km/h, precipitation as a sum of ten minutes. The measuring times are UTC and are additionally displayed locally. They do not describe a complete wind field and do not change the simulator wind. Missing quality flags remain unknown.';

  @override
  String get commonMethodSourcesLimits2cadbcdb => 'Method, sources & limits';

  @override
  String get commonMissingTilesRemainUnavailable2b39e068 =>
      'Missing tiles remain unavailable. Live data layers and API actions are separate and may still use the network.';

  @override
  String get commonMittelpunktAufDemGlobec923e1bf =>
      'Select the center on the globe or enter coordinates, select radius up to 25 km and desired details/assets. Web also offers the entire of Switzerland. Download and preparation require time, free memory and an open app. Source gaps and selected details limit the coverage.';

  @override
  String get commonMobilitaetOsint610c90a7 => 'Mobility & OSINT';

  @override
  String get commonModelWindAtM9f419984 =>
      'Model wind at 10 m and 80 m is not a prediction of local rotor turbulence. Valleys, ridges, obstacles and thermals may cause major deviations.';

  @override
  String get commonModellUndMessung5e4ffe89 => 'Model and measurement';

  @override
  String get commonMotorAnsprechzeitS5a0796fd => 'Motor response time (s)';

  @override
  String get commonMotorCount7eb9729b => 'Motor count';

  @override
  String get commonMoveTheMapTob0c48a5b =>
      'Move the map to a place, then tap the map to set your first waypoint.';

  @override
  String get commonNameDescriptionCategoryOr5d2460f9 =>
      'Name, description, category or tags';

  @override
  String get commonNaturUndSperrungen058761a3 => 'Nature and closures';

  @override
  String get commonNavigationUndMobilitaet625d3f0a => 'Navigation and mobility';

  @override
  String get commonNavigationUndVerkehredf4cfaf => 'Navigation and transport';

  @override
  String get commonNeuschneesummeH10eeb220 => 'New snow sum (1 h)';

  @override
  String get commonNextbc981983 => 'Next';

  @override
  String get commonNiederschlagUndGrossraeumigerRegen09d9c44f =>
      'Precipitation and large-scale rain are sums of the previous hour (mm), new snow in cm, snow height in m. A rain rate or type of precipitation is not derived from it.';

  @override
  String get commonNiederschlagssummeHb61d9c9a => 'Precipitation sum (1 h)';

  @override
  String get commonNo816c52fd => 'No';

  @override
  String get commonNoBuildingOrCanopy5fb91054 =>
      'No building or canopy service is connected. Import known local footprints as circular AGL height observations. These are approximate site observations, not a complete surface model.';

  @override
  String get commonNoEquipmentProfilesYet41f7bf08 =>
      'No equipment profiles yet. Add separate configurations for radio control, video or telemetry.';

  @override
  String get commonNone6eef6648 => 'None';

  @override
  String get commonNotRecorded305cc364 => 'Not recorded';

  @override
  String get commonNotes70440046 => 'Notes';

  @override
  String get commonNurNachManuellemStartca69930e =>
      'Only after manual start · limited query, no national downloads';

  @override
  String get commonObservationNotForecastMissingb7760aa1 =>
      'Observation, not forecast. Missing pixels and missing dates must not be interpreted as dry weather.';

  @override
  String get commonOffizielleBakomStandorteStationstyp81519366 =>
      'Official BAKOM locations. Station type, performance class and technology are displayed only according to source. The coordinates indicate the first mast of a station. They are not obstacle geometry and do not measure FPV coverage.';

  @override
  String get commonOfflineFlatMapShownaa2963ed =>
      'Offline: flat map shown. Terrain heights are unavailable.';

  @override
  String get commonOfflineKartenUndBackups5cb5d797 =>
      'Offline maps and backups';

  @override
  String commonOfflinePaketGrobMibeae634d2(String arg0, String arg1) {
    return 'Offline package coarse $arg0 MiB (map content varies), maximum 64 MiB. Original files for processing can be significantly larger.$arg1';
  }

  @override
  String get commonOfflineUndPersoenlicheDaten7b8d1b0c =>
      'Offline and personal data';

  @override
  String get commonOnePairPerLine94168101 =>
      'One pair per line. Level flight only, without climb power. No extrapolation outside the curve.';

  @override
  String get commonOpenCurrentBazlMap31b230a4 =>
      '1. Open current BAZL map, check every applicable overlapping zone and contact the competent authority when necessary.';

  @override
  String get commonOpenMeteoCcBy8eb16c41 =>
      'Open-Meteo · CC BY 4.0; free access for non-commercial use. Current model wind is updated every 15 minutes when active display or in flight. Forecasts use the next available hourly value. Sun time and wind time are independent. Wind vectors are interpolated between grid points and model heights (10, 80, 120, 180 m AGL). Outside known heights, the next layer is constantly continued. Outside of the loaded section or missing data, there is no wind influence. No additional artificial gusts and no calculation of building turbulences, thermals or small-scale terrain flow.';

  @override
  String get commonOpenSettingsfd7108f8 => 'Open settings';

  @override
  String get commonOptionalAdsbLolCommunity571b79fc =>
      'Optional adsb.lol community reception snapshot within 25 nautical miles (≈46 km). No automatic polling, history or extrapolation. No data is downloaded until requested. OpenSky is not used because application integration requires a written licence.';

  @override
  String get commonOptionalCircularAglObservations3ad9fcc1 =>
      'Optional circular AGL observations, as in preflight analysis. Visible 3D buildings, forests, masts and cables are not automatically included.';

  @override
  String get commonOptionalNearbyPointsFrom6d1c26fc =>
      'Optional nearby points from OpenStreetMap via Overpass. Each request is initiated manually, limited to 2 km and six categories. Missing results do not prove that a facility does not exist. Never use these results as an authoritative source of drinking-water safety or access.';

  @override
  String get commonOptionalStationspunkteKeineMasthoehen32868013 =>
      'Optional · Station points, no mast heights or signal cover';

  @override
  String get commonOptionalerInnenwiderstandJeZelle8ca0db6d =>
      'Optional internal resistance per cell (Ω; 0 = off)';

  @override
  String get commonOrientierung74a0fc2b => 'Orientation';

  @override
  String get commonOrtOderKoordinatenSuchen6904cb89 =>
      'Search for a place or coordinates';

  @override
  String get commonOrtSuchen06144b10 => 'Search for a place';

  @override
  String get commonOutdoorKartenUndMessstationen76975577 =>
      'Outdoor maps and measuring stations';

  @override
  String get commonPersoenlicheDatenf0cbba56 => 'Personal data';

  @override
  String get commonPersoenlicheEintraegeBleibenLokal72d5b20b =>
      'Personal entries remain local. Map providers see requested map sections; activated labels also send only the required area. A confirmed route sends start/target to the routing service. Location/address searches are only transferred when sent. Location display is voluntary and works only in the foreground; no location history is created.';

  @override
  String get commonPfeileUndEinflussAuf9b831fb0 =>
      'Arrows and influence on flight physics can be switched independently. A fixed sun/moon time does not change the wind data. For another wind forecast explicitly choose the data source/time. Local gusts and terrain effects may differ from the model approach.';

  @override
  String get commonPhotosc8b2e864 => 'Photos';

  @override
  String get commonPitchMaximalScbf3d02c => 'Maximum pitch rate (°/s)';

  @override
  String get commonPlanningChecksOnlyNo5a915c9e =>
      'Planning checks only. No flight authorisation or guarantee of terrain, obstacle or airspace clearance.';

  @override
  String get commonPlanungshilfen4c6529d9 => 'Planning aids';

  @override
  String get commonPlaygrounds2472110c => 'Playgrounds';

  @override
  String commonPotentialObstructionSurfaceMf0e561ae(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Potential obstruction: $arg0, $arg1 · surface $arg2 m WGS84 ellipsoid';
  }

  @override
  String get commonPowerPerformance72b3155b => 'Power & performance';

  @override
  String get commonPreparationa8bc3820 => 'Preparation';

  @override
  String get commonProfileUndAuswahlSindd905de42 =>
      'Profiles and selection are part of personal backups. Individual profiles can be exported as versioned .fpvprofile file. The import shows a preview and adds an inactive profile without overwriting existing profiles. Up to 32 profiles and files up to 128 KiB are supported.';

  @override
  String get commonPropellerCount0e5ac786 => 'Propeller count';

  @override
  String get commonPropellerPitchb46bd729 => 'Propeller pitch';

  @override
  String get commonPropulsione8ec111d => 'Propulsion';

  @override
  String get commonProtocolSystemb95bcf23 => 'Protocol / system';

  @override
  String commonQuelle25cfc7b8(String arg0) {
    return 'Source: $arg0';
  }

  @override
  String get commonQuelleBundesamtFuerEnergiea8a665a6 =>
      'Source: Federal Office of Energy (SFOE), sharedmobility.ch – locations and availability of shared mobility offers. Data may be delayed or incomplete. No booking or reservation.';

  @override
  String get commonRadiob11bf19e => 'Radio';

  @override
  String get commonReady20c7c552 => 'Ready';

  @override
  String get commonReceiverAntenna09c32a42 => 'Receiver & antenna';

  @override
  String get commonReceiverAntennaCharacteristics8fa01aa6 =>
      'Receiver antenna characteristics';

  @override
  String get commonReceiverAntennaGain1e5045a8 => 'Receiver antenna gain';

  @override
  String get commonReceiverCableConnectorLossa4943703 =>
      'Receiver cable / connector loss';

  @override
  String get commonReceiverModel33350928 => 'Receiver model';

  @override
  String get commonReceiverPolarization24abf7a4 => 'Receiver polarization';

  @override
  String get commonReceiverSensitivity1118dfab => 'Receiver sensitivity';

  @override
  String get commonReceiverSpecificationsOperatingMode752249f6 =>
      'Receiver specifications / operating mode';

  @override
  String commonRecordedTrajectoryNorthUp84f04fe5(String arg0) {
    return 'Recorded trajectory, north up, with height profile. $arg0 metres.';
  }

  @override
  String get commonRedMapSegmentsIndicate9cf68571 =>
      'Red map segments indicate sampled terrain clearance, battery reserve, or findings from the current route checks. Open Checks for the reason; a horizontal zone match does not establish legal applicability.';

  @override
  String get commonReferenceVoltage24d76e09 => 'Reference voltage';

  @override
  String get commonRefresh56e3badc => 'Refresh';

  @override
  String get commonRegenGrossraeumigH0f1e72be => 'Rain · Large (1 h)';

  @override
  String get commonRegionaleIndikatorenUndSatellitengestuetzte10059e46 =>
      'Regional indicators and satellite-based models, no measurement of local soil moisture. Neither fire bans nor water withdrawal restrictions are derived from these maps. Lack of tiles are no warning.';

  @override
  String get commonReliefbe53bb74 => 'Relief';

  @override
  String get commonReloadcce71553 => 'Reload';

  @override
  String get commonRemoveKey582d9a78 => 'Remove key';

  @override
  String get commonRemovee963907d => 'Remove';

  @override
  String get commonRequestsAppearInProviderc028be67 =>
      'Requests appear in provider logs. No spot names, notes or account data are sent.';

  @override
  String get commonReset44c57abd => 'Reset';

  @override
  String get commonResultsExpireAfterSecondsfc4e5dd8 =>
      'Results expire after 5 seconds. Flight movement, pauses, respawns and unavailable terrain can make a result unknown. Terrain publication time is not supplied by this sampling interface. Radio propagation, interference, antenna patterns and material attenuation are not modelled.';

  @override
  String get commonRetired37d1213e => 'Retired';

  @override
  String get commonRetraceThePlannedPathec9e751c =>
      'Retrace the planned path, with reverse-direction wind. No return leg is added at takeoff.';

  @override
  String commonRetrievedc0a8bd29(String arg0) {
    return 'Retrieved: $arg0';
  }

  @override
  String get commonRetry9f5cd8a2 => 'Retry';

  @override
  String get commonReturnToTakeoffIs90ab579c =>
      'Return to takeoff is included by retracing the planned path, with wind recalculated in reverse.';

  @override
  String get commonReviewTheSavedRoute73d944db =>
      'Review the saved route before real flight. Sampled motion, terrain and timing are simulated; drone and battery assignments can be added in the route editor.';

  @override
  String get commonRollMaximalS70a32bd1 => 'Maximum roll rate (°/s)';

  @override
  String get commonRollPitchGasUndf22bbf00 =>
      'Roll, pitch, gas and yaw require four different USB channels. Assignment and direction depend on remote control and operating system. Switches do not trigger reset or exit.';

  @override
  String get commonRouteName4421bcfb => 'Route name';

  @override
  String get commonRoutenUndAnsagenSind26c916e8 =>
      'Routes and announcements are orientation aids. Road rules and the real situation proceed. The compass first aligns to the north; again tapping returns to the oblique tracking view. Inaccurate GPS signals limit direction and recalculation.';

  @override
  String get commonRoutesTrafficAircraft309ea855 =>
      'Routes, traffic & aircraft';

  @override
  String get commonSampledModelPointsArounda07ce918 =>
      '49 sampled model points around the selected spot. Display spacing does NOT indicate actual meteorological model accuracy; no spatial interpolation. This is NOT a MeteoSwiss layer, even if MeteoSwiss is selected above.';

  @override
  String get commonSaveKeyf5216b3a => 'Save key';

  @override
  String get commonSaveSpotsImagesEquipmentdd4221ef =>
      'Save spots, images, equipment, routes, checklists, telemetry and planning preferences in one local file (up to 64 MiB). Public map/OSINT caches and API keys are excluded.';

  @override
  String get commonSavedPlaces364519ea => 'Saved places';

  @override
  String get commonSavedSpot64ad0674 => 'Saved spot';

  @override
  String get commonSaveefc007a3 => 'Save';

  @override
  String get commonSaving56a2285c => 'Saving…';

  @override
  String get commonSavingae7e8875 => 'Saving...';

  @override
  String commonScaleThisSavedRoutes1968fc72(String arg0) {
    return 'Scale this saved route’s power curve by $arg0. This is a level-flight approximation over the logged speed profile; climbs, wind, aggressive maneuvers and battery/sensor errors can distort it. The original CSV remains stored. Other routes and drone specifications are unchanged.';
  }

  @override
  String get commonSchliessen44424b18 => 'Close';

  @override
  String get commonSchneehoehe063f48a9 => 'Snow height';

  @override
  String get commonSchneeschuhrouten232e5840 => 'Snowshoe routes';

  @override
  String get commonSchubkurveLinearQuadratischa35ca8b8 =>
      'Thrust curve (0 linear, 1 quadratic)';

  @override
  String commonSelectedGlobeLocation8a849707(String arg0, String arg1) {
    return 'Selected globe location ($arg0, $arg1)';
  }

  @override
  String get commonSendSelectedCenterRadiusdd0ed3a0 =>
      'Send selected center, radius and categories to the public Overpass API.';

  @override
  String get commonSettingsc7f73bb5 => 'Settings';

  @override
  String get commonSharedMobilityBfeSharedmobility7d5c9e61 =>
      'Shared Mobility (SFOE / sharedmobility.ch). Pointed REST query, without automatic location monitoring or reservation.';

  @override
  String get commonSichernUndTeilen9769e149 => 'Secure and share';

  @override
  String get commonSichtfeldd835ebc7 => 'Field of view';

  @override
  String get commonSimModellwertKeineEchte2ec26181 =>
      'SIM: model estimate, not real battery telemetry.';

  @override
  String get commonSimulierterAkkuHud043eb4df => 'Simulated battery (HUD)';

  @override
  String get commonSituationsmeldungenUndMessstellenSinde2636ae0 =>
      'Situation messages and measuring points are different sources with their own tokens. TMC codes require the appropriate official location table. Unlocated, expired or incomplete messages must not be considered as a free distance. Measuring speeds are punctual observations, not a comprehensive live-stow map.';

  @override
  String get commonSomeTerrainTilesAre771ea391 =>
      'Some terrain tiles are unavailable. Loaded 3D terrain remains visible; heights may be missing in affected areas.';

  @override
  String get commonSource6da13add => 'Source';

  @override
  String get commonSourceMeteoswissFsdiStac0fd2fd76 =>
      'Source: MeteoSwiss · FSDI STAC · Swiss pollen monitoring network. Coverage is limited to published stations. Data are observations, not medical advice.';

  @override
  String get commonSourceNotSpecifieda922455d => 'Source not specified';

  @override
  String get commonSourceSnapshotIsDelayed341226cb =>
      'Source snapshot is delayed, its publication time is unknown, or the source/device clocks disagree. Retrieval/import time does not make old positions current.';

  @override
  String get commonSourceSwisstopoTerrainValues0aaf6e16 =>
      'Source: swisstopo terrain. Values use a digital terrain model, not measured aircraft height or verified obstacle clearance.';

  @override
  String get commonSpecificationSourceMeasurementContextf57759cc =>
      'Specification source / measurement context';

  @override
  String get commonSpeichern70b73bbc => 'Save';

  @override
  String get commonSperrung6e842243 => 'Blocking';

  @override
  String get commonSperrungenUndUmleitungenMountainbike12e5ddcf =>
      'Blocks and redirections · Mountain bike';

  @override
  String get commonSperrungenUndUmleitungenVelo88b39c0a =>
      'Locks and redirections · Velo';

  @override
  String get commonSperrungenUndUmleitungenWanderne50fe2ab =>
      'Blocks and redirections · Hiking';

  @override
  String commonSpotPositiond64f0e9b(String arg0, String arg1) {
    return 'Spot position · $arg0, $arg1';
  }

  @override
  String commonStandOfflineNichtLive42b1bd9b(String arg0) {
    return 'Status $arg0 · offline, not live';
  }

  @override
  String get commonStartZielUndReisezeit1a5914f9 =>
      'Send start, destination and travel time for query to opentransportdata.swiss.';

  @override
  String get commonStartenUndAnpassen92258e7a => 'Start and Customize';

  @override
  String get commonStarthoeheUeberGrundMc947203e =>
      'Starting height above ground (m)';

  @override
  String get commonStartladungSchaetzung865c309f =>
      'Starting charge (%) · Estimate';

  @override
  String commonStation5a5e3cd7(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return 'Station $arg0$arg1 · $arg2, $arg3';
  }

  @override
  String get commonStauStockenderVerkehr5b47c80a =>
      'Traffic jams / stagnant traffic';

  @override
  String get commonSteigenSinkenMaximalM011fe6b0 =>
      'Maximum climb / descent rate (m/s)';

  @override
  String get commonSteuerungUndSimulation3a676b6f => 'Control and simulation';

  @override
  String get commonSticksb0cca9f9 => 'Sticks';

  @override
  String get commonStopRecordingee0d9dc8 => 'Stop recording';

  @override
  String get commonStrasseOrtOderMeldung26ebddfb =>
      'Find a street, place or message';

  @override
  String get commonStrassenUndWegea615580e => 'Roads and paths';

  @override
  String get commonSwisstopoTerrainViaCesium6cb5e495 =>
      'swisstopo terrain via Cesium, WGS84 ellipsoidal heights. The straight ECEF line accounts for Earth curvature. Targets are at most 100 m apart and each radio path is sampled at intervals of at most 25 m. Imported surface observations add their specified height within their radius. Targets beyond 50 km or with unknown altitude are marked unknown. The map shows the group of up to 128 paths around the selected result. Recalculate after route, pilot or terrain changes.';

  @override
  String get commonSynthetischesModellPortaleUnd61794358 =>
      'Synthetic model · Portals and dimensions estimated. Simulation only, no real clearance.';

  @override
  String get commonTakeoffWeightc5470a62 => 'Takeoff weight';

  @override
  String get commonTastaturUndFunke92dc0407 => 'Keyboard and radio';

  @override
  String get commonTerrainChecksSampleAt803435c1 =>
      'Terrain checks sample at intervals up to 50 m. Terrain between samples, nearest-surface legal height, zone height limits, activation times and exemptions are not automatically verified.';

  @override
  String get commonTerrainInformation6e2466e7 => 'Terrain information';

  @override
  String get commonTerrainRadioPathe61f3070 => 'Terrain & radio path';

  @override
  String commonTerrainSamples1a8cac51(String arg0, String arg1) {
    return '$arg0 / $arg1 terrain samples';
  }

  @override
  String commonTerrainSamplesAtMost4dfad6d1(String arg0) {
    return '$arg0 terrain samples, at most 50 m apart horizontally. Heights interpolate linearly between waypoints; AGL applies at waypoints and does not imply terrain following.';
  }

  @override
  String get commonTerrainSamplesDoNote2bd895f =>
      'Terrain samples do not prove continuous clearance. Small features between samples, elevation-model errors, cables, trees and other unknown obstacles can be missed. Verify the route on site and with current official information.';

  @override
  String get commonTerrainUsesWgsEllipsoid7e8c1f46 =>
      'Terrain uses WGS84 ellipsoid heights. Other absolute references are preserved, but cannot yet be converted for the 3D view or clearance calculation. A * marker shows a 30 m AGL preview only.';

  @override
  String get commonTheAstraApiRejectsdfbcd277 =>
      'The ASTRA API rejects direct browser requests (CORS), before a token can be sent. Use Android for direct refresh, or import a DATEX XML snapshot downloaded with your own registered access. No public proxy is used.';

  @override
  String get commonTheDefaultMAgld0e44124 =>
      'The default 120 m AGL ceiling is a Swiss open-category planning reference. A configured value does not establish the applicable law, an exemption or authorisation. Vertical AGL samples do not evaluate distance to the nearest terrain surface on steep slopes.';

  @override
  String get commonTheseArePersonalLimits77b30a8a =>
      'These are personal limits, not manufacturer-approved wind tolerances.';

  @override
  String get commonTheseValuesDescribeAa43d2a95 =>
      'These values describe a simplified planning model. They do not account for gusts, manoeuvres, battery sag, temperature, battery ageing or unknown obstacles.';

  @override
  String get commonThisReplacesYourCurrentf961d89e =>
      'This replaces your current spots, equipment, routes, images, checklists, telemetry and backed-up preferences. Restored map preferences can reconnect enabled layers. API keys and downloaded maps/data remain on this device. Create a backup of your current data first.';

  @override
  String get commonTmcBeschreibtVorAllem56166f9f =>
      'TMC describes main roads above all. Unknown codes, version conflicts and non-clear sections remain without influence on the route recommendation.';

  @override
  String get commonToilets610d13f5 => 'Toilets';

  @override
  String get commonTokenVerwendenNichtToken28179d00 =>
      'Use tokens, not token hash.';

  @override
  String get commonTouchSteuerungAusblenden26a72091 => 'Hide touch controls';

  @override
  String get commonTransmitterAntennaCharacteristics19b4fc52 =>
      'Transmitter antenna characteristics';

  @override
  String get commonTransmitterAntennaGain38da48c0 => 'Transmitter antenna gain';

  @override
  String get commonTransmitterCableConnectorLoss9df9b0dd =>
      'Transmitter cable / connector loss';

  @override
  String get commonTransmitterPolarization34dcaed8 =>
      'Transmitter polarization';

  @override
  String get commonTunnelStammenAusDema4a6630f =>
      'Tunnels come from the prepared Swiss offline index. If this is missing, the online replacement search sends the map section to the data source. Cross-section, portals and heights are not measured. Only simulation, no real flight clearance.';

  @override
  String get commonType3deb7456 => 'Type';

  @override
  String get commonUasZonen81937e88 => 'UAS zones';

  @override
  String get commonUberProfilWaehlenOdera22070c5 =>
      'Use \"Select profile\" or \"Settings → Activity profiles\" to select a template, create an empty profile or skip the selection. Templates can be edited, duplicated and deleted. Preferred tools are in the menu first; map actions follow your quick actions. \"All tools\" opens the full functionality at any time. Flight routes and equipment retain their meaning. You select foot or bike mode in the ground routes area; an activity profile does not automatically change routing mode.';

  @override
  String get commonUnableToLoadDronecc1e0297 =>
      'Unable to load drone profiles.';

  @override
  String get commonUnavailable2c9c1f79 => 'Unavailable';

  @override
  String get commonUnbekanntd0b00a9f => 'Unknown';

  @override
  String get commonUnfallfb1a68ca => 'Accident';

  @override
  String get commonUnknownbc7819b3 => 'Unknown';

  @override
  String get commonUnprotectedBackupsContainReadableec1db6d0 =>
      'Unprotected backups contain readable personal data, including coordinates, notes and images.';

  @override
  String get commonUnterEinstellungenNavigationOder48dcba83 =>
      'Under Settings → Navigation or Map Display → 3D Environment, buildings and vegetation can be set to Like Map, Off or On. The normal map and aviation obstacles retain their own settings. Missing streaming data does not interrupt the navigation. The smoothed display stops at the last GPS point; speed and route guidance use the original measured values.';

  @override
  String get commonUseTheTokenFor892c903f =>
      'Use the Token for Road traffic - traffic situations, not Token Hash or OJP.';

  @override
  String get commonVeloba303bca => 'Bicycle';

  @override
  String get commonVelorouten02063824 => 'Velorouten';

  @override
  String get commonVerkehrsdaten47bcd2e4 => 'Transport data';

  @override
  String get commonVeroeffentlichteHindernissedcee0df6 => 'Obstacles published';

  @override
  String get commonVeroeffentlichungszeitTtlNichtBelegtd74df01f =>
      'Release time/TTL not used. Reported states are displayed, current availability remains unknown.';

  @override
  String get commonVerwerfen24cc57bc => 'Discard';

  @override
  String get commonViewpointse28a6555 => 'Viewpoints';

  @override
  String get commonVorDemStartce7119a6 => 'Before start';

  @override
  String get commonVorbereiteteKartenUndGelaende4e8adf4f =>
      'Prepared maps and terrain do not replace live information. UAS, obstacle and SLF snapshots retain their source data and validity. WMS, location/road labels, streaming 3D and live traffic/weather are not included as complete offline levels. Missing labels do not lead to a secret online call in Cache mode.';

  @override
  String get commonWaehrendDieNavigationGeoeffnet32560395 =>
      'While the navigation is open, your location is used continuously. In case of route deviations, location and destination are sent to FOSSGIS for recalculation. In the background, the navigation pauses.';

  @override
  String get commonWanderVeloMountainbikeUnd0dc3c854 =>
      'Hiking, cycling, mountain biking and winter routes are published networks. Legends explain the respective categories; without corresponding source data no difficulty is calculated. These online map areas are separated from your stored ground and flight routes. Map status, opening and current conditions must be independently checked.';

  @override
  String get commonWanderwege93acd7ea => 'Hiking trails';

  @override
  String get commonWarnings1430f976 => 'Warnings';

  @override
  String get commonWarnungZellspannungV6655c81c =>
      'Low voltage warning (V/cell)';

  @override
  String get commonWasFehltb7799bca => 'Was fehlt';

  @override
  String get commonWeatherForecastsArePlanning5820a8ab =>
      'Weather forecasts are planning aids, not real-time flight safety or legal authorisation.';

  @override
  String get commonWegenetzeNaturUndSperrungen0e7d404e =>
      'Road networks, nature and barriers';

  @override
  String get commonWeiterBearbeitencc234070 => 'Continue to Edit';

  @override
  String get commonWeitereMeldung12efe38b => 'Further message';

  @override
  String get commonWetterUndDWindd3dd8c5c => 'Weather and 3D wind';

  @override
  String get commonWetterUndGewaessermessstationendac59859 =>
      'Weather and water measuring stations';

  @override
  String get commonWetterrasterb939701a => 'Weather raster';

  @override
  String get commonWgsBreiteLaengeIna66287c0 =>
      'WGS84: Width, length in decimal degrees, e.g. 46.7, 8.4. LV95: East / North, e.g. 2600000 / 1200000. The local LV95 conversion is an approximation for orientation, not a measurement. A location or address search requires a connection.';

  @override
  String get commonWgsEllipsoidSchweizerLnc6e2dc07 =>
      'WGS84-Ellipsoid, Swiss LN02 and altitude over terrain (AGL) are different references. AGL refers to the terrain at the respective point, the starting height to the starting point. Unknown sources remain unknown. A flat replacement globe does not provide a measured terrain height.';

  @override
  String get commonWiderstandBeiHoechsttempoM510bfda4 =>
      'Drag at maximum speed (m/s²)';

  @override
  String get commonWildruhezonen6d338347 => 'Wild resting areas';

  @override
  String get commonWildruhezonenKoennenRechtsverbindlichOder5ba8618e =>
      'Wild resting zones can be legally binding or recommended. Protection periods, local regulations and permissible paths are listed in the official details. The spatial detail call is a limited extract; missing cantonal information or missing results do not confirm accessibility. Blocks and redirections have their own validity information. A protected area is not a standard air law classification.';

  @override
  String get commonWindFunk4ce9bd21 => 'Wind & radio';

  @override
  String get commonWindLegendMS1b571bdc =>
      'Wind legend (m/s): green <3, yellow 3–7, orange 7–12, red ≥12.';

  @override
  String get commonWinterwanderwege815871de => 'Winter hiking trails';

  @override
  String get commonWitterung98e69f2f => 'Weather';

  @override
  String get commonYawMaximalS71fd433b => 'Maximum yaw rate (°/s)';

  @override
  String get commonYes5397e058 => 'Yes';

  @override
  String get commonZeitangabenb06eb18b => 'Time data';

  @override
  String get commonZuFussda918eb3 => 'On foot';

  @override
  String get commonZugaengec08f0ef3 => 'Accesses';

  @override
  String get commonZurKarte4814658b => 'Return to map';

  @override
  String get commonZurueck40806243 => 'Back';

  @override
  String get commonZusaetzlicherSchubMS337bc8ea => 'Additional thrust (m/s²)';

  @override
  String get commonZustaende1b49baf7 => 'Conditions';

  @override
  String get datamanagementAForgottenPasswordCannot76d00a6a =>
      'A forgotten password cannot be recovered.';

  @override
  String datamanagementBackupFrome163c3fa(String arg0) {
    return 'Backup from $arg0';
  }

  @override
  String get datamanagementBackupPasswordd96a6076 => 'Backup password';

  @override
  String get datamanagementCreateBackup60e77f3b => 'Create backup';

  @override
  String get datamanagementOfflinePersonalDatae0f55e89 =>
      'Offline & personal data';

  @override
  String get datamanagementPassword8be3c943 => 'Password';

  @override
  String get datamanagementPasswordAtLeastCharacters518d1ae0 =>
      'Password (at least 12 characters)';

  @override
  String get datamanagementPortableBackups13832bb9 => 'Portable backups';

  @override
  String get datamanagementProtectBackupWithAf8add733 =>
      'Protect backup with a password';

  @override
  String get datamanagementRepeatPassword366c2415 => 'Repeat password';

  @override
  String get datamanagementReplaceAndRestoreee68c046 => 'Replace and restore';

  @override
  String get datamanagementReplacePersonalData946d9c54 =>
      'Replace personal data?';

  @override
  String get datamanagementRestoreBackupa65eaa88 => 'Restore backup';

  @override
  String get datamanagementTheMapCachePreference010bed10 =>
      'The map cache preference could not be saved.';

  @override
  String get dronesAddDroneProfile9af5c042 => 'Add drone profile';

  @override
  String get dronesAddDroned971a88b => 'Add drone';

  @override
  String get dronesDeleteDroneProfilec10d6154 => 'Delete drone profile?';

  @override
  String get dronesDeleteProfile7035d2d9 => 'Delete profile';

  @override
  String get dronesDroneProfile1ca23ee8 => 'Drone profile';

  @override
  String get dronesDroneProfilesb57e7452 => 'Drone profiles';

  @override
  String get dronesEditDroneProfilefc4f435a => 'Edit drone profile';

  @override
  String get dronesEditProfile15141eab => 'Edit profile';

  @override
  String get dronesNoDroneProfilesSavedca393a7c =>
      'No drone profiles saved yet. Add a profile to record your equipment.';

  @override
  String get dronesNoNumericParametersRecorded530d76ed =>
      'No numeric parameters recorded.';

  @override
  String dronesPermanentlyDeleteFlightPlansc2a19a5b(String arg0) {
    return 'Permanently delete \"$arg0\"? Flight plans will be kept without this drone assignment.';
  }

  @override
  String dronesSource0ef9cdaf(String arg0) {
    return '$arg0 source';
  }

  @override
  String get dronesThisDroneProfileNob7ffc857 =>
      'This drone profile no longer exists.';

  @override
  String get dronesUnableToLoadThis20f0daab =>
      'Unable to load this drone profile.';

  @override
  String globeAbfrageFehlgeschlagene25d055d(String arg0) {
    return 'Query failed: $arg0';
  }

  @override
  String get globeAktuellesGpsSignal291591fd => 'Current GPS signal';

  @override
  String get globeAllgemeineEinstellungen6f965a12 => 'General Settings';

  @override
  String get globeAmslIsHeightAbove8e48a714 =>
      'AMSL is height above mean sea level. Swiss national map heights use LN02; LHN95 is a separate height datum.';

  @override
  String get globeAmslSwissLnNot9423d99b => 'AMSL (Swiss LN02): not converted';

  @override
  String get globeAmtlicheQuellenSicherheit68a6f080 =>
      'Official sources & safety';

  @override
  String get globeApproximateConversionSwisstopoFormulase7bb7ac3 =>
      'Approximate conversion (swisstopo formulas)';

  @override
  String get globeAufStandortZentrierene8973c1b => 'Centre on location';

  @override
  String get globeAusAchseDGewoelbe0d1ef125 =>
      'Build a simulated 3D tunnel from its centreline';

  @override
  String get globeAusBeleuchtungDerKarte53fe9a28 =>
      'Off: Use illumination of the card.';

  @override
  String get globeAusgewaehltesBauwerke74d05ef => 'Selected structure';

  @override
  String globeAutomatischDargestellteSchematischeTunnel4dea34ff(
    String arg0,
    String arg1,
  ) {
    return 'Automatically displayed schematic tunnels: $arg0 of maximum $arg1 (graphic profile).';
  }

  @override
  String get globeBeschriftungenErneutLaden53e7b713 => 'Reload labels';

  @override
  String get globeBeschriftungenOfflineNichtVerfuegbar79eca86d =>
      'Labels not available offline.';

  @override
  String get globeBeschriftungenTeilweiseVerfuegbar5ada98f5 =>
      'Labels partly available.';

  @override
  String get globeBeschriftungenWerdenGeladenb8c71bdb => 'Loading labels..';

  @override
  String globeBringForwardcf73f6a1(String arg0) {
    return 'Bring $arg0 forward';
  }

  @override
  String get globeCancelSpawn701b7923 => 'Cancel spawn';

  @override
  String get globeClearUasDatasetCacheaad7bb57 => 'Clear UAS dataset cache';

  @override
  String get globeConvertToSwissHeight5c83b28a =>
      'Convert to Swiss height (LN02)';

  @override
  String get globeConvertedWithSwisstopoReframe07d146f4 =>
      'Converted with swisstopo REFRAME';

  @override
  String get globeConverting3985de51 => 'Converting…';

  @override
  String globeDAktionFehlgeschlagen11f40ae7(String arg0) {
    return '3D action failed: $arg0';
  }

  @override
  String get globeDDatenDerzeitNichtec1d811a =>
      '3D data currently not available.';

  @override
  String get globeDDatenOfflineNicht0512f9fe =>
      '3D data offline not fully available.';

  @override
  String get globeDGewoelbetunnelErzeugenSynthetischcf487df5 =>
      'Create 3D vault tunnels (synthetic)';

  @override
  String get globeDLicht8b58e045 => '3D & lighting';

  @override
  String get globeDModellkollisionenExperimentell6ac94586 =>
      '3D model collisions (experimental)';

  @override
  String get globeDTunnelAutomatischLadena71b41bc =>
      'Load 3D tunnels automatically';

  @override
  String get globeDTunnelEntfernenc327e7fe => 'Remove 3D tunnel';

  @override
  String globeDTunnele1017c1e(String arg0) {
    return '3D tunnel: $arg0';
  }

  @override
  String get globeDatenQuellen0b5b5779 => 'Data & Sources';

  @override
  String get globeDatenstand0ce51d29 => 'Data level';

  @override
  String get globeDatumUndUhrzeit6b922369 => 'Date and time';

  @override
  String get globeDeckkraft3c11c68b => 'Opacity';

  @override
  String globeDurchfluge383d59a(String arg0) {
    return 'Transit: $arg0';
  }

  @override
  String globeEastingM080f8cea(String arg0) {
    return 'Easting: $arg0 m';
  }

  @override
  String get globeEigeneSonnenUndMondzeit785565c8 => 'Custom lighting time';

  @override
  String get globeEinigeDKachelnFehlenbf4b88d2 =>
      'Some 3D tiles are missing. Loaded models remain visible.';

  @override
  String get globeErneutLaden9c56689e => 'Reload';

  @override
  String globeFahrtrichtung8ce70d3a(String arg0) {
    return 'Direction: $arg0°';
  }

  @override
  String get globeFailedToLoadDd6e93076 => 'Failed to load 3D globe';

  @override
  String get globeFuerBeschriftungenNaeherHeranzoomen6f64dcb5 =>
      'Zoom in closer for labels.';

  @override
  String globeGenauigkeitM4e998940(String arg0) {
    return 'Accuracy: ±$arg0 m';
  }

  @override
  String get globeGespeicherteSpots4f634531 => 'Saved spots';

  @override
  String get globeGroundElevation5d588142 => 'Ground elevation';

  @override
  String globeGroundViewb1f80610(String arg0) {
    return 'Ground view: $arg0';
  }

  @override
  String get globeHeightAboveLocalGround8c1c0da0 =>
      'Height above local ground (AGL)';

  @override
  String get globeHeightAboveTerrainAglcbf70384 => 'Height above terrain (AGL)';

  @override
  String get globeHeightAtThisAglfbdc9bdd => 'Height at this AGL:';

  @override
  String get globeHindernissed58845a0 => 'Obstacles';

  @override
  String get globeImportiertesMeshHerkunftUnd538c26a9 =>
      'Imported mesh. Source and vertical reference have not been independently verified. A terrain cutout is required.';

  @override
  String get globeImportiertesModellHerkunftUnd950bcbe2 =>
      'Imported model · Origin and light space unchecked. No real clearance.';

  @override
  String get globeJetzt6b627c53 => 'Now';

  @override
  String get globeKarteb1636a3d => 'Map';

  @override
  String get globeKarteinstellungenZuruecksetzen3bd1cc02 =>
      'Reset Map Settings';

  @override
  String get globeKartenbewegungBeendetDieVerfolgung00211415 =>
      'Moving the map stops following. Online tiles can reveal the area when you center or follow.';

  @override
  String get globeKarteneinstellungenWerdenGeladen349c7e7f =>
      'Loading map settings..';

  @override
  String get globeKeineImLokalenIndex7a2d66ae =>
      'No tunnels recorded in the local index in the map section. Data coverage may be incomplete.';

  @override
  String get globeLetzterBekannterStandortVeraltet04a9e861 =>
      'Last known location · outdated';

  @override
  String get globeLetzterStandortErneutOrten9afe561d =>
      'Last location · locate again';

  @override
  String get globeLoadingZoneDatacd4362a5 => 'Loading zone data...';

  @override
  String get globeLocalLibrary1c67cdf4 => 'Local library';

  @override
  String get globeLuftraum0992aecb => 'Airspace';

  @override
  String get globeLvConversionUnavailableOutsidedecfa6d5 =>
      'LV95 conversion unavailable outside the supported Swiss region.';

  @override
  String globeMapLayerError65930212(String arg0) {
    return 'Map layer error: $arg0';
  }

  @override
  String get globeMeinStandortLangeDrueckend4c6bff6 =>
      'My location · long press for options';

  @override
  String globeModellquelle05ae7da1(String arg0) {
    return 'Model source: $arg0';
  }

  @override
  String get globeNativeDGlobeIsf8235971 =>
      'Native 3D globe is currently supported on Android and iOS.';

  @override
  String get globeNeueBeschriftungenKonntenNicht08732593 =>
      'New labels could not be loaded.';

  @override
  String globeNichtModellierbareTunnelabschnitteVon25d903e4(
    String arg0,
    String arg1,
  ) {
    return 'Unmodelled tunnel sections: $arg0 of $arg1 detected axes.';
  }

  @override
  String get globeNochKeineTunnelGefundenbdf89230 => 'No tunnels found yet.';

  @override
  String globeNorthingMc882004d(String arg0) {
    return 'Northing: $arg0 m';
  }

  @override
  String get globeNurSchweizUndLiechtenstein1516f8d3 =>
      'Only Switzerland and Liechtenstein.';

  @override
  String get globeOnlineConversionSendsThis9f4e31f3 =>
      'Online conversion sends this position and ground elevation to swisstopo.';

  @override
  String get globeOriginaldatenKeineDurchflugfreigabeb2bc03bb =>
      'Source data · no clearance for flight.';

  @override
  String get globeOrtsUndStrassennamenbe90f8a3 => 'Place and street names';

  @override
  String globePolygonFillOpacityd148d398(String arg0) {
    return 'Polygon fill opacity: $arg0%';
  }

  @override
  String globeQuellkennung050247aa(String arg0) {
    return 'Source code: $arg0';
  }

  @override
  String get globeRefreshUasData3aea6b96 => 'Refresh UAS data';

  @override
  String get globeReihenfolgeDerEbenenf736c2db => 'Layer order';

  @override
  String get globeRetryTerraine3f14f82 => 'Retry terrain';

  @override
  String get globeReturnToGlobe687364e5 => 'Return to globe';

  @override
  String globeSamplinga7cf9539(String arg0) {
    return 'Sampling: $arg0';
  }

  @override
  String get globeSatellited1ffec93 => 'Satellite';

  @override
  String get globeSavedSpotsf65c2504 => 'Saved spots';

  @override
  String globeSichtdreieckeKollisionsdreiecke2eeb74c5(
    String arg0,
    String arg1,
  ) {
    return 'Visual triangle: $arg0 · Collision triangle: $arg1';
  }

  @override
  String globeSignalzeiteb1b8546(String arg0) {
    return 'Signaling time: $arg0';
  }

  @override
  String get globeSimulationOnlineErsatzsucheSendet67c4c630 =>
      'Simulation · Online replacement search sends map section.';

  @override
  String get globeSonnenUndMondlichtc6291e64 => 'Sunlight and moonlight';

  @override
  String get globeSpawnHeref28d3450 => 'Spawn here';

  @override
  String get globeStandortAnzeigenca6f8a53 => 'Show location';

  @override
  String get globeStandortVerfolgen14ee16f9 => 'Follow location';

  @override
  String get globeStandortWirdGesucht33b02f57 => 'Searching for location';

  @override
  String get globeStrassenLayerErneutLadenfb527544 => 'Reload roads layer';

  @override
  String get globeSwissCoordinatesLvb62ba2b6 => 'Swiss coordinates (LV95)';

  @override
  String get globeSwissHeightConversionIsae058df0 =>
      'Swiss height conversion is unavailable at this position or for this reference.';

  @override
  String get globeTagUndNachtNach5c260567 =>
      'Day and night follow the device time.';

  @override
  String globeTerrainAussparungenWeitereSichtbaree67506d9(String arg0) {
    return 'Terrain recesses: $arg0. Other visible tubes may be hidden from the grounds.';
  }

  @override
  String get globeTerrainInformation1a166cb2 => 'Terrain Information';

  @override
  String get globeTopo7416e691 => 'Topo';

  @override
  String globeTunnelDatenquellee8c8f0f5(String arg0) {
    return 'Tunnel data source: $arg0';
  }

  @override
  String globeTunnelGeladen76365023(String arg0, String arg1) {
    return '$arg0 / $arg1 tunnels loaded';
  }

  @override
  String get globeTunnelInDerNaehe75bf7c66 => 'Find nearby tunnels';

  @override
  String get globeTunnelabdeckungUnvollstaendigcfa66c0f =>
      'Tunnel coverage is incomplete.';

  @override
  String get globeTunnelachsenDerzeitOfflineNicht2a3ab99c =>
      'Tunnel axes are currently not available offline.';

  @override
  String globeTunnelachsenGefundenAbdeckungUnvollstaendigdabfec20(String arg0) {
    return '$arg0 Tunnel axes found; coverage incomplete.';
  }

  @override
  String globeTunnelachsenImKartenausschnittGefundenbbd7f549(String arg0) {
    return '$arg0 Tunnel axes found in the map section (schematic).';
  }

  @override
  String get globeTunnelachsenNurBeiBodennaherab983e29 =>
      'Automatically load tunnel axes only with Swiss map view close to the ground.';

  @override
  String get globeTunnelachsenWerdenAutomatischFuer8bbff5f7 =>
      'Tunnel axes are automatically searched for the near visible map section.';

  @override
  String get globeTunnelaktionenc0d41bdb => 'Tunnel actions';

  @override
  String get globeTunnelindexKonnteNichtGeladen03a91e8e =>
      'Unable to load tunnel index. Check source and build data.';

  @override
  String get globeTunnelmodellImportierenJson8ffcf7c7 =>
      'Import Tunnel Model (JSON)';

  @override
  String get globeTunnelstatusDatend6e42b7d => 'Tunnel status & data';

  @override
  String get globeTunnelwerkzeuge9873b3ba => 'Tunnel tools';

  @override
  String get globeUnableToReconnectTo7f563fb8 =>
      'Unable to reconnect to terrain. Please retry.';

  @override
  String get globeUnableToUpdateMap7af0a9ee =>
      'Unable to update map preferences. Please retry.';

  @override
  String get globeUnableToUpdateMapefb1235c =>
      'Unable to update map display. Please retry.';

  @override
  String get globeVorneNachHinten4d9d3fd7 => 'Front to back';

  @override
  String get globeWeitereDatenebenenUnterMobilitaetd36898b1 =>
      'Load more data levels under Mobility & OSINT.';

  @override
  String get globeWeitereEinschraenkungenMoeglichVor9c93ae78 =>
      'Further restrictions possible. Check official sources before flight.';

  @override
  String globeWgsLatituded60b5fd1(String arg0) {
    return 'WGS84 latitude: $arg0°';
  }

  @override
  String globeWgsLongitudece917f86(String arg0) {
    return 'WGS84 longitude: $arg0°';
  }

  @override
  String get globeZumErstenAchsenpunkt95f01d68 => 'To first axis point';

  @override
  String get globeZumLetztenAchsenpunkt5cbcd957 => 'To the last axis point';

  @override
  String get groundroutesAnderungenSpeichern00fe8153 => 'Save Changes';

  @override
  String groundroutesAngezeigteRouteeceb9858(String arg0) {
    return 'Shown route: $arg0';
  }

  @override
  String get groundroutesAufGlobeAnzeigenb40c4518 => 'Show on Globe';

  @override
  String get groundroutesBodenrouteBerechnena780689a => 'Calculate soil route';

  @override
  String get groundroutesBodenrouteLoeschen3c5c9ab7 => 'Delete ground route';

  @override
  String get groundroutesBodenrouteSpeichern5b0ba694 => 'Save ground route';

  @override
  String groundroutesBodenroutenGespeichert7c176a33(String arg0) {
    return '$arg0 Soil routes stored';
  }

  @override
  String get groundroutesDieAngezeigteRouteGehoert7159dcb8 =>
      'The route shown is one of the previous entries. Recalculate for the new entries.';

  @override
  String get groundroutesGespeicherteBodenroutenKonntenNicht88267d75 =>
      'Stored ground routes could not be loaded.';

  @override
  String get groundroutesGespeicherteBodenroutenSuchenf43e3c82 =>
      'Search for stored ground routes';

  @override
  String get groundroutesGespeichertenOrtAuswaehlenf23d82e2 =>
      'Select Saved Location';

  @override
  String get groundroutesGewaehltenKartenpunktUebernehmen1c0caa9a =>
      'Take selected card point';

  @override
  String get groundroutesGpxBodenroutenImportierenbc579b06 =>
      'Import GPX ground routes?';

  @override
  String get groundroutesGpxImportieren08a786c6 => 'Import GPX';

  @override
  String get groundroutesKartenvorschauAusblenden048fe407 =>
      'Hide Card Preview';

  @override
  String get groundroutesKeineGespeichertenBodenroutenGefunden7adb49f7 =>
      'No stored ground routes found';

  @override
  String groundroutesLoeschen42c1810b(String arg0) {
    return '\"$arg0? Delete?';
  }

  @override
  String groundroutesLokalGespeichertdafc6ec0(String arg0) {
    return '$arg0 · Locally stored';
  }

  @override
  String get groundroutesLokalGespeicherteBodenrouten5824582d =>
      'Locally stored soil routes';

  @override
  String get groundroutesMessstationenEntlangDerRouted9e511cf =>
      'Measurement stations along the route';

  @override
  String get groundroutesNameDerBodenroute997555dc =>
      'Name of the ground route';

  @override
  String get groundroutesNeueRoutec6a2c583 => 'New route';

  @override
  String groundroutesOberflaecheZugangHoehen28c32a79(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Surface: $arg0 · Access: $arg1 Altitude: $arg2';
  }

  @override
  String get groundroutesOvAnreiseZumBodenrouten39acd10e =>
      'Plan a public transport trip to the ground route start';

  @override
  String get groundroutesPassendesFussOderVeloprofilc351a9b0 =>
      'Suitable foot or bike profile · OpenStreetMap basis';

  @override
  String groundroutesPunkte525d4984(String arg0, String arg1, String arg2) {
    return '$arg0 · $arg1 · $arg2 points';
  }

  @override
  String groundroutesPunkte9b66050f(String arg0, String arg1, String arg2) {
    return '$arg0 points · $arg1 · $arg2';
  }

  @override
  String groundroutesQuelleBerechnet7150764e(String arg0, String arg1) {
    return 'Source: $arg0 Calculated: $arg1';
  }

  @override
  String get groundroutesRoutenmodusAusdruecklichWaehlen420b0d52 =>
      'Explicitly select route mode';

  @override
  String get groundroutesSperrungenImRoutenumfeld41a77f10 =>
      'Blocks in the route environment';

  @override
  String get groundroutesStartUndZielZur5a6b9fef =>
      'Send start and destination for calculation to FOSSGIS / OSRM';

  @override
  String get groundroutesStartWaehlendb986579 => 'Select Start';

  @override
  String get groundroutesTrefferAngezeigtBitteDiefb7ecafc =>
      '500 hits shown. Please narrow down the search.';

  @override
  String get groundroutesUngespeichertenEntwurfVerlassenff7b8bc6 =>
      'Leave unsaved design?';

  @override
  String get groundroutesWeitereBodenroutenAnzeigen6060cffc =>
      'Show more soil routes';

  @override
  String get groundroutesZielWaehlenaaa64252 => 'Select destination';

  @override
  String get helpGuidesUndHilfeecbecc1f => 'Guides and help';

  @override
  String helpKurzhilfec825661f(String arg0) {
    return 'Quick guide: $arg0';
  }

  @override
  String get homeAkkusa10fdf22 => 'Batteries';

  @override
  String homeAktivitaetsprofilfef983f3(String arg0) {
    return 'Activity profile: $arg0';
  }

  @override
  String get homeAlleKartenebenenc5387977 => 'All map layers';

  @override
  String get homeAlleWerkzeuge80af8bd2 => 'All tools';

  @override
  String get homeArbeitsbereichGewechseltKartenstartwerteFolgen74793f38 =>
      'Workspace changed. Card start values follow after the current view.';

  @override
  String get homeArbeitsbereichb5371daf => 'Workspace';

  @override
  String get homeAusruestung67d2d167 => 'Equipment';

  @override
  String get homeBevorzugteEbenen39447c21 => 'Favourite layers';

  @override
  String get homeCancelRouteReplayPreparationb6a2fd00 =>
      'Cancel route replay preparation';

  @override
  String get homeCheckAirspace81aa4af7 => 'Check airspace';

  @override
  String get homeCloseMapStatusbaaf9b31 => 'Close map status';

  @override
  String get homeCloseSpotDetailsb8c47dc2 => 'Close spot details';

  @override
  String get homeDGlobeReady1847f54f => '3D globe ready';

  @override
  String get homeDetailsdc3decbb => 'Details';

  @override
  String get homeDrohnen1cb44d64 => 'Drones';

  @override
  String get homeEinstellungen3e5af3d1 => 'Settings';

  @override
  String get homeFlatMapTerrainHeightsd993a5d7 =>
      'Flat map — terrain heights unavailable';

  @override
  String get homeFlugvorbereitungfc3259ae => 'Preflight';

  @override
  String get homeFlyToSpot253cde4f => 'Fly to Spot';

  @override
  String get homeFunkVideo955c11e1 => 'Radio & video';

  @override
  String get homeGespeicherteOrte681d182b => 'Saved places';

  @override
  String get homeKarteUndAktivitaetena2cfdeff => 'Map and activities';

  @override
  String get homeKartenaktionen61a84371 => 'Map actions';

  @override
  String get homeKartenstartwerteKonntenNichtUebernommen8dd81e2c =>
      'Card start values could not be taken over.';

  @override
  String get homeLoadingGlobe79eb5f94 => 'Loading globe...';

  @override
  String homeMapError05472eae(String arg0) {
    return 'Map error: $arg0';
  }

  @override
  String get homeMapStatus5f4e7ac0 => 'Map status';

  @override
  String get homeMenueSchliessen82332f74 => 'Close menu';

  @override
  String get homeMoreSpotActionsec926581 => 'More spot actions';

  @override
  String get homeNoMapDataWarnings4f085b42 => 'No map data warnings';

  @override
  String get homeOfflineDaten07b28abe => 'Offline & data';

  @override
  String get homeOpenNavigationMenu5f83b0b6 => 'Open navigation menu';

  @override
  String get homePlanenEntdecken9b5160ec => 'Planning & Discovering';

  @override
  String get homeProfilWaehlencae393b1 => 'Select Profile';

  @override
  String homeSpotMarkerSyncFailed5c7dee42(String arg0) {
    return 'Spot marker sync failed: $arg0';
  }

  @override
  String get homeSuchen20a96919 => 'Search';

  @override
  String homeTerrainQueryFailed53f78995(String arg0) {
    return 'Terrain query failed: $arg0';
  }

  @override
  String homeUnableToLoadStored9e66c17d(String arg0) {
    return 'Unable to load stored spots: $arg0';
  }

  @override
  String get homeWetter72a9fa32 => 'Weather';

  @override
  String get mobilityAbdeckungUndZusaetzlicheVerkehrsdatenca67bb5b =>
      'Coverage and additional traffic data';

  @override
  String mobilityAbdeckungWgsc9cd562f(String arg0) {
    return 'Cover (WGS84): $arg0';
  }

  @override
  String get mobilityAbfahrt3cca3329 => 'Departure';

  @override
  String get mobilityAbfrageBegrenztWeitereOder5efa5f1a =>
      'Query limited. More or overlapping rules possible.';

  @override
  String mobilityAbgerufenAma792bdd8(String arg0, String arg1, String arg2) {
    return 'Called at $arg0 · $arg1 → $arg2';
  }

  @override
  String mobilityAbgerufenUtc47bb4052(String arg0, String arg1, String arg2) {
    return 'Called: $arg0 (UTC)$arg1$arg2';
  }

  @override
  String mobilityAbrufQuellenpublikation2c701097(String arg0, String arg1) {
    return 'Search: $arg0 · Source publication: $arg1';
  }

  @override
  String get mobilityAbrufVeraltetErneutAktualisieren5ed4d00d =>
      'Retrieve outdated · re-update';

  @override
  String get mobilityAbrufVeraltetOderFehlgeschlagen4afc83f7 =>
      'Retrieve outdated or failed · Check the measurement time of each value.';

  @override
  String get mobilityAdresseOderOrtInfa9d68ac =>
      'Address or place in Switzerland';

  @override
  String get mobilityAktiverOjpApiPlan5dce0b6f =>
      'Active OJP API plan (session)';

  @override
  String get mobilityAktualisieren87c65f26 => 'Update';

  @override
  String get mobilityAktualisierungFehlgeschlagenAlteStandortdatenb2f09fc6 =>
      'Update failed: old location data; availability unknown.';

  @override
  String get mobilityAktualisierungFehlgeschlagenLetzterDatenstand97d6ca24 =>
      'Update failed · last data level remains visible';

  @override
  String get mobilityAktualisierungFehlgeschlagenVorhandenerStand6dbee97c =>
      'Updating failed: existing status is maintained.';

  @override
  String get mobilityAktualisierungFehlgeschlagenVorherigerStand6cb8348b =>
      'Updating failed; prior status is maintained.';

  @override
  String get mobilityAktualitaetNichtBestaetigtAngaben58f3aa99 =>
      'Actuality not confirmed – information may be outdated. Check local arrangements.';

  @override
  String get mobilityAktuelleAmtlicheMassnahmen1078b943 =>
      'Current official measures';

  @override
  String get mobilityAktuelleMeldungenAufKarte65e8ab99 =>
      'Show latest news on map';

  @override
  String get mobilityAlleAnbieter9c59c226 => 'All providers';

  @override
  String get mobilityAlleAngebote766cc617 => 'All offers';

  @override
  String get mobilityAlleEreignistypenf0956deb => 'All event types';

  @override
  String get mobilityAlleFahrzeugtypenc3d9470c => 'All vehicle types';

  @override
  String get mobilityAlleSekundenWaehrendDer0476b439 =>
      'Every 60 seconds during active navigation';

  @override
  String get mobilityAllowSendingStartAnde6a35229 =>
      'Allow sending start and destination to FOSSGIS / OpenStreetMap routing.';

  @override
  String get mobilityAllowSendingThisAread1710796 =>
      'Allow sending this area centre to adsb.lol.';

  @override
  String get mobilityAlsFahrzielWaehlen89ab104c =>
      'Choose as driving destination';

  @override
  String get mobilityAmtlicheCollectiond0ebbd40 => 'Amtliche Collection';

  @override
  String get mobilityAmtlicheLegendeProduktinformation73ec6293 =>
      'Official Legend / Product Information';

  @override
  String get mobilityAmtlicheMassnahmenAbfragen08c2e83d =>
      'Ask for official measures';

  @override
  String get mobilityAmtlicheQuelleAnsicht283a8bdd => 'Official source / view';

  @override
  String mobilityAmtlicherTitelf2b2a993(String arg0) {
    return 'Official title: $arg0';
  }

  @override
  String get mobilityAnbieterOeffnenKeineReservierung97c86374 =>
      'Open provider (no reservation)';

  @override
  String get mobilityAnbieterd062d4fe => 'Providers';

  @override
  String get mobilityAnfragebudgetGiltNurFuer8bf6ad74 =>
      'Request budget applies only to this app session. The official quotas apply jointly to all devices with the same key; HTTP 429 is respected.';

  @override
  String get mobilityAngebotsart3d303646 => 'Type of supply';

  @override
  String get mobilityAnkunft0b4333da => 'Arrival';

  @override
  String get mobilityAnschluesseNichtVeroeffentlicht1584b8b8 =>
      'Connections: not published';

  @override
  String get mobilityAnzeigereferenzGenaueAusdehnungUnbekannt92e1ba4c =>
      'Display reference · exact extension unknown';

  @override
  String get mobilityAstraMesswerteLadencc594459 => 'Load ASTRA readings';

  @override
  String mobilityAstraTabellenstandLokalBezogenfdd31ddb(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'ASTRA · Table level: $arg0 Locally sourced: $arg1$arg2';
  }

  @override
  String get mobilityAstraVerkehrsmeldungenLadenf278469c =>
      'Load ASTRA traffic messages';

  @override
  String mobilityAstraVmzChEreignis5068b250(String arg0, String arg1) {
    return 'ASTRA / VMZ-CH · Event $arg0 · $arg1 Partial messages';
  }

  @override
  String get mobilityAstraVmzChTraffic19a07166 =>
      'ASTRA / VMZ-CH traffic situations · Swiss road network. Registered API access is required. TMC-only references require the matching official topology. Unlocated or uncertain messages remain information; sufficiently matched current data can be enabled for route comparison.';

  @override
  String get mobilityAstraVmzChVeroeffentlicht4c4e6620 =>
      'ASTRA / VMZ-CH publishes event messages. Without a suitable official TMC location table, pure location codes cannot be located on the map. Such messages remain searchable here. Map points can only be an display reference; straight lines do not represent a precise road course. Continuous traffic density and traffic-dependent arrival times are therefore not available. ASTRA also offers speeds and vehicle volumes at counters via a separate API access.';

  @override
  String get mobilityAufDKarteAnzeigen2ad897d8 => 'Show on 3D map (max. 150)';

  @override
  String get mobilityAufDKarteZeigenb9c8e9a8 => 'Show on 3D map (max. 120)';

  @override
  String mobilityAufnahmeUtc809df7be(String arg0) {
    return 'Recording (UTC): $arg0';
  }

  @override
  String get mobilityAusgewaehltenKartenpunktUebernehmen849683eb =>
      'Apply selected map point';

  @override
  String get mobilityAusgewaehltenKartenpunktVerwenden90ebe0f5 =>
      'Use selected map point';

  @override
  String get mobilityAutomatischAktualisierena2f998d7 => 'Automatically update';

  @override
  String mobilityBafuFeatureId27de0e54(String arg0) {
    return 'BAFU Feature-ID: $arg0';
  }

  @override
  String get mobilityBakomErklaerungenUndAmtliche7dfa13ad =>
      'BAKOM declarations and official source';

  @override
  String get mobilityBakomMobilfunkBasisstationenb5426d86 =>
      'BAKOM mobile phone base stations';

  @override
  String get mobilityBeendence9e650e => 'Quit';

  @override
  String get mobilityBeiRoutenabweichungenSendetDie131b098f =>
      'FPVManager sends your location and destination to FOSSGIS when rerouting. FOSSGIS logs the request. Navigation pauses in the background.';

  @override
  String mobilityBeobachtungszeite60e71e7(String arg0) {
    return 'Observation time: $arg0';
  }

  @override
  String mobilityBeobachtungszeitraumStac7f2d19f8(String arg0, String arg1) {
    return 'Observation period (STAC): $arg0 – $arg1';
  }

  @override
  String get mobilityBewertungUnvollstaendigKeineVerkehrsbasierte655a9750 =>
      'Assessment incomplete · no traffic-based recommendation';

  @override
  String get mobilityBfeDokumentationUndNutzungsbedingungen58dca300 =>
      'SFOE Documentation and Terms of Use';

  @override
  String get mobilityBildebeneEntfernenBasiskarte8d450df2 =>
      'Remove Image Level / Base Map';

  @override
  String mobilityBildlayer7779aa56(String arg0, String arg1) {
    return 'Bildlayer: $arg0$arg1';
  }

  @override
  String get mobilityBreiteWgsbf85fa1c => 'Width (WGS84)';

  @override
  String get mobilityBreitengradf5eed2f2 => 'Latitude';

  @override
  String get mobilityCalculateDrivingRoute59eac3f8 => 'Calculate driving route';

  @override
  String mobilityCalculatedTheRoutingService9f5e2267(String arg0, String arg1) {
    return 'Calculated: $arg0 · $arg1. The routing service may snap endpoints to nearby roads.';
  }

  @override
  String get mobilityCategories6ccb6007 => 'Categories';

  @override
  String get mobilityCdiZeitstandOffiziellerWms68eccda7 =>
      'CDI (official WMS parameter)';

  @override
  String get mobilityDDatenFehlenOderdd9b0af0 =>
      '3D data are missing or not available offline.';

  @override
  String get mobilityDEinstellungKonnteNicht1dd69132 =>
      '3D adjustment could not be taken over.';

  @override
  String get mobilityDUmgebungInDer7e362fb8 => '3D environment in navigation';

  @override
  String get mobilityDUmgebungb7f47aad => '3D environment';

  @override
  String mobilityDarstellungsfehler750531ab(String arg0) {
    return 'Visual error: $arg0';
  }

  @override
  String get mobilityDatenabrufAelterAlsStundenf8a928a3 =>
      'Data retrieval older than 24 hours.';

  @override
  String get mobilityDatenstandUndBewertungsregeln47599d2e =>
      'Data status and evaluation rules';

  @override
  String mobilityDatenstatusd3d7b1d5(String arg0) {
    return 'Data status: $arg0';
  }

  @override
  String get mobilityDatierteAufnahmeAnzeigen461270db => 'Show Dated Recording';

  @override
  String get mobilityDatierteBilderSuchen2f4ff702 => 'Find Dated Images';

  @override
  String get mobilityDatierteSatellitenRapidMappingf807e800 =>
      'Dated satellite & rapid mapping images';

  @override
  String get mobilityDestinationSpotdfb0a64e => 'Destination spot';

  @override
  String mobilityDetektorFahrstreifenFahrbahntype8312098(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Detector: $arg0 · Road lanes: $arg1 · Roadway type: $arg2';
  }

  @override
  String get mobilityDieQuelleNenntWiederkehrende01133c3c =>
      'The source is called recurring time windows. Check individual time windows before driving.';

  @override
  String get mobilityDirectBrowserRequestsAre8f6307e5 =>
      'Direct browser requests are blocked by the provider CORS policy. Import a readsb/adsb.lol JSON snapshot or use Android; no public proxy is involved.';

  @override
  String get mobilityDirekterAbrufAufAndroid7c4ac605 =>
      'Direct retrieval available on Android.';

  @override
  String get mobilityDreiUnabhaengigeAmtlicheKartenebenen6c0dfad0 =>
      'Three Independent Official Sides · Optional';

  @override
  String get mobilityEigenerTrafficCountersTokenff5ddb8b =>
      'Own Traffic Counters Token';

  @override
  String get mobilityEigenerZugangFuerTraffic1a7bd79b =>
      'Own access for traffic counters. The key to traffic messages is not reused. Data remains in this session.';

  @override
  String get mobilityEinigeDKachelnFehlen747d8e09 =>
      'Some 3D tiles are missing.';

  @override
  String mobilityEintraegeStandf4269e5b(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0 records · Status $arg1 · $arg2$arg3';
  }

  @override
  String mobilityEreignisEinsatzac1a3fa0(String arg0) {
    return 'Event / deployment: $arg0';
  }

  @override
  String mobilityEreignisseOhneKartenpositionNichta9154e17(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return '$arg0 Events · $arg1 without map item · $arg2 not evaluable';
  }

  @override
  String get mobilityErforderlichEigenerOjpApi4a8d7c41 =>
      'Required: own OJP 2.0 API key with unlocked product. Access data remain in local Secure Storage (Web: only memory of this session).';

  @override
  String get mobilityErgebnisBegrenztKleinereSuchflaeche4bec8127 =>
      'Result limited; select smaller search area. No full coverage.';

  @override
  String mobilityErneutLaden13159aac(String arg0) {
    return 'Reload $arg0';
  }

  @override
  String mobilityFahrplan10147b40(String arg0, String arg1) {
    return '$arg0 Roadmap: $arg1';
  }

  @override
  String mobilityFahrzeugeLautAnbieterbf339e17(String arg0) {
    return 'Vehicles according to supplier: $arg0';
  }

  @override
  String get mobilityFahrzeugtyp76a9b894 => 'Vehicle type';

  @override
  String get mobilityFehlendeBenoetigteTabellenLaden3eb0f8e9 =>
      'Load missing needed tables';

  @override
  String get mobilityFindNearbyPlacesd0091995 => 'Find nearby places';

  @override
  String get mobilityFirstDetailsShownHere859f2457 =>
      'First 100 details shown here. Other positioned records remain selectable on the map.';

  @override
  String get mobilityFortschrittPausiertGpsPruefen63c6fa50 =>
      'Progress paused · Check GPS';

  @override
  String get mobilityFossgisLogsTheRoute7ac53fd4 =>
      'FOSSGIS logs the route request. Spot names and notes stay in the app.';

  @override
  String get mobilityFreeFloating38dd1268 => 'Free-Floating';

  @override
  String get mobilityFreiesZiele762f189 => 'Free destination';

  @override
  String get mobilityFuerDieseAnfrageWurden9803db4c =>
      'No connections were found for this request.';

  @override
  String get mobilityFuerDieseVersionIst88b3c175 =>
      'No LTE-ZIP is available for this version. Check the official catalogue; GeoPackage is not supported yet.';

  @override
  String get mobilityGeradeVerbindungZwischenQuellenpositionen0a65d12c =>
      'Straight link between source positions; no precise road.';

  @override
  String get mobilityGeraetestandorta680a346 => 'Device location';

  @override
  String mobilityGeraetezeit4dd99dec(String arg0, String arg1) {
    return '$arg0 $arg1 (device time)';
  }

  @override
  String get mobilityGeschwindigkeitenUndFahrzeugmengenAn522f5906 =>
      'Speeds and vehicle quantities at measuring points';

  @override
  String get mobilityGeschwindigkeitenUndFahrzeugratenAnba71d451 =>
      'Speeds and vehicle rates at up to 100 detectors in the selected 30 km area.';

  @override
  String get mobilityGespeicherteAbfrageAnzeigen62c7018c => 'Show Saved Query';

  @override
  String get mobilityGespeicherteDatenAktualitaetNichta41279f4 =>
      'Saved data · Actuality not checked live';

  @override
  String mobilityGespeicherteVerbindungen895ea994(String arg0) {
    return 'Stored connections $arg0';
  }

  @override
  String get mobilityGespeichertenSpotUebernehmenOptionald048ef49 =>
      'Apply saved spot (optional)';

  @override
  String get mobilityGespeichertenStand0b0b171e => 'Stored status';

  @override
  String get mobilityGespeicherterAbrufIstAelterc7e97b86 =>
      'Stored retrieval is older than 15 minutes.';

  @override
  String get mobilityGespeicherterMetadatenstandKeineAktuelle17c89c8f =>
      'Stored metadata stand – no current live confirmation.';

  @override
  String get mobilityGespeicherterSpotOptional1c4bdc07 =>
      'Stored spot (optional)';

  @override
  String get mobilityGespeicherterStandOfflineNutzbarc7dc6f17 =>
      'Stored stand (offline usable)';

  @override
  String get mobilityGpsErneutVerbindend3c0a56a => 'Reconnect GPS';

  @override
  String mobilityGueltigAbBisc0b768b9(String arg0, String arg1) {
    return 'Valid from: $arg0 · to: $arg1';
  }

  @override
  String mobilityGueltigSeitBise1e05815(String arg0, String arg1) {
    return 'Valid from: $arg0 · to: $arg1';
  }

  @override
  String get mobilityHidePoisOnD072cee45 => 'Hide POIs on 3D map';

  @override
  String mobilityHinweisec38e74ed(String arg0, String arg1) {
    return '$arg0 Notes · $arg1';
  }

  @override
  String get mobilityIHaveRegisteredAccessa282c504 =>
      'I have registered access and accepted the provider terms for my own use.';

  @override
  String get mobilityImWebDasOriginal2ebbbc3c =>
      'Get the original ZIP on the web via the official download and import it locally. No additional API key required.';

  @override
  String get mobilityImportAircraftJson444ad3f1 => 'Import aircraft JSON';

  @override
  String get mobilityImportDatexXml5eb44537 => 'Import DATEX XML';

  @override
  String get mobilityImportierteDatenOnlineNicht8129ba14 =>
      'Imported data · not checked online';

  @override
  String mobilityInKmImMf10f6e91(String arg0) {
    return 'In $arg0 km · in the 300 m route environment';
  }

  @override
  String get mobilityKachelnErneutVersuchenc1fb6d60 => 'Try tile again';

  @override
  String mobilityKachelnQuelldatumNichtDurch5d14a5bc(String arg0, String arg1) {
    return '$arg0 Tiles: $arg1 · Source date not confirmed by tile shop';
  }

  @override
  String mobilityKantonGebiet2306a36c(String arg0, String arg1) {
    return 'Canton: $arg0 · Area: $arg1';
  }

  @override
  String get mobilityKantonaleFachstellen9b9d1abf => 'Cantonal centres';

  @override
  String get mobilityKantonaleWaldbrandPraeventionsmassnahmena6d2b302 =>
      'Cantonal forest fire prevention measures';

  @override
  String get mobilityKarteFreiBewegene1d97140 => 'Move Map Free';

  @override
  String get mobilityKartendarstellungefb26012 => 'Map representation';

  @override
  String get mobilityKartenpunkt8b21f720 => 'Map point';

  @override
  String get mobilityKeinOeffentlicherBeschreibungstextVorhanden581108e5 =>
      'No public description available.';

  @override
  String get mobilityKeineAuswertbarenMesswerte4dc49063 =>
      'No evaluable measured values';

  @override
  String get mobilityKeineDatiertenMassnahmenFuer9c369d5c =>
      'No dated measures determined for this point. The coverage may be incomplete – NOT a warning.';

  @override
  String get mobilityKeineKontaktEMail7ee17077 =>
      'No contact e-mail required: REST-v1 interface without login.';

  @override
  String get mobilityKeinePassendenMeldungenDas1634f284 =>
      'No matching messages. This does not confirm a free ride or full source coverage.';

  @override
  String get mobilityKeineUeberpruefteQualitaetsmaskeWolken490d3ea2 =>
      'No checked quality mask – clouds and image gaps can be present.';

  @override
  String get mobilityKeineVerkehrsdatenGeladena56a2b8a =>
      'No traffic data loaded';

  @override
  String get mobilityKeysUseDeviceSecuref60f66e8 =>
      'Keys use device secure storage and are sent only to the official ASTRA endpoint.';

  @override
  String mobilityKmMinEstimated439c5826(String arg0, String arg1) {
    return '$arg0 km · $arg1 min estimated';
  }

  @override
  String get mobilityKoordinatenFuerDieAbfrage631e8e79 =>
      'Send coordinates for the query to geo.admin.ch';

  @override
  String mobilityLadestandorteAbrufe451a0c3(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return '$arg0 Loading sites · Retrieving $arg1$arg2';
  }

  @override
  String get mobilityLadestationenInDerSchweiza8bd739c =>
      'Charging stations in Switzerland · BFE / geo.admin.ch. Free spaces are only a dated message and no reservation. Results may be incomplete.';

  @override
  String get mobilityLadestationenSuchen805f1685 => 'Find Charging Stations';

  @override
  String get mobilityLaengeWgs7a5b794e => 'Length (WGS84)';

  @override
  String get mobilityLaengengrad9436942a => 'Longitude';

  @override
  String get mobilityLatitudeced3905e => 'Latitude';

  @override
  String get mobilityLayerUpdateFailedPlease636e8a82 =>
      'Layer update failed. Please retry.';

  @override
  String get mobilityLetzteAktualisierungFehlgeschlagenLetzterf5121616 =>
      'Last update failed; last update is displayed.';

  @override
  String get mobilityLetztenKatalogstandOeffnene2aafc7e =>
      'Open Last Catalog Stand';

  @override
  String get mobilityLetzterAbrufAktuellfe37dd68 => 'Last call up';

  @override
  String mobilityLetzterAbrufImportea742e4d(String arg0) {
    return 'Last call/import: $arg0';
  }

  @override
  String get mobilityListeAufEintraegeBegrenzt46a09ccd =>
      'List limited to 60 entries. Adjust filter or radius.';

  @override
  String get mobilityListeAufEintraegeBegrenzt47537bf9 =>
      'List limited to 60 entries; reduce radius.';

  @override
  String get mobilityLiveMesswerteTrafficCountersaee8a401 =>
      'Live-Messwerte · Traffic Counters';

  @override
  String mobilityLizenzMetadatenAssetVerweisedcf92706(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'License metadata: $arg0 · $arg1 Asset links; of which $arg2 classified as JSON/CSV.';
  }

  @override
  String get mobilityLocationAccessIsRequestedab7f6719 =>
      'Location access is requested only when pressed; coordinates are sent to the routing provider only when you calculate.';

  @override
  String get mobilityLoestSchweizerOrtscodesUnd47816372 =>
      'Dissolves Swiss location codes and table directions. Reference data are stored locally; the timeliness of traffic messages remains independent of this.';

  @override
  String get mobilityLongitude6f9f011c => 'Longitude';

  @override
  String get mobilityMaximaleTrefferzahlErreichtNichtcbd9a35f =>
      'Maximum number of hits reached: not all locations recorded. Reduce radius.';

  @override
  String get mobilityMehrereAmtlicheGebieteUeberlagern220c23d0 =>
      'Several official territories overlap. Scope and priority please check with the cantons.';

  @override
  String mobilityMeldungGeaenderta349466c(String arg0) {
    return 'Notification as amended: $arg0';
  }

  @override
  String get mobilityMeldungenImMUmfeld417f6077 =>
      'Notifications in the 300 m area; road and direction of travel are not confirmed. Arrival estimate does not include traffic jams.';

  @override
  String get mobilityMessstellenAufKarteZeigen191576b4 =>
      'Show measuring points on map';

  @override
  String get mobilityMessstellenImGewaehltenGebietfb7f4f74 =>
      'Measuring points in the selected area';

  @override
  String get mobilityMesswerteAktualisierendbc899d0 => 'Update readings';

  @override
  String get mobilityMesswerteWerdenGeladence66c18a => 'Loading readings..';

  @override
  String mobilityMesszeitIntervallSd22c606f(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
    String arg6,
  ) {
    return '$arg0 · $arg1: $arg2 $arg3 Measuring time: $arg4 · Interval: $arg5 s$arg6';
  }

  @override
  String get mobilityMetadatenAelterAlsHfcd2d03c =>
      'Metadata older than 24 h / time implausible.';

  @override
  String mobilityMetadatenHeruntergeladen4f8bd0e0(String arg0) {
    return 'Metadata downloaded: $arg0';
  }

  @override
  String mobilityMinAnkunft0b629c3a(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0 min · $arg1 · Arrival $arg2:$arg3';
  }

  @override
  String get mobilityMobilityOsint1a8134ea => 'Mobility & OSINT';

  @override
  String get mobilityNaeherHeranzoomenccfc2dce => 'Zoom Closer';

  @override
  String get mobilityNavigationcf03cf2e => 'Navigation';

  @override
  String get mobilityNeuberechnungenSindFruehestensAllea6a83143 =>
      'Recalculations are possible at the earliest every 30 seconds. The arrival estimate remains without traffic surcharges.';

  @override
  String get mobilityNichtAlleAnbieterLiefernb166930b =>
      'Not all providers provide data. Missing hits do not mean full coverage.';

  @override
  String mobilityNichtKlassifiziert32692a7b(String arg0) {
    return 'Not classified: $arg0';
  }

  @override
  String get mobilityNichtUnterstuetzteDateiAssetsaf920b33 =>
      'Unsupported file assets (e.g. GeoPackage) are not imported automatically.';

  @override
  String get mobilityNoAutomaticPollingQueries62b013f8 =>
      'No automatic polling. Queries are limited locally to 12/hour and at least 15 seconds apart. The provider may apply stricter limits.';

  @override
  String get mobilityNoInformationLoadedMissing2c3854cc =>
      'No information loaded. Missing data does not mean clear roads or empty airspace.';

  @override
  String get mobilityNoSavedSpotsChoose44cb95eb =>
      'No saved spots. Choose Freies Ziel to enter a destination.';

  @override
  String get mobilityNurAusreichendZugeordneteAktuellea3f9bd6d =>
      'Only sufficiently assigned current data. New messages alone do not trigger a route change.';

  @override
  String get mobilityNurBegrenzteStacAuswahla9abd316 =>
      'Only limited STAC selection checked; completeness not confirmed.';

  @override
  String get mobilityNurDurchAusdruecklichesSuchen62af35c2 =>
      'Only by explicit search; no site monitoring.';

  @override
  String get mobilityNurMitKartenposition87e01213 => 'Only with map position';

  @override
  String get mobilityNutztDeinenGespeichertenZugang06987d0c =>
      'Uses your saved access. Update in navigation if required; no congestion in the arrival estimate.';

  @override
  String get mobilityNutztVorhandeneDatenBeeinflusst7a5969ac =>
      'Uses existing data. Also influences later recalculations; the driving time remains an OSRM base estimate.';

  @override
  String get mobilityOfficialLegendSourcefc8aaddf => 'Official legend & source';

  @override
  String get mobilityOffizielleEinzelabfrageUnabhaengigVon105d62b9 =>
      'Official individual inquiry · independent of the forest fire hazard level';

  @override
  String get mobilityOffizielleNutzungsbedingungen7ce05187 =>
      'Official Terms of Use';

  @override
  String get mobilityOffizielleStacCollectiond6ac1266 =>
      'Offizielle STAC-Collection';

  @override
  String get mobilityOffiziellerDownloadUndQuellen43d0f2a7 =>
      'Official download and sources';

  @override
  String get mobilityOffiziellerOpenJourneyPlanner328efb58 =>
      'Official Open Journey Planner 2.0 (Switzerland). Connection search to the actual selected point; parking and auto coordinates are not used.';

  @override
  String get mobilityOfflineCacheKatalogKeine803aa9f6 =>
      'Offline/cache catalog – no live confirmation.';

  @override
  String get mobilityOfflineSprachausgabeEinschalten826f1a70 =>
      'Enable offline voice output';

  @override
  String get mobilityOhneKartenpositionTmcOrtstabelle29d7c796 =>
      'Without map position · TMC location table required';

  @override
  String get mobilityOhneNutzbareQuellenposition09a6b7b9 =>
      'Without usable source position';

  @override
  String get mobilityOjpAbfrageergebnis539abae1 => 'OJP query result';

  @override
  String get mobilityOjpDokumentationUndQuelle808dc1c2 =>
      'OJP documentation and source';

  @override
  String get mobilityOpenstreetmapCoverageIsIncompletee9ae81d0 =>
      'OpenStreetMap coverage is incomplete and attributes may be absent or outdated.';

  @override
  String get mobilityOptionalParkingAccessPoints7538207e =>
      'Optional parking & access points';

  @override
  String mobilityOsmPlacesRetrieved45a236fa(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return '$arg0 OSM places · retrieved $arg1$arg2';
  }

  @override
  String get mobilityOsrmLiefertNichtImmer92919ffd =>
      'OSRM does not always provide alternatives. Missing messages or measurements do not confirm free traffic flow.';

  @override
  String get mobilityOutdatedThisOfflineSnapshot5eb25014 =>
      'OUTDATED: This offline snapshot may no longer reflect available facilities.';

  @override
  String get mobilityOvVerbindungenOjp3ac37a87 =>
      'Public transport connections · OJP 2.0';

  @override
  String get mobilityOvVerbindungenSuchen7014824a =>
      'Search for public transport connections';

  @override
  String get mobilityOverpassApiDocumentationAnd4c33de59 =>
      'Overpass API documentation and fair-use policy';

  @override
  String get mobilityOwnAstraApiKey38bbd3b9 => 'Own ASTRA API key';

  @override
  String mobilityPassendeEreignisse872c00ef(String arg0, String arg1) {
    return '$arg0 appropriate events$arg1';
  }

  @override
  String mobilityPositionedRecordsWithoutUsable456e69a4(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0\n$arg1 positioned records · $arg2 without usable positions · $arg3 omitted.';
  }

  @override
  String mobilityProduktbc93422a(String arg0, String arg1) {
    return 'Product: $arg0 · $arg1';
  }

  @override
  String get mobilityPrognosezeitstandKeineDirekteBeobachtungbef744b1 =>
      'Forecast time: no direct observation.';

  @override
  String get mobilityProviderUnavailableShowingA4e8d9841 =>
      'Provider unavailable; showing a dated cached snapshot instead.';

  @override
  String mobilityPublikationsstandDerQuellec3da8498(String arg0) {
    return 'Source: $arg0';
  }

  @override
  String get mobilityPunktuelleGeschwindigkeitenWerdenOhne74f8b6a6 =>
      'Point speeds are not weighted without comparable measurements of all alternatives.';

  @override
  String get mobilityPunktuelleMessungenDerQuellee6b23c9f =>
      'Specific measurements of the source. Numbers of vehicles are rates in vehicles per hour. Values of different lanes and vehicle groups are not added. No continuous traffic card.';

  @override
  String get mobilityQualitaetsWolkenmaskeAlsEigenes3ad85811 =>
      'Quality/cloud mask available as own dataasset; not automatically interpreted as cloud-free.';

  @override
  String get mobilityQuelleBafuKantoneGeo76ff0395 =>
      'Source: FOEN / Cantons · geo.admin.ch · waldbranddranger.ch';

  @override
  String get mobilityQuelleUndNutzungsbedingungene5956cc4 =>
      'Source and Terms of Use';

  @override
  String get mobilityQuellenGrenzen4bc8454f => 'Sources & Limits';

  @override
  String mobilityQuellenmeldung8bdd0b3c(String arg0) {
    return 'Source: $arg0';
  }

  @override
  String mobilityQuellenpublikationd60ff8d0(String arg0) {
    return 'Source publication: $arg0';
  }

  @override
  String mobilityQuellenveroeffentlichung5456a71d(String arg0) {
    return 'Source publication: $arg0';
  }

  @override
  String get mobilityRasterkartenSendenDenKartenausschnittf2f4eb37 =>
      'Raster map requests send the displayed area to geo.admin.ch. The app retrieves the national SLF bulletin without sending a location. Retrieval dates do not establish official validity. Consult the AIP for aerodromes and local orders for fire restrictions. Map layers grant neither flight nor access authorisation.';

  @override
  String mobilityReferenz917463e5(String arg0) {
    return 'Reference: $arg0';
  }

  @override
  String get mobilityRefreshAircraftcf46fb55 => 'Refresh aircraft';

  @override
  String get mobilityRefreshFromOverpass6925d82f => 'Refresh from Overpass';

  @override
  String get mobilityRefreshTrafficde6624d5 => 'Refresh traffic';

  @override
  String mobilityRemoveLayer98fc17fe(String arg0) {
    return 'Remove $arg0 layer';
  }

  @override
  String get mobilityReportAMapError8ddb12c3 => 'Report a map error';

  @override
  String get mobilityResultsTruncatedToProtect98dcb26a =>
      'Results truncated to protect the device. Reduce your radius or category selection.';

  @override
  String mobilityRetrievedImportedSourcePublicationadd5e4e8(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0\n$arg1\nRetrieved/imported: $arg2\nSource publication: $arg3\nDataset validity: not declared; individual records may provide dates.';
  }

  @override
  String get mobilityRetryTilesa3340dc4 => 'Retry tiles';

  @override
  String get mobilityRouteNeuBerechnen8225e5ba => 'Recalculate route';

  @override
  String get mobilityRoutenalternativenNeuBerechnen5de70eb6 =>
      'Recalculate route alternatives';

  @override
  String get mobilitySatellitenkarte6afd828c => 'Satellite map';

  @override
  String get mobilitySaveAccessNotesLocallyf5e29d86 =>
      'Save access notes locally';

  @override
  String get mobilitySaveAsPersonalSpotc26312fd => 'Save as personal spot';

  @override
  String mobilitySavedAsSpota5bf3429(String arg0) {
    return 'Saved as spot #$arg0';
  }

  @override
  String get mobilitySavedSpotsUnavailableb5814146 =>
      'Saved spots unavailable.';

  @override
  String get mobilitySearchAroundSavedSpot88def52e =>
      'Search around saved spot (optional)';

  @override
  String get mobilitySearchRadiusMetres9f19e093 => 'Search radius (metres)';

  @override
  String get mobilitySharingAngeboteAmOvcb5d14df =>
      'Search for sharing offers at the public transport destination';

  @override
  String get mobilitySharingAngeboteSuchen5659da3e =>
      'Search for sharing offers';

  @override
  String get mobilityShowDrivingRouteOn3860ee86 => 'Show driving route on map';

  @override
  String get mobilityShowPoisOnD87e9f7a8 => 'Show POIs on 3D map';

  @override
  String get mobilityShowSavedSearchOffline9f9ba558 =>
      'Show saved search offline';

  @override
  String get mobilityShowSnapshotOnMap1ce6224b => 'Show snapshot on map';

  @override
  String get mobilityShowingTheFirstPoie98a81e6 =>
      'Showing the first 60 POI detail cards; up to 300 points can be rendered on the map.';

  @override
  String mobilitySnapshotVisiblec86e4891(String arg0) {
    return '$arg0 snapshot visible';
  }

  @override
  String get mobilitySnapshotsAreDelayedAnd4458e3d6 =>
      'Snapshots are delayed and incomplete. Amber markers are older than 30 seconds; positions older than 5 minutes are hidden. Markers sit on the terrain; reported aircraft altitudes are available in details. Never use this to replace visual airspace observation or official aviation information.';

  @override
  String get mobilitySprachausgabeAusschalten212e3af6 =>
      'Switch off voice output';

  @override
  String mobilityStacAbgefragtTrefferIn004b3edc(String arg0, String arg1) {
    return 'STAC requested: $arg0 · $arg1 Results in limited sample';
  }

  @override
  String get mobilityStacAssetsPruefen15fce27f => 'Check STAC Assets';

  @override
  String get mobilityStacDatenstandPruefen445b5f79 => 'Check STAC data level';

  @override
  String get mobilityStacMetadatenFuerSwisseofe06af42 =>
      'STAC metadata for swissEO VHI are requested only on request. The call-up time and the observation period are stored separately. WMS/WMTS tiles are not archived as an offline data record.';

  @override
  String mobilityStacStand0f0a2434(String arg0) {
    return 'STAC status: $arg0';
  }

  @override
  String get mobilityStandortFolgen5650d84d => 'Follow Location';

  @override
  String get mobilityStandortdatenAelterAlsFuenfe3719933 =>
      'Location data older than five minutes; not live.';

  @override
  String get mobilityStarten2beb7350 => 'Start';

  @override
  String mobilityStationen2bee7a5c(String arg0, String arg1) {
    return '$arg0 stations · $arg1';
  }

  @override
  String get mobilityStationenAufDemD84751cec => 'Stations on the 3D globe';

  @override
  String get mobilityStationenSuchen87f44373 => 'Search Stations';

  @override
  String get mobilityStationencfddc861 => 'Stationen';

  @override
  String get mobilityStationslayerAusblenden28212b4d => 'Hide Station Layer';

  @override
  String get mobilitySuchkoordinatenAnGeoAdmin3849c24c =>
      'Send search coordinates to geo.admin.ch';

  @override
  String get mobilitySuchkoordinatenBeimBfeGeo298d1eb7 =>
      'Search coordinates at the SFOE / geo.admin.ch';

  @override
  String get mobilitySuchkoordinatenFuerEineAbfrage44b6f76d =>
      'Send search coordinates for a query to sharedmobility.ch';

  @override
  String get mobilitySuchradius51fb2797 => 'Search radius';

  @override
  String get mobilitySuchzentrumGespeicherterSpotOptional8f6f54a7 =>
      'Search center: saved spot (optional)';

  @override
  String get mobilitySwisseoSentinelVAmtlichedcab45cb =>
      'swissEO Sentinel-2 v200 / official event recordings · optional';

  @override
  String mobilitySwisseoVhiDatenstatus0fe52fab(String arg0) {
    return 'swissEO VHI · Data status: $arg0';
  }

  @override
  String mobilityTabelleEntfernenad464a91(String arg0) {
    return 'Remove Table $arg0';
  }

  @override
  String mobilityTabelleLaden750049fc(String arg0) {
    return 'Load table $arg0';
  }

  @override
  String mobilityTabellenLokal09ba7ffc(String arg0, String arg1) {
    return '$arg0 local $arg1';
  }

  @override
  String get mobilityTabellenversionb0986031 => 'Table version';

  @override
  String get mobilityTechnologieUnbekanntbdb10475 => 'Technology unknown';

  @override
  String mobilityTeilmeldungenAufgeloestNochOffenaa8196c8(
    String arg0,
    String arg1,
  ) {
    return '$arg0 Partial messages dissolved · $arg1 still open';
  }

  @override
  String mobilityTmcOrted224adb9(String arg0, String arg1) {
    return 'TMC $arg0 · $arg1 Places';
  }

  @override
  String get mobilityTmcOrtsdatene977fc3e => 'TMC location data';

  @override
  String get mobilityTmcTabellenbezugKeinGenauer361692b0 =>
      'TMC table reference · no precise road route';

  @override
  String mobilityTmcVersionOrteRichtungscodecfd846ff(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'TMC version $arg0 · Places $arg1 · Direction code $arg2';
  }

  @override
  String get mobilityTmcZipImportieren41204dbf => 'Import TMC ZIP';

  @override
  String get mobilityTopografischeKarte0698a0c0 => 'Topographic map';

  @override
  String mobilityTrefferNachFilterd2e8e9db(String arg0) {
    return '$arg0 results by filter';
  }

  @override
  String get mobilityTrefferlimitErreichtKeineVollstaendigedb231641 =>
      'Hit limit reached: no complete area detection. Reduce search radius.';

  @override
  String get mobilityTrockenheitVegetationszustandBafuSwisseoa63812c2 =>
      'Dryness & Vegetation Condition (BAFU / swissEO)';

  @override
  String mobilityUmstiegeFusswege891d4f80(String arg0, String arg1) {
    return '$arg0 Change · $arg1 Footpaths';
  }

  @override
  String mobilityUnlocated0f6d01d4(String arg0) {
    return 'Unlocated · $arg0';
  }

  @override
  String get mobilityUseDeviceLocation37b5a739 => 'Use device location';

  @override
  String mobilityVerbindungc49ec173(String arg0, String arg1, String arg2) {
    return 'Connection $arg0: $arg1 – $arg2';
  }

  @override
  String get mobilityVerbindungenOfflineAlsMomentaufnahme0524e3f4 =>
      'Save connections offline as snapshot';

  @override
  String get mobilityVergleichbareGesamtverkehrsMessungenAller0e5faa9f =>
      'Comparable total traffic measurements of all alternatives slightly affect the comparison (at most one point of comparison).';

  @override
  String mobilityVergleichd42555f6(String arg0) {
    return 'Comparison: $arg0';
  }

  @override
  String get mobilityVerkehrAktualisieren7e12eefe => 'Update traffic';

  @override
  String get mobilityVerkehrAutomatischAktualisieren83ed17ce =>
      'Automatically update traffic';

  @override
  String get mobilityVerkehrBeiDerRoutenbewertung65a144f1 =>
      'Taking traffic into account in route evaluation';

  @override
  String get mobilityVerkehrBeiNeuberechnungBeruecksichtigen47577e32 =>
      'Account for transport when recalculating';

  @override
  String get mobilityVerkehrEntlangDerRoute746b9545 =>
      'Traffic along the route';

  @override
  String get mobilityVerkehrsdatenAusgeschalteta2ae8d43 =>
      'Traffic data disabled';

  @override
  String get mobilityVerkehrsdatenLadenPruefen27aded3f =>
      'Load/check traffic data';

  @override
  String get mobilityVerkehrsmeldungenWerdenAktualisiert10e1b261 =>
      'Updating traffic messages ..';

  @override
  String mobilityVeroeffentlichtf559efaf(String arg0) {
    return 'Published: $arg0';
  }

  @override
  String get mobilityVhiVWirdLaute6dca0e6 =>
      'According to swisstopo, VHI v100 will be replaced by v200 by the end of 2026. Until the verified conversion, the current layer is a transitional solution.';

  @override
  String get mobilityViewOsmSource395c9b71 => 'View OSM source';

  @override
  String get mobilityWebAvailabilityDependsOna0047196 =>
      'Web availability depends on the public endpoint’s CORS policy; direct requests may fail in browsers. No proxy or intermediary is configured. This search does not download OSM map tiles.';

  @override
  String get mobilityWebCorsNichtVerifiziert29e7d189 =>
      'Web: CORS not verified. Browser lock requires a proprietary proxy; none is set up.';

  @override
  String get mobilityWebOjpCorsUndd96e47d9 =>
      'Web: OJP-CORS and browser access not verified. Direct request may fail. No relay/proxy available; keys in the browser are not protected against page scripts.';

  @override
  String get mobilityWeiterHerauszoomen212b4f14 => 'Zoom Out More';

  @override
  String mobilityWeitereMeldungenc11d95f1(String arg0) {
    return 'Other messages $arg0';
  }

  @override
  String get mobilityWeitereMessstellene0dab34a => 'Other measuring points';

  @override
  String get mobilityWeitereStacSeitenVorhanden8ac44f7a =>
      'More STAC pages available or hit limit reached. Cover incomplete.';

  @override
  String mobilityWeitereUngueltigeAlternativenNichtc1e16f33(String arg0) {
    return '$arg0 other / invalid alternatives not shown.';
  }

  @override
  String mobilityWeitereZugeordneteHinweise883d2761(String arg0) {
    return '$arg0 other related references';
  }

  @override
  String get mobilityWieKarte9cb7c6de => 'As on map';

  @override
  String mobilityWolkenanteilGemaessQuelle15e9a8e3(String arg0) {
    return 'Cloud share according to source: $arg0 %';
  }

  @override
  String get mobilityWolkenanteilNichtAngegeben76ffb608 =>
      'Cloud share: not specified';

  @override
  String get mobilityZaehlstellenTokenEntfernen15b8092b =>
      'Remove Counting Point Token';

  @override
  String get mobilityZaehlstellenTokenSpeichern6579a132 => 'Save Count Tokens';

  @override
  String get mobilityZaehlstellenzugangFreigeschaltetUndAstraa64cddb1 =>
      'Count access unlocked and ASTRA conditions accepted';

  @override
  String get mobilityZiel44d12621 => 'Objective';

  @override
  String mobilityZiel85926175(String arg0) {
    return 'Objective: $arg0';
  }

  @override
  String get mobilityZielSuchen5a773b38 => 'Search Target';

  @override
  String get mobilityZuerstImTrafficTab4547f06d =>
      'First in the traffic tab store the token for road traffic - traffic situations and accept the provider conditions.';

  @override
  String get mobilityZuerstWerdenRoutenMit9d2c4bb2 =>
      'First, routes with associated blocking messages are displayed subordinately. After that, OSRM base time and the largest published delay value count. Delays are not summed up and do not change the displayed arrival time.';

  @override
  String mobilityZugeordneteDetektorenOhnePassende637e378d(
    String arg0,
    String arg1,
  ) {
    return '$arg0 associated detectors · $arg1 without matching metadata';
  }

  @override
  String mobilityZugeordneteSperrmeldungenZugeordneteQuellenhinweiseee632e99(
    String arg0,
    String arg1,
  ) {
    return 'Release messages associated with $arg0 · $arg1';
  }

  @override
  String get mobilityZuordnungUndQuellend088f13c => 'Allocation and sources';

  @override
  String get mobilityZusaetzlicheDatenebenenAngabenKoennen3a7acd85 =>
      'Additional data levels · Information may be incomplete or outdated.';

  @override
  String observationsAbgerufenZuletztGeprueft118070fc(
    String arg0,
    String arg1,
  ) {
    return 'Called: $arg0 Last checked: $arg1';
  }

  @override
  String get observationsAbrufenSendetBeiBafu0559cc82 =>
      'Retrieving sends a selection of nearby station numbers at BAFU; MeteoSwiss is loaded as a national file.';

  @override
  String get observationsDatenNichtVerfuegbar85f19360 => 'Data not available';

  @override
  String get observationsGemesseneStationswerteKeinePrognosef2d35acc =>
      'Station values measured · no forecast';

  @override
  String get observationsKeineVerfuegbarenMessstationenImb3c601f8 =>
      'No available measuring stations in the selected environment. Missing values do not mean no warning.';

  @override
  String get observationsLokalenSnapshotLoeschen500f4bea =>
      'Delete Local Snapshot';

  @override
  String get observationsMesswerteAbrufen404711d9 => 'Retrieve readings';

  @override
  String get observationsOffizielleStationsdetails03ee57d0 =>
      'Official Station Details';

  @override
  String get observationsQuelleBafuHydrologischeBeobachtungenc7f7e996 =>
      'Source: BAFU · Hydrological observations. Live is uncorrected; 10-minute mean and release status remain separate.';

  @override
  String get observationsQuelleMeteoschweizSwissmetnetCcd346cfc9 =>
      'Source: MeteoSchweiz · SwissMetNet · CC BY 4.0. Wind/bodies in km/h; precipitation as a 10-minute sum.';

  @override
  String get observationsQuelleUndProduktbeschreibunga056e6fd =>
      'Source and product description';

  @override
  String get observationsStationenAufDerKarte6bbce8f0 => 'Stations on the map';

  @override
  String observationsStationenOhneZuordenbareMetadaten7a9052fc(String arg0) {
    return '$arg0 stations without assignable metadata.';
  }

  @override
  String get observationsUnvollstaendigerDatenauszugWeitereMesswerte5c0b8d49 =>
      'Incomplete data extract; further readings may be missing.';

  @override
  String observationsVerfuegbareWerte3495e1b4(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0 · $arg1 available values$arg2$arg3';
  }

  @override
  String get obstaclesAmtlicherDatensatzNachImportd2d6162d =>
      'Official record · available offline after import.';

  @override
  String get obstaclesApproximateGeometryStraightConnectionsbd84ea99 =>
      'Approximate geometry: straight connections / polygon outlines from the source. Actual cable sag and obstacle surfaces are not defined.';

  @override
  String get obstaclesBazlObstacleLegend85da8229 => 'BAZL obstacle legend';

  @override
  String get obstaclesCheckSourceForUpdates9b2adfd6 =>
      'Check source for updates';

  @override
  String get obstaclesCloseObstacleDetails12608787 => 'Close obstacle details';

  @override
  String get obstaclesDObstacleModels82a00838 => '3D obstacle models';

  @override
  String obstaclesDataStatusef822b6e(String arg0) {
    return 'Data status: $arg0';
  }

  @override
  String get obstaclesDatenHoehenbezug36af217e => 'Data & Height Reference';

  @override
  String get obstaclesDownloadVectorDataset689316d7 =>
      'Download vector dataset';

  @override
  String obstaclesEffectiveDateUtc90780bc8(String arg0) {
    return 'Effective date: $arg0 UTC';
  }

  @override
  String obstaclesFirstSourceVertexHeight6eebb9de(String arg0, String arg1) {
    return 'First source vertex height: $arg0 m · $arg1';
  }

  @override
  String get obstaclesHighlightHazardAreas0d0a655e => 'Highlight hazard areas';

  @override
  String obstaclesHorizontalBufferMc4e67f2c(String arg0) {
    return 'Horizontal buffer: $arg0 m';
  }

  @override
  String obstaclesImportedObjectsUnsupportedRecords947e6f13(
    String arg0,
    String arg1,
  ) {
    return '$arg0 imported objects · $arg1 unsupported records';
  }

  @override
  String get obstaclesLegendUnavailableOpenThe1690ecec =>
      'Legend unavailable. Open the official link below.';

  @override
  String obstaclesLocalCacheSourceValidity2bcad0a6(String arg0, String arg1) {
    return 'Local cache: $arg0 · source validity: $arg1';
  }

  @override
  String obstaclesMetadataChecked61ccc766(String arg0) {
    return 'Metadata checked: $arg0';
  }

  @override
  String get obstaclesNotSupplied25fa1c12 => 'Not supplied';

  @override
  String get obstaclesNurVeroeffentlichteHindernisseFehlende874c23fc =>
      'Only published obstacles · missing objects possible.';

  @override
  String obstaclesObstacleImageryOpacity83ec0630(String arg0) {
    return 'Obstacle imagery opacity: $arg0%';
  }

  @override
  String get obstaclesOfficialWmsLegenda55cc700 => 'Official WMS legend';

  @override
  String get obstaclesPlanungshilfeKeineFreigabeOder3f2c05b6 =>
      'Planning assistance · no clearance or distance check.';

  @override
  String get obstaclesPublishedObstaclesWms03371ce2 =>
      'Published obstacles · WMS';

  @override
  String obstaclesPublishedUtcc490142e(String arg0) {
    return 'Published: $arg0 UTC';
  }

  @override
  String obstaclesPublishedValidityUtcb1c25560(String arg0, String arg1) {
    return 'Published validity: $arg0 → $arg1 UTC';
  }

  @override
  String get obstaclesRetryObstacleImagerya63bb8aa => 'Retry obstacle imagery';

  @override
  String get obstaclesSelectableObstaclesDVectore21d36db =>
      'Selectable obstacles · 3D vector';

  @override
  String get obstaclesSourceAssetUnavailablebc4a043d =>
      'Source asset unavailable';

  @override
  String get obstaclesSourceAttributesf0c00259 => 'Source attributes';

  @override
  String obstaclesSourceIdUuidc30a2ed8(String arg0, String arg1) {
    return 'Source ID: $arg0\nUUID: $arg1';
  }

  @override
  String obstaclesSourceMaximumHeight03ba5af5(String arg0) {
    return 'Source maximum height: $arg0';
  }

  @override
  String obstaclesSourceUpdated81b6e983(String arg0) {
    return 'Source updated: $arg0';
  }

  @override
  String obstaclesSourceUpdatedRetrieved4bba5e9c(String arg0, String arg1) {
    return 'Source updated: $arg0\nRetrieved: $arg1';
  }

  @override
  String get obstaclesSwissAviationObstacles1befa7cf =>
      'Swiss aviation obstacles';

  @override
  String obstaclesTopElevation140c7227(String arg0) {
    return 'Top elevation: $arg0';
  }

  @override
  String obstaclesTypeab721b15(String arg0, String arg1) {
    return 'Type: $arg0 · $arg1';
  }

  @override
  String get obstaclesVeroeffentlichteHoeheFormUnd8f84873d =>
      'Published height · shape and width estimated.';

  @override
  String obstaclesVerticesAltitudeModeddeefe8a(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0: $arg1 vertices · altitude mode: $arg2 · $arg3';
  }

  @override
  String get offlineAddOfflineRegion6d71cdd8 => 'Add offline region';

  @override
  String get offlineAnsichtspufferUndOptionalerLaptop62f2efd5 =>
      'View buffer and optional laptop export';

  @override
  String get offlineBereichOfflineVorbereiten91421709 =>
      'Preparing the offline area';

  @override
  String get offlineCachedBaseMapTerrainecfb9aaf =>
      'Cached base map & terrain · coverage may be incomplete or outdated. Live overlays and API actions require separate verification.';

  @override
  String get offlineCentreLatitudea76075f4 => 'Centre latitude';

  @override
  String get offlineCentreLongitude1cbc4661 => 'Centre longitude';

  @override
  String get offlineDGelaende41d0aed9 => '3D sites';

  @override
  String get offlineDerZusaetzlicheAnsichtspufferEnthaeltb23a8c6c =>
      'The additional view buffer contains only actually viewed tiles and can remain incomplete. It is independent of the automatic official region download above.';

  @override
  String get offlineGelaendedetailFuerOfflinePaketcbde183b =>
      'Terrain Detail for Offline Package';

  @override
  String get offlineGesamteSchweiz533dc2ed => 'Total Switzerland';

  @override
  String get offlineGesamteSchweizOfflineVorbereiten7cb30202 =>
      'Prepare all Switzerland offline';

  @override
  String offlineGeschaetzterLokalerSpeicherMibae938fa8(
    String arg0,
    String arg1,
  ) {
    return 'Estimated local memory: $arg0 MiB · $arg1 Tile. Original data and map content influence download quantity and duration. Existing region remains active until successful completion.';
  }

  @override
  String offlineGespeicherteKartendatenMibDerf8af680d(String arg0) {
    return 'Stored map data: $arg0 MiB. The additional buffer for tiles loaded during viewing is limited to 256 MiB.';
  }

  @override
  String get offlineGewuenschtenMittelpunktAufDem999be642 =>
      'Tap desired center on the globe.';

  @override
  String get offlineGrosserDownloadDetailUnd759ef111 =>
      'Large download. Detail and levels determine the storage requirement; the browser checks its available memory before starting.';

  @override
  String get offlineHoehenAusSwissaltiD5966fff3 =>
      'Heights from swissALTI3D; selected detail level determines the resolution in the globe.';

  @override
  String get offlineMaximumImageryDetaile83a21f6 => 'Maximum imagery detail';

  @override
  String get offlineMittelpunktAufGlobeMarkierenec84f922 =>
      'Mark Center on Globe';

  @override
  String get offlineMittelpunktAufKarteWaehlen0129acc2 =>
      'Select Center on Map';

  @override
  String get offlineMittelpunktUebernehmen654f1ce1 => 'Take centre';

  @override
  String get offlineNeueVorbereitungsdateif618c1fc => 'New Preparing File';

  @override
  String get offlineOfflineBereichVorbereitene86172db => 'Prepare offline area';

  @override
  String get offlineOfflineMapRegionse6d5c4de => 'Offline map regions';

  @override
  String get offlineOfflinePaketImportieren3e6d35a5 => 'Import Offline Package';

  @override
  String get offlineOfflineVerfuegbareKartenebenen3eca4f37 =>
      'Offline map borders available';

  @override
  String get offlineRefreshStorageStatus889bb274 => 'Refresh storage status';

  @override
  String get offlineRegionAktualisieren789dbcf6 => 'Update Region';

  @override
  String get offlineRemoveCachedRegion3fb1230e => 'Remove cached region';

  @override
  String get offlineSaveRegionForCaching87de5600 => 'Save region for caching';

  @override
  String get offlineSpeicherlimitFuerDiesenDownload142a1d01 =>
      'Memory limit for this download';

  @override
  String offlineStufed0ed7705(String arg0, String arg1) {
    return 'Level $arg0$arg1';
  }

  @override
  String get offlineSupportedMapb531fbb7 => 'Supported map';

  @override
  String offlineTilesMib2f032565(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
  ) {
    return '$arg0 / $arg1 tiles · $arg2 MiB\n$arg3 · $arg4\n$arg5';
  }

  @override
  String get offlineTopographicd28af3fe => 'Topographic';

  @override
  String get offlineUnterbrocheneAufbereitungVerwerfenf0149e36 =>
      'Discard interrupted treatment';

  @override
  String get offlineUseCachedBaseMapcac83b59 =>
      'Use cached base map and terrain';

  @override
  String get offlineVorbereitungsdateiFuerLaptopSpeichern42dca4b8 =>
      'Save Laptop Preparation File';

  @override
  String offlineZoomb67baf86(String arg0) {
    return 'Zoom $arg0';
  }

  @override
  String get offlineZusaetzlicheDatierteMomentaufnahmenAktualisieren66eddff9 =>
      'Update additional dated snapshots';

  @override
  String outdoorAbgerufenAmtlichesPublikationsdatumNicht1eb563a2(String arg0) {
    return 'Called up: $arg0 · official publication date not reported';
  }

  @override
  String get outdoorAmtlicheLegendeUndQuelle17cac2a2 =>
      'Official legend and source';

  @override
  String get outdoorAmtlicheWegenetzeee6981c0 => 'Official networks';

  @override
  String get outdoorAmtlicherOutdoorKontextab221e59 =>
      'Official outdoor context';

  @override
  String get outdoorAusgewaehlterKartenpunktd902892e => 'Selected map point';

  @override
  String get outdoorAuszugAktualisieren55f223d5 => 'Update Extract';

  @override
  String get outdoorAuszugAufKarteAnzeigen9105f450 => 'Show excerpt on map';

  @override
  String get outdoorBezugWaehlendcf73635 => 'Select Reference';

  @override
  String get outdoorDetailsUmDenKartenpunktdbe266e7 =>
      'Retrieve details around the map point';

  @override
  String get outdoorDieseDetailauszuegeWerdenNur71ff8d83 =>
      'These detail extracts are only kept in memory. Cross-Canton vector packages and their transmission require appropriate terms of use.';

  @override
  String get outdoorErgebnisgrenzeErreichtWeitereObjektefa8b4a21 =>
      'Result limit reached · other objects may be missing.';

  @override
  String get outdoorFlugrouteAuswaehlenLetzteeb04100f =>
      'Select route · last 100';

  @override
  String get outdoorGespeicherteFlugroutede6dec82 => 'Stored flight route';

  @override
  String get outdoorGespeicherterOrt25ce06f0 => 'Stored place';

  @override
  String outdoorKartenebeneQuelldatumNichtVom78282b34(String arg0) {
    return 'Map level: $arg0 · Source date not reported by service';
  }

  @override
  String get outdoorKartenkachelnErneutLadend22d2379 => 'Re-load map tiles';

  @override
  String get outdoorKeineObjekteImAuszug3e189c68 =>
      'No objects found in the extract. This does not confirm an open or free route.';

  @override
  String get outdoorNaturUndWildruhezonen7304b9ec =>
      'Nature and wild recreation areas';

  @override
  String get outdoorNochKeineFlugroutenGespeichertc7aeb7bc =>
      'No flight routes saved yet';

  @override
  String get outdoorOffizielleDetails573452dd => 'Official details';

  @override
  String get outdoorOnlineEbeneOfflineKacheldownload52ce6e5a =>
      'Online level · Offline tile download not released. Coverage and up-to-dateness can be incomplete.';

  @override
  String get outdoorOriginalattribute38290624 => 'Originalattribute';

  @override
  String get outdoorOutdoorEbeneKonnteNichtdae0b0f9 =>
      'Outdoor level could not be changed. Try again.';

  @override
  String outdoorQuellenIdba307a43(String arg0, String arg1) {
    return 'Source ID: $arg0 $arg1';
  }

  @override
  String get outdoorRouteOderAuszugUeberschreitene46a9d8f =>
      'Route or extract exceed the size limit for the complete single adjustment. Please select a shorter section. The original geometry is retained.';

  @override
  String get outdoorSperrungenUndUmleitungenc019df11 =>
      'Blocks and redirections';

  @override
  String get preflightAnyDrone97497506 => 'Any drone';

  @override
  String get preflightAnyFlightPlan5d58f177 => 'Any flight plan';

  @override
  String preflightChecklistCouldNotBe467e09ff(String arg0) {
    return 'Checklist could not be saved: $arg0';
  }

  @override
  String get preflightChecklistTemplate9368b50e => 'Checklist template';

  @override
  String get preflightCompletionIsSavedOna7956e8f =>
      'Completion is saved on this device. Start a new checklist for each flight; completing it does not grant flight authorization.';

  @override
  String get preflightEditItemsAssociations032f939c =>
      'Edit items & associations';

  @override
  String get preflightFlightPlan4cb79e47 => 'Flight plan';

  @override
  String get preflightItemsOnePerLinee1c97f47 => 'Items · one per line';

  @override
  String get preflightLocalChecklistsUnavailableReopende49292a =>
      'Local checklists unavailable. Reopen this screen to retry.';

  @override
  String get preflightNewTemplate865095cf => 'New template';

  @override
  String get preflightPreflightTelemetry0632b0c8 => 'Preflight & Telemetry';

  @override
  String preflightReusableTemplateItems8ec2077a(String arg0) {
    return 'Reusable template · $arg0 items';
  }

  @override
  String get preflightSaveLocally87522ab5 => 'Save locally';

  @override
  String get preflightStartWithAllItems29c20291 =>
      'Start with all items unchecked';

  @override
  String get preflightUnsupportedChecklistDatabe2cc486 =>
      'Unsupported checklist data';

  @override
  String get preflightUpToItemsChangeda0ae0a06 =>
      'Up to 100 items. Changed items or associations must be checked again.';

  @override
  String get profilesAnderungenVerwerfen9af398c1 => 'Discard changes?';

  @override
  String get profilesAusVorlage7a27bf2c => 'From template';

  @override
  String get profilesBearbeiten104f3bfd => 'Edit';

  @override
  String get profilesBeibehalten94ebabfe => 'Maintain';

  @override
  String get profilesDuplizieren8524c5cd => 'Duplicate';

  @override
  String get profilesEigenesProfila1a7ad19 => 'Own profile';

  @override
  String get profilesExportieren4e4a0d71 => 'Export';

  @override
  String get profilesHintergrundkarte2f67406f => 'Background map';

  @override
  String get profilesKartenstartwerteBeimAktivierenf2e700fc =>
      'Card start values when enabled';

  @override
  String get profilesMaximalProfileZumHinzufuegene6d6ba7e =>
      'Maximum 32 profiles. To add, first delete a profile.';

  @override
  String get profilesOhneProfilAlleWerkzeuge5ab1fd0c =>
      'Without profile · all tools';

  @override
  String get profilesProfilBearbeitend4e69e62 => 'Edit Profile';

  @override
  String get profilesProfilSpeichernfeda7fb0 => 'Save Profile';

  @override
  String get profilesProfilWurdeNichtGespeichert24e088e3 =>
      'Profile has not been saved. Your design is retained; please try again.';

  @override
  String get profilesProfilaktionFehlgeschlagenBitteErneutfc851528 =>
      'Profile action failed. Please try again.';

  @override
  String get profilesSatellit6020d8ce => 'Satellite';

  @override
  String get profilesTopografisch52f1415e => 'Topographic';

  @override
  String get profilesUberspringenAlleWerkzeuge95410f7f => 'Skip · all tools';

  @override
  String get profilesVorlageWaehlen7df6eb54 => 'Select Template';

  @override
  String get profilesVorlagenSindFreiAnpassbarff309b1d =>
      'Templates are freely customizable. All tools remain accessible.';

  @override
  String get profilesWerkzeugePassendZuDeiner8e101852 =>
      'Tools to match your activity';

  @override
  String profilesWerkzeugeSchnellaktionenc271b295(String arg0, String arg1) {
    return '$arg0 tools · $arg1 Rapid actions';
  }

  @override
  String get profilesWirdGespeichert129ed064 => 'Saving..';

  @override
  String get profilesWomitMoechtestDuStartenee1d09d8 =>
      'What do you want to start with?';

  @override
  String get radioADroneCanUsea385a1c2 =>
      'A drone can use several independent configurations.';

  @override
  String get radioAddEquipmentProfile85022529 => 'Add equipment profile';

  @override
  String get radioAddEquipmentda5d2801 => 'Add equipment';

  @override
  String get radioCreateIndependentControlAndf7437069 =>
      'Create independent control and video configurations. Leave unknown values empty. Maximum power is the transmitter output before antenna gain and cable loss; record the applicable mode and source below.';

  @override
  String get radioDeleteEquipmentProfile0d5a874b => 'Delete equipment profile?';

  @override
  String get radioEditEquipment92a5da88 => 'Edit equipment';

  @override
  String get radioEditEquipmentProfilef984d1a0 => 'Edit equipment profile';

  @override
  String get radioEquipmentDetailse402502a => 'Equipment details';

  @override
  String get radioNoDroneProfilesYetd1f93a9e =>
      'No drone profiles yet. You can assign this equipment later.';

  @override
  String radioPermanentlyDeleteAndIts53a62100(String arg0) {
    return 'Permanently delete \"$arg0\" and its assignments? Drone profiles and other equipment configurations are kept.';
  }

  @override
  String get radioRadioVideoEquipment93933cea => 'Radio & video equipment';

  @override
  String get radioRecordedSpecificationsUnknownValues7c5d9e94 =>
      'Recorded specifications. Unknown values remain unrecorded. Maximum transmitter power is before antenna gain and cable loss; the operating setting may be lower.';

  @override
  String get radioRefreshDronesc1a9ec7c => 'Refresh drones';

  @override
  String radioRemovedDroneUncheckTo9fe8cb40(String arg0) {
    return 'Removed drone (#$arg0) — uncheck to continue';
  }

  @override
  String get radioSystemCategorycc8be0ee => 'System category';

  @override
  String get radioThisEquipmentProfileNo59977e24 =>
      'This equipment profile no longer exists.';

  @override
  String get radioUnableToLoadEquipment2a0842d8 =>
      'Unable to load equipment profiles.';

  @override
  String get radioUnableToLoadThise6da0797 =>
      'Unable to load this equipment profile.';

  @override
  String get routesAboveTerrainAgle2867f26 => 'Above terrain (AGL)';

  @override
  String get routesAirspeedMSPower705d4a92 => 'Airspeed (m/s); power (W)';

  @override
  String get routesApplyEquipmente3cb5483 => 'Apply equipment';

  @override
  String get routesApplyHeightAndSpeed4746e071 =>
      'Apply height and speed to all waypoints';

  @override
  String get routesApplyPlanningAssumptions8576b420 =>
      'Apply planning assumptions';

  @override
  String get routesApplyRouteConstraintsf13386d6 => 'Apply route constraints';

  @override
  String get routesApplyWaypointSettingsd66af84a => 'Apply waypoint settings';

  @override
  String get routesApproximateDroneRadiuse7919b03 => 'Approximate drone radius';

  @override
  String get routesApproximateGreatCircleDistances9807e68d =>
      'Approximate great-circle distances. Recorded segment times are used when available; modeled times ignore gusts and manoeuvres. Confirm the drone can achieve the required speed and climb rate.';

  @override
  String get routesAssignAnIndividualBatteryb5d65676 =>
      'Assign an individual battery in Route equipment to compare capacity and reserve. Capacities of alternative packs are never added.';

  @override
  String get routesBackb52b36b7 => 'Back';

  @override
  String get routesBatteriesAreAlternativePackse90e4726 =>
      'Batteries are alternative packs for one flight. Their capacities are assessed individually.';

  @override
  String get routesBatteryToInspectAnde2d405d0 =>
      'Battery to inspect and highlight';

  @override
  String routesBazlFocaPublishedRetrievedede87b71(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'BAZL / FOCA · $arg0 · published $arg1 · retrieved $arg2';
  }

  @override
  String routesBufferMSelectedCategories6b55c391(String arg0, String arg1) {
    return 'Buffer $arg0 m · selected categories: $arg1';
  }

  @override
  String get routesBvlosPlannedVerifyThe1d105130 =>
      'BVLOS planned: verify the required operating category and authorisation with FOCA.';

  @override
  String get routesCalculateCurrentRoutea1896281 => 'Calculate current route';

  @override
  String get routesCalculatingRoute9e861349 => 'Calculating route…';

  @override
  String get routesCancelChecks480fd8da => 'Cancel checks';

  @override
  String get routesCancelMove23385b79 => 'Cancel move';

  @override
  String get routesCheckCurrentRoute87fb7469 => 'Check current route';

  @override
  String get routesCheckRouteAirspaced4d383e6 => 'Check route airspace';

  @override
  String get routesChecking820d6004 => 'Checking…';

  @override
  String get routesChooseASpotToc0d9ecad =>
      'Choose a spot to add the first waypoint at its saved coordinates.';

  @override
  String get routesClearanceIsIncompleteSet1a518685 =>
      'Clearance is incomplete: set a height for every waypoint. Absolute heights need WGS84 ellipsoid reference; other datums cannot be converted here.';

  @override
  String get routesClickTheNewPosition88166db4 =>
      'Click the new position on the map.';

  @override
  String get routesCloseAnalysis232a00e4 => 'Close analysis';

  @override
  String get routesConfigureConstraintsf3a3a710 => 'Configure constraints';

  @override
  String get routesConfiguredHeightsAreShowna9eb24e8 =>
      'Configured heights are shown in 3D. Points marked * use a 30 m AGL preview because their height is missing or uses an unsupported datum. Selected routes stay visible in ground view.';

  @override
  String routesConfiguredLegalCeilingMe4d4520c(String arg0, String arg1) {
    return 'Configured legal ceiling: $arg0 m AGL · operational ceiling: $arg1 m AGL';
  }

  @override
  String get routesCopyAvailableDroneValues12ac7ef8 =>
      'Copy available drone values for review';

  @override
  String get routesCreateBatteryProfilesIn4e35a626 =>
      'Create battery profiles in Equipment first.';

  @override
  String routesCriticalConservativeSegmentsfecdcba2(String arg0) {
    return 'Critical conservative segments: $arg0';
  }

  @override
  String get routesCurveSourceMeasurementConditions241dc3af =>
      'Curve source / measurement conditions';

  @override
  String get routesDInfrastructureClearanceAdvisory02222668 =>
      '3D Infrastructure Clearance (advisory)';

  @override
  String get routesDRoutePreviewIs18af1855 =>
      '3D route preview is hidden until detailed terrain is available.';

  @override
  String get routesDeletePoint24dc6e65 => 'Delete point';

  @override
  String get routesDiscardRouteChanges71a9dbd8 => 'Discard route changes?';

  @override
  String get routesEditPlanningAssumptions84735a68 =>
      'Edit planning assumptions';

  @override
  String get routesEmptyMeansUnknownApplies42bd9aa3 =>
      'Empty means unknown. Applies to the next segment.';

  @override
  String get routesEmptyMeansUnverifiedNotb3d057c4 =>
      'Empty means unverified / not configured.';

  @override
  String routesExaminedUpToModel89dfac48(String arg0, String arg1) {
    return 'Examined up to $arg0 model samples; $arg1 unknown-altitude probes.';
  }

  @override
  String routesExport98e40159(String arg0) {
    return 'Export $arg0';
  }

  @override
  String get routesExportGeojsonbdc0686f => 'Export GeoJSON';

  @override
  String get routesExportGpxed2fd89b => 'Export GPX';

  @override
  String get routesFertig708ad54e => 'Done';

  @override
  String get routesFilterSavedSpotsf0054cfd => 'Filter saved spots';

  @override
  String get routesFlightRoutescf03df8f => 'Flight routes';

  @override
  String get routesFpvWithObserver0eb784aa => 'FPV with observer';

  @override
  String get routesHeightConstraintseeba8204 => 'Height constraints';

  @override
  String get routesHeightNotSpecifiedfec716ae => 'Height not specified';

  @override
  String get routesHeightReferenceec9764fc => 'Height reference';

  @override
  String get routesHeightSpeedd20ac922 => 'Height & speed';

  @override
  String routesHorizontalDAirspeedMeb450600(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
    String arg6,
    String arg7,
  ) {
    return '$arg0 horizontal · $arg1 3D\nAirspeed $arg2 m/s ($arg3) · $arg4 ($arg5) · clearance $arg6\nGroundspeed: $arg7 m/s (simulated)';
  }

  @override
  String get routesHorizontalObstacleProximityb3d4572a =>
      'Horizontal obstacle proximity';

  @override
  String get routesImportLocalBridgeSupport8cc6480f =>
      'Import local bridge/support geometry (JSON)';

  @override
  String routesImportRoutes1b71c46b(String arg0) {
    return 'Import $arg0 routes?';
  }

  @override
  String get routesImportRoutesbbcd66ff => 'Import routes';

  @override
  String get routesIncludeReturnToTakeoff90a464ac =>
      'Include return to takeoff';

  @override
  String get routesIncludeSteadyWind4a449918 => 'Include steady wind';

  @override
  String routesInfrastructureImportFailed68671f9d(String arg0) {
    return 'Infrastructure import failed: $arg0';
  }

  @override
  String get routesKeepEditingd4d9e382 => 'Keep editing';

  @override
  String get routesLevelFlightPowerCurve5cf82060 => 'Level-flight power curve';

  @override
  String routesLocalBridgeSupportSurfacesc5994174(String arg0) {
    return 'Local bridge/support surfaces: $arg0. Imported dimensions are not independently verified.';
  }

  @override
  String get routesLocalGeometryLoadedRe52972d93 =>
      'Local geometry loaded. Re-run Check current route. Source claims remain unverified.';

  @override
  String get routesMAglPreviewOnly1b6aeb60 => '* = 30 m AGL preview only';

  @override
  String get routesManualVerificationRequireda6416489 =>
      'Manual verification required';

  @override
  String get routesMapCommandFailedPleasea043b9a7 =>
      'Map command failed. Please retry.';

  @override
  String get routesMovePoint4cfb85e2 => 'Move point';

  @override
  String get routesNewLocalCopiesArec3efa17b =>
      'New local copies are created. Existing routes and equipment assignments are preserved.';

  @override
  String get routesNewRoutef39fa269 => 'New route';

  @override
  String get routesNoConfiguredLimitExceedance5e7f8c0c =>
      'No configured limit exceedance detected in the evaluated inputs.';

  @override
  String get routesNoConflictFoundIn4baaf950 =>
      'No conflict found in the available local models. Infrastructure clearance remains unassessed elsewhere.';

  @override
  String get routesNoCurrentInfrastructureAssessmentc3d9ef92 =>
      'No current infrastructure assessment. Use Check current route.';

  @override
  String get routesNoDroneAssigned1a3203b5 => 'No drone assigned';

  @override
  String get routesNoHorizontalMatchIne04da067 =>
      'No horizontal match in the checked dataset. Unrestricted airspace is not established.';

  @override
  String get routesNoMatchingSavedSpots783f2c6f => 'No matching saved spots.';

  @override
  String get routesNoProximityDetectedIn75f77f3a =>
      'No proximity detected in the evaluated data. This does not establish an obstacle-free route.';

  @override
  String get routesNoSavedFlightRoutesa271a04f =>
      'No saved flight routes yet. Create a route and place waypoints on the map.';

  @override
  String get routesNoSavedRoutesCreateca237d75 =>
      'No saved routes. Create one in Flight routes.';

  @override
  String get routesNoSavedSpotsYet044a3542 =>
      'No saved spots yet. Use the place search or tap the map.';

  @override
  String get routesOfficialFocaFlightRulesa3ad892e =>
      'Official FOCA flight rules';

  @override
  String get routesOptInOnlyAvailable291368ee =>
      'Opt-in. Only available local surface geometry is inspected; 3D Tiles alone do not prove clearance.';

  @override
  String routesOptimisticConservativeReserveOf8919c819(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Optimistic ×$arg0 · conservative ×$arg1 · reserve $arg2% of nominal capacity.';
  }

  @override
  String get routesOutgoingAirspeedMS43d6115b => 'Outgoing airspeed (m/s)';

  @override
  String get routesPlannedVisibilityScenario8c3dd9f7 =>
      'Planned visibility scenario';

  @override
  String get routesPlanningAssumptions61ebf317 => 'Planning assumptions';

  @override
  String routesPowerCurveSource26cb2f6e(String arg0) {
    return 'Power curve source: $arg0';
  }

  @override
  String get routesPowerIsInterpolatedBy90df4a57 =>
      'Power is interpolated by airspeed and scaled by (takeoff mass / reference mass)^1.5. Climb adds m·g·height / efficiency. Descent does not recover energy. This assumes multirotor-like behaviour.';

  @override
  String get routesProcessingLimitReachedThe59278caf =>
      'Processing limit reached. The assessment or result list is incomplete.';

  @override
  String routesPublishedCoverageIsIncomplete8fda9cde(String arg0) {
    return 'Published coverage is incomplete. $arg0 unsupported source records. Missing objects and cables may exist; category filters exclude other objects.';
  }

  @override
  String get routesRecalculateRoute3aa2250f => 'Recalculate route';

  @override
  String routesRecordedChargePackStatus6e905850(String arg0, String arg1) {
    return 'Recorded charge: $arg0% · pack status: $arg1.';
  }

  @override
  String get routesRecordingDetailsUnavailable028143fa =>
      'Recording details unavailable';

  @override
  String get routesRedSegmentsTerrainReservefbd059b9 =>
      'Red segments: terrain / reserve estimates · Open analysis';

  @override
  String get routesReplacesExistingHeightAndbb3345ca =>
      'Replaces existing height and speed settings for this draft. Undo is available.';

  @override
  String get routesReserveAndUncertainty53aafdf4 => 'Reserve and uncertainty';

  @override
  String routesRetrieved06b37dcd(String arg0, String arg1, String arg2) {
    return '$arg0 · $arg1 · retrieved $arg2';
  }

  @override
  String get routesRetryLoading54b15f12 => 'Retry loading';

  @override
  String get routesRetryRouteListd4c0bbae => 'Retry route list';

  @override
  String get routesRetryRoutePreview25273ee7 => 'Retry route preview';

  @override
  String get routesReturnEnergyIsUnknownb2869d98 =>
      'Return energy is unknown; no complete feasibility estimate is available.';

  @override
  String get routesReturnFlightIsExcluded22c87afc =>
      'Return flight is excluded from the budget.';

  @override
  String get routesReviewCoordinatesAndHeight88280ee0 =>
      'Review coordinates and height references before planning a flight.';

  @override
  String get routesRouteAnalysise04589ed => 'Route analysis';

  @override
  String get routesRouteConstraints7de90cfc => 'Route constraints';

  @override
  String get routesRouteEditor9c06eac0 => 'Route editor';

  @override
  String get routesRouteEquipmentc4206690 => 'Route equipment';

  @override
  String get routesRouteOptions55d80b02 => 'Route options';

  @override
  String get routesRouteSavedLocally324d209a => 'Route saved locally';

  @override
  String routesSMah1c86b217(String arg0, String arg1, String arg2) {
    return '$arg0 · $arg1 mAh · $arg2';
  }

  @override
  String routesSamplesHaveUnknownClearance53029fc6(String arg0) {
    return '$arg0 samples have unknown clearance; intermediate height limits remain unassessed.';
  }

  @override
  String get routesSavedc0ae8f6e => 'Saved';

  @override
  String get routesSearchPlace48c850ed => 'Search place';

  @override
  String routesSegment2e9d80c3(String arg0) {
    return '$arg0 segment';
  }

  @override
  String routesSegmentMHorizontalSource0f6d6b0d(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
  ) {
    return 'Segment $arg0 · $arg1 m horizontal\n$arg2\nSource ID: $arg3$arg4';
  }

  @override
  String routesSegmentSimulatedSeparationM10cc26fd(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
  ) {
    return 'Segment $arg0 · simulated separation $arg1 m\n$arg2 · $arg3 · $arg4 / $arg5\nModel geometry only; not real-world flight clearance.';
  }

  @override
  String routesSegments5ae8cd98(String arg0, String arg1, String arg2) {
    return '$arg0 segments $arg1 $arg2';
  }

  @override
  String get routesShowDInfrastructureClearancedcae1002 =>
      'Show 3D Infrastructure Clearance findings on map';

  @override
  String get routesShowEntireRoute7e936417 => 'Show entire route';

  @override
  String routesShowOnMapa1a4e0a9(String arg0) {
    return 'Show $arg0 on map';
  }

  @override
  String routesSimulateFlight6c31fd20(String arg0) {
    return 'Simulate flight: $arg0';
  }

  @override
  String get routesSonnenUndMondzeit1999dfbc => 'Sun and moon time';

  @override
  String get routesSonnenUndMondzeitDer90b0d9c4 =>
      'Sun and moon time of the route';

  @override
  String routesSteadyWindAssumptionM2884cea1(String arg0, String arg1) {
    return 'Steady wind assumption: $arg0 m/s from $arg1° true. Crosswind compensation is included; an unachievable track remains unknown.';
  }

  @override
  String get routesStoredOnThisDevicece3661a2 => 'Stored on this device';

  @override
  String get routesTapMapToAdddf97da9f =>
      'Tap map to add · Select a waypoint to edit';

  @override
  String get routesTapTheProfileTo8cbd2ae2 =>
      'Tap the profile to inspect a sample. Planned altitude uses the primary colour; terrain uses grey.';

  @override
  String get routesTerrainAndPlannedAltitude8cc1136a =>
      'Terrain and planned altitude · WGS84 ellipsoid';

  @override
  String get routesTerrainClearanceRemainsUnknown8f8dbef8 =>
      'Terrain clearance remains unknown. The energy budget does not establish route safety.';

  @override
  String routesTerrainSamples14ad50c1(String arg0, String arg1) {
    return 'Terrain samples $arg0/$arg1';
  }

  @override
  String routesTerrainSamplingWgsEllipsoide722c804(String arg0) {
    return 'Terrain sampling: $arg0. WGS84 ellipsoid heights.';
  }

  @override
  String get routesTheAssignedDroneWas08ea7895 =>
      'The assigned drone was deleted. Choose another profile or clear the assignment.';

  @override
  String get routesTheCurrentDraftHas0d9d9939 =>
      'The current draft has unsaved changes.';

  @override
  String get routesTheLevelFlightPower308a2473 =>
      'The level-flight power curve is interpolated without extrapolation and scaled by mass^1.5. Climb work is added with the configured efficiency; descent has no energy recovery.';

  @override
  String get routesTheSameConfiguredTakeoff20e0843f =>
      'The same configured takeoff mass is used for alternative packs. Adjust it for the installed battery.';

  @override
  String get routesUasZoneIntersections5bc17c8d => 'UAS zone intersections';

  @override
  String get routesUnableToFrameThisbad8013a =>
      'Unable to frame this route. Please retry.';

  @override
  String get routesUnableToLoadSaved7cf6f705 =>
      'Unable to load saved spots. Retry';

  @override
  String get routesUnableToLoadSavedda813904 => 'Unable to load saved routes.';

  @override
  String get routesUndoWaypointChange8a12e7bc => 'Undo waypoint change';

  @override
  String get routesUnsaved2ab06e25 => 'Unsaved';

  @override
  String get routesUnverifiedeb27a190 => 'Unverified';

  @override
  String get routesVisibilityScenarioUnverifiedConfirmd7996cb0 =>
      'Visibility scenario unverified. Confirm VLOS/FPV observer requirements and any BVLOS authorisation.';

  @override
  String get routesVlosPlannedVerifyActual5fbdce06 =>
      'VLOS planned: verify actual visibility and surrounding airspace on site. A map radius does not establish VLOS.';

  @override
  String routesWaypoint2315aa1f(String arg0) {
    return 'Waypoint $arg0';
  }

  @override
  String get routesWaypointActionsf5f1d082 => 'Waypoint actions';

  @override
  String routesWaypointMS5220bb0f(String arg0, String arg1, String arg2) {
    return 'Waypoint $arg0 · $arg1 · $arg2 m/s';
  }

  @override
  String routesWaypoints31c92956(String arg0, String arg1) {
    return '$arg0 · $arg1 waypoints';
  }

  @override
  String get routesWaypoints8de9ac08 => 'Waypoints';

  @override
  String routesWaypointsbc27edbc(String arg0) {
    return '$arg0 waypoints';
  }

  @override
  String get routesWindIsExcludedEnablee95610f8 =>
      'Wind is excluded. Enable a manual wind assumption in Planning assumptions.';

  @override
  String get routesWirdMitDerRoutece20d1c9 =>
      'Saved with the route. A fixed time stops; \"Now\" runs with the device time.';

  @override
  String get settingsEinstellungKonnteNichtUebernommenf7be0131 =>
      'Could not apply the setting. Try again.';

  @override
  String get settingsFlugsimulatorControllerb56cd9ea =>
      'Flight simulator & controller';

  @override
  String get settingsFuerDieNaechsteSimulationfde989c1 =>
      'For the next simulation';

  @override
  String get settingsHilfeb74af50b => 'Help';

  @override
  String get settingsKarteneinstellungenZuruecksetzen65775760 =>
      'Reset Map Settings';

  @override
  String get settingsLuftraumquellene57512f8 => 'Airspace sources';

  @override
  String get settingsOfflineKartenDatenefa573cc => 'Offline maps & data';

  @override
  String get settingsOpenSourceLizenzen225c9494 => 'Open source licenses';

  @override
  String get settingsPrivacyPolicy7ceacdca => 'Privacy policy';

  @override
  String get settingsSprache3d9f5cb4 => 'Language';

  @override
  String get settingsStandortanzeige3f41a9ee => 'Location display';

  @override
  String get settingsTouchSteuerungAnzeigen41a3a9f0 => 'Show touch controls';

  @override
  String get settingsVerkehrZugaenge27db3ea6 => 'Traffic & access';

  @override
  String get settingsWetteranbietera62920c2 => 'Weather providers';

  @override
  String get signalAnalyzeAppliesInputsSave2af97340 =>
      'Analyze applies inputs; Save the route to keep them';

  @override
  String get signalAnalyzeRadioPathsf3709ab3 => 'Analyze radio paths';

  @override
  String get signalApplyRadioPreview1e94fdf7 => 'Apply radio preview';

  @override
  String get signalCancelAnalysisdf18d195 => 'Cancel analysis';

  @override
  String get signalClearObservationsc6114e52 => 'Clear observations';

  @override
  String get signalCloseSignalAnalysisad376625 => 'Close signal analysis';

  @override
  String get signalCurrentFlightLaunchPointb1e984c0 =>
      'Current flight launch point';

  @override
  String get signalEnableLiveRadioPreview96c70f99 =>
      'Enable live radio preview';

  @override
  String get signalFixedSpotCoordinatese71de0f9 => 'Fixed spot / coordinates';

  @override
  String get signalImportSurfaceCsv07954aaf => 'Import surface CSV';

  @override
  String signalImportedObservations6dc74f21(String arg0) {
    return '$arg0 imported observations';
  }

  @override
  String get signalIncludeImportedObservations2e110738 =>
      'Include imported observations';

  @override
  String get signalIncludeImportedSurfaceObservations3dc9dc80 =>
      'Include imported surface observations';

  @override
  String get signalInspectCommunicationPath2fdd77fe =>
      'Inspect communication path';

  @override
  String signalLastCompletedProfileaec2638b(String arg0, String arg1) {
    return 'Last completed profile: $arg0 · $arg1';
  }

  @override
  String get signalLatitudeWgsd5f5cf6c => 'Latitude · WGS84';

  @override
  String get signalLiveRadioLineOfb3b60fda => 'Live radio line of sight';

  @override
  String signalLocalObservationsb6dacb84(String arg0, String arg1) {
    return '$arg0 local observations · $arg1';
  }

  @override
  String get signalLocalSurfaceObservations5f83fa58 =>
      'Local surface observations';

  @override
  String get signalLongitudeWgs63c0ff8c => 'Longitude · WGS84';

  @override
  String signalMAglMRadiuscfb648b3(String arg0, String arg1, String arg2) {
    return '$arg0 · $arg1 m AGL · $arg2 m radius';
  }

  @override
  String signalMapTargetsOf0a2ebaa0(String arg0, String arg1, String arg2) {
    return 'Map targets $arg0–$arg1 of $arg2';
  }

  @override
  String signalMinimumConfiguredFresnelMargin119fbdcf(String arg0) {
    return 'Minimum configured Fresnel margin: $arg0 m';
  }

  @override
  String signalMinimumSampledGeometricClearancecf242d36(String arg0) {
    return 'Minimum sampled geometric clearance: $arg0 m';
  }

  @override
  String signalMinimumSampledLosClearance8c03754f(String arg0) {
    return 'Minimum sampled LOS clearance: $arg0 m';
  }

  @override
  String get signalOptionalBuildingVegetationObservations7a6fce33 =>
      'Optional building / vegetation observations';

  @override
  String get signalPeriodicGeometricPreviewBetweenb75cb376 =>
      'Periodic geometric preview between the transmitter and the simulated drone. This is not measured signal quality or a guaranteed communication range.';

  @override
  String get signalPilotFrequency12dc826d => 'Pilot & frequency';

  @override
  String get signalProfileBrownTerrainSurface4924cb6b =>
      'Profile: brown terrain/surface · cyan LOS · purple lower Fresnel boundary. Heights in WGS84 ellipsoid.';

  @override
  String get signalRadioLineOfSight3d11d898 => 'Radio line of sight';

  @override
  String get signalRemoveObservationsa17d9d68 => 'Remove observations';

  @override
  String signalRouteTargetsCheckedf545b613(String arg0, String arg1) {
    return '$arg0 / $arg1 route targets checked';
  }

  @override
  String signalRouteTargetsTerraind0166c82(String arg0, String arg1) {
    return '$arg0 route targets · terrain: $arg1';
  }

  @override
  String get signalSamplingAndLimits81b895c4 => 'Sampling and limits';

  @override
  String get signalSelectedMapPoint1717e7f7 => 'Selected map point';

  @override
  String get signalSwisstopoTerrainViaCesium5961555e =>
      'swisstopo terrain via Cesium · fixed terrain level 12 · profile points at most 25 m apart · live range 1 m–6 km. A new profile is attempted at most every 2 seconds. Sample heights may be reused for up to 30 seconds. Narrow or finer terrain features may be missed.';

  @override
  String get signalTransmitterHeightIsAboveb50b536b =>
      'Transmitter height is above sampled terrain. The receiving endpoint is the drone’s simulated WGS84 ellipsoidal height.';

  @override
  String get signalTransmitterPositiond87196e3 => 'Transmitter position';

  @override
  String get simulationAcroDrehratenf7001f19 => 'Acro rotation rates';

  @override
  String get simulationAcroFreieDrehratena37d7b4c =>
      'Acro · direct rate control';

  @override
  String get simulationAcroHatKeineSelbststabilisierung83a2e981 =>
      'Acro has no self-stabilization or elevation. Push follows the drone position; low thrust lets it fall free.';

  @override
  String get simulationAcroPhysikdf296beb => 'Acro physics';

  @override
  String get simulationAglFollowsTheTerrain71243353 =>
      'AGL follows the terrain between waypoints and may differ from the recorded absolute trajectory.';

  @override
  String get simulationAkkuprofilf5c68edf => 'Battery profile';

  @override
  String get simulationAngleSelbststabilisierenddb3cdc71 =>
      'Angle · Self-stabilizing';

  @override
  String get simulationAngleStabilisiertDieLage73f2f597 =>
      'Angle stabilizes the position and limits the inclination to 50°. More gas is needed to hold the height when tilting.';

  @override
  String get simulationBalanced03342dbb => 'Balanced';

  @override
  String get simulationBasedOnTerrainLoaded058810aa =>
      'Based on terrain loaded during recording.';

  @override
  String get simulationBetaflightaaa2dc4d => 'Betaflight';

  @override
  String get simulationCompatibility5d60c7dd => 'Compatibility';

  @override
  String get simulationContinuousSection1042d718 => 'Continuous section';

  @override
  String get simulationControllera36a5ffa => 'Controller';

  @override
  String get simulationControllertyp247db158 => 'Controller type';

  @override
  String get simulationDieNiedrigeZellspannungMuss653c3f34 =>
      'Low voltage warning must be above the critical cell voltage.';

  @override
  String get simulationDiscard36fff63c => 'Discard';

  @override
  String get simulationDiscardRecording76dde3d6 => 'Discard recording?';

  @override
  String get simulationDrohnenprofil2c80fbb6 => 'Drone profile';

  @override
  String get simulationDrohnenprofileUebernehmenGeschwindigkeitUndb7b1010f =>
      'Drone profiles provide the speed and climb rate for Angle and GPS modes. Acro physics and acceleration use estimated model values. Camera settings affect the view.';

  @override
  String get simulationFlugEinstellenf142a101 => 'Flight settings';

  @override
  String get simulationFlugStarten8846a2e4 => 'Take off flight';

  @override
  String get simulationFlugeinstellungenSchliessen974d8874 =>
      'Close flight settings';

  @override
  String get simulationFlugmodus699cac43 => 'Flight mode';

  @override
  String get simulationFlugsimulatore761527e => 'Flight simulator';

  @override
  String get simulationGamepad4dde0030 => 'Gamepad';

  @override
  String get simulationGasNullMitte62e44939 => 'Gas zero: middle (50%)';

  @override
  String get simulationGasNullUntenc2617787 => 'Gas zero: lower (0%)';

  @override
  String get simulationGasNullstellungd92cd012 => 'Zero-throttle position';

  @override
  String get simulationGelaendeUndUnterstuetzteModellflaechen2d8c2c0b =>
      'Terrain and supported model surfaces can stop movement. Obstacle and collision coverage is incomplete. Use the simulator only for simulated flight.';

  @override
  String get simulationGeschaetzteAkkuspannungAnzeigen3fc4417b =>
      'Show estimated battery voltage';

  @override
  String simulationGeschaetztesHorizontaltempoBeiVollgasbf685b25(String arg0) {
    return 'Estimated level speed at full throttle: $arg0 km/h. Higher drag lowers this speed. A dive can exceed it.';
  }

  @override
  String get simulationGoggles0b34f86f => 'Goggles';

  @override
  String get simulationGpsBremstAutomatischLinker62b42159 =>
      'GPS brakes automatically. Left stick: movement; right stick: direction of view.';

  @override
  String get simulationGpsUnterstuetzt4fba7ae2 => 'GPS · supported';

  @override
  String get simulationGrafikprofile6062f50 => 'Graphics profile';

  @override
  String get simulationGueltigeSchubUndWiderstandswerted87ecf7c =>
      'Enter valid thrust and drag values.';

  @override
  String get simulationGueltigeSchubwerteFuerDie9f739082 =>
      'Enter valid thrust values to estimate hover throttle.';

  @override
  String get simulationHudStil9e126e51 => 'HUD style';

  @override
  String simulationKanale8c667fd(String arg0) {
    return 'Channel $arg0';
  }

  @override
  String get simulationKeepAllSamples1900da8c => 'Keep all samples';

  @override
  String get simulationKeepForLatera212630b => 'Keep for later';

  @override
  String get simulationKeepRecording77ccc1b0 => 'Keep recording';

  @override
  String get simulationKeinAkkuAusgewaehltce2c46d1 => 'No battery selected';

  @override
  String get simulationKeineAutomatischeAufzeichnungOder98df029c =>
      'No automatic recording or export. Online map and site calls transmit the area considered to the providers.';

  @override
  String get simulationKoordinatenImHudAnzeigen5180787d =>
      'Show coordinates in HUD';

  @override
  String simulationMInD2d9450e4(String arg0) {
    return '$arg0 in 3D';
  }

  @override
  String simulationMInDSeefbaac5(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0 m in 3D · $arg1 s · $arg2 samples → $arg3 waypoints';
  }

  @override
  String get simulationManuelleWerte24267a01 => 'Manual values';

  @override
  String get simulationMaximumSimplificationDeviationd255b933 =>
      'Maximum simplification deviation';

  @override
  String get simulationMitteGamepad3ed3bc49 => '50% · middle (Gamepad)';

  @override
  String get simulationMoreThanWaypointsIncrease766de83d =>
      'More than 1000 waypoints: increase simplification or trim the section.';

  @override
  String get simulationPerformance63c90455 => 'Performance';

  @override
  String get simulationQualitya60f2c73 => 'Quality';

  @override
  String get simulationRecordOrSelectAt4a275e16 =>
      'Record or select at least two positions with movement.';

  @override
  String simulationRecordedGroundSpeedTerrainb2579dd6(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Recorded ground speed: $arg0 · Terrain samples: $arg1/$arg2';
  }

  @override
  String get simulationReviewSimulatedFlight21515c9f =>
      'Review simulated flight';

  @override
  String get simulationSaveAContinuousSectionead8234c =>
      'Save a continuous section as a new planning route. Unsaved recordings are lost when closing the app.';

  @override
  String get simulationSaveAsRouteb13386ba => 'Save as route';

  @override
  String get simulationSavedHeightReferenceWgs6f44e746 =>
      'Saved height reference: WGS84 ellipsoid. Recorded absolute heights are preserved.';

  @override
  String simulationSchwebeschaetzungGas487da692(String arg0) {
    return 'Estimated hover throttle: $arg0%';
  }

  @override
  String simulationSectionSamplesb76afcf0(String arg0, String arg1) {
    return 'Section $arg0 · $arg1 samples';
  }

  @override
  String get simulationSimulationKeineRealenFlugeigenschaften596363e0 =>
      'Simulation · no real flight characteristics';

  @override
  String get simulationStartAmMarkiertenPunktded1ae8f =>
      'Start at the marked point.';

  @override
  String get simulationStartUnterDerKartenmitted55a2a7c =>
      'Start under the center of the card.';

  @override
  String get simulationTheUnsavedSimulatedFlight363d0ff5 =>
      'The unsaved simulated flight will be removed.';

  @override
  String get simulationTrackNorthProfileHeight13701f87 =>
      'Track: north ↑ · Profile: height in metres';

  @override
  String simulationTrimSectionSamples9e88a826(String arg0, String arg1) {
    return 'Trim section · samples $arg0–$arg1';
  }

  @override
  String get simulationUbernehmen59430842 => 'Apply';

  @override
  String get simulationUmkehren1e1918e6 => 'Reverse';

  @override
  String simulationUmkehren7b06e49a(String arg0) {
    return 'Reverse $arg0';
  }

  @override
  String get simulationUnavailableTerrainHeightIs1122a292 =>
      'Unavailable: terrain height is missing for part of this section.';

  @override
  String get simulationUntenFernsteuerungb976566f =>
      '0 % · bottom (remote control)';

  @override
  String get simulationUsbFernsteuerungdab5ef74 => 'USB remote control';

  @override
  String get simulationUseHeightAboveTerrain0cc4fd11 =>
      'Use height above terrain (AGL)';

  @override
  String simulationUtcStartPerPoint7a1f6f82(String arg0) {
    return 'UTC start: $arg0 · Per-point elapsed time retained';
  }

  @override
  String simulationWertVonBisEingeben87edf0e9(String arg0, String arg1) {
    return 'Enter a value from $arg0 to $arg1.';
  }

  @override
  String get simulationZellspannungZusaetzlichAnzeigenb25b8602 =>
      'Show per-cell voltage';

  @override
  String get simulationZumVerbindenOderFortsetzenb43ff5ab =>
      'To connect or resume gas to zero and center the remaining sticks. R / Controller A resets; Escape / B terminates the flight. A mode change restarts at the starting point.';

  @override
  String get spotsAddFavorite4914d44e => 'Add favorite';

  @override
  String get spotsAddPhotod1434930 => 'Add photo';

  @override
  String get spotsAddSpot7e93bac9 => 'Add Spot';

  @override
  String get spotsAddTestSpotd92ef505 => 'Add Test Spot';

  @override
  String spotsAlleSpotsGeladen5c20251b(String arg0) {
    return 'All $arg0 spots loaded.';
  }

  @override
  String get spotsApplycfea419c => 'Apply';

  @override
  String spotsCategoriesTags7627b3f2(String arg0) {
    return 'Categories / tags$arg0';
  }

  @override
  String get spotsCategorya3c686e7 => 'Category';

  @override
  String spotsCategorybe4f88dd(String arg0) {
    return 'Category: $arg0';
  }

  @override
  String get spotsClearFilters41222671 => 'Clear filters';

  @override
  String get spotsClearSearch67300d0f => 'Clear search';

  @override
  String spotsDatabaseErrora227b5c8(String arg0) {
    return 'Database error: $arg0';
  }

  @override
  String spotsDeleteFailedfc2c6c69(String arg0) {
    return 'Delete failed: $arg0';
  }

  @override
  String get spotsDeleteSpot17e145be => 'Delete spot?';

  @override
  String get spotsDescriptionNotesOptionalcfd33085 =>
      'Description / notes (optional)';

  @override
  String get spotsDrivingRoute9ffe00fc => 'Driving route';

  @override
  String get spotsEdit5301648d => 'Edit';

  @override
  String get spotsEditSpot082811c9 => 'Edit Spot';

  @override
  String get spotsLatitudeWgs060b3235 => 'Latitude (WGS84)';

  @override
  String get spotsLocalStorageTest1337323b => 'Local Storage Test';

  @override
  String get spotsLocatinge46bab00 => 'Locating…';

  @override
  String get spotsLongitudeWgs39118820 => 'Longitude (WGS84)';

  @override
  String get spotsMatchesTheCategoryAnd2b0693e2 =>
      'Matches the category and every selected tag. Search and favorites also apply.';

  @override
  String get spotsNoDescriptionAdded0dc3dae3 => 'No description added.';

  @override
  String get spotsNoPhotosYetEdit1cb7ab6f =>
      'No photos yet. Edit this spot to add photos.';

  @override
  String get spotsNoSpotsFoundAdd55a4157e =>
      'No spots found. Add a spot or adjust your filters.';

  @override
  String get spotsNoSpotsSavedYet3b576669 =>
      'No spots saved yet.\nAdd a test spot to verify persistence.';

  @override
  String get spotsOpenSpotPhoto9410015a => 'Open spot photo';

  @override
  String spotsOpenstreetmapSource9af4238e(String arg0) {
    return 'OpenStreetMap source: $arg0';
  }

  @override
  String get spotsOptionalUpToCharactersbcc00326 =>
      'Optional · up to 40 characters';

  @override
  String get spotsOriginalOsmSourceReferenceebdb9f0a =>
      'Original OSM source reference is kept separately from personal edits.';

  @override
  String spotsPermanentlyDeleteAndIts798ab781(String arg0) {
    return 'Permanently delete \"$arg0\" and its photos?';
  }

  @override
  String spotsPhotosa324a5d2(String arg0) {
    return 'Photos: $arg0';
  }

  @override
  String spotsPhotosc4363ac9(String arg0, String arg1) {
    return 'Photos ($arg0/$arg1)';
  }

  @override
  String get spotsRemoveFavorite8b9da771 => 'Remove favorite';

  @override
  String spotsRemovePhoto67e118ac(String arg0) {
    return 'Remove photo $arg0';
  }

  @override
  String get spotsRetryLoadingPhotos2e5d214a => 'Retry loading photos';

  @override
  String get spotsSavedSpotPhoto279ddf6a => 'Saved spot photo';

  @override
  String get spotsSearchSpotsd3145737 => 'Search spots';

  @override
  String get spotsShowOnMap5ed4f4c1 => 'Show on map';

  @override
  String get spotsSpotDetailse32d6442 => 'Spot details';

  @override
  String get spotsSpotName811bf0db => 'Spot name';

  @override
  String get spotsSpotPhoto590ebf66 => 'Spot photo';

  @override
  String get spotsThisPhotoIsNo08b26948 => 'This photo is no longer available.';

  @override
  String get spotsThisSpotNoLongeraffbf566 => 'This spot no longer exists.';

  @override
  String get spotsUnableToDisplayThis38f897ec =>
      'Unable to display this photo.';

  @override
  String get spotsUnableToLoadPhotos634c2fc3 =>
      'Unable to load photos. Close this window and try again.';

  @override
  String get spotsUnableToLoadSpot827d0e55 => 'Unable to load spot details.';

  @override
  String get spotsUnableToLoadThisc9e4faa4 => 'Unable to load this photo.';

  @override
  String get spotsUnableToUpdateFavorite3001cf8d =>
      'Unable to update favorite. Please retry.';

  @override
  String get spotsUseCurrentLocation622c745f => 'Use current location';

  @override
  String get spotsWeitereSpotsWerdenBeim1f25ff94 =>
      'More spots are loaded while scrolling.';

  @override
  String get telemetryApplyRouteCalibration5c654485 =>
      'Apply route calibration?';

  @override
  String get telemetryApplyToThisRoute1635cca9 => 'Apply to this route';

  @override
  String get telemetryApproximationForAStill90100705 =>
      'Approximation for a still-air recording only';

  @override
  String get telemetryDeleteLocalTelemetryfa6452e1 => 'Delete local telemetry';

  @override
  String get telemetryDeleteRawTelemetryad6e4046 => 'Delete raw telemetry?';

  @override
  String get telemetryDifferentDronesAreAssociated17ab6eae =>
      'Different drones are associated with the log and route. Calibration is disabled.';

  @override
  String get telemetryDurationIncludesAllRecordedb1545492 =>
      'Duration includes all recorded idle/hover time. Trim the log to one flight before importing.';

  @override
  String get telemetryFlightPlanForComparison6e3eb9d5 =>
      'Flight plan for comparison';

  @override
  String get telemetryImportOneContinuousFlight94f89be2 =>
      'Import one continuous flight. Raw CSV stays in the local database. No telemetry is uploaded.';

  @override
  String get telemetryImportTelemetryCsveb2d1023 => 'Import telemetry CSV';

  @override
  String get telemetryImportTelemetryLocallyf7626443 =>
      'Import telemetry locally?';

  @override
  String telemetryImportedbd3c3768(String arg0) {
    return 'Imported $arg0';
  }

  @override
  String get telemetryLocalTelemetryUnavailableReopencb8a0598 =>
      'Local telemetry unavailable. Reopen this screen to retry.';

  @override
  String telemetryMeasuredEnergyWhAverage9acf6860(String arg0, String arg1) {
    return 'Measured energy: $arg0 Wh · average power $arg1 W';
  }

  @override
  String telemetryMeasuredModeledWhae99a8d2(String arg0, String arg1) {
    return 'Measured − modeled: $arg0 Wh ($arg1%)';
  }

  @override
  String get telemetryModelComparisondaa80a44 => 'Model comparison';

  @override
  String telemetryModelEnergyOverRecorded6bf1955f(String arg0) {
    return 'Model energy over recorded speeds: $arg0 Wh';
  }

  @override
  String get telemetryNoAssociatedFlightPlan5a0a6161 =>
      'No associated flight plan is available. Associate a plan when importing to compare its model.';

  @override
  String get telemetryPreviewApplyCalibrationa8b7db04 =>
      'Preview & apply calibration';

  @override
  String telemetryRecordedDurationSe198ddeb(String arg0) {
    return 'Recorded duration: $arg0 s';
  }

  @override
  String get telemetryRouteComparisonUnavailableCheck13192917 =>
      'Route comparison unavailable. Check the saved route inputs.';

  @override
  String get telemetryRouteComparisonsAssumeThed64d19cc =>
      'Route comparisons assume the recording covers the same outbound path. Return flights and idle time are not automatically removed.';

  @override
  String telemetrySamples49577d36(String arg0, String arg1) {
    return '$arg0 · $arg1 samples';
  }

  @override
  String telemetrySavedOutboundRouteDuration18b87ca4(String arg0) {
    return 'Saved outbound route duration: $arg0';
  }

  @override
  String telemetrySavedOutboundRouteMean0818ac58(String arg0, String arg1) {
    return 'Saved outbound route mean $arg0 speed: $arg1';
  }

  @override
  String get telemetrySupportedFormatsdf1bdc5f => 'Supported formats';

  @override
  String telemetryTelemetry9ac39ce5(String arg0) {
    return 'Telemetry: $arg0';
  }

  @override
  String get telemetryTheRoutePowerCurvee9b27f2a =>
      'The route power curve is evaluated at every recorded speed with its mass correction. Energy uses trapezoidal integration of voltage × current. No climb or maneuver correction is inferred.';

  @override
  String get telemetryUnassignede57016ed => 'Unassigned';

  @override
  String get telemetryUseGroundSpeedAs5bb04e27 =>
      'Use ground speed as airspeed';

  @override
  String get weatherAbgelaufenPfeileUndWindeinfluss1572fe42 =>
      'Expired: Arrows and wind influence are exposed.';

  @override
  String weatherAbgerufenRasterpunkte7532c53d(String arg0, String arg1) {
    return 'Retrieved: $arg0 · $arg1/9 Grid points';
  }

  @override
  String get weatherActiveForecastProvider589a3851 =>
      'Active forecast provider';

  @override
  String get weatherAktuellerModellwind402bf323 => 'Current model wind';

  @override
  String get weatherAllComparisonResultsUse418051c7 =>
      'All comparison results use the selected provider and identical flight time and criteria; missing data never yields a positive result.';

  @override
  String get weatherAngleAcroAbdriftGps88b761bf =>
      'Angle/Acro: Drift. GPS: Restraint to power limit.';

  @override
  String get weatherAusschnittUmDenGewaehlten25af0329 =>
      'Section around the selected point';

  @override
  String get weatherAutomaticObservationsFromAnda1a45d31 =>
      'Automatic observations (from 2023) and historical manual measurements are separate methods. Historical/manual series are not loaded here.';

  @override
  String get weatherChooseASavedFlyingba7ecae9 =>
      'Choose a saved flying spot or a globe coordinate to inspect nearby monitoring stations.';

  @override
  String get weatherClearRadar66544d4d => 'Clear radar';

  @override
  String get weatherCompareSavedSpotsc7ce5e7e => 'Compare saved spots';

  @override
  String get weatherDPfeileAktivbfcd3c26 => 'Active 3D arrows';

  @override
  String get weatherDWindUndFlugwinda2d72644 => '3D wind and flying wind';

  @override
  String get weatherDWindUndPrognose6efb0829 => '3D wind and forecast';

  @override
  String get weatherDWindpfeileAnzeigenbc5f17dc => 'Show 3D Wind Arrows';

  @override
  String weatherDataState98888b0e(String arg0, String arg1, String arg2) {
    return 'Data state: $arg0$arg1$arg2';
  }

  @override
  String get weatherDatenUndGrenzen98079772 => 'Data and borders';

  @override
  String get weatherDiesenAusschnittAktualisierenf0435deb =>
      'Update this section';

  @override
  String get weatherDiesesRasterAusblendenc09fe0a2 => 'Hide this grid';

  @override
  String weatherDirection2373dfc9(String arg0) {
    return 'Direction $arg0';
  }

  @override
  String get weatherDiscoverPublishedRadarTimes9528700a =>
      'Discover published radar times';

  @override
  String weatherDownloadedUtc177de02a(String arg0) {
    return 'Downloaded: $arg0 UTC';
  }

  @override
  String get weatherDroneProfileUserThresholdsf3e5ce7b =>
      'Drone profile (user thresholds)';

  @override
  String get weatherEvaluateSavedSpotsbdd72b2d => 'Evaluate saved spots';

  @override
  String get weatherFindMonitoringStations4d511534 =>
      'Find monitoring stations';

  @override
  String get weatherForecastIssueTimeNot72c0daa9 =>
      'Forecast issue time: not supplied by provider';

  @override
  String weatherForecastIssued2ab834ac(String arg0) {
    return 'Forecast issued: $arg0';
  }

  @override
  String get weatherFpvSuitabilityThresholdsd468f61f =>
      'FPV suitability thresholds';

  @override
  String get weatherGemesseneWetterUndGewaesserstationen70b38f8d =>
      'Measured weather and water stations';

  @override
  String get weatherHourlyPrecipitationRefersTob7611db2 =>
      'Hourly precipitation refers to the preceding hour ending at the forecast timestamp.';

  @override
  String weatherIndependentOpenMeteoSamples4c5f32a2(String arg0) {
    return '$arg0 independent Open-Meteo samples shown on globe.';
  }

  @override
  String get weatherInspectHourlyObservationUtcae90e45a =>
      'Inspect hourly observation (UTC)';

  @override
  String get weatherInspectLocalTerrainc851b2af => 'Inspect local terrain';

  @override
  String get weatherKartenebeneKonnteNichtAktualisiertab47fc9e =>
      'Could not update map level. Please try again.';

  @override
  String get weatherKmLocal5e8c161b => '1 km local';

  @override
  String weatherLatestStationObservationHourly1d766dcb(
    String arg0,
    String arg1,
  ) {
    return 'Latest station observation: $arg0 · $arg1 · hourly average';
  }

  @override
  String get weatherLetzteAktualisierungFehlgeschlagenDie140dfc53 =>
      'Last update failed. The previous data will remain available until expiry.';

  @override
  String get weatherLoadHourlyObservations7bc23c4c =>
      'Load hourly observations';

  @override
  String get weatherLocalTerrainExposuref78de89b => 'Local terrain exposure';

  @override
  String weatherLocation77d72845(String arg0, String arg1) {
    return 'Location: $arg0$arg1';
  }

  @override
  String get weatherMeteoswissEDoesNota574859d =>
      'MeteoSwiss E4 does not provide this parameter.';

  @override
  String get weatherMeteoswissStationDetails565885c8 =>
      'MeteoSwiss station details';

  @override
  String get weatherNativeModelResolutionNot32f4a5e7 =>
      'Native model resolution: not supplied by this API response. The selected spacing only sets the display sample grid.';

  @override
  String weatherNearbyReliefMFrom3afbc3bf(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Nearby relief $arg0 m from $arg1 terrain samples. $arg2';
  }

  @override
  String get weatherNearestMonitoringStationb112be37 =>
      'Nearest monitoring station';

  @override
  String weatherNiederschlagf18088c2(String arg0) {
    return 'Precipitation $arg0';
  }

  @override
  String get weatherNoDroneProfilesSaved1b2919fa =>
      'No drone profiles saved; configure generic thresholds below.';

  @override
  String get weatherNoOfficialSeverityClasses2d4def34 =>
      'No official severity classes are inferred. Missing is not zero. Readings describe the monitoring station only.';

  @override
  String get weatherNoPublishedQualityFlag88577e1e =>
      'No published quality flag for this frame (quality unknown).';

  @override
  String get weatherNoSavedSpotSelected8861bd5c =>
      'No saved spot selected. Select a point on the globe or save a spot.';

  @override
  String get weatherNoValidAutomaticObservationse3251aaa =>
      'No valid automatic observations published in this file.';

  @override
  String weatherObserved6b54f9ec(String arg0, String arg1) {
    return 'Observed: $arg0 · $arg1';
  }

  @override
  String get weatherOfficialAirspaceVerification1376fb67 =>
      'Official airspace verification';

  @override
  String get weatherOfficialMeteoswissFilesAre0450722a =>
      'Official MeteoSwiss files are large; comparison is limited to 3 spots per request to reduce traffic.';

  @override
  String get weatherOfficialMeteoswissPollenStations0d04b249 =>
      'Official MeteoSwiss pollen stations';

  @override
  String get weatherOfficialMeteoswissPrecipitationRadar58cad390 =>
      'Official MeteoSwiss precipitation radar';

  @override
  String get weatherOptionalCesiumReliefCheckff9531d9 =>
      'Optional Cesium relief check within 300 m (centre and four neighbours). Not an aerodynamic turbulence model.';

  @override
  String get weatherOptionalWinddatenNochNicht638f2548 =>
      'Optional · Wind data not yet loaded';

  @override
  String get weatherPlannedFlightTimeLocal410bf657 =>
      'Planned flight time (local)';

  @override
  String get weatherPlayForward4b395db1 => 'Play forward';

  @override
  String weatherPrognoseAbgerufenFehlendeStichproben23fbbb89(
    String arg0,
    String arg1,
    String arg2,
  ) {
    return 'Forecast: $arg0 Retrieved: $arg1 · $arg2 missing samples';
  }

  @override
  String get weatherProviderTermsDataSource3870b023 =>
      'Provider terms / data source';

  @override
  String weatherPublishedCpcQualityFlagdf44398e(String arg0) {
    return 'Published CPC quality flag: $arg0/9';
  }

  @override
  String weatherPublishedFramesMaximumIrregular94a6ff40(String arg0) {
    return '$arg0 published frames (maximum 12). Irregular timestamp gaps are retained.';
  }

  @override
  String get weatherRadarProducte1ab732e => 'Radar product';

  @override
  String get weatherRasterAbgelaufenAufDer98608088 =>
      'Grid expired · hidden on the map';

  @override
  String get weatherRefreshForecastfe3dbc62 => 'Refresh forecast';

  @override
  String get weatherRefreshStationMetadataa5976bc4 =>
      'Refresh station metadata';

  @override
  String get weatherRequireVisibilityForecastc232c2a0 =>
      'Require visibility forecast';

  @override
  String weatherResolutiona39d34b8(String arg0) {
    return 'Resolution: $arg0';
  }

  @override
  String get weatherSavedFlyingSpotedf5fa9d => 'Saved flying spot';

  @override
  String weatherSelectedObservation26593d3f(String arg0) {
    return 'Selected observation: $arg0';
  }

  @override
  String get weatherShowOnGlobe8ee06550 => 'Show on globe';

  @override
  String get weatherShowSelectedFrame26955c78 => 'Show selected frame';

  @override
  String get weatherSourceMeteoswissFsdiStacb55f0dac =>
      'Source: MeteoSwiss · FSDI STAC · online HDF5/WASM · EPSG:2056. Radar can be unavailable on Web or Android if data or decoder access is blocked.';

  @override
  String get weatherSourcePublicationTimeNot23697f29 =>
      'Source publication time: not provided';

  @override
  String weatherSourceStacUpdateddde9e800(String arg0) {
    return 'Source STAC updated: $arg0';
  }

  @override
  String weatherStacUpdated73855d9d(String arg0) {
    return 'STAC updated: $arg0';
  }

  @override
  String get weatherStationDirectoryCachedLastf07e00ef =>
      'Station directory: cached; last metadata refresh failed (original publication time unavailable).';

  @override
  String get weatherStationDirectoryLocallyCached005bbea0 =>
      'Station directory: locally cached (original publication time unavailable).';

  @override
  String weatherStationDirectoryRetrieved72729476(String arg0) {
    return 'Station directory: retrieved $arg0';
  }

  @override
  String weatherTerrainAndLegalAirspacedb03e335(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  ) {
    return '$arg0\n$arg1\n$arg2\n$arg3 · Terrain and legal airspace not assessed.';
  }

  @override
  String weatherUnsupportedSourceParametersNot75db504a(String arg0) {
    return 'Unsupported source parameters not classified: $arg0';
  }

  @override
  String weatherVisibility1b929d6e(String arg0) {
    return 'Visibility $arg0';
  }

  @override
  String get weatherWeatherFpvSuitabilitye893355f =>
      'Weather & FPV suitability';

  @override
  String get weatherWeatherMapOpenMeteodb0c967f =>
      'Weather map (Open-Meteo sample grid)';

  @override
  String weatherWeatherOverlayUnavailablef9e466e1(String arg0) {
    return 'Weather overlay unavailable: $arg0';
  }

  @override
  String get weatherWeatherPreferencesCouldNot1aa91b1b =>
      'Weather preferences could not be saved';

  @override
  String get weatherWindBeeinflusstDenSimulator0792a00b =>
      'Wind affects the simulator';

  @override
  String get weatherWindImFlugeffc2149 => 'Wind in flight';

  @override
  String get weatherWindImFlugsimulatorBeruecksichtigen2a47223c =>
      'Take wind into account in flight simulator';

  @override
  String get weatherWinddarstellungUndEinflussAus5d5ce187 =>
      'Wind display and influence from';

  @override
  String get weatherWinddatenAbgelaufend96548ce => 'Wind data expired';

  @override
  String get weatherWinddatenFuerPunktAnsichtfa5e2d66 =>
      'Load wind data for point / view';

  @override
  String get weatherWindpfeileWartenAufGeladenes9bd078a7 =>
      'Wind arrows are waiting for loaded 3D terrain.';

  @override
  String get weatherWindquelleZeitfc844a65 => 'Wind source / time';

  @override
  String get weatherZusaetzlichesPrognoseraster279c3ee9 =>
      'Additional forecast grid';

  @override
  String commonSavedRouteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved routes',
      one: 'One saved route',
      zero: 'No saved routes',
    );
    return '$_temp0';
  }

  @override
  String commonUpdatedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Updated on $dateString';
  }

  @override
  String get signalShowGroundStationMarker => 'Show ground station marker';

  @override
  String get signalShowLiveSignalPath => 'Show live line of sight';

  @override
  String get signalUseTakeoffAsGroundStation => 'Reset to takeoff position';

  @override
  String get signalChooseGroundStationFromMap =>
      'Select a point on the 3D map, then reopen this panel and choose “Selected map point”.';
}
