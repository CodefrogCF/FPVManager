import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'fpv_strings_de.dart';
import 'fpv_strings_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of FpvStrings
/// returned by `FpvStrings.of(context)`.
///
/// Applications need to include `FpvStrings.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/fpv_strings.dart';
///
/// return MaterialApp(
///   localizationsDelegates: FpvStrings.localizationsDelegates,
///   supportedLocales: FpvStrings.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the FpvStrings.supportedLocales
/// property.
abstract class FpvStrings {
  FpvStrings(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static FpvStrings of(BuildContext context) {
    return Localizations.of<FpvStrings>(context, FpvStrings)!;
  }

  static const LocalizationsDelegate<FpvStrings> delegate =
      _FpvStringsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// Legacy key: Absence of a match does not establish unrestricted airspace. Source coverage is not independently verified.
  ///
  /// In en, this message translates to:
  /// **'Absence of a match does not establish unrestricted airspace. Source coverage is not independently verified.'**
  String get airspaceAbsenceOfAMatch3e743a0d;

  /// Legacy key: Airspace & flight safety
  ///
  /// In en, this message translates to:
  /// **'Airspace & flight safety'**
  String get airspaceAirspaceFlightSafetyfe71cada;

  /// Legacy key: Airspace intersections
  ///
  /// In en, this message translates to:
  /// **'Airspace intersections'**
  String get airspaceAirspaceIntersectionsb23b9966;

  /// Legacy key: All source attributes ({0})
  ///
  /// In en, this message translates to:
  /// **'All source attributes ({arg0})'**
  String airspaceAllSourceAttributes5a87df81(String arg0);

  /// Legacy key: API access (free services only)
  ///
  /// In en, this message translates to:
  /// **'API access (free services only)'**
  String get airspaceApiAccessFreeServicesa6e68dbd;

  /// Legacy key: API key
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get airspaceApiKeycf678cab;

  /// Legacy key: Automatic DABS/NOTAM availability: not connected. No assertion is made that temporary restrictions have been retrieved or checked.
  ///
  /// In en, this message translates to:
  /// **'Automatic DABS/NOTAM availability: not connected. No assertion is made that temporary restrictions have been retrieved or checked.'**
  String get airspaceAutomaticDabsNotamAvailability2968fe7b;

  /// Legacy key: BAZL UAS geographical zones
  ///
  /// In en, this message translates to:
  /// **'BAZL UAS geographical zones'**
  String get airspaceBazlUasGeographicalZones729ad95f;

  /// Legacy key: Check the latest DABS and original NOTAM immediately before flying. DABS is a periodic snapshot.
  ///
  /// In en, this message translates to:
  /// **'Check the latest DABS and original NOTAM immediately before flying. DABS is a periodic snapshot.'**
  String get airspaceCheckTheLatestDabsf5c81052;

  /// Legacy key: Close airspace check
  ///
  /// In en, this message translates to:
  /// **'Close airspace check'**
  String get airspaceCloseAirspaceCheckeac0670c;

  /// Legacy key: Close details
  ///
  /// In en, this message translates to:
  /// **'Close details'**
  String get airspaceCloseDetails433da6d1;

  /// Legacy key: Close safety panel
  ///
  /// In en, this message translates to:
  /// **'Close safety panel'**
  String get airspaceCloseSafetyPanelc70c84b5;

  /// Legacy key: Close zone inspection
  ///
  /// In en, this message translates to:
  /// **'Close zone inspection'**
  String get airspaceCloseZoneInspection127a12af;

  /// Legacy key: Colors describe source restrictions. Blue is not flight clearance; check every overlapping zone and its conditions.
  ///
  /// In en, this message translates to:
  /// **'Colors describe source restrictions. Blue is not flight clearance; check every overlapping zone and its conditions.'**
  String get airspaceColorsDescribeSourceRestrictionsc0980bc9;

  /// Legacy key: Copy official link
  ///
  /// In en, this message translates to:
  /// **'Copy official link'**
  String get airspaceCopyOfficialLink14342de0;

  /// Legacy key: Could not open browser. Copy the URL instead.
  ///
  /// In en, this message translates to:
  /// **'Could not open browser. Copy the URL instead.'**
  String get airspaceCouldNotOpenBrowserfceaf72a;

  /// Legacy key: Data limitation: {0}
  ///
  /// In en, this message translates to:
  /// **'Data limitation: {arg0}'**
  String airspaceDataLimitation1a823833(String arg0);

  /// Legacy key: Dataset cache is stale or its clock is inconsistent.
  ///
  /// In en, this message translates to:
  /// **'Dataset cache is stale or its clock is inconsistent.'**
  String get airspaceDatasetCacheIsStale23d0712d;

  /// Legacy key: Each limit retains its own source unit and vertical reference.
  ///
  /// In en, this message translates to:
  /// **'Each limit retains its own source unit and vertical reference.'**
  String get airspaceEachLimitRetainsIts3b9913eb;

  /// Legacy key: {0}: {1} features
  ///
  /// In en, this message translates to:
  /// **'{arg0}: {arg1} features'**
  String airspaceFeatures98bdf3c0(String arg0, String arg1);

  /// Legacy key: Flight safety & current official publications
  ///
  /// In en, this message translates to:
  /// **'Flight safety & current official publications'**
  String get airspaceFlightSafetyCurrentOfficiala1a04e11;

  /// Legacy key: Get free API key
  ///
  /// In en, this message translates to:
  /// **'Get free API key'**
  String get airspaceGetFreeApiKeyb5c8a05f;

  /// Legacy key: Inspect restrictions
  ///
  /// In en, this message translates to:
  /// **'Inspect restrictions'**
  String get airspaceInspectRestrictionsdfa16e61;

  /// Legacy key: Intersecting zones: {0}
  ///
  /// In en, this message translates to:
  /// **'Intersecting zones: {arg0}'**
  String airspaceIntersectingZones8134036b(String arg0);

  /// Legacy key: Key configured
  ///
  /// In en, this message translates to:
  /// **'Key configured'**
  String get airspaceKeyConfigured61737de7;

  /// Legacy key: Keys are kept for this browser session only and disappear after reload.
  ///
  /// In en, this message translates to:
  /// **'Keys are kept for this browser session only and disappear after reload.'**
  String get airspaceKeysAreKeptFor409824c9;

  /// Legacy key: Last refresh failed: {0}
  ///
  /// In en, this message translates to:
  /// **'Last refresh failed: {arg0}'**
  String airspaceLastRefreshFailed7971e026(String arg0);

  /// Legacy key: Leave existing key unchanged by keeping this empty
  ///
  /// In en, this message translates to:
  /// **'Leave existing key unchanged by keeping this empty'**
  String get airspaceLeaveExistingKeyUnchanged814b9fe9;

  /// Legacy key: Loading UAS data and checking geometry…
  ///
  /// In en, this message translates to:
  /// **'Loading UAS data and checking geometry…'**
  String get airspaceLoadingUasDataAndddfb5ec6;

  /// Legacy key: Lower: {0}
  ///
  /// In en, this message translates to:
  /// **'Lower: {arg0}'**
  String airspaceLower082a2966(String arg0);

  /// Legacy key: Manual preflight checklist
  ///
  /// In en, this message translates to:
  /// **'Manual preflight checklist'**
  String get airspaceManualPreflightChecklistb4d4bf28;

  /// Legacy key: Next zone
  ///
  /// In en, this message translates to:
  /// **'Next zone'**
  String get airspaceNextZone6c44893a;

  /// Legacy key: No horizontal intersections found in the checked data.
  ///
  /// In en, this message translates to:
  /// **'No horizontal intersections found in the checked data.'**
  String get airspaceNoHorizontalIntersectionsFound318ee27f;

  /// Legacy key: No key configured
  ///
  /// In en, this message translates to:
  /// **'No key configured'**
  String get airspaceNoKeyConfigured697416d1;

  /// Legacy key: No supported airspace provider currently needs a freely obtainable API key. BAZL works without one; Skyguide NOTAM access is not verified as free.
  ///
  /// In en, this message translates to:
  /// **'No supported airspace provider currently needs a freely obtainable API key. BAZL works without one; Skyguide NOTAM access is not verified as free.'**
  String get airspaceNoSupportedAirspaceProviderdcf17faa;

  /// Legacy key: Open official source
  ///
  /// In en, this message translates to:
  /// **'Open official source'**
  String get airspaceOpenOfficialSource47aa309c;

  /// Legacy key: {0} polygon features checked
  ///
  /// In en, this message translates to:
  /// **'{arg0} polygon features checked'**
  String airspacePolygonFeaturesChecked0b14a2bb(String arg0);

  /// Legacy key: Preflight information only. FPVManager cannot issue a flight authorisation or guarantee that a flight is legal or safe.
  ///
  /// In en, this message translates to:
  /// **'Preflight information only. FPVManager cannot issue a flight authorisation or guarantee that a flight is legal or safe.'**
  String get airspacePreflightInformationOnlyFpvmanager3ddafa1c;

  /// Legacy key: Previous zone
  ///
  /// In en, this message translates to:
  /// **'Previous zone'**
  String get airspacePreviousZoneb179c069;

  /// Legacy key: 2. Read the latest DABS and original NOTAM for the entire flight period and route.
  ///
  /// In en, this message translates to:
  /// **'2. Read the latest DABS and original NOTAM for the entire flight period and route.'**
  String get airspaceReadTheLatestDabs49e90175;

  /// Legacy key: 4. Recheck immediately before take-off; a recent download or an empty intersection result is not proof of permission.
  ///
  /// In en, this message translates to:
  /// **'4. Recheck immediately before take-off; a recent download or an empty intersection result is not proof of permission.'**
  String get airspaceRecheckImmediatelyBeforeTake68acccbc;

  /// Legacy key: Refresh source data
  ///
  /// In en, this message translates to:
  /// **'Refresh source data'**
  String get airspaceRefreshSourceDatae31028f4;

  /// Legacy key: Restriction legend (Cesium map)
  ///
  /// In en, this message translates to:
  /// **'Restriction legend (Cesium map)'**
  String get airspaceRestrictionLegendCesiumMap50513b33;

  /// Legacy key: Restriction not provided
  ///
  /// In en, this message translates to:
  /// **'Restriction not provided'**
  String get airspaceRestrictionNotProvided55e0f3ad;

  /// Legacy key: Restriction not provided by source
  ///
  /// In en, this message translates to:
  /// **'Restriction not provided by source'**
  String get airspaceRestrictionNotProvidedBy569286af;

  /// Legacy key: Retry with fresh data
  ///
  /// In en, this message translates to:
  /// **'Retry with fresh data'**
  String get airspaceRetryWithFreshData71969c16;

  /// Legacy key: Route snapshot · {0} waypoints · all connecting segments
  ///
  /// In en, this message translates to:
  /// **'Route snapshot · {arg0} waypoints · all connecting segments'**
  String airspaceRouteSnapshotWaypointsAll292bb6c5(String arg0);

  /// Legacy key: Temporary / time-dependent information
  ///
  /// In en, this message translates to:
  /// **'Temporary / time-dependent information'**
  String get airspaceTemporaryTimeDependentInformation90a7f86a;

  /// Legacy key: Times and offsets are shown as supplied; applicability is not calculated.
  ///
  /// In en, this message translates to:
  /// **'Times and offsets are shown as supplied; applicability is not calculated.'**
  String get airspaceTimesAndOffsetsAred587335b;

  /// Legacy key: UAS data quality
  ///
  /// In en, this message translates to:
  /// **'UAS data quality'**
  String get airspaceUasDataQuality1458ab06;

  /// Legacy key: Waypoints: {0} · Segments: {1}
  ///
  /// In en, this message translates to:
  /// **'Waypoints: {arg0} · Segments: {arg1}'**
  String airspaceWaypointsSegments6fa17a75(String arg0, String arg1);

  /// Legacy key: Zone {0} of {1} at this position
  ///
  /// In en, this message translates to:
  /// **'Zone {arg0} of {arg1} at this position'**
  String airspaceZoneOfAtThiscce172f2(String arg0, String arg1);

  /// Legacy key: Abruf / Prüfung: {0}
  ///
  /// In en, this message translates to:
  /// **'Search/audit: {arg0}'**
  String avalancheAbrufPruefung87671789(String arg0);

  /// Legacy key: Darstellung der publizierten Tagesabschnitte
  ///
  /// In en, this message translates to:
  /// **'Presentation of the published daily sections'**
  String get avalancheDarstellungDerPubliziertenTagesabschnitte07920ee4;

  /// Legacy key: Erneut aktualisieren in {0} s
  ///
  /// In en, this message translates to:
  /// **'Update again in {arg0} s'**
  String avalancheErneutAktualisierenInSed2b6e00(String arg0);

  /// Legacy key: Früherer Tagesabschnitt
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get avalancheFruehererTagesabschnittbbaf5db6;

  /// Legacy key: Gefahrenstufen · regionale Übersicht
  ///
  /// In en, this message translates to:
  /// **'Levels of danger · regional overview'**
  String get avalancheGefahrenstufenRegionaleUbersicht44dc4622;

  /// Legacy key: Grau: unbekannt oder veralteter / nicht bestätigter Stand. Abgelaufene Flächen werden ausgeblendet. Ein fehlendes Bulletin ist keine Entwarnung.
  ///
  /// In en, this message translates to:
  /// **'Grey: unknown or outdated / unconfirmed status. Expired areas are hidden. A missing bulletin is not a warning.'**
  String get avalancheGrauUnbekanntOderVeralteter1feb3e46;

  /// Legacy key: Gültigkeit: {0} – {1}
  ///
  /// In en, this message translates to:
  /// **'Validity: {arg0} – {arg1}'**
  String avalancheGueltigkeita66abbe1(String arg0, String arg1);

  /// Legacy key: Lawinenbulletin · SLF
  ///
  /// In en, this message translates to:
  /// **'Avalanche bulletin · SLF'**
  String get avalancheLawinenbulletinSlfe00b361e;

  /// Legacy key: Publikation: {0}
  ///
  /// In en, this message translates to:
  /// **'Publication: {arg0}'**
  String avalanchePublikation0e56fdd8(String arg0);

  /// Legacy key: SLF-Bulletin aktualisieren
  ///
  /// In en, this message translates to:
  /// **'Update SLF Bulletin'**
  String get avalancheSlfBulletinAktualisieren6cedce41;

  /// Legacy key: Späterer Tagesabschnitt
  ///
  /// In en, this message translates to:
  /// **'Later part of day'**
  String get avalancheSpaetererTagesabschnitte6b59639;

  /// Legacy key: Tagesübersicht
  ///
  /// In en, this message translates to:
  /// **'Daily overview'**
  String get avalancheTagesuebersicht6ec1173c;

  /// Legacy key: Unbekannt / alter Stand
  ///
  /// In en, this message translates to:
  /// **'Unknown / old state'**
  String get avalancheUnbekanntAlterStandaba56b7e;

  /// Legacy key: Add battery
  ///
  /// In en, this message translates to:
  /// **'Add battery'**
  String get batteriesAddBattery418deef8;

  /// Legacy key: Add pack from type
  ///
  /// In en, this message translates to:
  /// **'Add pack from type'**
  String get batteriesAddPackFromTypea7df2842;

  /// Legacy key: Add type
  ///
  /// In en, this message translates to:
  /// **'Add type'**
  String get batteriesAddType937e2dfc;

  /// Legacy key: Associated flight plans
  ///
  /// In en, this message translates to:
  /// **'Associated flight plans'**
  String get batteriesAssociatedFlightPlans1c957aa1;

  /// Legacy key: Availability
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get batteriesAvailability681b5b5a;

  /// Legacy key: Battery details
  ///
  /// In en, this message translates to:
  /// **'Battery details'**
  String get batteriesBatteryDetails139e0037;

  /// Legacy key: Battery inventory
  ///
  /// In en, this message translates to:
  /// **'Battery inventory'**
  String get batteriesBatteryInventory01b473c6;

  /// Legacy key: Battery type · reusable template
  ///
  /// In en, this message translates to:
  /// **'Battery type · reusable template'**
  String get batteriesBatteryTypeReusableTemplate7a43b0a1;

  /// Legacy key: {0} battery{1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} battery{arg1}'**
  String batteriesBatterycc97f71f(String arg0, String arg1);

  /// Legacy key: Calculated nominal energy: {0} Wh (capacity × nominal voltage)
  ///
  /// In en, this message translates to:
  /// **'Calculated nominal energy: {arg0} Wh (capacity × nominal voltage)'**
  String batteriesCalculatedNominalEnergyWh30e6efe0(String arg0);

  /// Legacy key: Condition & availability
  ///
  /// In en, this message translates to:
  /// **'Condition & availability'**
  String get batteriesConditionAvailability033503de;

  /// Legacy key: Copy type specifications
  ///
  /// In en, this message translates to:
  /// **'Copy type specifications'**
  String get batteriesCopyTypeSpecifications02a95788;

  /// Legacy key: Delete battery{0}?
  ///
  /// In en, this message translates to:
  /// **'Delete battery{arg0}?'**
  String batteriesDeleteBattery7407e336(String arg0);

  /// Legacy key: Edit battery
  ///
  /// In en, this message translates to:
  /// **'Edit battery'**
  String get batteriesEditBattery29162bfe;

  /// Legacy key: Individual battery
  ///
  /// In en, this message translates to:
  /// **'Individual battery'**
  String get batteriesIndividualBattery211df7bd;

  /// Legacy key: No battery types yet. Add a reusable specification template.
  ///
  /// In en, this message translates to:
  /// **'No battery types yet. Add a reusable specification template.'**
  String get batteriesNoBatteryTypesYetc908d855;

  /// Legacy key: No drone profiles yet.
  ///
  /// In en, this message translates to:
  /// **'No drone profiles yet.'**
  String get batteriesNoDroneProfilesYet036373ca;

  /// Legacy key: No individual batteries yet. Add a pack to your inventory.
  ///
  /// In en, this message translates to:
  /// **'No individual batteries yet. Add a pack to your inventory.'**
  String get batteriesNoIndividualBatteriesYet2f6f284a;

  /// Legacy key: No saved flight plans yet.
  ///
  /// In en, this message translates to:
  /// **'No saved flight plans yet.'**
  String get batteriesNoSavedFlightPlans0eb9aef8;

  /// Legacy key: No type template
  ///
  /// In en, this message translates to:
  /// **'No type template'**
  String get batteriesNoTypeTemplate58240414;

  /// Legacy key: Optional
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get batteriesOptional0c6c4102;

  /// Legacy key: Packs keep independent specification copies. Later type edits do not change them.
  ///
  /// In en, this message translates to:
  /// **'Packs keep independent specification copies. Later type edits do not change them.'**
  String get batteriesPacksKeepIndependentSpecificationa8fd26d6;

  /// Legacy key: Removed type
  ///
  /// In en, this message translates to:
  /// **'Removed type'**
  String get batteriesRemovedType24f2204a;

  /// Legacy key: Retry loading options
  ///
  /// In en, this message translates to:
  /// **'Retry loading options'**
  String get batteriesRetryLoadingOptions99cf637e;

  /// Legacy key: The assigned type was removed. Select a type or no template.
  ///
  /// In en, this message translates to:
  /// **'The assigned type was removed. Select a type or no template.'**
  String get batteriesTheAssignedTypeWas57b002ba;

  /// Legacy key: This battery no longer exists.
  ///
  /// In en, this message translates to:
  /// **'This battery no longer exists.'**
  String get batteriesThisBatteryNoLongere1b6ecdf;

  /// Legacy key: Type template (optional)
  ///
  /// In en, this message translates to:
  /// **'Type template (optional)'**
  String get batteriesTypeTemplateOptionalbafc4970;

  /// Legacy key: Unable to load battery inventory.
  ///
  /// In en, this message translates to:
  /// **'Unable to load battery inventory.'**
  String get batteriesUnableToLoadBattery8a3276bc;

  /// Legacy key: Unable to load this battery.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this battery.'**
  String get batteriesUnableToLoadThis46eed388;

  /// Legacy key: Unable to load types and assignments.
  ///
  /// In en, this message translates to:
  /// **'Unable to load types and assignments.'**
  String get batteriesUnableToLoadTypesc7010120;

  /// Legacy key: A planning radius is not a VLOS limit. Visibility, aircraft orientation, observers, people, pilot qualifications, local restrictions and approvals require manual verification.
  ///
  /// In en, this message translates to:
  /// **'A planning radius is not a VLOS limit. Visibility, aircraft orientation, observers, people, pilot qualifications, local restrictions and approvals require manual verification.'**
  String get commonAPlanningRadiusIse6a1033a;

  /// Legacy key: Abbrechen
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonAbbrechen07af7cb3;

  /// Legacy key: Abrufzeit ist nicht Veröffentlichungszeit. Gültig von/bis beschreibt den angegebenen Zeitraum; ein frischer Download beweist nicht, dass der gesamte Inhalt aktuell ist. Fehlende Zeitangaben werden nicht ergänzt.
  ///
  /// In en, this message translates to:
  /// **'Retrieving time is not publication time. Valid from/until describes the specified period; a fresh download does not prove that the entire content is up-to-date. Missing time information is not added.'**
  String get commonAbrufzeitIstNichtVeroeffentlichungszeit8d993e52;

  /// Legacy key: Absolute source heights: LN02. Elevated display: CHGeo2004 + HTRANS to the ETRS89 ellipsoid, used as a WGS84 approximation. Unknown line/area elevations are shown only as a ground marker at their first source vertex. Isolated point obstacles with an official AGL height are displayed at that exact height above the currently rendered terrain; their visualized absolute top may differ from the surveyed LN02 top. Extra KML label points on lines/polygons are not drawn as obstacles. Cable vertices matching published masts follow the same terrain-adjusted mast tops, with interpolated display corrections between supports. Other geometry retains source absolute elevations. Cable sag is not reconstructed; route checks use original source geometry.
  ///
  /// In en, this message translates to:
  /// **'Absolute source heights: LN02. Elevated display: CHGeo2004 + HTRANS to the ETRS89 ellipsoid, used as a WGS84 approximation. Unknown line/area elevations are shown only as a ground marker at their first source vertex. Isolated point obstacles with an official AGL height are displayed at that exact height above the currently rendered terrain; their visualized absolute top may differ from the surveyed LN02 top. Extra KML label points on lines/polygons are not drawn as obstacles. Cable vertices matching published masts follow the same terrain-adjusted mast tops, with interpolated display corrections between supports. Other geometry retains source absolute elevations. Cable sag is not reconstructed; route checks use original source geometry.'**
  String get commonAbsoluteSourceHeightsLn1571b147;

  /// Legacy key: Add
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd61cc55aa;

  /// Legacy key: AGL is a distance above this ground point, not a sea-level height.
  ///
  /// In en, this message translates to:
  /// **'AGL is a distance above this ground point, not a sea-level height.'**
  String get commonAglIsADistance519675fb;

  /// Legacy key: Airframe
  ///
  /// In en, this message translates to:
  /// **'Airframe'**
  String get commonAirframe2149a671;

  /// Legacy key: Airspace status: NOT CHECKED by this weather assessment. Consult current UAS zones, DABS and NOTAM separately.
  ///
  /// In en, this message translates to:
  /// **'Airspace status: NOT CHECKED by this weather assessment. Consult current UAS zones, DABS and NOTAM separately.'**
  String get commonAirspaceStatusNotCheckedfcc694aa;

  /// Legacy key: Airspace
  ///
  /// In en, this message translates to:
  /// **'Airspace'**
  String get commonAirspaceb3cb9fb5;

  /// Legacy key: Aktivitätsprofile und Arbeitsbereiche
  ///
  /// In en, this message translates to:
  /// **'Activity profiles and work areas'**
  String get commonAktivitaetsprofileUndArbeitsbereiched4c2fe93;

  /// Legacy key: Aktivitätsprofile
  ///
  /// In en, this message translates to:
  /// **'Activity profiles'**
  String get commonAktivitaetsprofilee88c0015;

  /// Legacy key: Aktualisierung fehlgeschlagen: gespeicherte Daten, aktueller Status unbekannt.
  ///
  /// In en, this message translates to:
  /// **'Update failed: saved data, current status unknown.'**
  String get commonAktualisierungFehlgeschlagenGespeicherteDatene03c0f00;

  /// Legacy key: Aktuelle BAZL-Karte, DABS und Original-NOTAM für Flugzeit und Route sowie örtliche Regeln prüfen. DABS ist ein periodisches Bulletin; NOTAM können sich zwischen Ausgaben ändern. Der automatische DABS/NOTAM-Abruf ist derzeit nicht angeschlossen. Auch Wetter, Hindernisse und Höhenbezüge prüfen und unmittelbar vor Abflug erneut verifizieren.
  ///
  /// In en, this message translates to:
  /// **'Check current BAZL card, DABS and original NOTAM for flight time and route as well as local rules. DABS is a periodic bulletin; NOTAM can change between issues. Automatic DABS/NOTAM callup is currently not connected. Also check weather, obstacles and altitude cover and re-verify immediately before departure.'**
  String get commonAktuelleBazlKarteDabs491537fb;

  /// Legacy key: Alle
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAlle4c7a986f;

  /// Legacy key: Alle 60 Sekunden, solange die Navigation aktiv ist. Im Hintergrund pausiert der Abruf.
  ///
  /// In en, this message translates to:
  /// **'Every 60 seconds, as long as the navigation is active. In the background, the retrieval pauses.'**
  String get commonAlleSekundenSolangeDie8b77bd0f;

  /// Legacy key: Alle Zonen prüfen
  ///
  /// In en, this message translates to:
  /// **'Check all zones'**
  String get commonAlleZonenPruefen026c7d8e;

  /// Legacy key: Anbieterbedingungen und Berechtigungen gelten pro Quelle. Für ASTRA das Token des passenden Produkts verwenden, nicht Token-Hash oder OJP-Token. Android nutzt die bestehende sichere Schlüsselablage; Schlüssel gehören weder in einfache Einstellungen noch in Backups. Web-Zugänge bleiben in den bisher unterstützten Grenzen. Keine öffentlichen Proxys geben private Schlüssel weiter.
  ///
  /// In en, this message translates to:
  /// **'Provider conditions and permissions apply per source. Use ASTRA token of the appropriate product, not token hash or OJP token. Android uses the existing secure key storage; keys do not belong in simple settings or in backups. Web access remains within the previously supported limits. No public proxys pass on private keys.'**
  String get commonAnbieterbedingungenUndBerechtigungenGeltenff0efbff;

  /// Legacy key: Angle/Acro: E/Q Gas, A/D Yaw, W/S Pitch, Pfeile links/rechts Roll; IJKL steuert ebenfalls die Lage. GPS/Ego: WASD/Pfeile bewegen, Ziehen oder IJKL umsehen; GPS nutzt E/Q für die Höhe. Escape beendet die Ansicht. Für Controller nach Fokusverlust oder echter Trennung die passende Ruheposition einnehmen. Gas-Nullpunkt und Kanalzuordnung bleiben eigene Controller-Einstellungen.
  ///
  /// In en, this message translates to:
  /// **'Angle/Acro: E/Q Gas, A/D Yaw, W/S Pitch, left/right arrows Roll; IJKL also controls the location. GPS/Ego: WASD/arrows move, drag or IJKL look around; GPS uses E/Q for height. Escape ends the view. For controllers after focus loss or real separation take the appropriate resting position. Gas zero point and channel assignment remain their own controller settings.'**
  String get commonAngleAcroEQ41fdac85;

  /// Legacy key: Angle/Acro: links Gas und Yaw, rechts Pitch und Roll. GPS: links Bewegung, rechts Blickrichtung, separate Knöpfe für Steigen/Sinken. Beide Touch-Sticks sitzen fest. Die Schnelleinstellungen können sie ausblenden; Tastatur und externe Controller bleiben nutzbar.
  ///
  /// In en, this message translates to:
  /// **'Angle/Acro: left gas and Yaw, right pitch and roll. GPS: left movement, right direction of view, separate buttons for climbing/sinking. Both touch sticks are stuck. They can hide the quick settings; keyboard and external controllers remain usable.'**
  String get commonAngleAcroLinksGas98d5063f;

  /// Legacy key: Angle/Acro: Null unten nutzt den ganzen Gasweg; Null in der Mitte nur die obere Hälfte. Zum Verbinden oder Fortsetzen Gas auf null, übrige Sticks zentrieren.
  ///
  /// In en, this message translates to:
  /// **'Angle/Acro uses the full stick range when zero throttle is at the bottom. With zero at the centre it uses the upper half. Set zero throttle and centre the other sticks before connecting or resuming.'**
  String get commonAngleAcroNullUntena9ccc141;

  /// Legacy key: Angle stabilisiert die Lage, Acro gibt Drehraten vor, GPS bremst und hält die Höhe. „Flugeinstellungen“ bündelt Kamera/Anzeige, Grafik/Licht, Controller, Wind und Funkvorschau. Lange Bildpausen werden nicht als großer Flugschritt nachgeholt. Die Physik, Gelände- und Modellkontakte bleiben Näherungen; Gebäude, Bäume und Kabel bilden keine vollständige Kollisionswelt. Einstellungen außerhalb eines Fluges bereiten die nächste Simulation vor.
  ///
  /// In en, this message translates to:
  /// **'Angle stabilizes the position, Acro gives rotation rates, GPS brakes and keeps the height. \"Flight settings\" bundles camera/display, graphics/light, controller, wind and radio preview. Long pauses are not made as a big flight step. Physics, terrain and model contacts remain approximations; buildings, trees and cables do not form a complete collision world. Settings outside of a flight prepare the next simulation.'**
  String get commonAngleStabilisiertDieLage6d00e2df;

  /// Legacy key: Anwenden
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonAnwendenb18093c4;

  /// Legacy key: Approximate great-circle distances and constant airspeed per segment. No acceleration, hovering, manoeuvre time or gusts are included. The aircraft must be able to achieve the planned speed and climb rate.
  ///
  /// In en, this message translates to:
  /// **'Approximate great-circle distances and constant airspeed per segment. No acceleration, hovering, manoeuvre time or gusts are included. The aircraft must be able to achieve the planned speed and climb rate.'**
  String get commonApproximateGreatCircleDistances7eb1a34f;

  /// Legacy key: Approximate metric distances use the Swiss LV95 projection. 3D values use original source elevations converted to the terrain ellipsoid reference, not adjusted display geometry. The 30 m AGL preview is never a checked altitude.
  ///
  /// In en, this message translates to:
  /// **'Approximate metric distances use the Swiss LV95 projection. 3D values use original source elevations converted to the terrain ellipsoid reference, not adjusted display geometry. The 30 m AGL preview is never a checked altitude.'**
  String get commonApproximateMetricDistancesUse2ad8d0c4;

  /// Legacy key: Assess modeled bridges, supports and tunnel walls
  ///
  /// In en, this message translates to:
  /// **'Assess modeled bridges, supports and tunnel walls'**
  String get commonAssessModeledBridgesSupports6afd1bbd;

  /// Legacy key: Associated drones
  ///
  /// In en, this message translates to:
  /// **'Associated drones'**
  String get commonAssociatedDrones0b96fd82;

  /// Legacy key: ASTRA / VDP · Best-Effort-Messdaten, keine bestätigte Verkehrsprognose.
  ///
  /// In en, this message translates to:
  /// **'ASTRA / VDP · Best-Effort measurement data, no confirmed traffic forecast.'**
  String get commonAstraVdpBestEffort6d0423b7;

  /// Legacy key: At {0} m: ground {1}, altitude {2}, AGL {3}.
  ///
  /// In en, this message translates to:
  /// **'At {arg0} m: ground {arg1}, altitude {arg2}, AGL {arg3}.'**
  String commonAtMGroundAltitude06f0de9e(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  );

  /// Legacy key: Aus
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonAus6997e3eb;

  /// Legacy key: Ausgewählte Aufnahmen sind historische bzw. verzögert veröffentlichte Bilddaten. Keine Live-Beobachtung. Es werden nur kleine STAC-Metadaten gespeichert, keine Rohbilddateien. Wolken, Schatten und fehlende Bilddeckung sind keine leeren Flächen.
  ///
  /// In en, this message translates to:
  /// **'Selected recordings are historical or delayed published image data. No live observation. Only small STAC metadata are stored, no raw image files. Clouds, shadows and missing image coverage are not empty areas.'**
  String get commonAusgewaehlteAufnahmenSindHistorische73e77349;

  /// Legacy key: Available
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get commonAvailable7c62a142;

  /// Legacy key: Average airspeed: {0} m/s · maximum {1} m/s
  ///
  /// In en, this message translates to:
  /// **'Average airspeed: {arg0} m/s · maximum {arg1} m/s'**
  String commonAverageAirspeedMS071139b2(String arg0, String arg1);

  /// Legacy key: Average ground speed: {0} m/s · maximum {1} m/s
  ///
  /// In en, this message translates to:
  /// **'Average ground speed: {arg0} m/s · maximum {arg1} m/s'**
  String commonAverageGroundSpeedM20c0470a(String arg0, String arg1);

  /// Legacy key: Average {0} speed: {1} m/s · maximum {2} m/s
  ///
  /// In en, this message translates to:
  /// **'Average {arg0} speed: {arg1} m/s · maximum {arg2} m/s'**
  String commonAverageSpeedMSabf80b70(String arg0, String arg1, String arg2);

  /// Legacy key: Backups schützen Spots, Bilder, Ausrüstung und Planung unabhängig vom Kartencache. Optionales Passwort schützt den Export; ungeschützte Backups sind lesbar. API-Schlüssel und öffentliche Karten-/OSINT-Caches gehören nicht zum persönlichen Backup. Browser können lokalen Speicher löschen; wichtige Daten zusätzlich sichern.
  ///
  /// In en, this message translates to:
  /// **'Backups protect spots, images, equipment and planning regardless of the card cache. Optional password protects the export; unprotected backups are readable. API keys and public card/OSINT caches do not belong to the personal backup. Browsers can delete local memory; additional backups of important data.'**
  String get commonBackupsSchuetzenSpotsBilder26ad5793;

  /// Legacy key: BAFU-Live-Werte sind unkorrigiert. 10-Minuten-Mittel enthalten die bereitgestellte Einheit und den verfügbaren Freigabestatus; unbekannte Referenzen bleiben unbekannt. Frische des lokalen Snapshots und Alter einer einzelnen Messung sind getrennte Angaben. Beobachtungen bewerten weder eine Aktivität als sicher noch ersetzen sie amtliche Warnungen. Abrufe erfolgen bewusst, in begrenzten Abständen; lokale Messwert-Snapshots lassen sich auch ohne Netz öffnen.
  ///
  /// In en, this message translates to:
  /// **'FOEN live values are uncorrected. 10 minutes means contain the unit provided and the available release status; unknown references remain unknown. Fresh local snapshots and age of a single measurement are separate data. Observations do not evaluate an activity as safe or replace official warnings. Retrieves are done consciously, at limited intervals; local measurement snapshots can be opened even without a net.'**
  String get commonBafuLiveWerteSind2d1baf8b;

  /// Legacy key: Baustelle
  ///
  /// In en, this message translates to:
  /// **'Construction site'**
  String get commonBaustellee9cf26e7;

  /// Legacy key: BAZL authorisation subtypes (same category, different applicable conditions):
  ///
  /// In en, this message translates to:
  /// **'BAZL authorisation subtypes (same category, different applicable conditions):'**
  String get commonBazlAuthorisationSubtypesSame4c054fce;

  /// Legacy key: BAZL-WMS zeigt kombinierte Rasterbilder; Kategorien und Höhen sind daraus nicht einzeln auswählbar. Vektordaten bieten Details, soweit die Quelle sie enthält. Unbekannte Höhen bleiben unbekannt. Gerade Kabelverbindungen und einfache Mast-/Kranmodelle sind Näherungen, keine exakte Bauwerksaufnahme.
  ///
  /// In en, this message translates to:
  /// **'BAZL-WMS shows combined raster images; categories and heights are not individually selectable. Vector data provide details as far as the source contains them. Unknown heights remain unknown. Especially cable connections and simple mast/crane models are approximations, no exact building image.'**
  String get commonBazlWmsZeigtKombiniertee1af0170;

  /// Legacy key: Beim Abruf werden die gewählten Kartenkoordinaten an Open-Meteo gesendet. „Aktuell“ sind Modellwerte, keine Live-Messung vor Ort. Daten und Auswahl gelten für diese Sitzung.
  ///
  /// In en, this message translates to:
  /// **'The selected map coordinates are sent to Open-Meteo during retrieval. \"Currently, model values are not live measurements on site. Data and selection are valid for this session.'**
  String get commonBeimAbrufWerdenDiecd3b9e12;

  /// Legacy key: Beobachtungen
  ///
  /// In en, this message translates to:
  /// **'Observations'**
  String get commonBeobachtungen9156ea0e;

  /// Legacy key: Bereich bis 25 km Radius direkt auf diesem Gerät vorbereiten: Topografie, SWISSIMAGE-Satellitenbilder, neutrales Relief und 3D-Gelände aus offiziellen Downloadquellen. In der Webversion ist auch die gesamte Schweiz wählbar.
  ///
  /// In en, this message translates to:
  /// **'Prepare up to 25 km radius directly on this device: topography, SWISSIMAGE satellite images, neutral relief and 3D sites from official download sources. In the web version, the whole of Switzerland can also be selected.'**
  String get commonBereichBisKmRadiusfecda995;

  /// Legacy key: Bereiche vorbereiten
  ///
  /// In en, this message translates to:
  /// **'Prepare areas'**
  String get commonBereicheVorbereiten1c921757;

  /// Legacy key: Beschleunigung (m/s²)
  ///
  /// In en, this message translates to:
  /// **'Acceleration (m/s²)'**
  String get commonBeschleunigungMS1457d0c3;

  /// Legacy key: Bevorzugte Ebenen sind Schnellzugriffe zu den bestehenden Ebenenreglern. Ein Profil aktiviert keine Datenquelle, Standortfreigabe, API-Verbindung oder automatische Aktualisierung. Quelleneinstellungen und Berechtigungen bleiben eigenständig. Profile speichern keine Zugangsdaten oder persönlichen Orte.
  ///
  /// In en, this message translates to:
  /// **'Preferred levels are quick access to existing layer controllers. A profile does not enable data source, location sharing, API connection, or automatic update. Source settings and permissions remain independent. Profiles do not store access data or personal locations.'**
  String get commonBevorzugteEbenenSindSchnellzugriffe2eb52776;

  /// Legacy key: Bewölkung
  ///
  /// In en, this message translates to:
  /// **'Clouds'**
  String get commonBewoelkung3dac517c;

  /// Legacy key: Bewölkung: 0–100 % Modellbedeckung, keine gemessenen 3D-Wolken. Temperatur: °C in 2 m Höhe. Alle sichtbaren Raster verwenden dieselbe Prognosezeit.
  ///
  /// In en, this message translates to:
  /// **'Cloud: 0–100% model cover, no measured 3D clouds. Temperature: °C at 2 m height. All visible grids use the same forecast time.'**
  String get commonBewoelkungModellbedeckungKeineGemessenencfb37c6a;

  /// Legacy key: Bewölkung, Niederschlag, Regen, Neuschnee, Schneehöhe und Temperatur sind getrennte Modellprognosen mit gemeinsamer Zeit. Summen gelten für eine Stunde; Schneehöhe ist davon unabhängig. Dieses Stichprobenraster ist kein Wetterradar und keine gemessene 3D-Wolke. Der Wetterbereich bietet separat veröffentlichte MeteoSwiss-Radarbilder: Zeitpunkt wählen, laden oder abspielen. Radar ist eine Beobachtung; fehlende Bilder oder Pixel bedeuten nicht trockenes Wetter.
  ///
  /// In en, this message translates to:
  /// **'Clouds, precipitation, rain, new snow, snow height and temperature are separate model forecasts with common time. Sums are valid for one hour; snow height is independent of this. This sample grid is no weather radar and no measured 3D cloud. The weather area offers separately published MeteoSwiss radar images: Select time, load or play. Radar is an observation; missing images or pixels do not mean dry weather.'**
  String get commonBewoelkungNiederschlagRegenNeuschnee33c03591;

  /// Legacy key: Bezug: {0} · {1}, {2}
  ///
  /// In en, this message translates to:
  /// **'Reference: {arg0} · {arg1}, {arg2}'**
  String commonBezugb64247b0(String arg0, String arg1, String arg2);

  /// Legacy key: Bodenansicht
  ///
  /// In en, this message translates to:
  /// **'Ground View'**
  String get commonBodenansicht66b19097;

  /// Legacy key: Bodenrouten
  ///
  /// In en, this message translates to:
  /// **'Ground routes'**
  String get commonBodenroutenfc34e044;

  /// Legacy key: Bremswirkung (m/s²)
  ///
  /// In en, this message translates to:
  /// **'Braking (m/s²)'**
  String get commonBremswirkungMSaca7620a;

  /// Legacy key: Calibration outside 0.25–4× is not applied. Check units, sensors and flight conditions.
  ///
  /// In en, this message translates to:
  /// **'Calibration outside 0.25–4× is not applied. Check units, sensors and flight conditions.'**
  String get commonCalibrationOutsideIsNot45f5bb20;

  /// Legacy key: Campsites
  ///
  /// In en, this message translates to:
  /// **'Campsites'**
  String get commonCampsites7c38c052;

  /// Legacy key: Cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel77dfd213;

  /// Legacy key: ch.swisstopo.spezialbefliegungen
  ///
  /// In en, this message translates to:
  /// **'Specialised flying operations'**
  String get commonChSwisstopoSpezialbefliegungen7d9cb953;

  /// Legacy key: ch.swisstopo.swisseo_s2-sr_v200
  ///
  /// In en, this message translates to:
  /// **'ch.swisstopo.swisseo_s2-sr_v200'**
  String get commonChSwisstopoSwisseoS9f4a6c16;

  /// Legacy key: Channel bandwidth
  ///
  /// In en, this message translates to:
  /// **'Channel bandwidth'**
  String get commonChannelBandwidth0c1b6ee1;

  /// Legacy key: Charge, cycles and condition are recorded manually.
  ///
  /// In en, this message translates to:
  /// **'Charge, cycles and condition are recorded manually.'**
  String get commonChargeCyclesAndCondition2b6f03c0;

  /// Legacy key: 3. Check altitude references, local/cantonal rules, aerodrome procedures, weather and obstacles.
  ///
  /// In en, this message translates to:
  /// **'3. Check altitude references, local/cantonal rules, aerodrome procedures, weather and obstacles.'**
  String get commonCheckAltitudeReferencesLocal541cb086;

  /// Legacy key: Check current official zones, DABS/NOTAM, zone validity and height references, aircraft class and mass, pilot qualifications, people and property, permissions and local rules. These checks cannot be completed from the route alone.
  ///
  /// In en, this message translates to:
  /// **'Check current official zones, DABS/NOTAM, zone validity and height references, aircraft class and mass, pilot qualifications, people and property, permissions and local rules. These checks cannot be completed from the route alone.'**
  String get commonCheckCurrentOfficialZonesb6eb2aee;

  /// Legacy key: Clear overlay
  ///
  /// In en, this message translates to:
  /// **'Clear overlay'**
  String get commonClearOverlay89f8488e;

  /// Legacy key: Close navigation menu
  ///
  /// In en, this message translates to:
  /// **'Close navigation menu'**
  String get commonCloseNavigationMenu53cad4d7;

  /// Legacy key: Close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClosebbfa773e;

  /// Legacy key: Codefrog · ribbit@codefrog.ch. Die vollständige Datenschutzerklärung ist unter Offline & Daten verlinkt.
  ///
  /// In en, this message translates to:
  /// **'Codefrog · ribbit@codefrog.ch. The full privacy policy is linked under Offline & personal data.'**
  String get commonCodefrogRibbitCodefrogCh4326d9c5;

  /// Legacy key: Combined raster symbols: no category filters, object selection or precise 3D heights.
  ///
  /// In en, this message translates to:
  /// **'Combined raster symbols: no category filters, object selection or precise 3D heights.'**
  String get commonCombinedRasterSymbolsNo01f2553a;

  /// Legacy key: Comma separated · up to 10 tags, 32 characters each
  ///
  /// In en, this message translates to:
  /// **'Comma separated · up to 10 tags, 32 characters each'**
  String get commonCommaSeparatedUpTo0410e8b5;

  /// Legacy key: Communication profile unavailable. Select the path again to retry.
  ///
  /// In en, this message translates to:
  /// **'Communication profile unavailable. Select the path again to retry.'**
  String get commonCommunicationProfileUnavailableSelect22f9df96;

  /// Legacy key: Connecting to 3D terrain. Flat map shown.
  ///
  /// In en, this message translates to:
  /// **'Connecting to 3D terrain. Flat map shown.'**
  String get commonConnectingToDTerrain33c3d51a;

  /// Legacy key: Continue
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue2e026239;

  /// Legacy key: Cruise power
  ///
  /// In en, this message translates to:
  /// **'Cruise power'**
  String get commonCruisePowere01cb967;

  /// Legacy key: Cruise speed
  ///
  /// In en, this message translates to:
  /// **'Cruise speed'**
  String get commonCruiseSpeed806d91ba;

  /// Legacy key: 3D-Bauwerke
  ///
  /// In en, this message translates to:
  /// **'3D structures'**
  String get commonDBauwerkeff58c166;

  /// Legacy key: 3D-Gebäude
  ///
  /// In en, this message translates to:
  /// **'3D buildings'**
  String get commonDGebaeudee0eaa628;

  /// Legacy key: „3D & Licht“ enthält Gebäude, Vegetation, Bauwerke, automatische 3D-Tunnel und Beleuchtung. Tunnel und ergänzte Brückenpfeiler sind schematisch. Tunnelwände, Boden und Decke haben geometrische Kontaktprüfungen; die optionale Prüfung fremder 3D-Modelle ist nur eine Näherung geladener Oberflächen. Fehlende Objekte werden nicht ergänzt. Streaming-3D und Beschriftungen sind keine vollständigen Offlineebenen. „Quellen“ öffnet die vollständigen aktiven Angaben.
  ///
  /// In en, this message translates to:
  /// **'\"3D & Light\" contains buildings, vegetation, buildings, automatic 3D tunnels and lighting. Tunnels and bridge pillars are schematic. Tunnel walls, floor and ceiling have geometric contact checks; the optional testing of foreign 3D models is only an approximation of charged surfaces. Missing objects are not added. Streaming 3D and labels are not complete offline levels. \"Sources\" opens the full active information.'**
  String get commonDLichtEnthaeltGebaeude1ba3ed81;

  /// Legacy key: 3D terrain unavailable. Flat map shown; terrain heights are disabled.
  ///
  /// In en, this message translates to:
  /// **'3D terrain unavailable. Flat map shown; terrain heights are disabled.'**
  String get commonDTerrainUnavailableFlatc09ad4e3;

  /// Legacy key: 3D und Quellen
  ///
  /// In en, this message translates to:
  /// **'3D and Sources'**
  String get commonDUndQuellen2d9ae897;

  /// Legacy key: 3D-Vegetation
  ///
  /// In en, this message translates to:
  /// **'3D vegetation'**
  String get commonDVegetation7f361b72;

  /// Legacy key: Datenquelle: Bundesamt für Energie (BFE), Ladepunkte Elektromobilität, geo.admin.ch · O-By-Ask. Nutzung mit Quellenangabe; kommerzielle Nutzung nur mit vorheriger Erlaubnis des Dateninhabers.
  ///
  /// In en, this message translates to:
  /// **'Data source: Federal Office of Energy (SFOE), charging points Electromobility, geo.admin.ch · O-By-Ask. Use with source; commercial use only with prior permission of the data owner.'**
  String get commonDatenquelleBundesamtFuerEnergieb3a50654;

  /// Legacy key: Datenquellen
  ///
  /// In en, this message translates to:
  /// **'Data sources'**
  String get commonDatenquellen3253fdfe;

  /// Legacy key: {0} Datensätze nicht sicher zugeordnet / nicht gewichtet. Fehlende Straßenkennung, Richtung, Ortsauflösung oder Gültigkeit bleiben unbekannt.
  ///
  /// In en, this message translates to:
  /// **'{arg0} datasets not safely assigned / not weighted. Lack of road identification, direction, location resolution or validity remain unknown.'**
  String commonDatensaetzeNichtSicherZugeordnet393f5548(String arg0);

  /// Legacy key: Datenschutz und API-Zugänge
  ///
  /// In en, this message translates to:
  /// **'Data protection and API access'**
  String get commonDatenschutzUndApiZugaenge303f9be7;

  /// Legacy key: Datenschutzkontakt
  ///
  /// In en, this message translates to:
  /// **'Privacy contact'**
  String get commonDatenschutzkontakteec0b69d;

  /// Legacy key: Datenstand und Verfügbarkeit
  ///
  /// In en, this message translates to:
  /// **'Data level and availability'**
  String get commonDatenstandUndVerfuegbarkeit0ff67f1d;

  /// Legacy key: Defaults: 2 m antenna, 5800 MHz and 60% first-zone radius. Set the actual control or video frequency for each analysis.
  ///
  /// In en, this message translates to:
  /// **'Defaults: 2 m antenna, 5800 MHz and 60% first-zone radius. Set the actual control or video frequency for each analysis.'**
  String get commonDefaultsMAntennaMhz63828140;

  /// Legacy key: Delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDeletef6fdbe48;

  /// Legacy key: Der gewählte Ausschnitt wird an geo.admin.ch gesendet. Räumlicher Auszug, keine vollständige Zugänglichkeitsprüfung.
  ///
  /// In en, this message translates to:
  /// **'The selected section is sent to geo.admin.ch. Spatial extract, no complete accessibility check.'**
  String get commonDerGewaehlteAusschnittWird46b1cc5d;

  /// Legacy key: Der Kompass richtet die Karte nach Norden aus. „Mein Standort“ ortet erst nach Antippen. Langes Drücken öffnet Genauigkeit und Verfolgung; Kartenbewegungen beenden die Verfolgung. Die Suche akzeptiert Koordinaten, Orte und Straßen.
  ///
  /// In en, this message translates to:
  /// **'The compass directs the map to the north. \"My location is only looking for taps. Long press opens accuracy and tracking; map movements end the pursuit. The search accepts coordinates, places and roads.'**
  String get commonDerKompassRichtetDie15ee98a3;

  /// Legacy key: Die Kantone erlassen die verbindlichen Regeln. Eine Gefahrenstufe allein begründet kein Feuerverbot. Fehlende, veraltete oder unvollständige Daten bedeuten keine Entwarnung.
  ///
  /// In en, this message translates to:
  /// **'The cantons adopt the binding rules. A hazard level alone does not justify a fire ban. Lack of, outdated or incomplete data does not mean no warning.'**
  String get commonDieKantoneErlassenDiea929ec2f;

  /// Legacy key: Die Tagesübersicht zeigt die höchste publizierte regionale Stufe. Höhenlagen, Expositionen und Lawinenprobleme stehen in der Beschreibung beim Antippen. Die Farbe gilt nicht pauschal für jeden Hang.
  ///
  /// In en, this message translates to:
  /// **'The daily overview shows the highest published regional level. Altitudes, exposures and avalanche problems are described in the description when tapping. The colour does not apply to every slope.'**
  String get commonDieTagesuebersichtZeigtDie3e26c236;

  /// Legacy key: Disabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get commonDisabledf4f4473d;

  /// Legacy key: Documentation
  ///
  /// In en, this message translates to:
  /// **'Documentation'**
  String get commonDocumentation9e9cf322;

  /// Legacy key: Done
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDonee9b450d1;

  /// Legacy key: Drinking water
  ///
  /// In en, this message translates to:
  /// **'Drinking water'**
  String get commonDrinkingWaterc9176049;

  /// Legacy key: Driving route to an address, coordinates or saved spot. Times are OSRM baseline estimates. Available traffic can help compare alternatives. Verify parking, private roads and the final approach locally.
  ///
  /// In en, this message translates to:
  /// **'Driving route to an address, coordinates or saved spot. Times are OSRM baseline estimates. Available traffic can help compare alternatives. Verify parking, private roads and the final approach locally.'**
  String get commonDrivingRouteToAn298a4f2a;

  /// Legacy key: Drohnenprofile nicht verfügbar. Manuelle Werte bleiben nutzbar.
  ///
  /// In en, this message translates to:
  /// **'Drone profiles are unavailable. Manual settings are still available.'**
  String get commonDrohnenprofileNichtVerfuegbarManuelle5ff33edb;

  /// Legacy key: Durchflug nicht verfügbar: Angaben zu Einstieg, Höhenprofil oder Terrain-Ausschnitten.
  ///
  /// In en, this message translates to:
  /// **'Fly-through unavailable. Check the entry, elevation profile or terrain cutouts.'**
  String get commonDurchflugNichtVerfuegbarAngaben4931f578;

  /// Legacy key: Ebenen und Datenschutz
  ///
  /// In en, this message translates to:
  /// **'Levels and data protection'**
  String get commonEbenenUndDatenschutze913d2a4;

  /// Legacy key: Ebenen
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get commonEbenenc8f2bacd;

  /// Legacy key: Eigene Spots, Fotos, Ausrüstung, Routen und Checklisten sind bereits lokal. Heruntergeladene UAS-Zonen, Vektorhindernisse und SLF-Bulletins bleiben als datierte Momentaufnahmen verfügbar. Diese Ebenen bei Bedarf vorher in den Kartenebenen aktualisieren. WMS-Bilder, gestreamte Gebäude/Bäume, Verkehr, Flugbewegungen und laufende Wetterdaten werden nicht als vollständige Offline-Datensätze zugesagt.
  ///
  /// In en, this message translates to:
  /// **'Private spots, photos, equipment, routes and checklists are already local. Downloaded UAS zones, vector barriers and SLF bulletins remain available as dated snapshots. Update these levels in the map side if necessary. WMS images, streamed buildings/trees, traffic, flight movements and ongoing weather data are not promised as complete offline data sets.'**
  String get commonEigeneSpotsFotosAusruestunga83357cb;

  /// Legacy key: Ein
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonEin3b564e70;

  /// Legacy key: Ein Laptop ist für die Aufbereitung nicht erforderlich. Bereits erstellte .fpvregion-Pakete bis 64 MiB können weiterhin importiert werden. Quellenlücken, Landesgrenzen und der gewählte Detailgrad begrenzen die Abdeckung.
  ///
  /// In en, this message translates to:
  /// **'A laptop is not required for processing. Already created .fpvregion packages up to 64 MiB can still be imported. Source gaps, national borders and the selected level of detail limit the coverage.'**
  String get commonEinLaptopIstFuer32903d0e;

  /// Legacy key: Eine Modellprognose ist keine lokale Windmessung am Flugpunkt. Die 3D-Pfeile folgen der Luftströmung, nicht der meteorologischen Herkunftsrichtung. Farben: grün <3, gelb 3–7, orange 7–12, rot ab 12 m/s. Fehlende oder abgelaufene Werte bleiben nicht verfügbar.
  ///
  /// In en, this message translates to:
  /// **'A model forecast is not a local wind measurement at the flight point. The 3D arrows follow the air flow, not the meteorological direction of origin. Colors: green <3, yellow 3–7, orange 7–12, red from 12 m/s. Missing or expired values do not remain available.'**
  String get commonEineModellprognoseIstKeineae457c8d;

  /// Legacy key: Eine UAS-Zone ist nicht automatisch ein vollständiges Flugverbot. Prüfe jede überlappende Einschränkung, zuständige Stelle, Zeit, Höhe und Freigabeanforderung. Farben beschreiben unterstützte Quellattribute; Blau ist keine Flugfreigabe. Räumliche Checks prüfen Geometrie und ersetzen keine rechtliche Beurteilung.
  ///
  /// In en, this message translates to:
  /// **'Restrictions vary by UAS zone. Check every overlapping restriction, the authority responsible, times, heights and authorisation requirements. Colours reflect supported source attributes. Blue does not grant flight clearance. Spatial checks cover geometry and cannot replace a legal assessment.'**
  String get commonEineUasZoneIst43501474;

  /// Legacy key: Eingabe in der Zeitzone des Geräts; gespeichert in UTC. Nur Lichtvorschau, keine Wetter- oder Freigabeprüfung.
  ///
  /// In en, this message translates to:
  /// **'Enter the date and time in the device\'\'s time zone. The app stores them in UTC. This previews lighting only. Weather and flight authorisation are unchecked.'**
  String get commonEingabeInDerZeitzone41488cc9;

  /// Legacy key: Eingabe
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get commonEingabed3a77fb1;

  /// Legacy key: en
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get commonEn094b0fe0;

  /// Legacy key: Enabled
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get commonEnableddf174a3f;

  /// Legacy key: Endgeschwindigkeit im freien Fall (m/s)
  ///
  /// In en, this message translates to:
  /// **'Free-fall terminal velocity (m/s)'**
  String get commonEndgeschwindigkeitImFreienFall86d01f28;

  /// Legacy key: Erneut versuchen
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonErneutVersuchen3234b7ec;

  /// Legacy key: Estimated
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get commonEstimatedae64c7cf;

  /// Legacy key: Estimates are not guarantees. Scenarios scale consumption; they are not statistical confidence intervals. Validate the model against measured flights. Battery condition, temperature and voltage sag can reduce usable energy.
  ///
  /// In en, this message translates to:
  /// **'Estimates are not guarantees. Scenarios scale consumption; they are not statistical confidence intervals. Validate the model against measured flights. Battery condition, temperature and voltage sag can reduce usable energy.'**
  String get commonEstimatesAreNotGuarantees31122c9b;

  /// Legacy key: Experimentell · geladene Modelloberflächen, keine exakte Wandprüfung.
  ///
  /// In en, this message translates to:
  /// **'Experimental · approximate contact with loaded model surfaces.'**
  String get commonExperimentellGeladeneModelloberflaechenKeine5d6ce860;

  /// Legacy key: Expo (0 linear, 1 weich)
  ///
  /// In en, this message translates to:
  /// **'Expo (0 linear, 1 soft)'**
  String get commonExpoLinearWeich280777be;

  /// Legacy key: Fahrplan ist nicht garantiert. Prognosen nur, wenn vom Datenlieferanten verfügbar. Gespeicherte Daten sind niemals live.
  ///
  /// In en, this message translates to:
  /// **'Timetable is not guaranteed. Forecasts only if available from the data supplier. Stored data is never live.'**
  String get commonFahrplanIstNichtGarantiertc1ec8079;

  /// Legacy key: Fehlen im Akku die Startladungsdaten, wird 100 % als editierbare Annahme verwendet. Für eine Spannungsschätzung benötigt das Drohnenprofil Hover- und Cruise-Leistung sowie Cruise-Geschwindigkeit.
  ///
  /// In en, this message translates to:
  /// **'If starting charge is unknown, 100% is used as an editable assumption. Estimating voltage requires the drone profile to specify hover power, cruise power and cruise speed.'**
  String get commonFehlenImAkkuDie64009d59;

  /// Legacy key: First coordinate: {0}, {1} · WGS84
  ///
  /// In en, this message translates to:
  /// **'First coordinate: {arg0}, {arg1} · WGS84'**
  String commonFirstCoordinateWgsbca0344d(String arg0, String arg1);

  /// Legacy key: Flug & Bedienung
  ///
  /// In en, this message translates to:
  /// **'Flight & controls'**
  String get commonFlugBedienung59a0edfe;

  /// Legacy key: Flugaufzeichnung
  ///
  /// In en, this message translates to:
  /// **'Flight recording'**
  String get commonFlugaufzeichnung0cfe3bb1;

  /// Legacy key: Flugeigenschaften
  ///
  /// In en, this message translates to:
  /// **'Flight characteristics'**
  String get commonFlugeigenschaften5e125e21;

  /// Legacy key: Flugeinstellungen
  ///
  /// In en, this message translates to:
  /// **'Flight settings'**
  String get commonFlugeinstellungen51e6bd4a;

  /// Legacy key: Flugrouten
  ///
  /// In en, this message translates to:
  /// **'Flight routes'**
  String get commonFlugrouten39801473;

  /// Legacy key: FPV planned: verify observer requirements, direct visual contact and communication.
  ///
  /// In en, this message translates to:
  /// **'FPV planned: verify observer requirements, direct visual contact and communication.'**
  String get commonFpvPlannedVerifyObservera86fbfbe;

  /// Legacy key: FPVManager CSV v1: time_s,airspeed_m_s,voltage_v,current_a (groundspeed_m_s is also accepted).
  /// EdgeTX: Date, Time, GSpd(kmh/km/h/m/s/kts), Curr(A), VFAS(V) or Bat(V).
  /// Use a single voltage and speed column. UTF-8, decimal dot, 2–20000 rows, up to 4 MiB, gaps ≤30 s. Missing measurements are rejected. See docs/preflight.md for an example.
  ///
  /// In en, this message translates to:
  /// **'FPVManager CSV v1: time_s,airspeed_m_s,voltage_v,current_a (groundspeed_m_s is also accepted).\nEdgeTX: Date, Time, GSpd(kmh/km/h/m/s/kts), Curr(A), VFAS(V) or Bat(V).\nUse a single voltage and speed column. UTF-8, decimal dot, 2–20000 rows, up to 4 MiB, gaps ≤30 s. Missing measurements are rejected. See docs/preflight.md for an example.'**
  String get commonFpvmanagerCsvVTime07c740c7;

  /// Legacy key: FPVManager speichert persönliche Einträge auf dem Gerät. iOS kann sie in seine Gerätesicherung aufnehmen. Beim Zentrieren und Folgen können Online-Kacheln den Standortbereich erkennen lassen. FOSSGIS protokolliert Routenanfragen. Open-Meteo löscht seine Protokolle laut Anbieter nach 90 Tagen.
  ///
  /// In en, this message translates to:
  /// **'FPVManager stores personal records on the device. iOS can include them in device backups. Online tiles can reveal your location area when you center or follow. FOSSGIS logs route requests. Open-Meteo says it deletes logs after 90 days.'**
  String get commonFpvmanagerSpeichertPersoenlicheEintraegea3c540bd;

  /// Legacy key: Frequency
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get commonFrequency89836a87;

  /// Legacy key: Fresh: innerhalb der Abrufrichtlinie. Stale/expired: veraltet oder abgelaufen. Unavailable: kein nutzbarer Datenstand. Refresh failed: die Aktualisierung schlug fehl; ein vorheriger Stand kann noch angezeigt werden. Quellenstatus und Warnungen stehen weiterhin beim jeweiligen Werkzeug. Keine Anzeige garantiert einen sicheren oder erlaubten Flug.
  ///
  /// In en, this message translates to:
  /// **'Fresh: within the Retrieval Policy. Stale/expired: outdated or expired. Unavailable: no usable data level. Refresh failed: the update failed; a previous status can still be displayed. Source status and warnings remain with the respective tool. No display guarantees a safe or allowed flight.'**
  String get commonFreshInnerhalbDerAbrufrichtlinie329c6fa9;

  /// Legacy key: Für dieses Einsatzprodukt ist kein georeferenzierter, begrenzt lesbarer RGB-GeoTIFF mit bestätigter Projektion hinterlegt. Kein Kartenbild erfunden.
  ///
  /// In en, this message translates to:
  /// **'No georeferenced, limited readable RGB geoTIFF with confirmed projection is stored for this application product. No map image invented.'**
  String get commonFuerDiesesEinsatzproduktIst01b0accb;

  /// Legacy key: Gebiet: {0}, {1} · 30 km · maximal 100 Detektoren
  ///
  /// In en, this message translates to:
  /// **'Area: {arg0}, {arg1} · 30 km · maximum 100 detectors'**
  String commonGebietKmMaximalDetektoren3b49fe28(String arg0, String arg1);

  /// Legacy key: Gefahr
  ///
  /// In en, this message translates to:
  /// **'Danger'**
  String get commonGefahr7a20fb89;

  /// Legacy key: Geländehöhe
  ///
  /// In en, this message translates to:
  /// **'Terrain elevation'**
  String get commonGelaendehoehe77ccc7f0;

  /// Legacy key: Geländehöhe abfragen
  ///
  /// In en, this message translates to:
  /// **'Check terrain height'**
  String get commonGelaendehoeheAbfragencba121dc;

  /// Legacy key: Gemessene Werte
  ///
  /// In en, this message translates to:
  /// **'Values measured'**
  String get commonGemesseneWerte1e2beb80;

  /// Legacy key: Geometric visibility and Fresnel clearance are approximations, not measured signal quality or a guaranteed communication range.
  ///
  /// In en, this message translates to:
  /// **'Geometric visibility and Fresnel clearance are approximations, not measured signal quality or a guaranteed communication range.'**
  String get commonGeometricVisibilityAndFresnelcc5d61f4;

  /// Legacy key: Gewässer und Aktualität
  ///
  /// In en, this message translates to:
  /// **'Waters and timeliness'**
  String get commonGewaesserUndAktualitaet3be29a45;

  /// Legacy key: Grafik & Licht
  ///
  /// In en, this message translates to:
  /// **'Graphics & lighting'**
  String get commonGrafikLichtfef9954a;

  /// Legacy key: Grafik & Tageszeit
  ///
  /// In en, this message translates to:
  /// **'Graphics & time of day'**
  String get commonGrafikTageszeitac9c3755;

  /// Legacy key: Grenzen
  ///
  /// In en, this message translates to:
  /// **'Boundaries'**
  String get commonGrenzend6f52947;

  /// Legacy key: Größte publizierte Verzögerung: {0} min · Vergleichswert, nicht zur Ankunftszeit addiert
  ///
  /// In en, this message translates to:
  /// **'Largest published delay: {arg0} min · Comparable value, not added to arrival time'**
  String commonGroesstePublizierteVerzoegerungMinc0ec7c7c(String arg0);

  /// Legacy key: Height conversion: CHGeo2004 + HTRANS → ETRS89 ellipsoid (WGS84 approximation). For single Point obstacles with valid AGL, the rendered marker and height stem use local Cesium terrain + source AGL; the source top AMSL remains listed above and may differ. Cable vertices that match a unique published mast (within 2 m horizontally and 5 m in source top elevation) follow its displayed top; offsets between matched supports are interpolated. This is an approximate display correction, not surveyed cable geometry. Unmatched sections retain source heights. Route checks use original source elevations.
  ///
  /// In en, this message translates to:
  /// **'Height conversion: CHGeo2004 + HTRANS → ETRS89 ellipsoid (WGS84 approximation). For single Point obstacles with valid AGL, the rendered marker and height stem use local Cesium terrain + source AGL; the source top AMSL remains listed above and may differ. Cable vertices that match a unique published mast (within 2 m horizontally and 5 m in source top elevation) follow its displayed top; offsets between matched supports are interpolated. This is an approximate display correction, not surveyed cable geometry. Unmatched sections retain source heights. Route checks use original source elevations.'**
  String get commonHeightConversionChgeoHtranscc1a7473;

  /// Legacy key: Hilfe & Hinweise
  ///
  /// In en, this message translates to:
  /// **'Help & information'**
  String get commonHilfeHinweise1f11bc49;

  /// Legacy key: Hilfe zur Karte
  ///
  /// In en, this message translates to:
  /// **'Map help'**
  String get commonHilfeZurKarte2a98c570;

  /// Legacy key: Hindernisse und Funkabschattung
  ///
  /// In en, this message translates to:
  /// **'Obstacles and wireless shading'**
  String get commonHindernisseUndFunkabschattunga9ce1773;

  /// Legacy key: Hinzufügen
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonHinzufuegenf0d37b9d;

  /// Legacy key: Höchstgeschwindigkeit (m/s)
  ///
  /// In en, this message translates to:
  /// **'Maximum speed (m/s)'**
  String get commonHoechstgeschwindigkeitMS7904c398;

  /// Legacy key: Höhenbezug
  ///
  /// In en, this message translates to:
  /// **'Height reference'**
  String get commonHoehenbezug920e5815;

  /// Legacy key: {0} horizontal · {1} 3D
  /// Airspeed {2} m/s · {3} · clearance {4}
  ///
  /// In en, this message translates to:
  /// **'{arg0} horizontal · {arg1} 3D\nAirspeed {arg2} m/s · {arg3} · clearance {arg4}'**
  String commonHorizontalDAirspeedM069070e6(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
  );

  /// Legacy key: Horizontal WGS84 geometry only, including boundary contact. Route segments are straight between waypoints. Height limits, activation times and legal applicability are not evaluated. This check is not flight authorization.
  ///
  /// In en, this message translates to:
  /// **'Horizontal WGS84 geometry only, including boundary contact. Route segments are straight between waypoints. Height limits, activation times and legal applicability are not evaluated. This check is not flight authorization.'**
  String get commonHorizontalWgsGeometryOnly45382b9e;

  /// Legacy key: Horizontales Sichtfeld (°)
  ///
  /// In en, this message translates to:
  /// **'Horizontal field of view (°)'**
  String get commonHorizontalesSichtfeldae3aaf25;

  /// Legacy key: Hover power
  ///
  /// In en, this message translates to:
  /// **'Hover power'**
  String get commonHoverPowerbaf23552;

  /// Legacy key: Im Bereich Bodenrouten wählst du ausdrücklich „Zu Fuß“ oder „Velo“. Nach deiner Zustimmung werden Start und Ziel an die dazu passenden FOSSGIS-/OSRM-Profile gesendet. Berechnete und importierte Routen bleiben als eigene lokale Datensätze auch ohne Netz verfügbar und werden mit dem persönlichen Backup gesichert. GPX erhält den Aktivitätsmodus und vorhandene Quellenhöhen, ohne daraus AGL-Höhen zu erzeugen. Unbekannte GPX-Typen benötigen den gewählten Importmodus; zusätzliche oder nicht unterstützte Angaben werden gemeldet. Ein gespeicherter Linienverlauf bestätigt keine aktuelle Öffnung. Der Bereich bietet Planung und Austausch; die bisherige Autonavigation ist eigenständig.
  ///
  /// In en, this message translates to:
  /// **'In the area of ground routes, you explicitly select \"On foot\" or \"Velo\". After your consent, start and destination are sent to the corresponding FOSSGIS/OSRM profiles. Calculated and imported routes remain available as own local datasets even without a network and are backed up with the personal backup. GPX receives the activity mode and existing source heights without generating AGL heights. Unknown GPX types require the selected import mode; additional or unsupported information is reported. A stored line history does not confirm any current opening. The area provides planning and exchange; the previous autonavigation is independent.'**
  String get commonImBereichBodenroutenWaehlstf1272516;

  /// Legacy key: Import locally
  ///
  /// In en, this message translates to:
  /// **'Import locally'**
  String get commonImportLocallycfc01f3f;

  /// Legacy key: Importieren
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImportieren7d4a3f2a;

  /// Legacy key: Incomplete check: geometry, candidate or calculation limits were reached. Some obstacles were not evaluated.
  ///
  /// In en, this message translates to:
  /// **'Incomplete check: geometry, candidate or calculation limits were reached. Some obstacles were not evaluated.'**
  String get commonIncompleteCheckGeometryCandidate8ab13e83;

  /// Legacy key: JPEG, PNG or WebP · up to 12 MiB and 16 MP each. Photos are resized and stored locally.
  ///
  /// In en, this message translates to:
  /// **'JPEG, PNG or WebP · up to 12 MiB and 16 MP each. Photos are resized and stored locally.'**
  String get commonJpegPngOrWebpe13c3bbf;

  /// Legacy key: JSON mit EPSG:4979, Quelle und separatem Kollisionsmesh. GLB/IFC werden nicht direkt unterstützt.
  ///
  /// In en, this message translates to:
  /// **'JSON with EPSG:4979, source and separate collision mesh. GLB/IFC are not supported directly.'**
  String get commonJsonMitEpsgQuellef95a2fe5;

  /// Legacy key: kacory
  ///
  /// In en, this message translates to:
  /// **'kacory'**
  String get commonKacory5617237a;

  /// Legacy key: Kamera & Anzeige
  ///
  /// In en, this message translates to:
  /// **'Camera & display'**
  String get commonKameraAnzeige6c89d080;

  /// Legacy key: Kamera & HUD
  ///
  /// In en, this message translates to:
  /// **'Camera & HUD'**
  String get commonKameraHudd79e87be;

  /// Legacy key: Kameraneigung
  ///
  /// In en, this message translates to:
  /// **'Camera tilt'**
  String get commonKameraneigung4c3e596e;

  /// Legacy key: Kameraneigung nach oben (°)
  ///
  /// In en, this message translates to:
  /// **'Upward camera tilt (°)'**
  String get commonKameraneigungNachOben943b5e57;

  /// Legacy key: „Karte & Ansicht“ bündelt Karte, Luftraum, Hindernisse und OSINT. Satellit, Topo und Relief sind Hintergrundkarten; Straßen, Beschriftungen und gespeicherte Spots sind unabhängig schaltbar. Beschriftungen zeigen eine begrenzte Auswahl Schweizer Orts- und Straßennamen. Seltene Werkzeuge und Metadaten lassen sich bei Bedarf öffnen; laufende Fehler und Datenlücken bleiben sichtbar.
  ///
  /// In en, this message translates to:
  /// **'\"Map & View\" bundles map, airspace, obstacles and OSINT. Satellite, topo and relief are background maps; streets, labels and saved spots can be switched independently. Labels show a limited selection of Swiss local and street names. Rare tools and metadata can be opened if necessary; current errors and data gaps remain visible.'**
  String get commonKarteAnsichtBuendeltKarte719d6808;

  /// Legacy key: Karte & Ansicht
  ///
  /// In en, this message translates to:
  /// **'Map & view'**
  String get commonKarteAnsichtb4cd1571;

  /// Legacy key: Karte und Beschriftungen
  ///
  /// In en, this message translates to:
  /// **'Map and labels'**
  String get commonKarteUndBeschriftungen20474dfe;

  /// Legacy key: Karte und laufende Aktivitäten
  ///
  /// In en, this message translates to:
  /// **'Map and current activities'**
  String get commonKarteUndLaufendeAktivitaeten4df7dcc2;

  /// Legacy key: Karte zurücksetzen
  ///
  /// In en, this message translates to:
  /// **'Reset map'**
  String get commonKarteZuruecksetzend562ce9b;

  /// Legacy key: Kartenbewegung beendet die Verfolgung.
  ///
  /// In en, this message translates to:
  /// **'Moving the map stops location following.'**
  String get commonKartenbewegungBeendetDieVerfolgung79535231;

  /// Legacy key: Kartenebenen
  ///
  /// In en, this message translates to:
  /// **'Sides'**
  String get commonKartenebenen83ea2698;

  /// Legacy key: Kartenpunkt, Ort oder Route wählen
  ///
  /// In en, this message translates to:
  /// **'Select map point, location or route'**
  String get commonKartenpunktOrtOderRoute53c79c56;

  /// Legacy key: Kartenstartwerte gelten beim App-Start, Aktivieren oder Speichern des aktiven Profils. Spätere Änderungen auf der Karte bleiben bis zur nächsten Aktivierung oder zum Neustart erhalten. Während Bodenansicht, Simulation, Navigation oder pausiertem Renderer werden Startwerte zurückgestellt und erst danach angewendet. Kamera, Auswahl, laufende Steuerung, Formulare und persönliche Datensätze werden beim Wechsel nicht zurückgesetzt. Ohne Profil bleibt die aktuelle Karte erhalten.
  ///
  /// In en, this message translates to:
  /// **'Card start values are valid for the app start, activate or save the active profile. Later changes on the map remain until the next activation or restart. During ground view, simulation, navigation or paused renderer, start values are reset and applied only afterwards. Camera, selection, running control, forms and personal records are not reset when switching. Without profile, the current map is retained.'**
  String get commonKartenstartwerteGeltenBeimApp3fbf4f32;

  /// Legacy key: Kein Online-Nachladen für Grundkarte und Gelände, auch nach Neustart. Live-Daten können weiterhin online sein.
  ///
  /// In en, this message translates to:
  /// **'Base map and terrain stay cache-only after restart. Live data can still use the network.'**
  String get commonKeinOnlineNachladenFuer3b0d241a;

  /// Legacy key: Keine
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonKeine3ce60e74;

  /// Legacy key: Keine Treffer bedeuten nicht, dass es keine Ladestationen gibt.
  ///
  /// In en, this message translates to:
  /// **'No hits don\'\'t mean there are no charging stations.'**
  String get commonKeineTrefferBedeutenNicht4cb792ac;

  /// Legacy key: Keine Treffer bedeuten nicht, dass keine Anlage vorhanden ist.
  ///
  /// In en, this message translates to:
  /// **'No hits do not mean that there is no attachment.'**
  String get commonKeineTrefferBedeutenNichtdf8f1b9e;

  /// Legacy key: Keys are stored locally using encrypted OS-backed storage, not app preferences.
  ///
  /// In en, this message translates to:
  /// **'Keys are stored locally using encrypted OS-backed storage, not app preferences.'**
  String get commonKeysAreStoredLocally5e3f356a;

  /// Legacy key: Koordinaten, Ort oder Straße
  ///
  /// In en, this message translates to:
  /// **'Coordinates, place or street'**
  String get commonKoordinatenOrtOderStrasseed101593;

  /// Legacy key: Koordinaten und Höhen
  ///
  /// In en, this message translates to:
  /// **'Coordinates and heights'**
  String get commonKoordinatenUndHoehene15ceca0;

  /// Legacy key: Kritische Zellspannung (V)
  ///
  /// In en, this message translates to:
  /// **'Critical voltage (V/cell)'**
  String get commonKritischeZellspannungVc0450582;

  /// Legacy key: latitude,longitude,height_m_agl,radius_m,kind,source
  /// Kinds: building, vegetation, other. Up to 100 observations. Heights 0–1000 m AGL, radius 1–1000 m.
  ///
  /// In en, this message translates to:
  /// **'latitude,longitude,height_m_agl,radius_m,kind,source\nKinds: building, vegetation, other. Up to 100 observations. Heights 0–1000 m AGL, radius 1–1000 m.'**
  String get commonLatitudeLongitudeHeightM29549b09;

  /// Legacy key: Lawineninformationen
  ///
  /// In en, this message translates to:
  /// **'Lawineninformationen'**
  String get commonLawineninformationen505b7525;

  /// Legacy key: Leave unknown values empty. Identify each entered value as measured, estimated or source not specified. Editing a number resets its previous source.
  ///
  /// In en, this message translates to:
  /// **'Leave unknown values empty. Identify each entered value as measured, estimated or source not specified. Editing a number resets its previous source.'**
  String get commonLeaveUnknownValuesEmptyc1fa72a7;

  /// Legacy key: Links: Bewegung · Rechts: Blick · E/Q: Höhe
  ///
  /// In en, this message translates to:
  /// **'Left: movement · Right: look · E/Q: altitude'**
  String get commonLinksBewegungRechtsBlickf668a7b3;

  /// Legacy key: Links: Gas / Yaw · Rechts: Pitch / Roll
  ///
  /// In en, this message translates to:
  /// **'Left: throttle / yaw · Right: pitch / roll'**
  String get commonLinksGasYawRechtsd7f829e1;

  /// Legacy key: Loading…
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading33ce4174;

  /// Legacy key: Löschen
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonLoeschenffa5a8a7;

  /// Legacy key: Lokal und online
  ///
  /// In en, this message translates to:
  /// **'Local and online'**
  String get commonLokalUndOnline5fe8b49a;

  /// Legacy key: Luftfahrthindernisse
  ///
  /// In en, this message translates to:
  /// **'Air traffic barriers'**
  String get commonLuftfahrthindernissef4bb6756;

  /// Legacy key: Luftraum und Flugvorbereitung
  ///
  /// In en, this message translates to:
  /// **'Airspace and flight preparation'**
  String get commonLuftraumUndFlugvorbereitung28d1eda6;

  /// Legacy key: Manual assumption, not an automatically verified forecast.
  ///
  /// In en, this message translates to:
  /// **'Manual assumption, not an automatically verified forecast.'**
  String get commonManualAssumptionNotAn31019e80;

  /// Legacy key: Map Layers
  ///
  /// In en, this message translates to:
  /// **'Map Layers'**
  String get commonMapLayerse2967959;

  /// Legacy key: Map layers
  ///
  /// In en, this message translates to:
  /// **'Map layers'**
  String get commonMapLayersfdee4317;

  /// Legacy key: Map: orange = potential obstruction, purple = Fresnel intrusion, cyan = no sampled obstruction, gray = unknown. The selected path shows the configured Fresnel envelope.
  ///
  /// In en, this message translates to:
  /// **'Map: orange = potential obstruction, purple = Fresnel intrusion, cyan = no sampled obstruction, gray = unknown. The selected path shows the configured Fresnel envelope.'**
  String get commonMapOrangePotentialObstructionbe96635a;

  /// Legacy key: Markierte Puffer um veröffentlichte Punkte/Linien sind Planungshilfen. Sie definieren weder rechtlichen Abstand noch vertikale Freigängigkeit. Funk-LOS/Fresnel prüft unterstützte Geländedaten und Annahmen; Gebäude, Vegetation und nicht erfasste Objekte können weiterhin abschatten. Fehlende Hindernisse oder freie Geometrie sind kein Sicherheitsnachweis.
  ///
  /// In en, this message translates to:
  /// **'Marked buffers around published points/lines are planning aids. They do not define legal distance nor vertical free-access. Funk-LOS/Fresnel checks supported terrain data and assumptions; buildings, vegetation and undetected objects can continue to shade. Missing obstacles or free geometry are not a security evidence.'**
  String get commonMarkiertePufferUmVeroeffentlichte170a2673;

  /// Legacy key: Maximaler Schub / Gewicht
  ///
  /// In en, this message translates to:
  /// **'Maximum thrust-to-weight ratio'**
  String get commonMaximalerSchubGewichtbf903e1b;

  /// Legacy key: Maximum climb rate
  ///
  /// In en, this message translates to:
  /// **'Maximum climb rate'**
  String get commonMaximumClimbRate97079473;

  /// Legacy key: Maximum power
  ///
  /// In en, this message translates to:
  /// **'Maximum power'**
  String get commonMaximumPower96af2765;

  /// Legacy key: Maximum speed
  ///
  /// In en, this message translates to:
  /// **'Maximum speed'**
  String get commonMaximumSpeedb02bf3de;

  /// Legacy key: Maximum transmitter power
  ///
  /// In en, this message translates to:
  /// **'Maximum transmitter power'**
  String get commonMaximumTransmitterPower654a8d01;

  /// Legacy key: Measured
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get commonMeasured9550373e;

  /// Legacy key: Measured hourly station averages (No/m³, pollen grains per cubic metre); not a forecast or an exposure estimate at the selected spot.
  ///
  /// In en, this message translates to:
  /// **'Measured hourly station averages (No/m³, pollen grains per cubic metre); not a forecast or an exposure estimate at the selected spot.'**
  String get commonMeasuredHourlyStationAverages6b75bd38;

  /// Legacy key: Mein Standort
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get commonMeinStandort98425c52;

  /// Legacy key: Messstationen
  ///
  /// In en, this message translates to:
  /// **'Measuring stations'**
  String get commonMessstationenf5f4587a;

  /// Legacy key: MeteoSwiss-Stationswerte sind Messungen an einem einzelnen Standort; Wind und Böen stehen im Quellenformat km/h, Niederschlag als Summe über zehn Minuten. Die Messzeiten sind UTC und werden zusätzlich lokal angezeigt. Sie beschreiben kein vollständiges Windfeld und ändern den Simulatorwind nicht. Fehlende Qualitätsflags bleiben unbekannt.
  ///
  /// In en, this message translates to:
  /// **'MeteoSwiss station values are measurements at a single location; wind and gusts are in the source format km/h, precipitation as a sum of ten minutes. The measuring times are UTC and are additionally displayed locally. They do not describe a complete wind field and do not change the simulator wind. Missing quality flags remain unknown.'**
  String get commonMeteoswissStationswerteSindMessungen2c9d236f;

  /// Legacy key: Method, sources & limits
  ///
  /// In en, this message translates to:
  /// **'Method, sources & limits'**
  String get commonMethodSourcesLimits2cadbcdb;

  /// Legacy key: Missing tiles remain unavailable. Live data layers and API actions are separate and may still use the network.
  ///
  /// In en, this message translates to:
  /// **'Missing tiles remain unavailable. Live data layers and API actions are separate and may still use the network.'**
  String get commonMissingTilesRemainUnavailable2b39e068;

  /// Legacy key: Mittelpunkt auf dem Globe wählen oder Koordinaten eingeben, Radius bis 25 km und gewünschte Details/Assets wählen. Web bietet zusätzlich die gesamte Schweiz. Download und Aufbereitung benötigen Zeit, freien Speicher und eine geöffnete App. Quelllücken und gewählte Details begrenzen die Abdeckung.
  ///
  /// In en, this message translates to:
  /// **'Select the center on the globe or enter coordinates, select radius up to 25 km and desired details/assets. Web also offers the entire of Switzerland. Download and preparation require time, free memory and an open app. Source gaps and selected details limit the coverage.'**
  String get commonMittelpunktAufDemGlobec923e1bf;

  /// Legacy key: Mobilität & OSINT
  ///
  /// In en, this message translates to:
  /// **'Mobility & OSINT'**
  String get commonMobilitaetOsint610c90a7;

  /// Legacy key: Model wind at 10 m and 80 m is not a prediction of local rotor turbulence. Valleys, ridges, obstacles and thermals may cause major deviations.
  ///
  /// In en, this message translates to:
  /// **'Model wind at 10 m and 80 m is not a prediction of local rotor turbulence. Valleys, ridges, obstacles and thermals may cause major deviations.'**
  String get commonModelWindAtM9f419984;

  /// Legacy key: Modell und Messung
  ///
  /// In en, this message translates to:
  /// **'Model and measurement'**
  String get commonModellUndMessung5e4ffe89;

  /// Legacy key: Motor-Ansprechzeit (s)
  ///
  /// In en, this message translates to:
  /// **'Motor response time (s)'**
  String get commonMotorAnsprechzeitS5a0796fd;

  /// Legacy key: Motor count
  ///
  /// In en, this message translates to:
  /// **'Motor count'**
  String get commonMotorCount7eb9729b;

  /// Legacy key: Move the map to a place, then tap the map to set your first waypoint.
  ///
  /// In en, this message translates to:
  /// **'Move the map to a place, then tap the map to set your first waypoint.'**
  String get commonMoveTheMapTob0c48a5b;

  /// Legacy key: Name, description, category or tags
  ///
  /// In en, this message translates to:
  /// **'Name, description, category or tags'**
  String get commonNameDescriptionCategoryOr5d2460f9;

  /// Legacy key: Natur und Sperrungen
  ///
  /// In en, this message translates to:
  /// **'Nature and closures'**
  String get commonNaturUndSperrungen058761a3;

  /// Legacy key: Navigation und Mobilität
  ///
  /// In en, this message translates to:
  /// **'Navigation and mobility'**
  String get commonNavigationUndMobilitaet625d3f0a;

  /// Legacy key: Navigation und Verkehr
  ///
  /// In en, this message translates to:
  /// **'Navigation and transport'**
  String get commonNavigationUndVerkehredf4cfaf;

  /// Legacy key: Neuschneesumme (1 h)
  ///
  /// In en, this message translates to:
  /// **'New snow sum (1 h)'**
  String get commonNeuschneesummeH10eeb220;

  /// Legacy key: Next
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNextbc981983;

  /// Legacy key: Niederschlag und großräumiger Regen sind Summen der vorangegangenen Stunde (mm), Neuschnee in cm, Schneehöhe in m. Eine Regenrate oder Niederschlagsart wird daraus nicht abgeleitet.
  ///
  /// In en, this message translates to:
  /// **'Precipitation and large-scale rain are sums of the previous hour (mm), new snow in cm, snow height in m. A rain rate or type of precipitation is not derived from it.'**
  String get commonNiederschlagUndGrossraeumigerRegen09d9c44f;

  /// Legacy key: Niederschlagssumme (1 h)
  ///
  /// In en, this message translates to:
  /// **'Precipitation sum (1 h)'**
  String get commonNiederschlagssummeHb61d9c9a;

  /// Legacy key: No
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo816c52fd;

  /// Legacy key: No building or canopy service is connected. Import known local footprints as circular AGL height observations. These are approximate site observations, not a complete surface model.
  ///
  /// In en, this message translates to:
  /// **'No building or canopy service is connected. Import known local footprints as circular AGL height observations. These are approximate site observations, not a complete surface model.'**
  String get commonNoBuildingOrCanopy5fb91054;

  /// Legacy key: No equipment profiles yet. Add separate configurations for radio control, video or telemetry.
  ///
  /// In en, this message translates to:
  /// **'No equipment profiles yet. Add separate configurations for radio control, video or telemetry.'**
  String get commonNoEquipmentProfilesYet41f7bf08;

  /// Legacy key: None
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone6eef6648;

  /// Legacy key: Not recorded
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get commonNotRecorded305cc364;

  /// Legacy key: Notes
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commonNotes70440046;

  /// Legacy key: Nur nach manuellem Start · begrenzte Abfrage, keine nationalen Downloads
  ///
  /// In en, this message translates to:
  /// **'Only after manual start · limited query, no national downloads'**
  String get commonNurNachManuellemStartca69930e;

  /// Legacy key: Observation, not forecast. Missing pixels and missing dates must not be interpreted as dry weather.
  ///
  /// In en, this message translates to:
  /// **'Observation, not forecast. Missing pixels and missing dates must not be interpreted as dry weather.'**
  String get commonObservationNotForecastMissingb7760aa1;

  /// Legacy key: Offizielle BAKOM-Standorte. Stationstyp, Leistungsklasse und Technologie werden nur nach Quellenangabe angezeigt. Die Koordinaten bezeichnen den ersten Mast einer Station. Sie sind keine Hindernisgeometrie und messen keine FPV-Abdeckung.
  ///
  /// In en, this message translates to:
  /// **'Official BAKOM locations. Station type, performance class and technology are displayed only according to source. The coordinates indicate the first mast of a station. They are not obstacle geometry and do not measure FPV coverage.'**
  String get commonOffizielleBakomStandorteStationstyp81519366;

  /// Legacy key: Offline: flat map shown. Terrain heights are unavailable.
  ///
  /// In en, this message translates to:
  /// **'Offline: flat map shown. Terrain heights are unavailable.'**
  String get commonOfflineFlatMapShownaa2963ed;

  /// Legacy key: Offline-Karten und Backups
  ///
  /// In en, this message translates to:
  /// **'Offline maps and backups'**
  String get commonOfflineKartenUndBackups5cb5d797;

  /// Legacy key: Offline-Paket grob {0} MiB (Karteninhalt variiert), maximal 64 MiB. Originaldateien für die Aufbereitung können deutlich größer sein.{1}
  ///
  /// In en, this message translates to:
  /// **'Offline package coarse {arg0} MiB (map content varies), maximum 64 MiB. Original files for processing can be significantly larger.{arg1}'**
  String commonOfflinePaketGrobMibeae634d2(String arg0, String arg1);

  /// Legacy key: Offline und persönliche Daten
  ///
  /// In en, this message translates to:
  /// **'Offline and personal data'**
  String get commonOfflineUndPersoenlicheDaten7b8d1b0c;

  /// Legacy key: One pair per line. Level flight only, without climb power. No extrapolation outside the curve.
  ///
  /// In en, this message translates to:
  /// **'One pair per line. Level flight only, without climb power. No extrapolation outside the curve.'**
  String get commonOnePairPerLine94168101;

  /// Legacy key: 1. Open current BAZL map, check every applicable overlapping zone and contact the competent authority when necessary.
  ///
  /// In en, this message translates to:
  /// **'1. Open current BAZL map, check every applicable overlapping zone and contact the competent authority when necessary.'**
  String get commonOpenCurrentBazlMap31b230a4;

  /// Legacy key: Open-Meteo · CC BY 4.0; kostenloser Zugang für nicht kommerzielle Nutzung. Aktueller Modellwind wird bei aktiver Darstellung oder im Flug alle 15 Minuten aktualisiert. Prognosen verwenden den nächsten verfügbaren Stundenwert. Sonnenzeit und Windzeit sind unabhängig. Zwischen Rasterpunkten und Modellhöhen (10, 80, 120, 180 m AGL) werden Windvektoren interpoliert. Außerhalb bekannter Höhen wird die nächste Schicht konstant fortgesetzt. Außerhalb des geladenen Ausschnitts oder bei fehlenden Daten gibt es keinen Windeinfluss. Keine zusätzlichen künstlichen Böen und keine Berechnung von Gebäudeverwirbelungen, Thermik oder kleinräumiger Geländeströmung.
  ///
  /// In en, this message translates to:
  /// **'Open-Meteo · CC BY 4.0; free access for non-commercial use. Current model wind is updated every 15 minutes when active display or in flight. Forecasts use the next available hourly value. Sun time and wind time are independent. Wind vectors are interpolated between grid points and model heights (10, 80, 120, 180 m AGL). Outside known heights, the next layer is constantly continued. Outside of the loaded section or missing data, there is no wind influence. No additional artificial gusts and no calculation of building turbulences, thermals or small-scale terrain flow.'**
  String get commonOpenMeteoCcBy8eb16c41;

  /// Legacy key: Open settings
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get commonOpenSettingsfd7108f8;

  /// Legacy key: Optional adsb.lol community reception snapshot within 25 nautical miles (≈46 km). No automatic polling, history or extrapolation. No data is downloaded until requested. OpenSky is not used because application integration requires a written licence.
  ///
  /// In en, this message translates to:
  /// **'Optional adsb.lol community reception snapshot within 25 nautical miles (≈46 km). No automatic polling, history or extrapolation. No data is downloaded until requested. OpenSky is not used because application integration requires a written licence.'**
  String get commonOptionalAdsbLolCommunity571b79fc;

  /// Legacy key: Optional circular AGL observations, as in preflight analysis. Visible 3D buildings, forests, masts and cables are not automatically included.
  ///
  /// In en, this message translates to:
  /// **'Optional circular AGL observations, as in preflight analysis. Visible 3D buildings, forests, masts and cables are not automatically included.'**
  String get commonOptionalCircularAglObservations3ad9fcc1;

  /// Legacy key: Optional nearby points from OpenStreetMap via Overpass. Each request is initiated manually, limited to 2 km and six categories. Missing results do not prove that a facility does not exist. Never use these results as an authoritative source of drinking-water safety or access.
  ///
  /// In en, this message translates to:
  /// **'Optional nearby points from OpenStreetMap via Overpass. Each request is initiated manually, limited to 2 km and six categories. Missing results do not prove that a facility does not exist. Never use these results as an authoritative source of drinking-water safety or access.'**
  String get commonOptionalNearbyPointsFrom6d1c26fc;

  /// Legacy key: Optional · Stationspunkte, keine Masthöhen oder Signalabdeckung
  ///
  /// In en, this message translates to:
  /// **'Optional · Station points, no mast heights or signal cover'**
  String get commonOptionalStationspunkteKeineMasthoehen32868013;

  /// Legacy key: Optionaler Innenwiderstand je Zelle (Ω; 0 = aus)
  ///
  /// In en, this message translates to:
  /// **'Optional internal resistance per cell (Ω; 0 = off)'**
  String get commonOptionalerInnenwiderstandJeZelle8ca0db6d;

  /// Legacy key: Orientierung
  ///
  /// In en, this message translates to:
  /// **'Orientation'**
  String get commonOrientierung74a0fc2b;

  /// Legacy key: Ort oder Koordinaten suchen
  ///
  /// In en, this message translates to:
  /// **'Search for a place or coordinates'**
  String get commonOrtOderKoordinatenSuchen6904cb89;

  /// Legacy key: Ort suchen
  ///
  /// In en, this message translates to:
  /// **'Search for a place'**
  String get commonOrtSuchen06144b10;

  /// Legacy key: Outdoor-Karten und Messstationen
  ///
  /// In en, this message translates to:
  /// **'Outdoor maps and measuring stations'**
  String get commonOutdoorKartenUndMessstationen76975577;

  /// Legacy key: Persönliche Daten
  ///
  /// In en, this message translates to:
  /// **'Personal data'**
  String get commonPersoenlicheDatenf0cbba56;

  /// Legacy key: Persönliche Einträge bleiben lokal. Kartenanbieter sehen angeforderte Kartenausschnitte; aktivierte Beschriftungen senden ebenfalls nur den benötigten Bereich. Eine bestätigte Route sendet Start/Ziel an den Routingdienst. Orts-/Adresssuchen werden erst beim Absenden übertragen. Standortanzeige ist freiwillig und arbeitet nur im Vordergrund; es wird kein Standortverlauf angelegt.
  ///
  /// In en, this message translates to:
  /// **'Personal entries remain local. Map providers see requested map sections; activated labels also send only the required area. A confirmed route sends start/target to the routing service. Location/address searches are only transferred when sent. Location display is voluntary and works only in the foreground; no location history is created.'**
  String get commonPersoenlicheEintraegeBleibenLokal72d5b20b;

  /// Legacy key: Pfeile und Einfluss auf die Flugphysik sind unabhängig schaltbar. Eine feste Sonnen-/Mondzeit ändert die Winddaten nicht. Für eine andere Windprognose die Datenquelle/Zeit ausdrücklich wählen. Lokale Böen und Gelände-Effekte können von der Modellnäherung abweichen.
  ///
  /// In en, this message translates to:
  /// **'Arrows and influence on flight physics can be switched independently. A fixed sun/moon time does not change the wind data. For another wind forecast explicitly choose the data source/time. Local gusts and terrain effects may differ from the model approach.'**
  String get commonPfeileUndEinflussAuf9b831fb0;

  /// Legacy key: Photos
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get commonPhotosc8b2e864;

  /// Legacy key: Pitch maximal (°/s)
  ///
  /// In en, this message translates to:
  /// **'Maximum pitch rate (°/s)'**
  String get commonPitchMaximalScbf3d02c;

  /// Legacy key: Planning checks only. No flight authorisation or guarantee of terrain, obstacle or airspace clearance.
  ///
  /// In en, this message translates to:
  /// **'Planning checks only. No flight authorisation or guarantee of terrain, obstacle or airspace clearance.'**
  String get commonPlanningChecksOnlyNo5a915c9e;

  /// Legacy key: Planungshilfen
  ///
  /// In en, this message translates to:
  /// **'Planning aids'**
  String get commonPlanungshilfen4c6529d9;

  /// Legacy key: Playgrounds
  ///
  /// In en, this message translates to:
  /// **'Playgrounds'**
  String get commonPlaygrounds2472110c;

  /// Legacy key: Potential obstruction: {0}, {1} · surface {2} m WGS84 ellipsoid
  ///
  /// In en, this message translates to:
  /// **'Potential obstruction: {arg0}, {arg1} · surface {arg2} m WGS84 ellipsoid'**
  String commonPotentialObstructionSurfaceMf0e561ae(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: Power & performance
  ///
  /// In en, this message translates to:
  /// **'Power & performance'**
  String get commonPowerPerformance72b3155b;

  /// Legacy key: Preparation
  ///
  /// In en, this message translates to:
  /// **'Preparation'**
  String get commonPreparationa8bc3820;

  /// Legacy key: Profile und Auswahl sind Bestandteil persönlicher Backups. Einzelne Profile können als versionierte .fpvprofile-Datei exportiert werden. Der Import zeigt eine Vorschau und ergänzt ein inaktives Profil, ohne vorhandene Profile zu überschreiben. Unterstützt werden höchstens 32 Profile und Dateien bis 128 KiB.
  ///
  /// In en, this message translates to:
  /// **'Profiles and selection are part of personal backups. Individual profiles can be exported as versioned .fpvprofile file. The import shows a preview and adds an inactive profile without overwriting existing profiles. Up to 32 profiles and files up to 128 KiB are supported.'**
  String get commonProfileUndAuswahlSindd905de42;

  /// Legacy key: Propeller count
  ///
  /// In en, this message translates to:
  /// **'Propeller count'**
  String get commonPropellerCount0e5ac786;

  /// Legacy key: Propeller pitch
  ///
  /// In en, this message translates to:
  /// **'Propeller pitch'**
  String get commonPropellerPitchb46bd729;

  /// Legacy key: Propulsion
  ///
  /// In en, this message translates to:
  /// **'Propulsion'**
  String get commonPropulsione8ec111d;

  /// Legacy key: Protocol / system
  ///
  /// In en, this message translates to:
  /// **'Protocol / system'**
  String get commonProtocolSystemb95bcf23;

  /// Legacy key: Quelle: {0}
  ///
  /// In en, this message translates to:
  /// **'Source: {arg0}'**
  String commonQuelle25cfc7b8(String arg0);

  /// Legacy key: Quelle: Bundesamt für Energie (BFE), sharedmobility.ch – Standorte und Verfügbarkeit von Shared-Mobility-Angeboten. Daten können verzögert oder unvollständig sein. Keine Buchung oder Reservierung.
  ///
  /// In en, this message translates to:
  /// **'Source: Federal Office of Energy (SFOE), sharedmobility.ch – locations and availability of shared mobility offers. Data may be delayed or incomplete. No booking or reservation.'**
  String get commonQuelleBundesamtFuerEnergiea8a665a6;

  /// Legacy key: Radio
  ///
  /// In en, this message translates to:
  /// **'Radio'**
  String get commonRadiob11bf19e;

  /// Legacy key: Ready
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get commonReady20c7c552;

  /// Legacy key: Receiver & antenna
  ///
  /// In en, this message translates to:
  /// **'Receiver & antenna'**
  String get commonReceiverAntenna09c32a42;

  /// Legacy key: Receiver antenna characteristics
  ///
  /// In en, this message translates to:
  /// **'Receiver antenna characteristics'**
  String get commonReceiverAntennaCharacteristics8fa01aa6;

  /// Legacy key: Receiver antenna gain
  ///
  /// In en, this message translates to:
  /// **'Receiver antenna gain'**
  String get commonReceiverAntennaGain1e5045a8;

  /// Legacy key: Receiver cable / connector loss
  ///
  /// In en, this message translates to:
  /// **'Receiver cable / connector loss'**
  String get commonReceiverCableConnectorLossa4943703;

  /// Legacy key: Receiver model
  ///
  /// In en, this message translates to:
  /// **'Receiver model'**
  String get commonReceiverModel33350928;

  /// Legacy key: Receiver polarization
  ///
  /// In en, this message translates to:
  /// **'Receiver polarization'**
  String get commonReceiverPolarization24abf7a4;

  /// Legacy key: Receiver sensitivity
  ///
  /// In en, this message translates to:
  /// **'Receiver sensitivity'**
  String get commonReceiverSensitivity1118dfab;

  /// Legacy key: Receiver specifications / operating mode
  ///
  /// In en, this message translates to:
  /// **'Receiver specifications / operating mode'**
  String get commonReceiverSpecificationsOperatingMode752249f6;

  /// Legacy key: Recorded trajectory, north up, with height profile. {0} metres.
  ///
  /// In en, this message translates to:
  /// **'Recorded trajectory, north up, with height profile. {arg0} metres.'**
  String commonRecordedTrajectoryNorthUp84f04fe5(String arg0);

  /// Legacy key: Red map segments indicate sampled terrain clearance, battery reserve, or findings from the current route checks. Open Checks for the reason; a horizontal zone match does not establish legal applicability.
  ///
  /// In en, this message translates to:
  /// **'Red map segments indicate sampled terrain clearance, battery reserve, or findings from the current route checks. Open Checks for the reason; a horizontal zone match does not establish legal applicability.'**
  String get commonRedMapSegmentsIndicate9cf68571;

  /// Legacy key: Reference voltage
  ///
  /// In en, this message translates to:
  /// **'Reference voltage'**
  String get commonReferenceVoltage24d76e09;

  /// Legacy key: Refresh
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefresh56e3badc;

  /// Legacy key: Regen · großräumig (1 h)
  ///
  /// In en, this message translates to:
  /// **'Rain · Large (1 h)'**
  String get commonRegenGrossraeumigH0f1e72be;

  /// Legacy key: Regionale Indikatoren und satellitengestützte Modelle, keine Messung der lokalen Bodenfeuchte. Weder Feuerverbote noch Wasserentnahmebeschränkungen werden aus diesen Karten abgeleitet. Fehlende Kacheln sind keine Entwarnung.
  ///
  /// In en, this message translates to:
  /// **'Regional indicators and satellite-based models, no measurement of local soil moisture. Neither fire bans nor water withdrawal restrictions are derived from these maps. Lack of tiles are no warning.'**
  String get commonRegionaleIndikatorenUndSatellitengestuetzte10059e46;

  /// Legacy key: Relief
  ///
  /// In en, this message translates to:
  /// **'Relief'**
  String get commonReliefbe53bb74;

  /// Legacy key: Reload
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get commonReloadcce71553;

  /// Legacy key: Remove key
  ///
  /// In en, this message translates to:
  /// **'Remove key'**
  String get commonRemoveKey582d9a78;

  /// Legacy key: Remove
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemovee963907d;

  /// Legacy key: Requests appear in provider logs. No spot names, notes or account data are sent.
  ///
  /// In en, this message translates to:
  /// **'Requests appear in provider logs. No spot names, notes or account data are sent.'**
  String get commonRequestsAppearInProviderc028be67;

  /// Legacy key: Reset
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset44c57abd;

  /// Legacy key: Results expire after 5 seconds. Flight movement, pauses, respawns and unavailable terrain can make a result unknown. Terrain publication time is not supplied by this sampling interface. Radio propagation, interference, antenna patterns and material attenuation are not modelled.
  ///
  /// In en, this message translates to:
  /// **'Results expire after 5 seconds. Flight movement, pauses, respawns and unavailable terrain can make a result unknown. Terrain publication time is not supplied by this sampling interface. Radio propagation, interference, antenna patterns and material attenuation are not modelled.'**
  String get commonResultsExpireAfterSecondsfc4e5dd8;

  /// Legacy key: Retired
  ///
  /// In en, this message translates to:
  /// **'Retired'**
  String get commonRetired37d1213e;

  /// Legacy key: Retrace the planned path, with reverse-direction wind. No return leg is added at takeoff.
  ///
  /// In en, this message translates to:
  /// **'Retrace the planned path, with reverse-direction wind. No return leg is added at takeoff.'**
  String get commonRetraceThePlannedPathec9e751c;

  /// Legacy key: Retrieved: {0}
  ///
  /// In en, this message translates to:
  /// **'Retrieved: {arg0}'**
  String commonRetrievedc0a8bd29(String arg0);

  /// Legacy key: Retry
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry9f5cd8a2;

  /// Legacy key: Return to takeoff is included by retracing the planned path, with wind recalculated in reverse.
  ///
  /// In en, this message translates to:
  /// **'Return to takeoff is included by retracing the planned path, with wind recalculated in reverse.'**
  String get commonReturnToTakeoffIs90ab579c;

  /// Legacy key: Review the saved route before real flight. Sampled motion, terrain and timing are simulated; drone and battery assignments can be added in the route editor.
  ///
  /// In en, this message translates to:
  /// **'Review the saved route before real flight. Sampled motion, terrain and timing are simulated; drone and battery assignments can be added in the route editor.'**
  String get commonReviewTheSavedRoute73d944db;

  /// Legacy key: Roll maximal (°/s)
  ///
  /// In en, this message translates to:
  /// **'Maximum roll rate (°/s)'**
  String get commonRollMaximalS70a32bd1;

  /// Legacy key: Roll, Pitch, Gas und Yaw benötigen vier verschiedene USB-Kanäle. Zuordnung und Richtung hängen von Fernsteuerung und Betriebssystem ab. Schalter lösen weder Zurücksetzen noch Beenden aus.
  ///
  /// In en, this message translates to:
  /// **'Roll, pitch, gas and yaw require four different USB channels. Assignment and direction depend on remote control and operating system. Switches do not trigger reset or exit.'**
  String get commonRollPitchGasUndf22bbf00;

  /// Legacy key: Route name
  ///
  /// In en, this message translates to:
  /// **'Route name'**
  String get commonRouteName4421bcfb;

  /// Legacy key: Routen und Ansagen sind Orientierungshilfen. Straßenregeln und die reale Situation gehen vor. Der Kompass richtet zuerst nach Norden aus; erneutes Antippen kehrt zur schrägen Verfolgungsansicht zurück. Ungenaue GPS-Signale begrenzen Richtung und Neuberechnung.
  ///
  /// In en, this message translates to:
  /// **'Routes and announcements are orientation aids. Road rules and the real situation proceed. The compass first aligns to the north; again tapping returns to the oblique tracking view. Inaccurate GPS signals limit direction and recalculation.'**
  String get commonRoutenUndAnsagenSind26c916e8;

  /// Legacy key: Routes, traffic & aircraft
  ///
  /// In en, this message translates to:
  /// **'Routes, traffic & aircraft'**
  String get commonRoutesTrafficAircraft309ea855;

  /// Legacy key: 49 sampled model points around the selected spot. Display spacing does NOT indicate actual meteorological model accuracy; no spatial interpolation. This is NOT a MeteoSwiss layer, even if MeteoSwiss is selected above.
  ///
  /// In en, this message translates to:
  /// **'49 sampled model points around the selected spot. Display spacing does NOT indicate actual meteorological model accuracy; no spatial interpolation. This is NOT a MeteoSwiss layer, even if MeteoSwiss is selected above.'**
  String get commonSampledModelPointsArounda07ce918;

  /// Legacy key: Save key
  ///
  /// In en, this message translates to:
  /// **'Save key'**
  String get commonSaveKeyf5216b3a;

  /// Legacy key: Save spots, images, equipment, routes, checklists, telemetry and planning preferences in one local file (up to 64 MiB). Public map/OSINT caches and API keys are excluded.
  ///
  /// In en, this message translates to:
  /// **'Save spots, images, equipment, routes, checklists, telemetry and planning preferences in one local file (up to 64 MiB). Public map/OSINT caches and API keys are excluded.'**
  String get commonSaveSpotsImagesEquipmentdd4221ef;

  /// Legacy key: Saved places
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get commonSavedPlaces364519ea;

  /// Legacy key: Saved spot
  ///
  /// In en, this message translates to:
  /// **'Saved spot'**
  String get commonSavedSpot64ad0674;

  /// Legacy key: Save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSaveefc007a3;

  /// Legacy key: Saving…
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get commonSaving56a2285c;

  /// Legacy key: Saving...
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get commonSavingae7e8875;

  /// Legacy key: Scale this saved route’s power curve by {0}. This is a level-flight approximation over the logged speed profile; climbs, wind, aggressive maneuvers and battery/sensor errors can distort it. The original CSV remains stored. Other routes and drone specifications are unchanged.
  ///
  /// In en, this message translates to:
  /// **'Scale this saved route’s power curve by {arg0}. This is a level-flight approximation over the logged speed profile; climbs, wind, aggressive maneuvers and battery/sensor errors can distort it. The original CSV remains stored. Other routes and drone specifications are unchanged.'**
  String commonScaleThisSavedRoutes1968fc72(String arg0);

  /// Legacy key: Schließen
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonSchliessen44424b18;

  /// Legacy key: Schneehöhe
  ///
  /// In en, this message translates to:
  /// **'Snow height'**
  String get commonSchneehoehe063f48a9;

  /// Legacy key: Schneeschuhrouten
  ///
  /// In en, this message translates to:
  /// **'Snowshoe routes'**
  String get commonSchneeschuhrouten232e5840;

  /// Legacy key: Schubkurve (0 linear, 1 quadratisch)
  ///
  /// In en, this message translates to:
  /// **'Thrust curve (0 linear, 1 quadratic)'**
  String get commonSchubkurveLinearQuadratischa35ca8b8;

  /// Legacy key: Selected globe location ({0}, {1})
  ///
  /// In en, this message translates to:
  /// **'Selected globe location ({arg0}, {arg1})'**
  String commonSelectedGlobeLocation8a849707(String arg0, String arg1);

  /// Legacy key: Send selected center, radius and categories to the public Overpass API.
  ///
  /// In en, this message translates to:
  /// **'Send selected center, radius and categories to the public Overpass API.'**
  String get commonSendSelectedCenterRadiusdd0ed3a0;

  /// Legacy key: Settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettingsc7f73bb5;

  /// Legacy key: Shared Mobility (BFE / sharedmobility.ch). Punktuelle REST-Abfrage, ohne automatische Standortüberwachung oder Reservierung.
  ///
  /// In en, this message translates to:
  /// **'Shared Mobility (SFOE / sharedmobility.ch). Pointed REST query, without automatic location monitoring or reservation.'**
  String get commonSharedMobilityBfeSharedmobility7d5c9e61;

  /// Legacy key: Sichern und teilen
  ///
  /// In en, this message translates to:
  /// **'Secure and share'**
  String get commonSichernUndTeilen9769e149;

  /// Legacy key: Sichtfeld
  ///
  /// In en, this message translates to:
  /// **'Field of view'**
  String get commonSichtfeldd835ebc7;

  /// Legacy key: SIM: Modellwert, keine echte Akkutelemetrie.
  ///
  /// In en, this message translates to:
  /// **'SIM: model estimate, not real battery telemetry.'**
  String get commonSimModellwertKeineEchte2ec26181;

  /// Legacy key: Simulierter Akku (HUD)
  ///
  /// In en, this message translates to:
  /// **'Simulated battery (HUD)'**
  String get commonSimulierterAkkuHud043eb4df;

  /// Legacy key: Situationsmeldungen und Messstellen sind verschiedene Quellen mit eigenen Tokens. TMC-Codes benötigen die passende amtliche Ortstabelle. Unverortete, abgelaufene oder unvollständige Meldungen dürfen nicht als freie Strecke gelten. Messgeschwindigkeiten sind punktuelle Beobachtungen, keine flächendeckende Live-Staukarte.
  ///
  /// In en, this message translates to:
  /// **'Situation messages and measuring points are different sources with their own tokens. TMC codes require the appropriate official location table. Unlocated, expired or incomplete messages must not be considered as a free distance. Measuring speeds are punctual observations, not a comprehensive live-stow map.'**
  String get commonSituationsmeldungenUndMessstellenSinde2636ae0;

  /// Legacy key: Some terrain tiles are unavailable. Loaded 3D terrain remains visible; heights may be missing in affected areas.
  ///
  /// In en, this message translates to:
  /// **'Some terrain tiles are unavailable. Loaded 3D terrain remains visible; heights may be missing in affected areas.'**
  String get commonSomeTerrainTilesAre771ea391;

  /// Legacy key: Source
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get commonSource6da13add;

  /// Legacy key: Source: MeteoSwiss · FSDI STAC · Swiss pollen monitoring network. Coverage is limited to published stations. Data are observations, not medical advice.
  ///
  /// In en, this message translates to:
  /// **'Source: MeteoSwiss · FSDI STAC · Swiss pollen monitoring network. Coverage is limited to published stations. Data are observations, not medical advice.'**
  String get commonSourceMeteoswissFsdiStac0fd2fd76;

  /// Legacy key: Source not specified
  ///
  /// In en, this message translates to:
  /// **'Source not specified'**
  String get commonSourceNotSpecifieda922455d;

  /// Legacy key: Source snapshot is delayed, its publication time is unknown, or the source/device clocks disagree. Retrieval/import time does not make old positions current.
  ///
  /// In en, this message translates to:
  /// **'Source snapshot is delayed, its publication time is unknown, or the source/device clocks disagree. Retrieval/import time does not make old positions current.'**
  String get commonSourceSnapshotIsDelayed341226cb;

  /// Legacy key: Source: swisstopo terrain. Values use a digital terrain model, not measured aircraft height or verified obstacle clearance.
  ///
  /// In en, this message translates to:
  /// **'Source: swisstopo terrain. Values use a digital terrain model, not measured aircraft height or verified obstacle clearance.'**
  String get commonSourceSwisstopoTerrainValues0aaf6e16;

  /// Legacy key: Specification source / measurement context
  ///
  /// In en, this message translates to:
  /// **'Specification source / measurement context'**
  String get commonSpecificationSourceMeasurementContextf57759cc;

  /// Legacy key: Speichern
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSpeichern70b73bbc;

  /// Legacy key: Sperrung
  ///
  /// In en, this message translates to:
  /// **'Blocking'**
  String get commonSperrung6e842243;

  /// Legacy key: Sperrungen und Umleitungen · Mountainbike
  ///
  /// In en, this message translates to:
  /// **'Blocks and redirections · Mountain bike'**
  String get commonSperrungenUndUmleitungenMountainbike12e5ddcf;

  /// Legacy key: Sperrungen und Umleitungen · Velo
  ///
  /// In en, this message translates to:
  /// **'Locks and redirections · Velo'**
  String get commonSperrungenUndUmleitungenVelo88b39c0a;

  /// Legacy key: Sperrungen und Umleitungen · Wandern
  ///
  /// In en, this message translates to:
  /// **'Blocks and redirections · Hiking'**
  String get commonSperrungenUndUmleitungenWanderne50fe2ab;

  /// Legacy key: Spot position · {0}, {1}
  ///
  /// In en, this message translates to:
  /// **'Spot position · {arg0}, {arg1}'**
  String commonSpotPositiond64f0e9b(String arg0, String arg1);

  /// Legacy key: Stand {0} · offline, nicht live
  ///
  /// In en, this message translates to:
  /// **'Status {arg0} · offline, not live'**
  String commonStandOfflineNichtLive42b1bd9b(String arg0);

  /// Legacy key: Start, Ziel und Reisezeit für die Abfrage an opentransportdata.swiss senden.
  ///
  /// In en, this message translates to:
  /// **'Send start, destination and travel time for query to opentransportdata.swiss.'**
  String get commonStartZielUndReisezeit1a5914f9;

  /// Legacy key: Starten und anpassen
  ///
  /// In en, this message translates to:
  /// **'Start and Customize'**
  String get commonStartenUndAnpassen92258e7a;

  /// Legacy key: Starthöhe über Grund (m)
  ///
  /// In en, this message translates to:
  /// **'Starting height above ground (m)'**
  String get commonStarthoeheUeberGrundMc947203e;

  /// Legacy key: Startladung (%) · Schätzung
  ///
  /// In en, this message translates to:
  /// **'Starting charge (%) · Estimate'**
  String get commonStartladungSchaetzung865c309f;

  /// Legacy key: Station {0}{1} · {2}, {3}
  ///
  /// In en, this message translates to:
  /// **'Station {arg0}{arg1} · {arg2}, {arg3}'**
  String commonStation5a5e3cd7(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  );

  /// Legacy key: Stau / stockender Verkehr
  ///
  /// In en, this message translates to:
  /// **'Traffic jams / stagnant traffic'**
  String get commonStauStockenderVerkehr5b47c80a;

  /// Legacy key: Steigen / Sinken maximal (m/s)
  ///
  /// In en, this message translates to:
  /// **'Maximum climb / descent rate (m/s)'**
  String get commonSteigenSinkenMaximalM011fe6b0;

  /// Legacy key: Steuerung und Simulation
  ///
  /// In en, this message translates to:
  /// **'Control and simulation'**
  String get commonSteuerungUndSimulation3a676b6f;

  /// Legacy key: Sticks
  ///
  /// In en, this message translates to:
  /// **'Sticks'**
  String get commonSticksb0cca9f9;

  /// Legacy key: Stop recording
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get commonStopRecordingee0d9dc8;

  /// Legacy key: Straße, Ort oder Meldung suchen
  ///
  /// In en, this message translates to:
  /// **'Find a street, place or message'**
  String get commonStrasseOrtOderMeldung26ebddfb;

  /// Legacy key: Straßen und Wege
  ///
  /// In en, this message translates to:
  /// **'Roads and paths'**
  String get commonStrassenUndWegea615580e;

  /// Legacy key: swisstopo terrain via Cesium, WGS84 ellipsoidal heights. The straight ECEF line accounts for Earth curvature. Targets are at most 100 m apart and each radio path is sampled at intervals of at most 25 m. Imported surface observations add their specified height within their radius. Targets beyond 50 km or with unknown altitude are marked unknown. The map shows the group of up to 128 paths around the selected result. Recalculate after route, pilot or terrain changes.
  ///
  /// In en, this message translates to:
  /// **'swisstopo terrain via Cesium, WGS84 ellipsoidal heights. The straight ECEF line accounts for Earth curvature. Targets are at most 100 m apart and each radio path is sampled at intervals of at most 25 m. Imported surface observations add their specified height within their radius. Targets beyond 50 km or with unknown altitude are marked unknown. The map shows the group of up to 128 paths around the selected result. Recalculate after route, pilot or terrain changes.'**
  String get commonSwisstopoTerrainViaCesium6cb5e495;

  /// Legacy key: Synthetisches Modell · Portale und Abmessungen geschätzt. Nur Simulation, keine reale Durchflugfreigabe.
  ///
  /// In en, this message translates to:
  /// **'Synthetic model · Portals and dimensions estimated. Simulation only, no real clearance.'**
  String get commonSynthetischesModellPortaleUnd61794358;

  /// Legacy key: Takeoff weight
  ///
  /// In en, this message translates to:
  /// **'Takeoff weight'**
  String get commonTakeoffWeightc5470a62;

  /// Legacy key: Tastatur und Funke
  ///
  /// In en, this message translates to:
  /// **'Keyboard and radio'**
  String get commonTastaturUndFunke92dc0407;

  /// Legacy key: Terrain checks sample at intervals up to 50 m. Terrain between samples, nearest-surface legal height, zone height limits, activation times and exemptions are not automatically verified.
  ///
  /// In en, this message translates to:
  /// **'Terrain checks sample at intervals up to 50 m. Terrain between samples, nearest-surface legal height, zone height limits, activation times and exemptions are not automatically verified.'**
  String get commonTerrainChecksSampleAt803435c1;

  /// Legacy key: Terrain information
  ///
  /// In en, this message translates to:
  /// **'Terrain information'**
  String get commonTerrainInformation6e2466e7;

  /// Legacy key: Terrain & radio path
  ///
  /// In en, this message translates to:
  /// **'Terrain & radio path'**
  String get commonTerrainRadioPathe61f3070;

  /// Legacy key: {0} / {1} terrain samples
  ///
  /// In en, this message translates to:
  /// **'{arg0} / {arg1} terrain samples'**
  String commonTerrainSamples1a8cac51(String arg0, String arg1);

  /// Legacy key: {0} terrain samples, at most 50 m apart horizontally. Heights interpolate linearly between waypoints; AGL applies at waypoints and does not imply terrain following.
  ///
  /// In en, this message translates to:
  /// **'{arg0} terrain samples, at most 50 m apart horizontally. Heights interpolate linearly between waypoints; AGL applies at waypoints and does not imply terrain following.'**
  String commonTerrainSamplesAtMost4dfad6d1(String arg0);

  /// Legacy key: Terrain samples do not prove continuous clearance. Small features between samples, elevation-model errors, cables, trees and other unknown obstacles can be missed. Verify the route on site and with current official information.
  ///
  /// In en, this message translates to:
  /// **'Terrain samples do not prove continuous clearance. Small features between samples, elevation-model errors, cables, trees and other unknown obstacles can be missed. Verify the route on site and with current official information.'**
  String get commonTerrainSamplesDoNote2bd895f;

  /// Legacy key: Terrain uses WGS84 ellipsoid heights. Other absolute references are preserved, but cannot yet be converted for the 3D view or clearance calculation. A * marker shows a 30 m AGL preview only.
  ///
  /// In en, this message translates to:
  /// **'Terrain uses WGS84 ellipsoid heights. Other absolute references are preserved, but cannot yet be converted for the 3D view or clearance calculation. A * marker shows a 30 m AGL preview only.'**
  String get commonTerrainUsesWgsEllipsoid7e8c1f46;

  /// Legacy key: The ASTRA API rejects direct browser requests (CORS), before a token can be sent. Use Android for direct refresh, or import a DATEX XML snapshot downloaded with your own registered access. No public proxy is used.
  ///
  /// In en, this message translates to:
  /// **'The ASTRA API rejects direct browser requests (CORS), before a token can be sent. Use Android for direct refresh, or import a DATEX XML snapshot downloaded with your own registered access. No public proxy is used.'**
  String get commonTheAstraApiRejectsdfbcd277;

  /// Legacy key: The default 120 m AGL ceiling is a Swiss open-category planning reference. A configured value does not establish the applicable law, an exemption or authorisation. Vertical AGL samples do not evaluate distance to the nearest terrain surface on steep slopes.
  ///
  /// In en, this message translates to:
  /// **'The default 120 m AGL ceiling is a Swiss open-category planning reference. A configured value does not establish the applicable law, an exemption or authorisation. Vertical AGL samples do not evaluate distance to the nearest terrain surface on steep slopes.'**
  String get commonTheDefaultMAgld0e44124;

  /// Legacy key: These are personal limits, not manufacturer-approved wind tolerances.
  ///
  /// In en, this message translates to:
  /// **'These are personal limits, not manufacturer-approved wind tolerances.'**
  String get commonTheseArePersonalLimits77b30a8a;

  /// Legacy key: These values describe a simplified planning model. They do not account for gusts, manoeuvres, battery sag, temperature, battery ageing or unknown obstacles.
  ///
  /// In en, this message translates to:
  /// **'These values describe a simplified planning model. They do not account for gusts, manoeuvres, battery sag, temperature, battery ageing or unknown obstacles.'**
  String get commonTheseValuesDescribeAa43d2a95;

  /// Legacy key: This replaces your current spots, equipment, routes, images, checklists, telemetry and backed-up preferences. Restored map preferences can reconnect enabled layers. API keys and downloaded maps/data remain on this device. Create a backup of your current data first.
  ///
  /// In en, this message translates to:
  /// **'This replaces your current spots, equipment, routes, images, checklists, telemetry and backed-up preferences. Restored map preferences can reconnect enabled layers. API keys and downloaded maps/data remain on this device. Create a backup of your current data first.'**
  String get commonThisReplacesYourCurrentf961d89e;

  /// Legacy key: TMC beschreibt vor allem Hauptverkehrsstraßen. Unbekannte Codes, Versionskonflikte und nicht eindeutige Abschnitte bleiben ohne Einfluss auf die Routenempfehlung.
  ///
  /// In en, this message translates to:
  /// **'TMC describes main roads above all. Unknown codes, version conflicts and non-clear sections remain without influence on the route recommendation.'**
  String get commonTmcBeschreibtVorAllem56166f9f;

  /// Legacy key: Toilets
  ///
  /// In en, this message translates to:
  /// **'Toilets'**
  String get commonToilets610d13f5;

  /// Legacy key: Token verwenden, nicht Token Hash.
  ///
  /// In en, this message translates to:
  /// **'Use tokens, not token hash.'**
  String get commonTokenVerwendenNichtToken28179d00;

  /// Legacy key: Touch-Steuerung ausblenden
  ///
  /// In en, this message translates to:
  /// **'Hide touch controls'**
  String get commonTouchSteuerungAusblenden26a72091;

  /// Legacy key: Transmitter antenna characteristics
  ///
  /// In en, this message translates to:
  /// **'Transmitter antenna characteristics'**
  String get commonTransmitterAntennaCharacteristics19b4fc52;

  /// Legacy key: Transmitter antenna gain
  ///
  /// In en, this message translates to:
  /// **'Transmitter antenna gain'**
  String get commonTransmitterAntennaGain38da48c0;

  /// Legacy key: Transmitter cable / connector loss
  ///
  /// In en, this message translates to:
  /// **'Transmitter cable / connector loss'**
  String get commonTransmitterCableConnectorLoss9df9b0dd;

  /// Legacy key: Transmitter polarization
  ///
  /// In en, this message translates to:
  /// **'Transmitter polarization'**
  String get commonTransmitterPolarization34dcaed8;

  /// Legacy key: Tunnel stammen aus dem vorbereiteten Schweizer Offlineindex. Fehlt dieser, sendet die Online-Ersatzsuche den Kartenausschnitt an die Datenquelle. Querschnitt, Portale und Höhen sind nicht vermessen. Nur Simulation, keine reale Durchflugfreigabe.
  ///
  /// In en, this message translates to:
  /// **'Tunnels come from the prepared Swiss offline index. If this is missing, the online replacement search sends the map section to the data source. Cross-section, portals and heights are not measured. Only simulation, no real flight clearance.'**
  String get commonTunnelStammenAusDema4a6630f;

  /// Legacy key: Type
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get commonType3deb7456;

  /// Legacy key: UAS-Zonen
  ///
  /// In en, this message translates to:
  /// **'UAS zones'**
  String get commonUasZonen81937e88;

  /// Legacy key: Über „Profil wählen“ oder Einstellungen → Aktivitätsprofile wählst du eine Vorlage, erstellst ein leeres Profil oder überspringst die Auswahl. Vorlagen lassen sich bearbeiten, duplizieren und löschen. Bevorzugte Werkzeuge stehen im Menü zuerst; die Kartenaktionen folgen deinen Schnellaktionen. „Alle Werkzeuge“ öffnet jederzeit den vollständigen Funktionsumfang. Flugrouten und Ausrüstung behalten ihre Bedeutung. Den Fuß- oder Velomodus wählst du im Bereich Bodenrouten; ein Aktivitätsprofil ändert den Routingmodus nicht automatisch.
  ///
  /// In en, this message translates to:
  /// **'Use \"Select profile\" or \"Settings → Activity profiles\" to select a template, create an empty profile or skip the selection. Templates can be edited, duplicated and deleted. Preferred tools are in the menu first; map actions follow your quick actions. \"All tools\" opens the full functionality at any time. Flight routes and equipment retain their meaning. You select foot or bike mode in the ground routes area; an activity profile does not automatically change routing mode.'**
  String get commonUberProfilWaehlenOdera22070c5;

  /// Legacy key: Unable to load drone profiles.
  ///
  /// In en, this message translates to:
  /// **'Unable to load drone profiles.'**
  String get commonUnableToLoadDronecc1e0297;

  /// Legacy key: Unavailable
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get commonUnavailable2c9c1f79;

  /// Legacy key: Unbekannt
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnbekanntd0b00a9f;

  /// Legacy key: Unfall
  ///
  /// In en, this message translates to:
  /// **'Accident'**
  String get commonUnfallfb1a68ca;

  /// Legacy key: Unknown
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknownbc7819b3;

  /// Legacy key: Unprotected backups contain readable personal data, including coordinates, notes and images.
  ///
  /// In en, this message translates to:
  /// **'Unprotected backups contain readable personal data, including coordinates, notes and images.'**
  String get commonUnprotectedBackupsContainReadableec1db6d0;

  /// Legacy key: Unter Einstellungen → Navigation oder Kartendarstellung → 3D-Umgebung lassen sich Gebäude und Vegetation jeweils auf Wie Karte, Aus oder Ein stellen. Die normale Karte und Luftfahrthindernisse behalten eigene Einstellungen. Fehlende Streaming-Daten unterbrechen die Navigation nicht. Die geglättete Anzeige bleibt beim letzten GPS-Punkt stehen; Geschwindigkeit und Routenführung verwenden die ursprünglichen Messwerte.
  ///
  /// In en, this message translates to:
  /// **'Under Settings → Navigation or Map Display → 3D Environment, buildings and vegetation can be set to Like Map, Off or On. The normal map and aviation obstacles retain their own settings. Missing streaming data does not interrupt the navigation. The smoothed display stops at the last GPS point; speed and route guidance use the original measured values.'**
  String get commonUnterEinstellungenNavigationOder48dcba83;

  /// Legacy key: Use the Token for Road traffic - traffic situations, not Token Hash or OJP.
  ///
  /// In en, this message translates to:
  /// **'Use the Token for Road traffic - traffic situations, not Token Hash or OJP.'**
  String get commonUseTheTokenFor892c903f;

  /// Legacy key: Velo
  ///
  /// In en, this message translates to:
  /// **'Bicycle'**
  String get commonVeloba303bca;

  /// Legacy key: Velorouten
  ///
  /// In en, this message translates to:
  /// **'Velorouten'**
  String get commonVelorouten02063824;

  /// Legacy key: Verkehrsdaten
  ///
  /// In en, this message translates to:
  /// **'Transport data'**
  String get commonVerkehrsdaten47bcd2e4;

  /// Legacy key: Veröffentlichte Hindernisse
  ///
  /// In en, this message translates to:
  /// **'Obstacles published'**
  String get commonVeroeffentlichteHindernissedcee0df6;

  /// Legacy key: Veröffentlichungszeit/TTL nicht belegt. Gemeldete Zustände werden angezeigt, aktuelle Verfügbarkeit bleibt unbekannt.
  ///
  /// In en, this message translates to:
  /// **'Release time/TTL not used. Reported states are displayed, current availability remains unknown.'**
  String get commonVeroeffentlichungszeitTtlNichtBelegtd74df01f;

  /// Legacy key: Verwerfen
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get commonVerwerfen24cc57bc;

  /// Legacy key: Viewpoints
  ///
  /// In en, this message translates to:
  /// **'Viewpoints'**
  String get commonViewpointse28a6555;

  /// Legacy key: Vor dem Start
  ///
  /// In en, this message translates to:
  /// **'Before start'**
  String get commonVorDemStartce7119a6;

  /// Legacy key: Vorbereitete Karten und Gelände ersetzen keine Liveinformationen. UAS-, Hindernis- und SLF-Snapshots behalten ihre Quelldaten und Gültigkeit. WMS, Orts-/Straßenbeschriftungen, Streaming-3D und Liveverkehr/Wetter sind nicht als vollständige Offlineebenen enthalten. Fehlende Beschriftungen führen im Nur-Cache-Modus nicht zu einem heimlichen Onlineabruf.
  ///
  /// In en, this message translates to:
  /// **'Prepared maps and terrain do not replace live information. UAS, obstacle and SLF snapshots retain their source data and validity. WMS, location/road labels, streaming 3D and live traffic/weather are not included as complete offline levels. Missing labels do not lead to a secret online call in Cache mode.'**
  String get commonVorbereiteteKartenUndGelaende4e8adf4f;

  /// Legacy key: Während die Navigation geöffnet ist, wird dein Standort laufend genutzt. Bei Routenabweichungen werden Standort und Ziel zur Neuberechnung an FOSSGIS gesendet. Im Hintergrund pausiert die Navigation.
  ///
  /// In en, this message translates to:
  /// **'While the navigation is open, your location is used continuously. In case of route deviations, location and destination are sent to FOSSGIS for recalculation. In the background, the navigation pauses.'**
  String get commonWaehrendDieNavigationGeoeffnet32560395;

  /// Legacy key: Wander-, Velo-, Mountainbike- und Winterrouten sind veröffentlichte Netze. Legenden erklären die jeweiligen Kategorien; ohne entsprechende Quelldaten wird keine Schwierigkeit berechnet. Diese Online-Kartenebenen sind von deinen gespeicherten Boden- und Flugrouten getrennt. Kartenstand, Öffnung und aktuelle Bedingungen sind eigenständig zu prüfen.
  ///
  /// In en, this message translates to:
  /// **'Hiking, cycling, mountain biking and winter routes are published networks. Legends explain the respective categories; without corresponding source data no difficulty is calculated. These online map areas are separated from your stored ground and flight routes. Map status, opening and current conditions must be independently checked.'**
  String get commonWanderVeloMountainbikeUnd0dc3c854;

  /// Legacy key: Wanderwege
  ///
  /// In en, this message translates to:
  /// **'Hiking trails'**
  String get commonWanderwege93acd7ea;

  /// Legacy key: Warnings
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get commonWarnings1430f976;

  /// Legacy key: Warnung Zellspannung (V)
  ///
  /// In en, this message translates to:
  /// **'Low voltage warning (V/cell)'**
  String get commonWarnungZellspannungV6655c81c;

  /// Legacy key: Was fehlt
  ///
  /// In en, this message translates to:
  /// **'Was fehlt'**
  String get commonWasFehltb7799bca;

  /// Legacy key: Weather forecasts are planning aids, not real-time flight safety or legal authorisation.
  ///
  /// In en, this message translates to:
  /// **'Weather forecasts are planning aids, not real-time flight safety or legal authorisation.'**
  String get commonWeatherForecastsArePlanning5820a8ab;

  /// Legacy key: Wegenetze, Natur und Sperrungen
  ///
  /// In en, this message translates to:
  /// **'Road networks, nature and barriers'**
  String get commonWegenetzeNaturUndSperrungen0e7d404e;

  /// Legacy key: Weiter bearbeiten
  ///
  /// In en, this message translates to:
  /// **'Continue to Edit'**
  String get commonWeiterBearbeitencc234070;

  /// Legacy key: Weitere Meldung
  ///
  /// In en, this message translates to:
  /// **'Further message'**
  String get commonWeitereMeldung12efe38b;

  /// Legacy key: Wetter und 3D-Wind
  ///
  /// In en, this message translates to:
  /// **'Weather and 3D wind'**
  String get commonWetterUndDWindd3dd8c5c;

  /// Legacy key: Wetter- und Gewässermessstationen
  ///
  /// In en, this message translates to:
  /// **'Weather and water measuring stations'**
  String get commonWetterUndGewaessermessstationendac59859;

  /// Legacy key: Wetterraster
  ///
  /// In en, this message translates to:
  /// **'Weather raster'**
  String get commonWetterrasterb939701a;

  /// Legacy key: WGS84: Breite, Länge in Dezimalgrad, z. B. 46.7, 8.4. LV95: Ost / Nord, z. B. 2600000 / 1200000. Die lokale LV95-Umrechnung ist eine Näherung für Orientierung, keine Vermessung. Eine Orts- oder Adresssuche benötigt dagegen eine Verbindung.
  ///
  /// In en, this message translates to:
  /// **'WGS84: Width, length in decimal degrees, e.g. 46.7, 8.4. LV95: East / North, e.g. 2600000 / 1200000. The local LV95 conversion is an approximation for orientation, not a measurement. A location or address search requires a connection.'**
  String get commonWgsBreiteLaengeIna66287c0;

  /// Legacy key: WGS84-Ellipsoid, Schweizer LN02 und Höhe über Gelände (AGL) sind unterschiedliche Bezüge. AGL bezieht sich auf das Gelände am jeweiligen Punkt, die Starthöhe auf den Startpunkt. Unbekannte Quellenbezüge bleiben unbekannt. Ein flacher Ersatzglobe liefert keine gemessene Geländehöhe.
  ///
  /// In en, this message translates to:
  /// **'WGS84-Ellipsoid, Swiss LN02 and altitude over terrain (AGL) are different references. AGL refers to the terrain at the respective point, the starting height to the starting point. Unknown sources remain unknown. A flat replacement globe does not provide a measured terrain height.'**
  String get commonWgsEllipsoidSchweizerLnc6e2dc07;

  /// Legacy key: Widerstand bei Höchsttempo (m/s²)
  ///
  /// In en, this message translates to:
  /// **'Drag at maximum speed (m/s²)'**
  String get commonWiderstandBeiHoechsttempoM510bfda4;

  /// Legacy key: Wildruhezonen
  ///
  /// In en, this message translates to:
  /// **'Wild resting areas'**
  String get commonWildruhezonen6d338347;

  /// Legacy key: Wildruhezonen können rechtsverbindlich oder empfohlen sein. Schutzzeiten, örtliche Bestimmungen und zulässige Wege stehen in den offiziellen Details. Der räumliche Detailabruf ist ein begrenzter Auszug; fehlende kantonale Informationen oder fehlende Treffer bestätigen keine Zugänglichkeit. Sperrungen und Umleitungen haben eigene Gültigkeitsangaben. Eine Schutzfläche ist keine pauschale luftrechtliche Einstufung.
  ///
  /// In en, this message translates to:
  /// **'Wild resting zones can be legally binding or recommended. Protection periods, local regulations and permissible paths are listed in the official details. The spatial detail call is a limited extract; missing cantonal information or missing results do not confirm accessibility. Blocks and redirections have their own validity information. A protected area is not a standard air law classification.'**
  String get commonWildruhezonenKoennenRechtsverbindlichOder5ba8618e;

  /// Legacy key: Wind & Funk
  ///
  /// In en, this message translates to:
  /// **'Wind & radio'**
  String get commonWindFunk4ce9bd21;

  /// Legacy key: Wind legend (m/s): green <3, yellow 3–7, orange 7–12, red ≥12.
  ///
  /// In en, this message translates to:
  /// **'Wind legend (m/s): green <3, yellow 3–7, orange 7–12, red ≥12.'**
  String get commonWindLegendMS1b571bdc;

  /// Legacy key: Winterwanderwege
  ///
  /// In en, this message translates to:
  /// **'Winter hiking trails'**
  String get commonWinterwanderwege815871de;

  /// Legacy key: Witterung
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get commonWitterung98e69f2f;

  /// Legacy key: Yaw maximal (°/s)
  ///
  /// In en, this message translates to:
  /// **'Maximum yaw rate (°/s)'**
  String get commonYawMaximalS71fd433b;

  /// Legacy key: Yes
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes5397e058;

  /// Legacy key: Zeitangaben
  ///
  /// In en, this message translates to:
  /// **'Time data'**
  String get commonZeitangabenb06eb18b;

  /// Legacy key: Zu Fuß
  ///
  /// In en, this message translates to:
  /// **'On foot'**
  String get commonZuFussda918eb3;

  /// Legacy key: Zugänge
  ///
  /// In en, this message translates to:
  /// **'Accesses'**
  String get commonZugaengec08f0ef3;

  /// Legacy key: Zur Karte
  ///
  /// In en, this message translates to:
  /// **'Return to map'**
  String get commonZurKarte4814658b;

  /// Legacy key: Zurück
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonZurueck40806243;

  /// Legacy key: Zusätzlicher Schub (m/s²)
  ///
  /// In en, this message translates to:
  /// **'Additional thrust (m/s²)'**
  String get commonZusaetzlicherSchubMS337bc8ea;

  /// Legacy key: Zustände
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get commonZustaende1b49baf7;

  /// Legacy key: A forgotten password cannot be recovered.
  ///
  /// In en, this message translates to:
  /// **'A forgotten password cannot be recovered.'**
  String get datamanagementAForgottenPasswordCannot76d00a6a;

  /// Legacy key: Backup from {0}
  ///
  /// In en, this message translates to:
  /// **'Backup from {arg0}'**
  String datamanagementBackupFrome163c3fa(String arg0);

  /// Legacy key: Backup password
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get datamanagementBackupPasswordd96a6076;

  /// Legacy key: Create backup
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get datamanagementCreateBackup60e77f3b;

  /// Legacy key: Offline & personal data
  ///
  /// In en, this message translates to:
  /// **'Offline & personal data'**
  String get datamanagementOfflinePersonalDatae0f55e89;

  /// Legacy key: Password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get datamanagementPassword8be3c943;

  /// Legacy key: Password (at least 12 characters)
  ///
  /// In en, this message translates to:
  /// **'Password (at least 12 characters)'**
  String get datamanagementPasswordAtLeastCharacters518d1ae0;

  /// Legacy key: Portable backups
  ///
  /// In en, this message translates to:
  /// **'Portable backups'**
  String get datamanagementPortableBackups13832bb9;

  /// Legacy key: Protect backup with a password
  ///
  /// In en, this message translates to:
  /// **'Protect backup with a password'**
  String get datamanagementProtectBackupWithAf8add733;

  /// Legacy key: Repeat password
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get datamanagementRepeatPassword366c2415;

  /// Legacy key: Replace and restore
  ///
  /// In en, this message translates to:
  /// **'Replace and restore'**
  String get datamanagementReplaceAndRestoreee68c046;

  /// Legacy key: Replace personal data?
  ///
  /// In en, this message translates to:
  /// **'Replace personal data?'**
  String get datamanagementReplacePersonalData946d9c54;

  /// Legacy key: Restore backup
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get datamanagementRestoreBackupa65eaa88;

  /// Legacy key: The map cache preference could not be saved.
  ///
  /// In en, this message translates to:
  /// **'The map cache preference could not be saved.'**
  String get datamanagementTheMapCachePreference010bed10;

  /// Legacy key: Add drone profile
  ///
  /// In en, this message translates to:
  /// **'Add drone profile'**
  String get dronesAddDroneProfile9af5c042;

  /// Legacy key: Add drone
  ///
  /// In en, this message translates to:
  /// **'Add drone'**
  String get dronesAddDroned971a88b;

  /// Legacy key: Delete drone profile?
  ///
  /// In en, this message translates to:
  /// **'Delete drone profile?'**
  String get dronesDeleteDroneProfilec10d6154;

  /// Legacy key: Delete profile
  ///
  /// In en, this message translates to:
  /// **'Delete profile'**
  String get dronesDeleteProfile7035d2d9;

  /// Legacy key: Drone profile
  ///
  /// In en, this message translates to:
  /// **'Drone profile'**
  String get dronesDroneProfile1ca23ee8;

  /// Legacy key: Drone profiles
  ///
  /// In en, this message translates to:
  /// **'Drone profiles'**
  String get dronesDroneProfilesb57e7452;

  /// Legacy key: Edit drone profile
  ///
  /// In en, this message translates to:
  /// **'Edit drone profile'**
  String get dronesEditDroneProfilefc4f435a;

  /// Legacy key: Edit profile
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get dronesEditProfile15141eab;

  /// Legacy key: No drone profiles saved yet. Add a profile to record your equipment.
  ///
  /// In en, this message translates to:
  /// **'No drone profiles saved yet. Add a profile to record your equipment.'**
  String get dronesNoDroneProfilesSavedca393a7c;

  /// Legacy key: No numeric parameters recorded.
  ///
  /// In en, this message translates to:
  /// **'No numeric parameters recorded.'**
  String get dronesNoNumericParametersRecorded530d76ed;

  /// Legacy key: Permanently delete "{0}"? Flight plans will be kept without this drone assignment.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete \"{arg0}\"? Flight plans will be kept without this drone assignment.'**
  String dronesPermanentlyDeleteFlightPlansc2a19a5b(String arg0);

  /// Legacy key: {0} source
  ///
  /// In en, this message translates to:
  /// **'{arg0} source'**
  String dronesSource0ef9cdaf(String arg0);

  /// Legacy key: This drone profile no longer exists.
  ///
  /// In en, this message translates to:
  /// **'This drone profile no longer exists.'**
  String get dronesThisDroneProfileNob7ffc857;

  /// Legacy key: Unable to load this drone profile.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this drone profile.'**
  String get dronesUnableToLoadThis20f0daab;

  /// Legacy key: Abfrage fehlgeschlagen: {0}
  ///
  /// In en, this message translates to:
  /// **'Query failed: {arg0}'**
  String globeAbfrageFehlgeschlagene25d055d(String arg0);

  /// Legacy key: Aktuelles GPS-Signal
  ///
  /// In en, this message translates to:
  /// **'Current GPS signal'**
  String get globeAktuellesGpsSignal291591fd;

  /// Legacy key: Allgemeine Einstellungen
  ///
  /// In en, this message translates to:
  /// **'General Settings'**
  String get globeAllgemeineEinstellungen6f965a12;

  /// Legacy key: AMSL is height above mean sea level. Swiss national map heights use LN02; LHN95 is a separate height datum.
  ///
  /// In en, this message translates to:
  /// **'AMSL is height above mean sea level. Swiss national map heights use LN02; LHN95 is a separate height datum.'**
  String get globeAmslIsHeightAbove8e48a714;

  /// Legacy key: AMSL (Swiss LN02): not converted
  ///
  /// In en, this message translates to:
  /// **'AMSL (Swiss LN02): not converted'**
  String get globeAmslSwissLnNot9423d99b;

  /// Legacy key: Amtliche Quellen & Sicherheit
  ///
  /// In en, this message translates to:
  /// **'Official sources & safety'**
  String get globeAmtlicheQuellenSicherheit68a6f080;

  /// Legacy key: Approximate conversion (swisstopo formulas)
  ///
  /// In en, this message translates to:
  /// **'Approximate conversion (swisstopo formulas)'**
  String get globeApproximateConversionSwisstopoFormulase7bb7ac3;

  /// Legacy key: Auf Standort zentrieren
  ///
  /// In en, this message translates to:
  /// **'Centre on location'**
  String get globeAufStandortZentrierene8973c1b;

  /// Legacy key: Aus Achse 3D-Gewölbe simulieren
  ///
  /// In en, this message translates to:
  /// **'Build a simulated 3D tunnel from its centreline'**
  String get globeAusAchseDGewoelbe0d1ef125;

  /// Legacy key: Aus: Beleuchtung der Karte verwenden.
  ///
  /// In en, this message translates to:
  /// **'Off: Use illumination of the card.'**
  String get globeAusBeleuchtungDerKarte53fe9a28;

  /// Legacy key: Ausgewähltes Bauwerk
  ///
  /// In en, this message translates to:
  /// **'Selected structure'**
  String get globeAusgewaehltesBauwerke74d05ef;

  /// Legacy key: Automatisch dargestellte schematische Tunnel: {0} von maximal {1} (Grafikprofil).
  ///
  /// In en, this message translates to:
  /// **'Automatically displayed schematic tunnels: {arg0} of maximum {arg1} (graphic profile).'**
  String globeAutomatischDargestellteSchematischeTunnel4dea34ff(
    String arg0,
    String arg1,
  );

  /// Legacy key: Beschriftungen erneut laden
  ///
  /// In en, this message translates to:
  /// **'Reload labels'**
  String get globeBeschriftungenErneutLaden53e7b713;

  /// Legacy key: Beschriftungen offline nicht verfügbar.
  ///
  /// In en, this message translates to:
  /// **'Labels not available offline.'**
  String get globeBeschriftungenOfflineNichtVerfuegbar79eca86d;

  /// Legacy key: Beschriftungen teilweise verfügbar.
  ///
  /// In en, this message translates to:
  /// **'Labels partly available.'**
  String get globeBeschriftungenTeilweiseVerfuegbar5ada98f5;

  /// Legacy key: Beschriftungen werden geladen …
  ///
  /// In en, this message translates to:
  /// **'Loading labels..'**
  String get globeBeschriftungenWerdenGeladenb8c71bdb;

  /// Legacy key: Bring {0} forward
  ///
  /// In en, this message translates to:
  /// **'Bring {arg0} forward'**
  String globeBringForwardcf73f6a1(String arg0);

  /// Legacy key: Cancel spawn
  ///
  /// In en, this message translates to:
  /// **'Cancel spawn'**
  String get globeCancelSpawn701b7923;

  /// Legacy key: Clear UAS dataset cache
  ///
  /// In en, this message translates to:
  /// **'Clear UAS dataset cache'**
  String get globeClearUasDatasetCacheaad7bb57;

  /// Legacy key: Convert to Swiss height (LN02)
  ///
  /// In en, this message translates to:
  /// **'Convert to Swiss height (LN02)'**
  String get globeConvertToSwissHeight5c83b28a;

  /// Legacy key: Converted with swisstopo REFRAME
  ///
  /// In en, this message translates to:
  /// **'Converted with swisstopo REFRAME'**
  String get globeConvertedWithSwisstopoReframe07d146f4;

  /// Legacy key: Converting…
  ///
  /// In en, this message translates to:
  /// **'Converting…'**
  String get globeConverting3985de51;

  /// Legacy key: 3D-Aktion fehlgeschlagen: {0}
  ///
  /// In en, this message translates to:
  /// **'3D action failed: {arg0}'**
  String globeDAktionFehlgeschlagen11f40ae7(String arg0);

  /// Legacy key: 3D-Daten derzeit nicht verfügbar.
  ///
  /// In en, this message translates to:
  /// **'3D data currently not available.'**
  String get globeDDatenDerzeitNichtec1d811a;

  /// Legacy key: 3D-Daten offline nicht vollständig verfügbar.
  ///
  /// In en, this message translates to:
  /// **'3D data offline not fully available.'**
  String get globeDDatenOfflineNicht0512f9fe;

  /// Legacy key: 3D-Gewölbetunnel erzeugen (synthetisch)
  ///
  /// In en, this message translates to:
  /// **'Create 3D vault tunnels (synthetic)'**
  String get globeDGewoelbetunnelErzeugenSynthetischcf487df5;

  /// Legacy key: 3D & Licht
  ///
  /// In en, this message translates to:
  /// **'3D & lighting'**
  String get globeDLicht8b58e045;

  /// Legacy key: 3D-Modellkollisionen (experimentell)
  ///
  /// In en, this message translates to:
  /// **'3D model collisions (experimental)'**
  String get globeDModellkollisionenExperimentell6ac94586;

  /// Legacy key: 3D-Tunnel automatisch laden
  ///
  /// In en, this message translates to:
  /// **'Load 3D tunnels automatically'**
  String get globeDTunnelAutomatischLadena71b41bc;

  /// Legacy key: 3D-Tunnel entfernen
  ///
  /// In en, this message translates to:
  /// **'Remove 3D tunnel'**
  String get globeDTunnelEntfernenc327e7fe;

  /// Legacy key: 3D-Tunnel: {0}
  ///
  /// In en, this message translates to:
  /// **'3D tunnel: {arg0}'**
  String globeDTunnele1017c1e(String arg0);

  /// Legacy key: Daten & Quellen
  ///
  /// In en, this message translates to:
  /// **'Data & Sources'**
  String get globeDatenQuellen0b5b5779;

  /// Legacy key: Datenstand
  ///
  /// In en, this message translates to:
  /// **'Data level'**
  String get globeDatenstand0ce51d29;

  /// Legacy key: Datum und Uhrzeit
  ///
  /// In en, this message translates to:
  /// **'Date and time'**
  String get globeDatumUndUhrzeit6b922369;

  /// Legacy key: Deckkraft
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get globeDeckkraft3c11c68b;

  /// Legacy key: Durchflug: {0}
  ///
  /// In en, this message translates to:
  /// **'Transit: {arg0}'**
  String globeDurchfluge383d59a(String arg0);

  /// Legacy key: Easting: {0} m
  ///
  /// In en, this message translates to:
  /// **'Easting: {arg0} m'**
  String globeEastingM080f8cea(String arg0);

  /// Legacy key: Eigene Sonnen- und Mondzeit
  ///
  /// In en, this message translates to:
  /// **'Custom lighting time'**
  String get globeEigeneSonnenUndMondzeit785565c8;

  /// Legacy key: Einige 3D-Kacheln fehlen. Geladene Modelle bleiben sichtbar.
  ///
  /// In en, this message translates to:
  /// **'Some 3D tiles are missing. Loaded models remain visible.'**
  String get globeEinigeDKachelnFehlenbf4b88d2;

  /// Legacy key: Erneut laden
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get globeErneutLaden9c56689e;

  /// Legacy key: Fahrtrichtung: {0}°
  ///
  /// In en, this message translates to:
  /// **'Direction: {arg0}°'**
  String globeFahrtrichtung8ce70d3a(String arg0);

  /// Legacy key: Failed to load 3D globe
  ///
  /// In en, this message translates to:
  /// **'Failed to load 3D globe'**
  String get globeFailedToLoadDd6e93076;

  /// Legacy key: Für Beschriftungen näher heranzoomen.
  ///
  /// In en, this message translates to:
  /// **'Zoom in closer for labels.'**
  String get globeFuerBeschriftungenNaeherHeranzoomen6f64dcb5;

  /// Legacy key: Genauigkeit: ±{0} m
  ///
  /// In en, this message translates to:
  /// **'Accuracy: ±{arg0} m'**
  String globeGenauigkeitM4e998940(String arg0);

  /// Legacy key: Gespeicherte Spots
  ///
  /// In en, this message translates to:
  /// **'Saved spots'**
  String get globeGespeicherteSpots4f634531;

  /// Legacy key: Ground elevation
  ///
  /// In en, this message translates to:
  /// **'Ground elevation'**
  String get globeGroundElevation5d588142;

  /// Legacy key: Ground view: {0}
  ///
  /// In en, this message translates to:
  /// **'Ground view: {arg0}'**
  String globeGroundViewb1f80610(String arg0);

  /// Legacy key: Height above local ground (AGL)
  ///
  /// In en, this message translates to:
  /// **'Height above local ground (AGL)'**
  String get globeHeightAboveLocalGround8c1c0da0;

  /// Legacy key: Height above terrain (AGL)
  ///
  /// In en, this message translates to:
  /// **'Height above terrain (AGL)'**
  String get globeHeightAboveTerrainAglcbf70384;

  /// Legacy key: Height at this AGL:
  ///
  /// In en, this message translates to:
  /// **'Height at this AGL:'**
  String get globeHeightAtThisAglfbdc9bdd;

  /// Legacy key: Hindernisse
  ///
  /// In en, this message translates to:
  /// **'Obstacles'**
  String get globeHindernissed58845a0;

  /// Legacy key: Importiertes Mesh · Herkunft und Höhenbezug nicht unabhängig geprüft. Geländeöffnung erforderlich.
  ///
  /// In en, this message translates to:
  /// **'Imported mesh. Source and vertical reference have not been independently verified. A terrain cutout is required.'**
  String get globeImportiertesMeshHerkunftUnd538c26a9;

  /// Legacy key: Importiertes Modell · Herkunft und Lichtraum ungeprüft. Keine reale Durchflugfreigabe.
  ///
  /// In en, this message translates to:
  /// **'Imported model · Origin and light space unchecked. No real clearance.'**
  String get globeImportiertesModellHerkunftUnd950bcbe2;

  /// Legacy key: Jetzt
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get globeJetzt6b627c53;

  /// Legacy key: Karte
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get globeKarteb1636a3d;

  /// Legacy key: Karteinstellungen zurücksetzen
  ///
  /// In en, this message translates to:
  /// **'Reset Map Settings'**
  String get globeKarteinstellungenZuruecksetzen3bd1cc02;

  /// Legacy key: Kartenbewegung beendet die Verfolgung. Online-Karten können beim Zentrieren und Folgen den Standortbereich erkennen lassen.
  ///
  /// In en, this message translates to:
  /// **'Moving the map stops following. Online tiles can reveal the area when you center or follow.'**
  String get globeKartenbewegungBeendetDieVerfolgung00211415;

  /// Legacy key: Karteneinstellungen werden geladen …
  ///
  /// In en, this message translates to:
  /// **'Loading map settings..'**
  String get globeKarteneinstellungenWerdenGeladen349c7e7f;

  /// Legacy key: Keine im lokalen Index erfassten Tunnel im Kartenausschnitt. Datenabdeckung möglicherweise unvollständig.
  ///
  /// In en, this message translates to:
  /// **'No tunnels recorded in the local index in the map section. Data coverage may be incomplete.'**
  String get globeKeineImLokalenIndex7a2d66ae;

  /// Legacy key: Letzter bekannter Standort · veraltet
  ///
  /// In en, this message translates to:
  /// **'Last known location · outdated'**
  String get globeLetzterBekannterStandortVeraltet04a9e861;

  /// Legacy key: Letzter Standort · erneut orten
  ///
  /// In en, this message translates to:
  /// **'Last location · locate again'**
  String get globeLetzterStandortErneutOrten9afe561d;

  /// Legacy key: Loading zone data...
  ///
  /// In en, this message translates to:
  /// **'Loading zone data...'**
  String get globeLoadingZoneDatacd4362a5;

  /// Legacy key: Local library
  ///
  /// In en, this message translates to:
  /// **'Local library'**
  String get globeLocalLibrary1c67cdf4;

  /// Legacy key: Luftraum
  ///
  /// In en, this message translates to:
  /// **'Airspace'**
  String get globeLuftraum0992aecb;

  /// Legacy key: LV95 conversion unavailable outside the supported Swiss region.
  ///
  /// In en, this message translates to:
  /// **'LV95 conversion unavailable outside the supported Swiss region.'**
  String get globeLvConversionUnavailableOutsidedecfa6d5;

  /// Legacy key: Map layer error: {0}
  ///
  /// In en, this message translates to:
  /// **'Map layer error: {arg0}'**
  String globeMapLayerError65930212(String arg0);

  /// Legacy key: Mein Standort · lange drücken für Optionen
  ///
  /// In en, this message translates to:
  /// **'My location · long press for options'**
  String get globeMeinStandortLangeDrueckend4c6bff6;

  /// Legacy key: Modellquelle: {0}
  ///
  /// In en, this message translates to:
  /// **'Model source: {arg0}'**
  String globeModellquelle05ae7da1(String arg0);

  /// Legacy key: Native 3D globe is currently supported on Android and iOS.
  ///
  /// In en, this message translates to:
  /// **'Native 3D globe is currently supported on Android and iOS.'**
  String get globeNativeDGlobeIsf8235971;

  /// Legacy key: Neue Beschriftungen konnten nicht geladen werden.
  ///
  /// In en, this message translates to:
  /// **'New labels could not be loaded.'**
  String get globeNeueBeschriftungenKonntenNicht08732593;

  /// Legacy key: Nicht modellierbare Tunnelabschnitte: {0} von {1} erfassten Achsen.
  ///
  /// In en, this message translates to:
  /// **'Unmodelled tunnel sections: {arg0} of {arg1} detected axes.'**
  String globeNichtModellierbareTunnelabschnitteVon25d903e4(
    String arg0,
    String arg1,
  );

  /// Legacy key: Noch keine Tunnel gefunden.
  ///
  /// In en, this message translates to:
  /// **'No tunnels found yet.'**
  String get globeNochKeineTunnelGefundenbdf89230;

  /// Legacy key: Northing: {0} m
  ///
  /// In en, this message translates to:
  /// **'Northing: {arg0} m'**
  String globeNorthingMc882004d(String arg0);

  /// Legacy key: Nur Schweiz und Liechtenstein.
  ///
  /// In en, this message translates to:
  /// **'Only Switzerland and Liechtenstein.'**
  String get globeNurSchweizUndLiechtenstein1516f8d3;

  /// Legacy key: Online conversion sends this position and ground elevation to swisstopo.
  ///
  /// In en, this message translates to:
  /// **'Online conversion sends this position and ground elevation to swisstopo.'**
  String get globeOnlineConversionSendsThis9f4e31f3;

  /// Legacy key: Originaldaten · keine Durchflugfreigabe.
  ///
  /// In en, this message translates to:
  /// **'Source data · no clearance for flight.'**
  String get globeOriginaldatenKeineDurchflugfreigabeb2bc03bb;

  /// Legacy key: Orts- und Straßennamen
  ///
  /// In en, this message translates to:
  /// **'Place and street names'**
  String get globeOrtsUndStrassennamenbe90f8a3;

  /// Legacy key: Polygon fill opacity: {0}%
  ///
  /// In en, this message translates to:
  /// **'Polygon fill opacity: {arg0}%'**
  String globePolygonFillOpacityd148d398(String arg0);

  /// Legacy key: Quellkennung: {0}
  ///
  /// In en, this message translates to:
  /// **'Source code: {arg0}'**
  String globeQuellkennung050247aa(String arg0);

  /// Legacy key: Refresh UAS data
  ///
  /// In en, this message translates to:
  /// **'Refresh UAS data'**
  String get globeRefreshUasData3aea6b96;

  /// Legacy key: Reihenfolge der Ebenen
  ///
  /// In en, this message translates to:
  /// **'Layer order'**
  String get globeReihenfolgeDerEbenenf736c2db;

  /// Legacy key: Retry terrain
  ///
  /// In en, this message translates to:
  /// **'Retry terrain'**
  String get globeRetryTerraine3f14f82;

  /// Legacy key: Return to globe
  ///
  /// In en, this message translates to:
  /// **'Return to globe'**
  String get globeReturnToGlobe687364e5;

  /// Legacy key: Sampling: {0}
  ///
  /// In en, this message translates to:
  /// **'Sampling: {arg0}'**
  String globeSamplinga7cf9539(String arg0);

  /// Legacy key: Satellite
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get globeSatellited1ffec93;

  /// Legacy key: Saved spots
  ///
  /// In en, this message translates to:
  /// **'Saved spots'**
  String get globeSavedSpotsf65c2504;

  /// Legacy key: Sichtdreiecke: {0} · Kollisionsdreiecke: {1}
  ///
  /// In en, this message translates to:
  /// **'Visual triangle: {arg0} · Collision triangle: {arg1}'**
  String globeSichtdreieckeKollisionsdreiecke2eeb74c5(String arg0, String arg1);

  /// Legacy key: Signalzeit: {0}
  ///
  /// In en, this message translates to:
  /// **'Signaling time: {arg0}'**
  String globeSignalzeiteb1b8546(String arg0);

  /// Legacy key: Simulation · Online-Ersatzsuche sendet Kartenausschnitt.
  ///
  /// In en, this message translates to:
  /// **'Simulation · Online replacement search sends map section.'**
  String get globeSimulationOnlineErsatzsucheSendet67c4c630;

  /// Legacy key: Sonnen- und Mondlicht
  ///
  /// In en, this message translates to:
  /// **'Sunlight and moonlight'**
  String get globeSonnenUndMondlichtc6291e64;

  /// Legacy key: Spawn here
  ///
  /// In en, this message translates to:
  /// **'Spawn here'**
  String get globeSpawnHeref28d3450;

  /// Legacy key: Standort anzeigen
  ///
  /// In en, this message translates to:
  /// **'Show location'**
  String get globeStandortAnzeigenca6f8a53;

  /// Legacy key: Standort verfolgen
  ///
  /// In en, this message translates to:
  /// **'Follow location'**
  String get globeStandortVerfolgen14ee16f9;

  /// Legacy key: Standort wird gesucht
  ///
  /// In en, this message translates to:
  /// **'Searching for location'**
  String get globeStandortWirdGesucht33b02f57;

  /// Legacy key: Straßen-Layer erneut laden
  ///
  /// In en, this message translates to:
  /// **'Reload roads layer'**
  String get globeStrassenLayerErneutLadenfb527544;

  /// Legacy key: Swiss coordinates (LV95)
  ///
  /// In en, this message translates to:
  /// **'Swiss coordinates (LV95)'**
  String get globeSwissCoordinatesLvb62ba2b6;

  /// Legacy key: Swiss height conversion is unavailable at this position or for this reference.
  ///
  /// In en, this message translates to:
  /// **'Swiss height conversion is unavailable at this position or for this reference.'**
  String get globeSwissHeightConversionIsae058df0;

  /// Legacy key: Tag und Nacht nach Gerätezeit.
  ///
  /// In en, this message translates to:
  /// **'Day and night follow the device time.'**
  String get globeTagUndNachtNach5c260567;

  /// Legacy key: Terrain-Aussparungen: {0}. Weitere sichtbare Röhren sind ggf. vom Gelände verdeckt.
  ///
  /// In en, this message translates to:
  /// **'Terrain recesses: {arg0}. Other visible tubes may be hidden from the grounds.'**
  String globeTerrainAussparungenWeitereSichtbaree67506d9(String arg0);

  /// Legacy key: Terrain Information
  ///
  /// In en, this message translates to:
  /// **'Terrain Information'**
  String get globeTerrainInformation1a166cb2;

  /// Legacy key: Topo
  ///
  /// In en, this message translates to:
  /// **'Topo'**
  String get globeTopo7416e691;

  /// Legacy key: Tunnel-Datenquelle: {0}
  ///
  /// In en, this message translates to:
  /// **'Tunnel data source: {arg0}'**
  String globeTunnelDatenquellee8c8f0f5(String arg0);

  /// Legacy key: {0} / {1} Tunnel geladen
  ///
  /// In en, this message translates to:
  /// **'{arg0} / {arg1} tunnels loaded'**
  String globeTunnelGeladen76365023(String arg0, String arg1);

  /// Legacy key: Tunnel in der Nähe suchen
  ///
  /// In en, this message translates to:
  /// **'Find nearby tunnels'**
  String get globeTunnelInDerNaehe75bf7c66;

  /// Legacy key: Tunnelabdeckung unvollständig.
  ///
  /// In en, this message translates to:
  /// **'Tunnel coverage is incomplete.'**
  String get globeTunnelabdeckungUnvollstaendigcfa66c0f;

  /// Legacy key: Tunnelachsen derzeit offline nicht verfügbar.
  ///
  /// In en, this message translates to:
  /// **'Tunnel axes are currently not available offline.'**
  String get globeTunnelachsenDerzeitOfflineNicht2a3ab99c;

  /// Legacy key: {0} Tunnelachsen gefunden; Abdeckung unvollständig.
  ///
  /// In en, this message translates to:
  /// **'{arg0} Tunnel axes found; coverage incomplete.'**
  String globeTunnelachsenGefundenAbdeckungUnvollstaendigdabfec20(String arg0);

  /// Legacy key: {0} Tunnelachsen im Kartenausschnitt gefunden (schematisch).
  ///
  /// In en, this message translates to:
  /// **'{arg0} Tunnel axes found in the map section (schematic).'**
  String globeTunnelachsenImKartenausschnittGefundenbbd7f549(String arg0);

  /// Legacy key: Tunnelachsen nur bei bodennaher Schweizer Kartenansicht automatisch laden.
  ///
  /// In en, this message translates to:
  /// **'Automatically load tunnel axes only with Swiss map view close to the ground.'**
  String get globeTunnelachsenNurBeiBodennaherab983e29;

  /// Legacy key: Tunnelachsen werden automatisch für den nahen sichtbaren Kartenausschnitt gesucht.
  ///
  /// In en, this message translates to:
  /// **'Tunnel axes are automatically searched for the near visible map section.'**
  String get globeTunnelachsenWerdenAutomatischFuer8bbff5f7;

  /// Legacy key: Tunnelaktionen
  ///
  /// In en, this message translates to:
  /// **'Tunnel actions'**
  String get globeTunnelaktionenc0d41bdb;

  /// Legacy key: Tunnelindex konnte nicht geladen werden. Quelle und Build-Daten prüfen.
  ///
  /// In en, this message translates to:
  /// **'Unable to load tunnel index. Check source and build data.'**
  String get globeTunnelindexKonnteNichtGeladen03a91e8e;

  /// Legacy key: Tunnelmodell importieren (JSON)
  ///
  /// In en, this message translates to:
  /// **'Import Tunnel Model (JSON)'**
  String get globeTunnelmodellImportierenJson8ffcf7c7;

  /// Legacy key: Tunnelstatus & Daten
  ///
  /// In en, this message translates to:
  /// **'Tunnel status & data'**
  String get globeTunnelstatusDatend6e42b7d;

  /// Legacy key: Tunnelwerkzeuge
  ///
  /// In en, this message translates to:
  /// **'Tunnel tools'**
  String get globeTunnelwerkzeuge9873b3ba;

  /// Legacy key: Unable to reconnect to terrain. Please retry.
  ///
  /// In en, this message translates to:
  /// **'Unable to reconnect to terrain. Please retry.'**
  String get globeUnableToReconnectTo7f563fb8;

  /// Legacy key: Unable to update map preferences. Please retry.
  ///
  /// In en, this message translates to:
  /// **'Unable to update map preferences. Please retry.'**
  String get globeUnableToUpdateMap7af0a9ee;

  /// Legacy key: Unable to update map display. Please retry.
  ///
  /// In en, this message translates to:
  /// **'Unable to update map display. Please retry.'**
  String get globeUnableToUpdateMapefb1235c;

  /// Legacy key: Vorne nach hinten
  ///
  /// In en, this message translates to:
  /// **'Front to back'**
  String get globeVorneNachHinten4d9d3fd7;

  /// Legacy key: Weitere Datenebenen unter Mobilität & OSINT laden.
  ///
  /// In en, this message translates to:
  /// **'Load more data levels under Mobility & OSINT.'**
  String get globeWeitereDatenebenenUnterMobilitaetd36898b1;

  /// Legacy key: Weitere Einschränkungen möglich. Vor dem Flug amtliche Quellen prüfen.
  ///
  /// In en, this message translates to:
  /// **'Further restrictions possible. Check official sources before flight.'**
  String get globeWeitereEinschraenkungenMoeglichVor9c93ae78;

  /// Legacy key: WGS84 latitude: {0}°
  ///
  /// In en, this message translates to:
  /// **'WGS84 latitude: {arg0}°'**
  String globeWgsLatituded60b5fd1(String arg0);

  /// Legacy key: WGS84 longitude: {0}°
  ///
  /// In en, this message translates to:
  /// **'WGS84 longitude: {arg0}°'**
  String globeWgsLongitudece917f86(String arg0);

  /// Legacy key: Zum ersten Achsenpunkt
  ///
  /// In en, this message translates to:
  /// **'To first axis point'**
  String get globeZumErstenAchsenpunkt95f01d68;

  /// Legacy key: Zum letzten Achsenpunkt
  ///
  /// In en, this message translates to:
  /// **'To the last axis point'**
  String get globeZumLetztenAchsenpunkt5cbcd957;

  /// Legacy key: Änderungen speichern
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get groundroutesAnderungenSpeichern00fe8153;

  /// Legacy key: Angezeigte Route: {0}
  ///
  /// In en, this message translates to:
  /// **'Shown route: {arg0}'**
  String groundroutesAngezeigteRouteeceb9858(String arg0);

  /// Legacy key: Auf Globe anzeigen
  ///
  /// In en, this message translates to:
  /// **'Show on Globe'**
  String get groundroutesAufGlobeAnzeigenb40c4518;

  /// Legacy key: Bodenroute berechnen
  ///
  /// In en, this message translates to:
  /// **'Calculate soil route'**
  String get groundroutesBodenrouteBerechnena780689a;

  /// Legacy key: Bodenroute löschen
  ///
  /// In en, this message translates to:
  /// **'Delete ground route'**
  String get groundroutesBodenrouteLoeschen3c5c9ab7;

  /// Legacy key: Bodenroute speichern
  ///
  /// In en, this message translates to:
  /// **'Save ground route'**
  String get groundroutesBodenrouteSpeichern5b0ba694;

  /// Legacy key: {0} Bodenrouten gespeichert
  ///
  /// In en, this message translates to:
  /// **'{arg0} Soil routes stored'**
  String groundroutesBodenroutenGespeichert7c176a33(String arg0);

  /// Legacy key: Die angezeigte Route gehört zu den vorherigen Eingaben. Für die neuen Eingaben erneut berechnen.
  ///
  /// In en, this message translates to:
  /// **'The route shown is one of the previous entries. Recalculate for the new entries.'**
  String get groundroutesDieAngezeigteRouteGehoert7159dcb8;

  /// Legacy key: Gespeicherte Bodenrouten konnten nicht geladen werden.
  ///
  /// In en, this message translates to:
  /// **'Stored ground routes could not be loaded.'**
  String get groundroutesGespeicherteBodenroutenKonntenNicht88267d75;

  /// Legacy key: Gespeicherte Bodenrouten suchen
  ///
  /// In en, this message translates to:
  /// **'Search for stored ground routes'**
  String get groundroutesGespeicherteBodenroutenSuchenf43e3c82;

  /// Legacy key: Gespeicherten Ort auswählen
  ///
  /// In en, this message translates to:
  /// **'Select Saved Location'**
  String get groundroutesGespeichertenOrtAuswaehlenf23d82e2;

  /// Legacy key: Gewählten Kartenpunkt übernehmen
  ///
  /// In en, this message translates to:
  /// **'Take selected card point'**
  String get groundroutesGewaehltenKartenpunktUebernehmen1c0caa9a;

  /// Legacy key: GPX-Bodenrouten importieren?
  ///
  /// In en, this message translates to:
  /// **'Import GPX ground routes?'**
  String get groundroutesGpxBodenroutenImportierenbc579b06;

  /// Legacy key: GPX importieren
  ///
  /// In en, this message translates to:
  /// **'Import GPX'**
  String get groundroutesGpxImportieren08a786c6;

  /// Legacy key: Kartenvorschau ausblenden
  ///
  /// In en, this message translates to:
  /// **'Hide Card Preview'**
  String get groundroutesKartenvorschauAusblenden048fe407;

  /// Legacy key: Keine gespeicherten Bodenrouten gefunden
  ///
  /// In en, this message translates to:
  /// **'No stored ground routes found'**
  String get groundroutesKeineGespeichertenBodenroutenGefunden7adb49f7;

  /// Legacy key: „{0}“ löschen?
  ///
  /// In en, this message translates to:
  /// **'\"{arg0}? Delete?'**
  String groundroutesLoeschen42c1810b(String arg0);

  /// Legacy key: {0} · lokal gespeichert
  ///
  /// In en, this message translates to:
  /// **'{arg0} · Locally stored'**
  String groundroutesLokalGespeichertdafc6ec0(String arg0);

  /// Legacy key: Lokal gespeicherte Bodenrouten
  ///
  /// In en, this message translates to:
  /// **'Locally stored soil routes'**
  String get groundroutesLokalGespeicherteBodenrouten5824582d;

  /// Legacy key: Messstationen entlang der Route
  ///
  /// In en, this message translates to:
  /// **'Measurement stations along the route'**
  String get groundroutesMessstationenEntlangDerRouted9e511cf;

  /// Legacy key: Name der Bodenroute
  ///
  /// In en, this message translates to:
  /// **'Name of the ground route'**
  String get groundroutesNameDerBodenroute997555dc;

  /// Legacy key: Neue Route
  ///
  /// In en, this message translates to:
  /// **'New route'**
  String get groundroutesNeueRoutec6a2c583;

  /// Legacy key: Oberfläche: {0} · Zugang: {1}
  /// Höhen: {2}
  ///
  /// In en, this message translates to:
  /// **'Surface: {arg0} · Access: {arg1} Altitude: {arg2}'**
  String groundroutesOberflaecheZugangHoehen28c32a79(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: ÖV-Anreise zum Bodenrouten-Start planen
  ///
  /// In en, this message translates to:
  /// **'Plan a public transport trip to the ground route start'**
  String get groundroutesOvAnreiseZumBodenrouten39acd10e;

  /// Legacy key: Passendes Fuß- oder Veloprofil · OpenStreetMap-Grundlage
  ///
  /// In en, this message translates to:
  /// **'Suitable foot or bike profile · OpenStreetMap basis'**
  String get groundroutesPassendesFussOderVeloprofilc351a9b0;

  /// Legacy key: {0} · {1} · {2} Punkte
  ///
  /// In en, this message translates to:
  /// **'{arg0} · {arg1} · {arg2} points'**
  String groundroutesPunkte525d4984(String arg0, String arg1, String arg2);

  /// Legacy key: {0} Punkte · {1} · {2}
  ///
  /// In en, this message translates to:
  /// **'{arg0} points · {arg1} · {arg2}'**
  String groundroutesPunkte9b66050f(String arg0, String arg1, String arg2);

  /// Legacy key: Quelle: {0}
  /// Berechnet: {1}
  ///
  /// In en, this message translates to:
  /// **'Source: {arg0} Calculated: {arg1}'**
  String groundroutesQuelleBerechnet7150764e(String arg0, String arg1);

  /// Legacy key: Routenmodus ausdrücklich wählen
  ///
  /// In en, this message translates to:
  /// **'Explicitly select route mode'**
  String get groundroutesRoutenmodusAusdruecklichWaehlen420b0d52;

  /// Legacy key: Sperrungen im Routenumfeld
  ///
  /// In en, this message translates to:
  /// **'Blocks in the route environment'**
  String get groundroutesSperrungenImRoutenumfeld41a77f10;

  /// Legacy key: Start und Ziel zur Berechnung an FOSSGIS / OSRM senden
  ///
  /// In en, this message translates to:
  /// **'Send start and destination for calculation to FOSSGIS / OSRM'**
  String get groundroutesStartUndZielZur5a6b9fef;

  /// Legacy key: Start wählen
  ///
  /// In en, this message translates to:
  /// **'Select Start'**
  String get groundroutesStartWaehlendb986579;

  /// Legacy key: 500 Treffer angezeigt. Bitte die Suche eingrenzen.
  ///
  /// In en, this message translates to:
  /// **'500 hits shown. Please narrow down the search.'**
  String get groundroutesTrefferAngezeigtBitteDiefb7ecafc;

  /// Legacy key: Ungespeicherten Entwurf verlassen?
  ///
  /// In en, this message translates to:
  /// **'Leave unsaved design?'**
  String get groundroutesUngespeichertenEntwurfVerlassenff7b8bc6;

  /// Legacy key: Weitere Bodenrouten anzeigen
  ///
  /// In en, this message translates to:
  /// **'Show more soil routes'**
  String get groundroutesWeitereBodenroutenAnzeigen6060cffc;

  /// Legacy key: Ziel wählen
  ///
  /// In en, this message translates to:
  /// **'Select destination'**
  String get groundroutesZielWaehlenaaa64252;

  /// Legacy key: Guides und Hilfe
  ///
  /// In en, this message translates to:
  /// **'Guides and help'**
  String get helpGuidesUndHilfeecbecc1f;

  /// Legacy key: Kurzhilfe: {0}
  ///
  /// In en, this message translates to:
  /// **'Quick guide: {arg0}'**
  String helpKurzhilfec825661f(String arg0);

  /// Legacy key: Akkus
  ///
  /// In en, this message translates to:
  /// **'Batteries'**
  String get homeAkkusa10fdf22;

  /// Legacy key: Aktivitätsprofil: {0}
  ///
  /// In en, this message translates to:
  /// **'Activity profile: {arg0}'**
  String homeAktivitaetsprofilfef983f3(String arg0);

  /// Legacy key: Alle Kartenebenen
  ///
  /// In en, this message translates to:
  /// **'All map layers'**
  String get homeAlleKartenebenenc5387977;

  /// Legacy key: Alle Werkzeuge
  ///
  /// In en, this message translates to:
  /// **'All tools'**
  String get homeAlleWerkzeuge80af8bd2;

  /// Legacy key: Arbeitsbereich gewechselt. Kartenstartwerte folgen nach der laufenden Ansicht.
  ///
  /// In en, this message translates to:
  /// **'Workspace changed. Card start values follow after the current view.'**
  String get homeArbeitsbereichGewechseltKartenstartwerteFolgen74793f38;

  /// Legacy key: Arbeitsbereich
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get homeArbeitsbereichb5371daf;

  /// Legacy key: Ausrüstung
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get homeAusruestung67d2d167;

  /// Legacy key: Bevorzugte Ebenen
  ///
  /// In en, this message translates to:
  /// **'Favourite layers'**
  String get homeBevorzugteEbenen39447c21;

  /// Legacy key: Cancel route replay preparation
  ///
  /// In en, this message translates to:
  /// **'Cancel route replay preparation'**
  String get homeCancelRouteReplayPreparationb6a2fd00;

  /// Legacy key: Check airspace
  ///
  /// In en, this message translates to:
  /// **'Check airspace'**
  String get homeCheckAirspace81aa4af7;

  /// Legacy key: Close map status
  ///
  /// In en, this message translates to:
  /// **'Close map status'**
  String get homeCloseMapStatusbaaf9b31;

  /// Legacy key: Close spot details
  ///
  /// In en, this message translates to:
  /// **'Close spot details'**
  String get homeCloseSpotDetailsb8c47dc2;

  /// Legacy key: 3D globe ready
  ///
  /// In en, this message translates to:
  /// **'3D globe ready'**
  String get homeDGlobeReady1847f54f;

  /// Legacy key: Details
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get homeDetailsdc3decbb;

  /// Legacy key: Drohnen
  ///
  /// In en, this message translates to:
  /// **'Drones'**
  String get homeDrohnen1cb44d64;

  /// Legacy key: Einstellungen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeEinstellungen3e5af3d1;

  /// Legacy key: Flat map — terrain heights unavailable
  ///
  /// In en, this message translates to:
  /// **'Flat map — terrain heights unavailable'**
  String get homeFlatMapTerrainHeightsd993a5d7;

  /// Legacy key: Flugvorbereitung
  ///
  /// In en, this message translates to:
  /// **'Preflight'**
  String get homeFlugvorbereitungfc3259ae;

  /// Legacy key: Fly to Spot
  ///
  /// In en, this message translates to:
  /// **'Fly to Spot'**
  String get homeFlyToSpot253cde4f;

  /// Legacy key: Funk & Video
  ///
  /// In en, this message translates to:
  /// **'Radio & video'**
  String get homeFunkVideo955c11e1;

  /// Legacy key: Gespeicherte Orte
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get homeGespeicherteOrte681d182b;

  /// Legacy key: Karte und Aktivitäten
  ///
  /// In en, this message translates to:
  /// **'Map and activities'**
  String get homeKarteUndAktivitaetena2cfdeff;

  /// Legacy key: Kartenaktionen
  ///
  /// In en, this message translates to:
  /// **'Map actions'**
  String get homeKartenaktionen61a84371;

  /// Legacy key: Kartenstartwerte konnten nicht übernommen werden.
  ///
  /// In en, this message translates to:
  /// **'Card start values could not be taken over.'**
  String get homeKartenstartwerteKonntenNichtUebernommen8dd81e2c;

  /// Legacy key: Loading globe...
  ///
  /// In en, this message translates to:
  /// **'Loading globe...'**
  String get homeLoadingGlobe79eb5f94;

  /// Legacy key: Map error: {0}
  ///
  /// In en, this message translates to:
  /// **'Map error: {arg0}'**
  String homeMapError05472eae(String arg0);

  /// Legacy key: Map status
  ///
  /// In en, this message translates to:
  /// **'Map status'**
  String get homeMapStatus5f4e7ac0;

  /// Legacy key: Menü schließen
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get homeMenueSchliessen82332f74;

  /// Legacy key: More spot actions
  ///
  /// In en, this message translates to:
  /// **'More spot actions'**
  String get homeMoreSpotActionsec926581;

  /// Legacy key: No map data warnings
  ///
  /// In en, this message translates to:
  /// **'No map data warnings'**
  String get homeNoMapDataWarnings4f085b42;

  /// Legacy key: Offline & Daten
  ///
  /// In en, this message translates to:
  /// **'Offline & data'**
  String get homeOfflineDaten07b28abe;

  /// Legacy key: Open navigation menu
  ///
  /// In en, this message translates to:
  /// **'Open navigation menu'**
  String get homeOpenNavigationMenu5f83b0b6;

  /// Legacy key: Planen & Entdecken
  ///
  /// In en, this message translates to:
  /// **'Planning & Discovering'**
  String get homePlanenEntdecken9b5160ec;

  /// Legacy key: Profil wählen
  ///
  /// In en, this message translates to:
  /// **'Select Profile'**
  String get homeProfilWaehlencae393b1;

  /// Legacy key: Spot marker sync failed: {0}
  ///
  /// In en, this message translates to:
  /// **'Spot marker sync failed: {arg0}'**
  String homeSpotMarkerSyncFailed5c7dee42(String arg0);

  /// Legacy key: Suchen
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get homeSuchen20a96919;

  /// Legacy key: Terrain query failed: {0}
  ///
  /// In en, this message translates to:
  /// **'Terrain query failed: {arg0}'**
  String homeTerrainQueryFailed53f78995(String arg0);

  /// Legacy key: Unable to load stored spots: {0}
  ///
  /// In en, this message translates to:
  /// **'Unable to load stored spots: {arg0}'**
  String homeUnableToLoadStored9e66c17d(String arg0);

  /// Legacy key: Wetter
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get homeWetter72a9fa32;

  /// Legacy key: Abdeckung und zusätzliche Verkehrsdaten
  ///
  /// In en, this message translates to:
  /// **'Coverage and additional traffic data'**
  String get mobilityAbdeckungUndZusaetzlicheVerkehrsdatenca67bb5b;

  /// Legacy key: Abdeckung (WGS84): {0}
  ///
  /// In en, this message translates to:
  /// **'Cover (WGS84): {arg0}'**
  String mobilityAbdeckungWgsc9cd562f(String arg0);

  /// Legacy key: Abfahrt
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get mobilityAbfahrt3cca3329;

  /// Legacy key: Abfrage begrenzt. Weitere oder überlappende Regeln möglich.
  ///
  /// In en, this message translates to:
  /// **'Query limited. More or overlapping rules possible.'**
  String get mobilityAbfrageBegrenztWeitereOder5efa5f1a;

  /// Legacy key: Abgerufen am {0} · {1} → {2}
  ///
  /// In en, this message translates to:
  /// **'Called at {arg0} · {arg1} → {arg2}'**
  String mobilityAbgerufenAma792bdd8(String arg0, String arg1, String arg2);

  /// Legacy key: Abgerufen: {0} (UTC){1}{2}
  ///
  /// In en, this message translates to:
  /// **'Called: {arg0} (UTC){arg1}{arg2}'**
  String mobilityAbgerufenUtc47bb4052(String arg0, String arg1, String arg2);

  /// Legacy key: Abruf: {0} · Quellenpublikation: {1}
  ///
  /// In en, this message translates to:
  /// **'Search: {arg0} · Source publication: {arg1}'**
  String mobilityAbrufQuellenpublikation2c701097(String arg0, String arg1);

  /// Legacy key: Abruf veraltet · erneut aktualisieren
  ///
  /// In en, this message translates to:
  /// **'Retrieve outdated · re-update'**
  String get mobilityAbrufVeraltetErneutAktualisieren5ed4d00d;

  /// Legacy key: Abruf veraltet oder fehlgeschlagen · Messzeit jedes Werts prüfen.
  ///
  /// In en, this message translates to:
  /// **'Retrieve outdated or failed · Check the measurement time of each value.'**
  String get mobilityAbrufVeraltetOderFehlgeschlagen4afc83f7;

  /// Legacy key: Adresse oder Ort in der Schweiz
  ///
  /// In en, this message translates to:
  /// **'Address or place in Switzerland'**
  String get mobilityAdresseOderOrtInfa9d68ac;

  /// Legacy key: Aktiver OJP-API-Plan (Sitzung)
  ///
  /// In en, this message translates to:
  /// **'Active OJP API plan (session)'**
  String get mobilityAktiverOjpApiPlan5dce0b6f;

  /// Legacy key: Aktualisieren
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get mobilityAktualisieren87c65f26;

  /// Legacy key: Aktualisierung fehlgeschlagen: alte Standortdaten; Verfügbarkeit unbekannt.
  ///
  /// In en, this message translates to:
  /// **'Update failed: old location data; availability unknown.'**
  String get mobilityAktualisierungFehlgeschlagenAlteStandortdatenb2f09fc6;

  /// Legacy key: Aktualisierung fehlgeschlagen · letzter Datenstand bleibt sichtbar
  ///
  /// In en, this message translates to:
  /// **'Update failed · last data level remains visible'**
  String get mobilityAktualisierungFehlgeschlagenLetzterDatenstand97d6ca24;

  /// Legacy key: Aktualisierung fehlgeschlagen: vorhandener Stand bleibt erhalten.
  ///
  /// In en, this message translates to:
  /// **'Updating failed: existing status is maintained.'**
  String get mobilityAktualisierungFehlgeschlagenVorhandenerStand6dbee97c;

  /// Legacy key: Aktualisierung fehlgeschlagen; vorheriger Stand wird beibehalten.
  ///
  /// In en, this message translates to:
  /// **'Updating failed; prior status is maintained.'**
  String get mobilityAktualisierungFehlgeschlagenVorherigerStand6cb8348b;

  /// Legacy key: Aktualität nicht bestätigt – Angaben können überholt sein. Lokale Anordnungen prüfen.
  ///
  /// In en, this message translates to:
  /// **'Actuality not confirmed – information may be outdated. Check local arrangements.'**
  String get mobilityAktualitaetNichtBestaetigtAngaben58f3aa99;

  /// Legacy key: Aktuelle amtliche Massnahmen
  ///
  /// In en, this message translates to:
  /// **'Current official measures'**
  String get mobilityAktuelleAmtlicheMassnahmen1078b943;

  /// Legacy key: Aktuelle Meldungen auf Karte zeigen
  ///
  /// In en, this message translates to:
  /// **'Show latest news on map'**
  String get mobilityAktuelleMeldungenAufKarte65e8ab99;

  /// Legacy key: Alle Anbieter
  ///
  /// In en, this message translates to:
  /// **'All providers'**
  String get mobilityAlleAnbieter9c59c226;

  /// Legacy key: Alle Angebote
  ///
  /// In en, this message translates to:
  /// **'All offers'**
  String get mobilityAlleAngebote766cc617;

  /// Legacy key: Alle Ereignistypen
  ///
  /// In en, this message translates to:
  /// **'All event types'**
  String get mobilityAlleEreignistypenf0956deb;

  /// Legacy key: Alle Fahrzeugtypen
  ///
  /// In en, this message translates to:
  /// **'All vehicle types'**
  String get mobilityAlleFahrzeugtypenc3d9470c;

  /// Legacy key: Alle 60 Sekunden während der aktiven Navigation
  ///
  /// In en, this message translates to:
  /// **'Every 60 seconds during active navigation'**
  String get mobilityAlleSekundenWaehrendDer0476b439;

  /// Legacy key: Allow sending start and destination to FOSSGIS / OpenStreetMap routing.
  ///
  /// In en, this message translates to:
  /// **'Allow sending start and destination to FOSSGIS / OpenStreetMap routing.'**
  String get mobilityAllowSendingStartAnde6a35229;

  /// Legacy key: Allow sending this area centre to adsb.lol.
  ///
  /// In en, this message translates to:
  /// **'Allow sending this area centre to adsb.lol.'**
  String get mobilityAllowSendingThisAread1710796;

  /// Legacy key: Als Fahrziel wählen
  ///
  /// In en, this message translates to:
  /// **'Choose as driving destination'**
  String get mobilityAlsFahrzielWaehlen89ab104c;

  /// Legacy key: Amtliche Collection
  ///
  /// In en, this message translates to:
  /// **'Amtliche Collection'**
  String get mobilityAmtlicheCollectiond0ebbd40;

  /// Legacy key: Amtliche Legende / Produktinformation
  ///
  /// In en, this message translates to:
  /// **'Official Legend / Product Information'**
  String get mobilityAmtlicheLegendeProduktinformation73ec6293;

  /// Legacy key: Amtliche Massnahmen abfragen
  ///
  /// In en, this message translates to:
  /// **'Ask for official measures'**
  String get mobilityAmtlicheMassnahmenAbfragen08c2e83d;

  /// Legacy key: Amtliche Quelle / Ansicht
  ///
  /// In en, this message translates to:
  /// **'Official source / view'**
  String get mobilityAmtlicheQuelleAnsicht283a8bdd;

  /// Legacy key: Amtlicher Titel: {0}
  ///
  /// In en, this message translates to:
  /// **'Official title: {arg0}'**
  String mobilityAmtlicherTitelf2b2a993(String arg0);

  /// Legacy key: Anbieter öffnen (keine Reservierung)
  ///
  /// In en, this message translates to:
  /// **'Open provider (no reservation)'**
  String get mobilityAnbieterOeffnenKeineReservierung97c86374;

  /// Legacy key: Anbieter
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get mobilityAnbieterd062d4fe;

  /// Legacy key: Anfragebudget gilt nur für diese App-Sitzung. Die offiziellen Quoten gelten gemeinsam für alle Geräte mit demselben Schlüssel; HTTP 429 wird respektiert.
  ///
  /// In en, this message translates to:
  /// **'Request budget applies only to this app session. The official quotas apply jointly to all devices with the same key; HTTP 429 is respected.'**
  String get mobilityAnfragebudgetGiltNurFuer8bf6ad74;

  /// Legacy key: Angebotsart
  ///
  /// In en, this message translates to:
  /// **'Type of supply'**
  String get mobilityAngebotsart3d303646;

  /// Legacy key: Ankunft
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get mobilityAnkunft0b4333da;

  /// Legacy key: Anschlüsse: nicht veröffentlicht
  ///
  /// In en, this message translates to:
  /// **'Connections: not published'**
  String get mobilityAnschluesseNichtVeroeffentlicht1584b8b8;

  /// Legacy key: Anzeigereferenz · genaue Ausdehnung unbekannt
  ///
  /// In en, this message translates to:
  /// **'Display reference · exact extension unknown'**
  String get mobilityAnzeigereferenzGenaueAusdehnungUnbekannt92e1ba4c;

  /// Legacy key: ASTRA-Messwerte laden
  ///
  /// In en, this message translates to:
  /// **'Load ASTRA readings'**
  String get mobilityAstraMesswerteLadencc594459;

  /// Legacy key: ASTRA · Tabellenstand: {0}
  /// Lokal bezogen: {1}{2}
  ///
  /// In en, this message translates to:
  /// **'ASTRA · Table level: {arg0} Locally sourced: {arg1}{arg2}'**
  String mobilityAstraTabellenstandLokalBezogenfdd31ddb(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: ASTRA-Verkehrsmeldungen laden
  ///
  /// In en, this message translates to:
  /// **'Load ASTRA traffic messages'**
  String get mobilityAstraVerkehrsmeldungenLadenf278469c;

  /// Legacy key: ASTRA / VMZ-CH · Ereignis {0} · {1} Teilmeldungen
  ///
  /// In en, this message translates to:
  /// **'ASTRA / VMZ-CH · Event {arg0} · {arg1} Partial messages'**
  String mobilityAstraVmzChEreignis5068b250(String arg0, String arg1);

  /// Legacy key: ASTRA / VMZ-CH traffic situations · Swiss road network. Registered API access is required. TMC-only references require the matching official topology. Unlocated or uncertain messages remain information; sufficiently matched current data can be enabled for route comparison.
  ///
  /// In en, this message translates to:
  /// **'ASTRA / VMZ-CH traffic situations · Swiss road network. Registered API access is required. TMC-only references require the matching official topology. Unlocated or uncertain messages remain information; sufficiently matched current data can be enabled for route comparison.'**
  String get mobilityAstraVmzChTraffic19a07166;

  /// Legacy key: ASTRA / VMZ-CH veröffentlicht Ereignismeldungen. Ohne passende offizielle TMC-Ortstabelle können reine Ortscodes nicht auf der Karte verortet werden. Solche Meldungen bleiben hier durchsuchbar. Kartenpunkte können nur eine Anzeigereferenz sein; gerade Linien bilden keinen genauen Straßenverlauf ab.
  ///
  /// Durchgehende Verkehrsdichte und verkehrsabhängige Ankunftszeiten sind damit nicht verfügbar. ASTRA bietet zusätzlich Geschwindigkeiten und Fahrzeugmengen an Zählstellen über einen separaten API-Zugang an.
  ///
  /// In en, this message translates to:
  /// **'ASTRA / VMZ-CH publishes event messages. Without a suitable official TMC location table, pure location codes cannot be located on the map. Such messages remain searchable here. Map points can only be an display reference; straight lines do not represent a precise road course. Continuous traffic density and traffic-dependent arrival times are therefore not available. ASTRA also offers speeds and vehicle volumes at counters via a separate API access.'**
  String get mobilityAstraVmzChVeroeffentlicht4c4e6620;

  /// Legacy key: Auf 3D-Karte anzeigen (max. 150)
  ///
  /// In en, this message translates to:
  /// **'Show on 3D map (max. 150)'**
  String get mobilityAufDKarteAnzeigen2ad897d8;

  /// Legacy key: Auf 3D-Karte zeigen (max. 120)
  ///
  /// In en, this message translates to:
  /// **'Show on 3D map (max. 120)'**
  String get mobilityAufDKarteZeigenb9c8e9a8;

  /// Legacy key: Aufnahme (UTC): {0}
  ///
  /// In en, this message translates to:
  /// **'Recording (UTC): {arg0}'**
  String mobilityAufnahmeUtc809df7be(String arg0);

  /// Legacy key: Ausgewählten Kartenpunkt übernehmen
  ///
  /// In en, this message translates to:
  /// **'Apply selected map point'**
  String get mobilityAusgewaehltenKartenpunktUebernehmen849683eb;

  /// Legacy key: Ausgewählten Kartenpunkt verwenden
  ///
  /// In en, this message translates to:
  /// **'Use selected map point'**
  String get mobilityAusgewaehltenKartenpunktVerwenden90ebe0f5;

  /// Legacy key: Automatisch aktualisieren
  ///
  /// In en, this message translates to:
  /// **'Automatically update'**
  String get mobilityAutomatischAktualisierena2f998d7;

  /// Legacy key: BAFU Feature-ID: {0}
  ///
  /// In en, this message translates to:
  /// **'BAFU Feature-ID: {arg0}'**
  String mobilityBafuFeatureId27de0e54(String arg0);

  /// Legacy key: BAKOM-Erklärungen und amtliche Quelle
  ///
  /// In en, this message translates to:
  /// **'BAKOM declarations and official source'**
  String get mobilityBakomErklaerungenUndAmtliche7dfa13ad;

  /// Legacy key: BAKOM Mobilfunk-Basisstationen
  ///
  /// In en, this message translates to:
  /// **'BAKOM mobile phone base stations'**
  String get mobilityBakomMobilfunkBasisstationenb5426d86;

  /// Legacy key: Beenden
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get mobilityBeendence9e650e;

  /// Legacy key: Bei Routenabweichungen sendet die App Standort und Ziel an FOSSGIS. Der Dienst protokolliert die Anfrage. Im Hintergrund pausiert die Navigation.
  ///
  /// In en, this message translates to:
  /// **'FPVManager sends your location and destination to FOSSGIS when rerouting. FOSSGIS logs the request. Navigation pauses in the background.'**
  String get mobilityBeiRoutenabweichungenSendetDie131b098f;

  /// Legacy key: Beobachtungszeit: {0}
  ///
  /// In en, this message translates to:
  /// **'Observation time: {arg0}'**
  String mobilityBeobachtungszeite60e71e7(String arg0);

  /// Legacy key: Beobachtungszeitraum (STAC): {0} – {1}
  ///
  /// In en, this message translates to:
  /// **'Observation period (STAC): {arg0} – {arg1}'**
  String mobilityBeobachtungszeitraumStac7f2d19f8(String arg0, String arg1);

  /// Legacy key: Bewertung unvollständig · keine verkehrsbasierte Empfehlung
  ///
  /// In en, this message translates to:
  /// **'Assessment incomplete · no traffic-based recommendation'**
  String get mobilityBewertungUnvollstaendigKeineVerkehrsbasierte655a9750;

  /// Legacy key: BFE-Dokumentation und Nutzungsbedingungen
  ///
  /// In en, this message translates to:
  /// **'SFOE Documentation and Terms of Use'**
  String get mobilityBfeDokumentationUndNutzungsbedingungen58dca300;

  /// Legacy key: Bildebene entfernen / Basiskarte
  ///
  /// In en, this message translates to:
  /// **'Remove Image Level / Base Map'**
  String get mobilityBildebeneEntfernenBasiskarte8d450df2;

  /// Legacy key: Bildlayer: {0}{1}
  ///
  /// In en, this message translates to:
  /// **'Bildlayer: {arg0}{arg1}'**
  String mobilityBildlayer7779aa56(String arg0, String arg1);

  /// Legacy key: Breite (WGS84)
  ///
  /// In en, this message translates to:
  /// **'Width (WGS84)'**
  String get mobilityBreiteWgsbf85fa1c;

  /// Legacy key: Breitengrad
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get mobilityBreitengradf5eed2f2;

  /// Legacy key: Calculate driving route
  ///
  /// In en, this message translates to:
  /// **'Calculate driving route'**
  String get mobilityCalculateDrivingRoute59eac3f8;

  /// Legacy key: Calculated: {0} · {1}. The routing service may snap endpoints to nearby roads.
  ///
  /// In en, this message translates to:
  /// **'Calculated: {arg0} · {arg1}. The routing service may snap endpoints to nearby roads.'**
  String mobilityCalculatedTheRoutingService9f5e2267(String arg0, String arg1);

  /// Legacy key: Categories
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get mobilityCategories6ccb6007;

  /// Legacy key: CDI-Zeitstand (offizieller WMS-Parameter)
  ///
  /// In en, this message translates to:
  /// **'CDI (official WMS parameter)'**
  String get mobilityCdiZeitstandOffiziellerWms68eccda7;

  /// Legacy key: 3D-Daten fehlen oder sind offline nicht verfügbar.
  ///
  /// In en, this message translates to:
  /// **'3D data are missing or not available offline.'**
  String get mobilityDDatenFehlenOderdd9b0af0;

  /// Legacy key: 3D-Einstellung konnte nicht übernommen werden.
  ///
  /// In en, this message translates to:
  /// **'3D adjustment could not be taken over.'**
  String get mobilityDEinstellungKonnteNicht1dd69132;

  /// Legacy key: 3D-Umgebung in der Navigation
  ///
  /// In en, this message translates to:
  /// **'3D environment in navigation'**
  String get mobilityDUmgebungInDer7e362fb8;

  /// Legacy key: 3D-Umgebung
  ///
  /// In en, this message translates to:
  /// **'3D environment'**
  String get mobilityDUmgebungb7f47aad;

  /// Legacy key: Darstellungsfehler: {0}
  ///
  /// In en, this message translates to:
  /// **'Visual error: {arg0}'**
  String mobilityDarstellungsfehler750531ab(String arg0);

  /// Legacy key: Datenabruf älter als 24 Stunden.
  ///
  /// In en, this message translates to:
  /// **'Data retrieval older than 24 hours.'**
  String get mobilityDatenabrufAelterAlsStundenf8a928a3;

  /// Legacy key: Datenstand und Bewertungsregeln
  ///
  /// In en, this message translates to:
  /// **'Data status and evaluation rules'**
  String get mobilityDatenstandUndBewertungsregeln47599d2e;

  /// Legacy key: Datenstatus: {0}
  ///
  /// In en, this message translates to:
  /// **'Data status: {arg0}'**
  String mobilityDatenstatusd3d7b1d5(String arg0);

  /// Legacy key: Datierte Aufnahme anzeigen
  ///
  /// In en, this message translates to:
  /// **'Show Dated Recording'**
  String get mobilityDatierteAufnahmeAnzeigen461270db;

  /// Legacy key: Datierte Bilder suchen
  ///
  /// In en, this message translates to:
  /// **'Find Dated Images'**
  String get mobilityDatierteBilderSuchen2f4ff702;

  /// Legacy key: Datierte Satelliten- & Rapid-Mapping-Bilder
  ///
  /// In en, this message translates to:
  /// **'Dated satellite & rapid mapping images'**
  String get mobilityDatierteSatellitenRapidMappingf807e800;

  /// Legacy key: Destination spot
  ///
  /// In en, this message translates to:
  /// **'Destination spot'**
  String get mobilityDestinationSpotdfb0a64e;

  /// Legacy key: Detektor: {0} · Fahrstreifen: {1} · Fahrbahntyp: {2}
  ///
  /// In en, this message translates to:
  /// **'Detector: {arg0} · Road lanes: {arg1} · Roadway type: {arg2}'**
  String mobilityDetektorFahrstreifenFahrbahntype8312098(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: Die Quelle nennt wiederkehrende Zeitfenster. Einzelne Zeitfenster vor Fahrtantritt prüfen.
  ///
  /// In en, this message translates to:
  /// **'The source is called recurring time windows. Check individual time windows before driving.'**
  String get mobilityDieQuelleNenntWiederkehrende01133c3c;

  /// Legacy key: Direct browser requests are blocked by the provider CORS policy. Import a readsb/adsb.lol JSON snapshot or use Android; no public proxy is involved.
  ///
  /// In en, this message translates to:
  /// **'Direct browser requests are blocked by the provider CORS policy. Import a readsb/adsb.lol JSON snapshot or use Android; no public proxy is involved.'**
  String get mobilityDirectBrowserRequestsAre8f6307e5;

  /// Legacy key: Direkter Abruf auf Android verfügbar.
  ///
  /// In en, this message translates to:
  /// **'Direct retrieval available on Android.'**
  String get mobilityDirekterAbrufAufAndroid7c4ac605;

  /// Legacy key: Drei unabhängige amtliche Kartenebenen · optional
  ///
  /// In en, this message translates to:
  /// **'Three Independent Official Sides · Optional'**
  String get mobilityDreiUnabhaengigeAmtlicheKartenebenen6c0dfad0;

  /// Legacy key: Eigener Traffic-Counters-Token
  ///
  /// In en, this message translates to:
  /// **'Own Traffic Counters Token'**
  String get mobilityEigenerTrafficCountersTokenff5ddb8b;

  /// Legacy key: Eigener Zugang für Traffic Counters. Der Schlüssel für Verkehrsmeldungen wird dafür nicht wiederverwendet. Daten bleiben in dieser Sitzung.
  ///
  /// In en, this message translates to:
  /// **'Own access for traffic counters. The key to traffic messages is not reused. Data remains in this session.'**
  String get mobilityEigenerZugangFuerTraffic1a7bd79b;

  /// Legacy key: Einige 3D-Kacheln fehlen.
  ///
  /// In en, this message translates to:
  /// **'Some 3D tiles are missing.'**
  String get mobilityEinigeDKachelnFehlen747d8e09;

  /// Legacy key: {0} Einträge · Stand {1} · {2}{3}
  ///
  /// In en, this message translates to:
  /// **'{arg0} records · Status {arg1} · {arg2}{arg3}'**
  String mobilityEintraegeStandf4269e5b(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  );

  /// Legacy key: Ereignis / Einsatz: {0}
  ///
  /// In en, this message translates to:
  /// **'Event / deployment: {arg0}'**
  String mobilityEreignisEinsatzac1a3fa0(String arg0);

  /// Legacy key: {0} Ereignisse · {1} ohne Kartenposition · {2} nicht auswertbar
  ///
  /// In en, this message translates to:
  /// **'{arg0} Events · {arg1} without map item · {arg2} not evaluable'**
  String mobilityEreignisseOhneKartenpositionNichta9154e17(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: Erforderlich: eigener OJP-2.0-API-Schlüssel mit freigeschaltetem Produkt. Zugangsdaten bleiben in lokalem Secure Storage (Web: nur Arbeitsspeicher dieser Sitzung).
  ///
  /// In en, this message translates to:
  /// **'Required: own OJP 2.0 API key with unlocked product. Access data remain in local Secure Storage (Web: only memory of this session).'**
  String get mobilityErforderlichEigenerOjpApi4a8d7c41;

  /// Legacy key: Ergebnis begrenzt; kleinere Suchfläche wählen. Keine vollständige Abdeckung.
  ///
  /// In en, this message translates to:
  /// **'Result limited; select smaller search area. No full coverage.'**
  String get mobilityErgebnisBegrenztKleinereSuchflaeche4bec8127;

  /// Legacy key: {0} erneut laden
  ///
  /// In en, this message translates to:
  /// **'Reload {arg0}'**
  String mobilityErneutLaden13159aac(String arg0);

  /// Legacy key: {0} Fahrplan: {1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} Roadmap: {arg1}'**
  String mobilityFahrplan10147b40(String arg0, String arg1);

  /// Legacy key: Fahrzeuge laut Anbieter: {0}
  ///
  /// In en, this message translates to:
  /// **'Vehicles according to supplier: {arg0}'**
  String mobilityFahrzeugeLautAnbieterbf339e17(String arg0);

  /// Legacy key: Fahrzeugtyp
  ///
  /// In en, this message translates to:
  /// **'Vehicle type'**
  String get mobilityFahrzeugtyp76a9b894;

  /// Legacy key: Fehlende benötigte Tabellen laden
  ///
  /// In en, this message translates to:
  /// **'Load missing needed tables'**
  String get mobilityFehlendeBenoetigteTabellenLaden3eb0f8e9;

  /// Legacy key: Find nearby places
  ///
  /// In en, this message translates to:
  /// **'Find nearby places'**
  String get mobilityFindNearbyPlacesd0091995;

  /// Legacy key: First 100 details shown here. Other positioned records remain selectable on the map.
  ///
  /// In en, this message translates to:
  /// **'First 100 details shown here. Other positioned records remain selectable on the map.'**
  String get mobilityFirstDetailsShownHere859f2457;

  /// Legacy key: Fortschritt pausiert · GPS prüfen
  ///
  /// In en, this message translates to:
  /// **'Progress paused · Check GPS'**
  String get mobilityFortschrittPausiertGpsPruefen63c6fa50;

  /// Legacy key: FOSSGIS logs the route request. Spot names and notes stay in the app.
  ///
  /// In en, this message translates to:
  /// **'FOSSGIS logs the route request. Spot names and notes stay in the app.'**
  String get mobilityFossgisLogsTheRoute7ac53fd4;

  /// Legacy key: Free-Floating
  ///
  /// In en, this message translates to:
  /// **'Free-Floating'**
  String get mobilityFreeFloating38dd1268;

  /// Legacy key: Freies Ziel
  ///
  /// In en, this message translates to:
  /// **'Free destination'**
  String get mobilityFreiesZiele762f189;

  /// Legacy key: Für diese Anfrage wurden keine Verbindungen gefunden.
  ///
  /// In en, this message translates to:
  /// **'No connections were found for this request.'**
  String get mobilityFuerDieseAnfrageWurden9803db4c;

  /// Legacy key: Für diese Version ist kein LTEF-ZIP hinterlegt. Im offiziellen Katalog prüfen; GeoPackage wird noch nicht unterstützt.
  ///
  /// In en, this message translates to:
  /// **'No LTE-ZIP is available for this version. Check the official catalogue; GeoPackage is not supported yet.'**
  String get mobilityFuerDieseVersionIst88b3c175;

  /// Legacy key: Gerade Verbindung zwischen Quellenpositionen; kein genauer Straßenverlauf.
  ///
  /// In en, this message translates to:
  /// **'Straight link between source positions; no precise road.'**
  String get mobilityGeradeVerbindungZwischenQuellenpositionen0a65d12c;

  /// Legacy key: Gerätestandort
  ///
  /// In en, this message translates to:
  /// **'Device location'**
  String get mobilityGeraetestandorta680a346;

  /// Legacy key: {0} {1} (Gerätezeit)
  ///
  /// In en, this message translates to:
  /// **'{arg0} {arg1} (device time)'**
  String mobilityGeraetezeit4dd99dec(String arg0, String arg1);

  /// Legacy key: Geschwindigkeiten und Fahrzeugmengen an Messstellen
  ///
  /// In en, this message translates to:
  /// **'Speeds and vehicle quantities at measuring points'**
  String get mobilityGeschwindigkeitenUndFahrzeugmengenAn522f5906;

  /// Legacy key: Geschwindigkeiten und Fahrzeugraten an bis zu 100 Detektoren im gewählten 30-km-Gebiet.
  ///
  /// In en, this message translates to:
  /// **'Speeds and vehicle rates at up to 100 detectors in the selected 30 km area.'**
  String get mobilityGeschwindigkeitenUndFahrzeugratenAnba71d451;

  /// Legacy key: Gespeicherte Abfrage anzeigen
  ///
  /// In en, this message translates to:
  /// **'Show Saved Query'**
  String get mobilityGespeicherteAbfrageAnzeigen62c7018c;

  /// Legacy key: Gespeicherte Daten · Aktualität nicht live geprüft
  ///
  /// In en, this message translates to:
  /// **'Saved data · Actuality not checked live'**
  String get mobilityGespeicherteDatenAktualitaetNichta41279f4;

  /// Legacy key: Gespeicherte Verbindungen ({0})
  ///
  /// In en, this message translates to:
  /// **'Stored connections {arg0}'**
  String mobilityGespeicherteVerbindungen895ea994(String arg0);

  /// Legacy key: Gespeicherten Spot übernehmen (optional)
  ///
  /// In en, this message translates to:
  /// **'Apply saved spot (optional)'**
  String get mobilityGespeichertenSpotUebernehmenOptionald048ef49;

  /// Legacy key: Gespeicherten Stand
  ///
  /// In en, this message translates to:
  /// **'Stored status'**
  String get mobilityGespeichertenStand0b0b171e;

  /// Legacy key: Gespeicherter Abruf ist älter als 15 Minuten.
  ///
  /// In en, this message translates to:
  /// **'Stored retrieval is older than 15 minutes.'**
  String get mobilityGespeicherterAbrufIstAelterc7e97b86;

  /// Legacy key: Gespeicherter Metadatenstand – keine aktuelle Live-Bestätigung.
  ///
  /// In en, this message translates to:
  /// **'Stored metadata stand – no current live confirmation.'**
  String get mobilityGespeicherterMetadatenstandKeineAktuelle17c89c8f;

  /// Legacy key: Gespeicherter Spot (optional)
  ///
  /// In en, this message translates to:
  /// **'Stored spot (optional)'**
  String get mobilityGespeicherterSpotOptional1c4bdc07;

  /// Legacy key: Gespeicherter Stand (offline nutzbar)
  ///
  /// In en, this message translates to:
  /// **'Stored stand (offline usable)'**
  String get mobilityGespeicherterStandOfflineNutzbarc7dc6f17;

  /// Legacy key: GPS erneut verbinden
  ///
  /// In en, this message translates to:
  /// **'Reconnect GPS'**
  String get mobilityGpsErneutVerbindend3c0a56a;

  /// Legacy key: Gültig ab: {0} · bis: {1}
  ///
  /// In en, this message translates to:
  /// **'Valid from: {arg0} · to: {arg1}'**
  String mobilityGueltigAbBisc0b768b9(String arg0, String arg1);

  /// Legacy key: Gültig seit: {0} · bis: {1}
  ///
  /// In en, this message translates to:
  /// **'Valid from: {arg0} · to: {arg1}'**
  String mobilityGueltigSeitBise1e05815(String arg0, String arg1);

  /// Legacy key: Hide POIs on 3D map
  ///
  /// In en, this message translates to:
  /// **'Hide POIs on 3D map'**
  String get mobilityHidePoisOnD072cee45;

  /// Legacy key: {0} Hinweise · {1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} Notes · {arg1}'**
  String mobilityHinweisec38e74ed(String arg0, String arg1);

  /// Legacy key: I have registered access and accepted the provider terms for my own use.
  ///
  /// In en, this message translates to:
  /// **'I have registered access and accepted the provider terms for my own use.'**
  String get mobilityIHaveRegisteredAccessa282c504;

  /// Legacy key: Im Web das Original-ZIP über den offiziellen Download beziehen und lokal importieren. Kein zusätzlicher API-Schlüssel erforderlich.
  ///
  /// In en, this message translates to:
  /// **'Get the original ZIP on the web via the official download and import it locally. No additional API key required.'**
  String get mobilityImWebDasOriginal2ebbbc3c;

  /// Legacy key: Import aircraft JSON
  ///
  /// In en, this message translates to:
  /// **'Import aircraft JSON'**
  String get mobilityImportAircraftJson444ad3f1;

  /// Legacy key: Import DATEX XML
  ///
  /// In en, this message translates to:
  /// **'Import DATEX XML'**
  String get mobilityImportDatexXml5eb44537;

  /// Legacy key: Importierte Daten · online nicht geprüft
  ///
  /// In en, this message translates to:
  /// **'Imported data · not checked online'**
  String get mobilityImportierteDatenOnlineNicht8129ba14;

  /// Legacy key: In {0} km · im 300-m-Routenumfeld
  ///
  /// In en, this message translates to:
  /// **'In {arg0} km · in the 300 m route environment'**
  String mobilityInKmImMf10f6e91(String arg0);

  /// Legacy key: Kacheln erneut versuchen
  ///
  /// In en, this message translates to:
  /// **'Try tile again'**
  String get mobilityKachelnErneutVersuchenc1fb6d60;

  /// Legacy key: {0}
  /// Kacheln: {1} · Quelldatum nicht durch Kachelladen bestätigt
  ///
  /// In en, this message translates to:
  /// **'{arg0} Tiles: {arg1} · Source date not confirmed by tile shop'**
  String mobilityKachelnQuelldatumNichtDurch5d14a5bc(String arg0, String arg1);

  /// Legacy key: Kanton: {0} · Gebiet: {1}
  ///
  /// In en, this message translates to:
  /// **'Canton: {arg0} · Area: {arg1}'**
  String mobilityKantonGebiet2306a36c(String arg0, String arg1);

  /// Legacy key: Kantonale Fachstellen
  ///
  /// In en, this message translates to:
  /// **'Cantonal centres'**
  String get mobilityKantonaleFachstellen9b9d1abf;

  /// Legacy key: Kantonale Waldbrand-Präventionsmassnahmen
  ///
  /// In en, this message translates to:
  /// **'Cantonal forest fire prevention measures'**
  String get mobilityKantonaleWaldbrandPraeventionsmassnahmena6d2b302;

  /// Legacy key: Karte frei bewegen
  ///
  /// In en, this message translates to:
  /// **'Move Map Free'**
  String get mobilityKarteFreiBewegene1d97140;

  /// Legacy key: Kartendarstellung
  ///
  /// In en, this message translates to:
  /// **'Map representation'**
  String get mobilityKartendarstellungefb26012;

  /// Legacy key: Kartenpunkt
  ///
  /// In en, this message translates to:
  /// **'Map point'**
  String get mobilityKartenpunkt8b21f720;

  /// Legacy key: Kein öffentlicher Beschreibungstext vorhanden.
  ///
  /// In en, this message translates to:
  /// **'No public description available.'**
  String get mobilityKeinOeffentlicherBeschreibungstextVorhanden581108e5;

  /// Legacy key: Keine auswertbaren Messwerte
  ///
  /// In en, this message translates to:
  /// **'No evaluable measured values'**
  String get mobilityKeineAuswertbarenMesswerte4dc49063;

  /// Legacy key: Keine datierten Massnahmen für diesen Punkt ermittelt. Die Abdeckung kann unvollständig sein – KEINE Entwarnung.
  ///
  /// In en, this message translates to:
  /// **'No dated measures determined for this point. The coverage may be incomplete – NOT a warning.'**
  String get mobilityKeineDatiertenMassnahmenFuer9c369d5c;

  /// Legacy key: Keine Kontakt-E-Mail nötig: REST-v1-Schnittstelle ohne Login.
  ///
  /// In en, this message translates to:
  /// **'No contact e-mail required: REST-v1 interface without login.'**
  String get mobilityKeineKontaktEMail7ee17077;

  /// Legacy key: Keine passenden Meldungen. Das bestätigt keine freie Fahrt oder vollständige Quellenabdeckung.
  ///
  /// In en, this message translates to:
  /// **'No matching messages. This does not confirm a free ride or full source coverage.'**
  String get mobilityKeinePassendenMeldungenDas1634f284;

  /// Legacy key: Keine überprüfte Qualitätsmaske – Wolken und Bildlücken können vorhanden sein.
  ///
  /// In en, this message translates to:
  /// **'No checked quality mask – clouds and image gaps can be present.'**
  String get mobilityKeineUeberpruefteQualitaetsmaskeWolken490d3ea2;

  /// Legacy key: Keine Verkehrsdaten geladen
  ///
  /// In en, this message translates to:
  /// **'No traffic data loaded'**
  String get mobilityKeineVerkehrsdatenGeladena56a2b8a;

  /// Legacy key: Keys use device secure storage and are sent only to the official ASTRA endpoint.
  ///
  /// In en, this message translates to:
  /// **'Keys use device secure storage and are sent only to the official ASTRA endpoint.'**
  String get mobilityKeysUseDeviceSecuref60f66e8;

  /// Legacy key: {0} km · {1} min estimated
  ///
  /// In en, this message translates to:
  /// **'{arg0} km · {arg1} min estimated'**
  String mobilityKmMinEstimated439c5826(String arg0, String arg1);

  /// Legacy key: Koordinaten für die Abfrage an geo.admin.ch senden
  ///
  /// In en, this message translates to:
  /// **'Send coordinates for the query to geo.admin.ch'**
  String get mobilityKoordinatenFuerDieAbfrage631e8e79;

  /// Legacy key: {0} Ladestandorte · Abruf {1}{2}
  ///
  /// In en, this message translates to:
  /// **'{arg0} Loading sites · Retrieving {arg1}{arg2}'**
  String mobilityLadestandorteAbrufe451a0c3(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: Ladestationen in der Schweiz · BFE / geo.admin.ch. Freie Plätze sind nur eine datierte Meldung und keine Reservierung. Ergebnisse können unvollständig sein.
  ///
  /// In en, this message translates to:
  /// **'Charging stations in Switzerland · BFE / geo.admin.ch. Free spaces are only a dated message and no reservation. Results may be incomplete.'**
  String get mobilityLadestationenInDerSchweiza8bd739c;

  /// Legacy key: Ladestationen suchen
  ///
  /// In en, this message translates to:
  /// **'Find Charging Stations'**
  String get mobilityLadestationenSuchen805f1685;

  /// Legacy key: Länge (WGS84)
  ///
  /// In en, this message translates to:
  /// **'Length (WGS84)'**
  String get mobilityLaengeWgs7a5b794e;

  /// Legacy key: Längengrad
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get mobilityLaengengrad9436942a;

  /// Legacy key: Latitude
  ///
  /// In en, this message translates to:
  /// **'Latitude'**
  String get mobilityLatitudeced3905e;

  /// Legacy key: Layer update failed. Please retry.
  ///
  /// In en, this message translates to:
  /// **'Layer update failed. Please retry.'**
  String get mobilityLayerUpdateFailedPlease636e8a82;

  /// Legacy key: Letzte Aktualisierung fehlgeschlagen; letzter Stand wird angezeigt.
  ///
  /// In en, this message translates to:
  /// **'Last update failed; last update is displayed.'**
  String get mobilityLetzteAktualisierungFehlgeschlagenLetzterf5121616;

  /// Legacy key: Letzten Katalogstand öffnen
  ///
  /// In en, this message translates to:
  /// **'Open Last Catalog Stand'**
  String get mobilityLetztenKatalogstandOeffnene2aafc7e;

  /// Legacy key: Letzter Abruf aktuell
  ///
  /// In en, this message translates to:
  /// **'Last call up'**
  String get mobilityLetzterAbrufAktuellfe37dd68;

  /// Legacy key: Letzter Abruf / Import: {0}
  ///
  /// In en, this message translates to:
  /// **'Last call/import: {arg0}'**
  String mobilityLetzterAbrufImportea742e4d(String arg0);

  /// Legacy key: Liste auf 60 Einträge begrenzt. Filter oder Radius anpassen.
  ///
  /// In en, this message translates to:
  /// **'List limited to 60 entries. Adjust filter or radius.'**
  String get mobilityListeAufEintraegeBegrenzt46a09ccd;

  /// Legacy key: Liste auf 60 Einträge begrenzt; Radius verkleinern.
  ///
  /// In en, this message translates to:
  /// **'List limited to 60 entries; reduce radius.'**
  String get mobilityListeAufEintraegeBegrenzt47537bf9;

  /// Legacy key: Live-Messwerte · Traffic Counters
  ///
  /// In en, this message translates to:
  /// **'Live-Messwerte · Traffic Counters'**
  String get mobilityLiveMesswerteTrafficCountersaee8a401;

  /// Legacy key: Lizenz-Metadaten: {0} · {1} Asset-Verweise; davon {2} als JSON/CSV klassifiziert.
  ///
  /// In en, this message translates to:
  /// **'License metadata: {arg0} · {arg1} Asset links; of which {arg2} classified as JSON/CSV.'**
  String mobilityLizenzMetadatenAssetVerweisedcf92706(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: Location access is requested only when pressed; coordinates are sent to the routing provider only when you calculate.
  ///
  /// In en, this message translates to:
  /// **'Location access is requested only when pressed; coordinates are sent to the routing provider only when you calculate.'**
  String get mobilityLocationAccessIsRequestedab7f6719;

  /// Legacy key: Löst Schweizer Ortscodes und Tabellenrichtungen auf. Referenzdaten werden lokal gespeichert; die Aktualität der Verkehrsmeldungen bleibt unabhängig davon.
  ///
  /// In en, this message translates to:
  /// **'Dissolves Swiss location codes and table directions. Reference data are stored locally; the timeliness of traffic messages remains independent of this.'**
  String get mobilityLoestSchweizerOrtscodesUnd47816372;

  /// Legacy key: Longitude
  ///
  /// In en, this message translates to:
  /// **'Longitude'**
  String get mobilityLongitude6f9f011c;

  /// Legacy key: Maximale Trefferzahl erreicht: nicht alle Standorte erfasst. Radius verkleinern.
  ///
  /// In en, this message translates to:
  /// **'Maximum number of hits reached: not all locations recorded. Reduce radius.'**
  String get mobilityMaximaleTrefferzahlErreichtNichtcbd9a35f;

  /// Legacy key: Mehrere amtliche Gebiete überlagern sich. Geltungsbereich und Vorrang bitte bei den Kantonen prüfen.
  ///
  /// In en, this message translates to:
  /// **'Several official territories overlap. Scope and priority please check with the cantons.'**
  String get mobilityMehrereAmtlicheGebieteUeberlagern220c23d0;

  /// Legacy key: Meldung geändert: {0}
  ///
  /// In en, this message translates to:
  /// **'Notification as amended: {arg0}'**
  String mobilityMeldungGeaenderta349466c(String arg0);

  /// Legacy key: Meldungen im 300-m-Umfeld; Straße und Fahrtrichtung sind nicht bestätigt. Die Ankunftsschätzung enthält keine Stauzeiten.
  ///
  /// In en, this message translates to:
  /// **'Notifications in the 300 m area; road and direction of travel are not confirmed. Arrival estimate does not include traffic jams.'**
  String get mobilityMeldungenImMUmfeld417f6077;

  /// Legacy key: Messstellen auf Karte zeigen
  ///
  /// In en, this message translates to:
  /// **'Show measuring points on map'**
  String get mobilityMessstellenAufKarteZeigen191576b4;

  /// Legacy key: Messstellen im gewählten Gebiet
  ///
  /// In en, this message translates to:
  /// **'Measuring points in the selected area'**
  String get mobilityMessstellenImGewaehltenGebietfb7f4f74;

  /// Legacy key: Messwerte aktualisieren
  ///
  /// In en, this message translates to:
  /// **'Update readings'**
  String get mobilityMesswerteAktualisierendbc899d0;

  /// Legacy key: Messwerte werden geladen …
  ///
  /// In en, this message translates to:
  /// **'Loading readings..'**
  String get mobilityMesswerteWerdenGeladence66c18a;

  /// Legacy key: {0} · {1}: {2} {3}
  /// Messzeit: {4} · Intervall: {5} s{6}
  ///
  /// In en, this message translates to:
  /// **'{arg0} · {arg1}: {arg2} {arg3} Measuring time: {arg4} · Interval: {arg5} s{arg6}'**
  String mobilityMesszeitIntervallSd22c606f(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
    String arg6,
  );

  /// Legacy key: Metadaten älter als 24 h / Uhrzeit unplausibel.
  ///
  /// In en, this message translates to:
  /// **'Metadata older than 24 h / time implausible.'**
  String get mobilityMetadatenAelterAlsHfcd2d03c;

  /// Legacy key: Metadaten heruntergeladen: {0}
  ///
  /// In en, this message translates to:
  /// **'Metadata downloaded: {arg0}'**
  String mobilityMetadatenHeruntergeladen4f8bd0e0(String arg0);

  /// Legacy key: {0} min · {1} · Ankunft {2}:{3}
  ///
  /// In en, this message translates to:
  /// **'{arg0} min · {arg1} · Arrival {arg2}:{arg3}'**
  String mobilityMinAnkunft0b629c3a(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  );

  /// Legacy key: Mobility & OSINT
  ///
  /// In en, this message translates to:
  /// **'Mobility & OSINT'**
  String get mobilityMobilityOsint1a8134ea;

  /// Legacy key: Näher heranzoomen
  ///
  /// In en, this message translates to:
  /// **'Zoom Closer'**
  String get mobilityNaeherHeranzoomenccfc2dce;

  /// Legacy key: Navigation
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get mobilityNavigationcf03cf2e;

  /// Legacy key: Neuberechnungen sind frühestens alle 30 Sekunden möglich. Die Ankunftsschätzung bleibt ohne Verkehrszuschläge.
  ///
  /// In en, this message translates to:
  /// **'Recalculations are possible at the earliest every 30 seconds. The arrival estimate remains without traffic surcharges.'**
  String get mobilityNeuberechnungenSindFruehestensAllea6a83143;

  /// Legacy key: Nicht alle Anbieter liefern Daten. Fehlende Treffer bedeuten keine vollständige Abdeckung.
  ///
  /// In en, this message translates to:
  /// **'Not all providers provide data. Missing hits do not mean full coverage.'**
  String get mobilityNichtAlleAnbieterLiefernb166930b;

  /// Legacy key: Nicht klassifiziert: {0}
  ///
  /// In en, this message translates to:
  /// **'Not classified: {arg0}'**
  String mobilityNichtKlassifiziert32692a7b(String arg0);

  /// Legacy key: Nicht unterstützte Datei-Assets (z. B. GeoPackage) werden nicht automatisch importiert.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file assets (e.g. GeoPackage) are not imported automatically.'**
  String get mobilityNichtUnterstuetzteDateiAssetsaf920b33;

  /// Legacy key: No automatic polling. Queries are limited locally to 12/hour and at least 15 seconds apart. The provider may apply stricter limits.
  ///
  /// In en, this message translates to:
  /// **'No automatic polling. Queries are limited locally to 12/hour and at least 15 seconds apart. The provider may apply stricter limits.'**
  String get mobilityNoAutomaticPollingQueries62b013f8;

  /// Legacy key: No information loaded. Missing data does not mean clear roads or empty airspace.
  ///
  /// In en, this message translates to:
  /// **'No information loaded. Missing data does not mean clear roads or empty airspace.'**
  String get mobilityNoInformationLoadedMissing2c3854cc;

  /// Legacy key: No saved spots. Choose Freies Ziel to enter a destination.
  ///
  /// In en, this message translates to:
  /// **'No saved spots. Choose Freies Ziel to enter a destination.'**
  String get mobilityNoSavedSpotsChoose44cb95eb;

  /// Legacy key: Nur ausreichend zugeordnete aktuelle Daten. Neue Meldungen allein lösen keinen Routenwechsel aus.
  ///
  /// In en, this message translates to:
  /// **'Only sufficiently assigned current data. New messages alone do not trigger a route change.'**
  String get mobilityNurAusreichendZugeordneteAktuellea3f9bd6d;

  /// Legacy key: Nur begrenzte STAC-Auswahl geprüft; Vollständigkeit nicht bestätigt.
  ///
  /// In en, this message translates to:
  /// **'Only limited STAC selection checked; completeness not confirmed.'**
  String get mobilityNurBegrenzteStacAuswahla9abd316;

  /// Legacy key: Nur durch ausdrückliches Suchen; keine Standortüberwachung.
  ///
  /// In en, this message translates to:
  /// **'Only by explicit search; no site monitoring.'**
  String get mobilityNurDurchAusdruecklichesSuchen62af35c2;

  /// Legacy key: Nur mit Kartenposition
  ///
  /// In en, this message translates to:
  /// **'Only with map position'**
  String get mobilityNurMitKartenposition87e01213;

  /// Legacy key: Nutzt deinen gespeicherten Zugang. Aktualisierung bei Bedarf in der Navigation; keine Stauzeiten in der Ankunftsschätzung.
  ///
  /// In en, this message translates to:
  /// **'Uses your saved access. Update in navigation if required; no congestion in the arrival estimate.'**
  String get mobilityNutztDeinenGespeichertenZugang06987d0c;

  /// Legacy key: Nutzt vorhandene Daten. Beeinflusst auch spätere Neuberechnungen; die Fahrzeit bleibt eine OSRM-Basisschätzung.
  ///
  /// In en, this message translates to:
  /// **'Uses existing data. Also influences later recalculations; the driving time remains an OSRM base estimate.'**
  String get mobilityNutztVorhandeneDatenBeeinflusst7a5969ac;

  /// Legacy key: Official legend & source
  ///
  /// In en, this message translates to:
  /// **'Official legend & source'**
  String get mobilityOfficialLegendSourcefc8aaddf;

  /// Legacy key: Offizielle Einzelabfrage · unabhängig von der Waldbrand-Gefahrenstufe
  ///
  /// In en, this message translates to:
  /// **'Official individual inquiry · independent of the forest fire hazard level'**
  String get mobilityOffizielleEinzelabfrageUnabhaengigVon105d62b9;

  /// Legacy key: Offizielle Nutzungsbedingungen
  ///
  /// In en, this message translates to:
  /// **'Official Terms of Use'**
  String get mobilityOffizielleNutzungsbedingungen7ce05187;

  /// Legacy key: Offizielle STAC-Collection
  ///
  /// In en, this message translates to:
  /// **'Offizielle STAC-Collection'**
  String get mobilityOffizielleStacCollectiond6ac1266;

  /// Legacy key: Offizieller Download und Quellen
  ///
  /// In en, this message translates to:
  /// **'Official download and sources'**
  String get mobilityOffiziellerDownloadUndQuellen43d0f2a7;

  /// Legacy key: Offizieller Open Journey Planner 2.0 (Schweiz). Verbindungssuche bis zum tatsächlichen gewählten Punkt; Parkplatz- und Autokoordinaten werden nicht eingesetzt.
  ///
  /// In en, this message translates to:
  /// **'Official Open Journey Planner 2.0 (Switzerland). Connection search to the actual selected point; parking and auto coordinates are not used.'**
  String get mobilityOffiziellerOpenJourneyPlanner328efb58;

  /// Legacy key: Offline-/Cache-Katalog – keine Live-Bestätigung.
  ///
  /// In en, this message translates to:
  /// **'Offline/cache catalog – no live confirmation.'**
  String get mobilityOfflineCacheKatalogKeine803aa9f6;

  /// Legacy key: Offline-Sprachausgabe einschalten
  ///
  /// In en, this message translates to:
  /// **'Enable offline voice output'**
  String get mobilityOfflineSprachausgabeEinschalten826f1a70;

  /// Legacy key: Ohne Kartenposition · TMC-Ortstabelle erforderlich
  ///
  /// In en, this message translates to:
  /// **'Without map position · TMC location table required'**
  String get mobilityOhneKartenpositionTmcOrtstabelle29d7c796;

  /// Legacy key: Ohne nutzbare Quellenposition
  ///
  /// In en, this message translates to:
  /// **'Without usable source position'**
  String get mobilityOhneNutzbareQuellenposition09a6b7b9;

  /// Legacy key: OJP-Abfrageergebnis
  ///
  /// In en, this message translates to:
  /// **'OJP query result'**
  String get mobilityOjpAbfrageergebnis539abae1;

  /// Legacy key: OJP-Dokumentation und Quelle
  ///
  /// In en, this message translates to:
  /// **'OJP documentation and source'**
  String get mobilityOjpDokumentationUndQuelle808dc1c2;

  /// Legacy key: OpenStreetMap coverage is incomplete and attributes may be absent or outdated.
  ///
  /// In en, this message translates to:
  /// **'OpenStreetMap coverage is incomplete and attributes may be absent or outdated.'**
  String get mobilityOpenstreetmapCoverageIsIncompletee9ae81d0;

  /// Legacy key: Optional parking & access points
  ///
  /// In en, this message translates to:
  /// **'Optional parking & access points'**
  String get mobilityOptionalParkingAccessPoints7538207e;

  /// Legacy key: {0} OSM places · retrieved {1}{2}
  ///
  /// In en, this message translates to:
  /// **'{arg0} OSM places · retrieved {arg1}{arg2}'**
  String mobilityOsmPlacesRetrieved45a236fa(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: OSRM liefert nicht immer Alternativen. Fehlende Meldungen oder Messungen bestätigen keinen freien Verkehrsfluss.
  ///
  /// In en, this message translates to:
  /// **'OSRM does not always provide alternatives. Missing messages or measurements do not confirm free traffic flow.'**
  String get mobilityOsrmLiefertNichtImmer92919ffd;

  /// Legacy key: OUTDATED: This offline snapshot may no longer reflect available facilities.
  ///
  /// In en, this message translates to:
  /// **'OUTDATED: This offline snapshot may no longer reflect available facilities.'**
  String get mobilityOutdatedThisOfflineSnapshot5eb25014;

  /// Legacy key: ÖV-Verbindungen · OJP 2.0
  ///
  /// In en, this message translates to:
  /// **'Public transport connections · OJP 2.0'**
  String get mobilityOvVerbindungenOjp3ac37a87;

  /// Legacy key: ÖV-Verbindungen suchen
  ///
  /// In en, this message translates to:
  /// **'Search for public transport connections'**
  String get mobilityOvVerbindungenSuchen7014824a;

  /// Legacy key: Overpass API documentation and fair-use policy
  ///
  /// In en, this message translates to:
  /// **'Overpass API documentation and fair-use policy'**
  String get mobilityOverpassApiDocumentationAnd4c33de59;

  /// Legacy key: Own ASTRA API key
  ///
  /// In en, this message translates to:
  /// **'Own ASTRA API key'**
  String get mobilityOwnAstraApiKey38bbd3b9;

  /// Legacy key: {0} passende Ereignisse{1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} appropriate events{arg1}'**
  String mobilityPassendeEreignisse872c00ef(String arg0, String arg1);

  /// Legacy key: {0}
  /// {1} positioned records · {2} without usable positions · {3} omitted.
  ///
  /// In en, this message translates to:
  /// **'{arg0}\n{arg1} positioned records · {arg2} without usable positions · {arg3} omitted.'**
  String mobilityPositionedRecordsWithoutUsable456e69a4(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  );

  /// Legacy key: Produkt: {0} · {1}
  ///
  /// In en, this message translates to:
  /// **'Product: {arg0} · {arg1}'**
  String mobilityProduktbc93422a(String arg0, String arg1);

  /// Legacy key: Prognosezeitstand: keine direkte Beobachtung.
  ///
  /// In en, this message translates to:
  /// **'Forecast time: no direct observation.'**
  String get mobilityPrognosezeitstandKeineDirekteBeobachtungbef744b1;

  /// Legacy key: Provider unavailable; showing a dated cached snapshot instead.
  ///
  /// In en, this message translates to:
  /// **'Provider unavailable; showing a dated cached snapshot instead.'**
  String get mobilityProviderUnavailableShowingA4e8d9841;

  /// Legacy key: Publikationsstand der Quelle: {0}
  ///
  /// In en, this message translates to:
  /// **'Source: {arg0}'**
  String mobilityPublikationsstandDerQuellec3da8498(String arg0);

  /// Legacy key: Punktuelle Geschwindigkeiten werden ohne vergleichbare Messungen aller Alternativen nicht gewichtet.
  ///
  /// In en, this message translates to:
  /// **'Point speeds are not weighted without comparable measurements of all alternatives.'**
  String get mobilityPunktuelleGeschwindigkeitenWerdenOhne74f8b6a6;

  /// Legacy key: Punktuelle Messungen der Quelle. Fahrzeugmengen sind Raten in Fahrzeugen pro Stunde. Werte verschiedener Fahrstreifen und Fahrzeuggruppen werden nicht addiert. Keine durchgehende Staukarte.
  ///
  /// In en, this message translates to:
  /// **'Specific measurements of the source. Numbers of vehicles are rates in vehicles per hour. Values of different lanes and vehicle groups are not added. No continuous traffic card.'**
  String get mobilityPunktuelleMessungenDerQuellee6b23c9f;

  /// Legacy key: Qualitäts-/Wolkenmaske als eigenes Datenasset vorhanden; nicht automatisch als wolkenfrei interpretiert.
  ///
  /// In en, this message translates to:
  /// **'Quality/cloud mask available as own dataasset; not automatically interpreted as cloud-free.'**
  String get mobilityQualitaetsWolkenmaskeAlsEigenes3ad85811;

  /// Legacy key: Quelle: BAFU / Kantone · geo.admin.ch · waldbrandgefahr.ch
  ///
  /// In en, this message translates to:
  /// **'Source: FOEN / Cantons · geo.admin.ch · waldbranddranger.ch'**
  String get mobilityQuelleBafuKantoneGeo76ff0395;

  /// Legacy key: Quelle und Nutzungsbedingungen
  ///
  /// In en, this message translates to:
  /// **'Source and Terms of Use'**
  String get mobilityQuelleUndNutzungsbedingungene5956cc4;

  /// Legacy key: Quellen & Grenzen
  ///
  /// In en, this message translates to:
  /// **'Sources & Limits'**
  String get mobilityQuellenGrenzen4bc8454f;

  /// Legacy key: Quellenmeldung: {0}
  ///
  /// In en, this message translates to:
  /// **'Source: {arg0}'**
  String mobilityQuellenmeldung8bdd0b3c(String arg0);

  /// Legacy key: Quellenpublikation: {0}
  ///
  /// In en, this message translates to:
  /// **'Source publication: {arg0}'**
  String mobilityQuellenpublikationd60ff8d0(String arg0);

  /// Legacy key: Quellenveröffentlichung: {0}
  ///
  /// In en, this message translates to:
  /// **'Source publication: {arg0}'**
  String mobilityQuellenveroeffentlichung5456a71d(String arg0);

  /// Legacy key: Rasterkarten senden den Kartenausschnitt an geo.admin.ch. Das SLF-Bulletin wird ohne Standort als nationaler Datensatz geladen. Ladedaten bestätigen keine amtliche Gültigkeit. Flugplatzdaten ersetzen nicht das AIP; Brandgefahrenkarten ersetzen keine lokalen Anordnungen. Die Ebenen erteilen keine Flug- oder Zugangsfreigabe.
  ///
  /// In en, this message translates to:
  /// **'Raster map requests send the displayed area to geo.admin.ch. The app retrieves the national SLF bulletin without sending a location. Retrieval dates do not establish official validity. Consult the AIP for aerodromes and local orders for fire restrictions. Map layers grant neither flight nor access authorisation.'**
  String get mobilityRasterkartenSendenDenKartenausschnittf2f4eb37;

  /// Legacy key: Referenz: {0}
  ///
  /// In en, this message translates to:
  /// **'Reference: {arg0}'**
  String mobilityReferenz917463e5(String arg0);

  /// Legacy key: Refresh aircraft
  ///
  /// In en, this message translates to:
  /// **'Refresh aircraft'**
  String get mobilityRefreshAircraftcf46fb55;

  /// Legacy key: Refresh from Overpass
  ///
  /// In en, this message translates to:
  /// **'Refresh from Overpass'**
  String get mobilityRefreshFromOverpass6925d82f;

  /// Legacy key: Refresh traffic
  ///
  /// In en, this message translates to:
  /// **'Refresh traffic'**
  String get mobilityRefreshTrafficde6624d5;

  /// Legacy key: Remove {0} layer
  ///
  /// In en, this message translates to:
  /// **'Remove {arg0} layer'**
  String mobilityRemoveLayer98fc17fe(String arg0);

  /// Legacy key: Report a map error
  ///
  /// In en, this message translates to:
  /// **'Report a map error'**
  String get mobilityReportAMapError8ddb12c3;

  /// Legacy key: Results truncated to protect the device. Reduce your radius or category selection.
  ///
  /// In en, this message translates to:
  /// **'Results truncated to protect the device. Reduce your radius or category selection.'**
  String get mobilityResultsTruncatedToProtect98dcb26a;

  /// Legacy key: {0}
  /// {1}
  /// Retrieved/imported: {2}
  /// Source publication: {3}
  /// Dataset validity: not declared; individual records may provide dates.
  ///
  /// In en, this message translates to:
  /// **'{arg0}\n{arg1}\nRetrieved/imported: {arg2}\nSource publication: {arg3}\nDataset validity: not declared; individual records may provide dates.'**
  String mobilityRetrievedImportedSourcePublicationadd5e4e8(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  );

  /// Legacy key: Retry tiles
  ///
  /// In en, this message translates to:
  /// **'Retry tiles'**
  String get mobilityRetryTilesa3340dc4;

  /// Legacy key: Route neu berechnen
  ///
  /// In en, this message translates to:
  /// **'Recalculate route'**
  String get mobilityRouteNeuBerechnen8225e5ba;

  /// Legacy key: Routenalternativen neu berechnen
  ///
  /// In en, this message translates to:
  /// **'Recalculate route alternatives'**
  String get mobilityRoutenalternativenNeuBerechnen5de70eb6;

  /// Legacy key: Satellitenkarte
  ///
  /// In en, this message translates to:
  /// **'Satellite map'**
  String get mobilitySatellitenkarte6afd828c;

  /// Legacy key: Save access notes locally
  ///
  /// In en, this message translates to:
  /// **'Save access notes locally'**
  String get mobilitySaveAccessNotesLocallyf5e29d86;

  /// Legacy key: Save as personal spot
  ///
  /// In en, this message translates to:
  /// **'Save as personal spot'**
  String get mobilitySaveAsPersonalSpotc26312fd;

  /// Legacy key: Saved as spot #{0}
  ///
  /// In en, this message translates to:
  /// **'Saved as spot #{arg0}'**
  String mobilitySavedAsSpota5bf3429(String arg0);

  /// Legacy key: Saved spots unavailable.
  ///
  /// In en, this message translates to:
  /// **'Saved spots unavailable.'**
  String get mobilitySavedSpotsUnavailableb5814146;

  /// Legacy key: Search around saved spot (optional)
  ///
  /// In en, this message translates to:
  /// **'Search around saved spot (optional)'**
  String get mobilitySearchAroundSavedSpot88def52e;

  /// Legacy key: Search radius (metres)
  ///
  /// In en, this message translates to:
  /// **'Search radius (metres)'**
  String get mobilitySearchRadiusMetres9f19e093;

  /// Legacy key: Sharing-Angebote am ÖV-Ziel suchen
  ///
  /// In en, this message translates to:
  /// **'Search for sharing offers at the public transport destination'**
  String get mobilitySharingAngeboteAmOvcb5d14df;

  /// Legacy key: Sharing-Angebote suchen
  ///
  /// In en, this message translates to:
  /// **'Search for sharing offers'**
  String get mobilitySharingAngeboteSuchen5659da3e;

  /// Legacy key: Show driving route on map
  ///
  /// In en, this message translates to:
  /// **'Show driving route on map'**
  String get mobilityShowDrivingRouteOn3860ee86;

  /// Legacy key: Show POIs on 3D map
  ///
  /// In en, this message translates to:
  /// **'Show POIs on 3D map'**
  String get mobilityShowPoisOnD87e9f7a8;

  /// Legacy key: Show saved search offline
  ///
  /// In en, this message translates to:
  /// **'Show saved search offline'**
  String get mobilityShowSavedSearchOffline9f9ba558;

  /// Legacy key: Show snapshot on map
  ///
  /// In en, this message translates to:
  /// **'Show snapshot on map'**
  String get mobilityShowSnapshotOnMap1ce6224b;

  /// Legacy key: Showing the first 60 POI detail cards; up to 300 points can be rendered on the map.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 60 POI detail cards; up to 300 points can be rendered on the map.'**
  String get mobilityShowingTheFirstPoie98a81e6;

  /// Legacy key: {0} snapshot visible
  ///
  /// In en, this message translates to:
  /// **'{arg0} snapshot visible'**
  String mobilitySnapshotVisiblec86e4891(String arg0);

  /// Legacy key: Snapshots are delayed and incomplete. Amber markers are older than 30 seconds; positions older than 5 minutes are hidden. Markers sit on the terrain; reported aircraft altitudes are available in details. Never use this to replace visual airspace observation or official aviation information.
  ///
  /// In en, this message translates to:
  /// **'Snapshots are delayed and incomplete. Amber markers are older than 30 seconds; positions older than 5 minutes are hidden. Markers sit on the terrain; reported aircraft altitudes are available in details. Never use this to replace visual airspace observation or official aviation information.'**
  String get mobilitySnapshotsAreDelayedAnd4458e3d6;

  /// Legacy key: Sprachausgabe ausschalten
  ///
  /// In en, this message translates to:
  /// **'Switch off voice output'**
  String get mobilitySprachausgabeAusschalten212e3af6;

  /// Legacy key: STAC abgefragt: {0} · {1} Treffer in begrenzter Stichprobe
  ///
  /// In en, this message translates to:
  /// **'STAC requested: {arg0} · {arg1} Results in limited sample'**
  String mobilityStacAbgefragtTrefferIn004b3edc(String arg0, String arg1);

  /// Legacy key: STAC-Assets prüfen
  ///
  /// In en, this message translates to:
  /// **'Check STAC Assets'**
  String get mobilityStacAssetsPruefen15fce27f;

  /// Legacy key: STAC-Datenstand prüfen
  ///
  /// In en, this message translates to:
  /// **'Check STAC data level'**
  String get mobilityStacDatenstandPruefen445b5f79;

  /// Legacy key: STAC-Metadaten für swissEO VHI werden nur auf Wunsch abgefragt. Der Abrufzeitpunkt und der Beobachtungszeitraum werden getrennt gespeichert. WMS-/WMTS-Kacheln werden nicht als Offline-Datensatz archiviert.
  ///
  /// In en, this message translates to:
  /// **'STAC metadata for swissEO VHI are requested only on request. The call-up time and the observation period are stored separately. WMS/WMTS tiles are not archived as an offline data record.'**
  String get mobilityStacMetadatenFuerSwisseofe06af42;

  /// Legacy key: STAC-Stand: {0}
  ///
  /// In en, this message translates to:
  /// **'STAC status: {arg0}'**
  String mobilityStacStand0f0a2434(String arg0);

  /// Legacy key: Standort folgen
  ///
  /// In en, this message translates to:
  /// **'Follow Location'**
  String get mobilityStandortFolgen5650d84d;

  /// Legacy key: Standortdaten älter als fünf Minuten; nicht live.
  ///
  /// In en, this message translates to:
  /// **'Location data older than five minutes; not live.'**
  String get mobilityStandortdatenAelterAlsFuenfe3719933;

  /// Legacy key: Starten
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get mobilityStarten2beb7350;

  /// Legacy key: {0} Stationen · {1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} stations · {arg1}'**
  String mobilityStationen2bee7a5c(String arg0, String arg1);

  /// Legacy key: Stationen auf dem 3D-Globus
  ///
  /// In en, this message translates to:
  /// **'Stations on the 3D globe'**
  String get mobilityStationenAufDemD84751cec;

  /// Legacy key: Stationen suchen
  ///
  /// In en, this message translates to:
  /// **'Search Stations'**
  String get mobilityStationenSuchen87f44373;

  /// Legacy key: Stationen
  ///
  /// In en, this message translates to:
  /// **'Stationen'**
  String get mobilityStationencfddc861;

  /// Legacy key: Stationslayer ausblenden
  ///
  /// In en, this message translates to:
  /// **'Hide Station Layer'**
  String get mobilityStationslayerAusblenden28212b4d;

  /// Legacy key: Suchkoordinaten an geo.admin.ch senden
  ///
  /// In en, this message translates to:
  /// **'Send search coordinates to geo.admin.ch'**
  String get mobilitySuchkoordinatenAnGeoAdmin3849c24c;

  /// Legacy key: Suchkoordinaten beim BFE / geo.admin.ch abfragen
  ///
  /// In en, this message translates to:
  /// **'Search coordinates at the SFOE / geo.admin.ch'**
  String get mobilitySuchkoordinatenBeimBfeGeo298d1eb7;

  /// Legacy key: Suchkoordinaten für eine Abfrage an sharedmobility.ch senden
  ///
  /// In en, this message translates to:
  /// **'Send search coordinates for a query to sharedmobility.ch'**
  String get mobilitySuchkoordinatenFuerEineAbfrage44b6f76d;

  /// Legacy key: Suchradius
  ///
  /// In en, this message translates to:
  /// **'Search radius'**
  String get mobilitySuchradius51fb2797;

  /// Legacy key: Suchzentrum: gespeicherter Spot (optional)
  ///
  /// In en, this message translates to:
  /// **'Search center: saved spot (optional)'**
  String get mobilitySuchzentrumGespeicherterSpotOptional8f6f54a7;

  /// Legacy key: swissEO Sentinel-2 v200 / amtliche Ereignisaufnahmen · optional
  ///
  /// In en, this message translates to:
  /// **'swissEO Sentinel-2 v200 / official event recordings · optional'**
  String get mobilitySwisseoSentinelVAmtlichedcab45cb;

  /// Legacy key: swissEO VHI · Datenstatus: {0}
  ///
  /// In en, this message translates to:
  /// **'swissEO VHI · Data status: {arg0}'**
  String mobilitySwisseoVhiDatenstatus0fe52fab(String arg0);

  /// Legacy key: Tabelle {0} entfernen
  ///
  /// In en, this message translates to:
  /// **'Remove Table {arg0}'**
  String mobilityTabelleEntfernenad464a91(String arg0);

  /// Legacy key: Tabelle {0} laden
  ///
  /// In en, this message translates to:
  /// **'Load table {arg0}'**
  String mobilityTabelleLaden750049fc(String arg0);

  /// Legacy key: {0} Tabellen lokal{1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} local {arg1}'**
  String mobilityTabellenLokal09ba7ffc(String arg0, String arg1);

  /// Legacy key: Tabellenversion
  ///
  /// In en, this message translates to:
  /// **'Table version'**
  String get mobilityTabellenversionb0986031;

  /// Legacy key: Technologie unbekannt
  ///
  /// In en, this message translates to:
  /// **'Technology unknown'**
  String get mobilityTechnologieUnbekanntbdb10475;

  /// Legacy key: {0} Teilmeldungen aufgelöst · {1} noch offen
  ///
  /// In en, this message translates to:
  /// **'{arg0} Partial messages dissolved · {arg1} still open'**
  String mobilityTeilmeldungenAufgeloestNochOffenaa8196c8(
    String arg0,
    String arg1,
  );

  /// Legacy key: TMC {0} · {1} Orte
  ///
  /// In en, this message translates to:
  /// **'TMC {arg0} · {arg1} Places'**
  String mobilityTmcOrted224adb9(String arg0, String arg1);

  /// Legacy key: TMC-Ortsdaten
  ///
  /// In en, this message translates to:
  /// **'TMC location data'**
  String get mobilityTmcOrtsdatene977fc3e;

  /// Legacy key: TMC-Tabellenbezug · kein genauer Straßenverlauf
  ///
  /// In en, this message translates to:
  /// **'TMC table reference · no precise road route'**
  String get mobilityTmcTabellenbezugKeinGenauer361692b0;

  /// Legacy key: TMC-Version {0} · Orte {1} · Richtungscode {2}
  ///
  /// In en, this message translates to:
  /// **'TMC version {arg0} · Places {arg1} · Direction code {arg2}'**
  String mobilityTmcVersionOrteRichtungscodecfd846ff(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: TMC-ZIP importieren
  ///
  /// In en, this message translates to:
  /// **'Import TMC ZIP'**
  String get mobilityTmcZipImportieren41204dbf;

  /// Legacy key: Topografische Karte
  ///
  /// In en, this message translates to:
  /// **'Topographic map'**
  String get mobilityTopografischeKarte0698a0c0;

  /// Legacy key: {0} Treffer nach Filter
  ///
  /// In en, this message translates to:
  /// **'{arg0} results by filter'**
  String mobilityTrefferNachFilterd2e8e9db(String arg0);

  /// Legacy key: Trefferlimit erreicht: keine vollständige Gebietserfassung. Suchradius verkleinern.
  ///
  /// In en, this message translates to:
  /// **'Hit limit reached: no complete area detection. Reduce search radius.'**
  String get mobilityTrefferlimitErreichtKeineVollstaendigedb231641;

  /// Legacy key: Trockenheit & Vegetationszustand (BAFU / swissEO)
  ///
  /// In en, this message translates to:
  /// **'Dryness & Vegetation Condition (BAFU / swissEO)'**
  String get mobilityTrockenheitVegetationszustandBafuSwisseoa63812c2;

  /// Legacy key: {0} Umstiege · {1} Fußwege
  ///
  /// In en, this message translates to:
  /// **'{arg0} Change · {arg1} Footpaths'**
  String mobilityUmstiegeFusswege891d4f80(String arg0, String arg1);

  /// Legacy key: Unlocated · {0}
  ///
  /// In en, this message translates to:
  /// **'Unlocated · {arg0}'**
  String mobilityUnlocated0f6d01d4(String arg0);

  /// Legacy key: Use device location
  ///
  /// In en, this message translates to:
  /// **'Use device location'**
  String get mobilityUseDeviceLocation37b5a739;

  /// Legacy key: Verbindung {0}: {1} – {2}
  ///
  /// In en, this message translates to:
  /// **'Connection {arg0}: {arg1} – {arg2}'**
  String mobilityVerbindungc49ec173(String arg0, String arg1, String arg2);

  /// Legacy key: Verbindungen offline als Momentaufnahme speichern
  ///
  /// In en, this message translates to:
  /// **'Save connections offline as snapshot'**
  String get mobilityVerbindungenOfflineAlsMomentaufnahme0524e3f4;

  /// Legacy key: Vergleichbare Gesamtverkehrs-Messungen aller Alternativen beeinflussen den Vergleich geringfügig (höchstens ein Vergleichspunkt).
  ///
  /// In en, this message translates to:
  /// **'Comparable total traffic measurements of all alternatives slightly affect the comparison (at most one point of comparison).'**
  String get mobilityVergleichbareGesamtverkehrsMessungenAller0e5faa9f;

  /// Legacy key: Vergleich: {0}
  ///
  /// In en, this message translates to:
  /// **'Comparison: {arg0}'**
  String mobilityVergleichd42555f6(String arg0);

  /// Legacy key: Verkehr aktualisieren
  ///
  /// In en, this message translates to:
  /// **'Update traffic'**
  String get mobilityVerkehrAktualisieren7e12eefe;

  /// Legacy key: Verkehr automatisch aktualisieren
  ///
  /// In en, this message translates to:
  /// **'Automatically update traffic'**
  String get mobilityVerkehrAutomatischAktualisieren83ed17ce;

  /// Legacy key: Verkehr bei der Routenbewertung berücksichtigen
  ///
  /// In en, this message translates to:
  /// **'Taking traffic into account in route evaluation'**
  String get mobilityVerkehrBeiDerRoutenbewertung65a144f1;

  /// Legacy key: Verkehr bei Neuberechnung berücksichtigen
  ///
  /// In en, this message translates to:
  /// **'Account for transport when recalculating'**
  String get mobilityVerkehrBeiNeuberechnungBeruecksichtigen47577e32;

  /// Legacy key: Verkehr entlang der Route
  ///
  /// In en, this message translates to:
  /// **'Traffic along the route'**
  String get mobilityVerkehrEntlangDerRoute746b9545;

  /// Legacy key: Verkehrsdaten ausgeschaltet
  ///
  /// In en, this message translates to:
  /// **'Traffic data disabled'**
  String get mobilityVerkehrsdatenAusgeschalteta2ae8d43;

  /// Legacy key: Verkehrsdaten laden / prüfen
  ///
  /// In en, this message translates to:
  /// **'Load/check traffic data'**
  String get mobilityVerkehrsdatenLadenPruefen27aded3f;

  /// Legacy key: Verkehrsmeldungen werden aktualisiert …
  ///
  /// In en, this message translates to:
  /// **'Updating traffic messages ..'**
  String get mobilityVerkehrsmeldungenWerdenAktualisiert10e1b261;

  /// Legacy key: Veröffentlicht: {0}
  ///
  /// In en, this message translates to:
  /// **'Published: {arg0}'**
  String mobilityVeroeffentlichtf559efaf(String arg0);

  /// Legacy key: VHI v100 wird laut swisstopo bis Ende 2026 durch v200 ersetzt. Bis zur verifizierten Umstellung ist der aktuelle Layer eine Übergangslösung.
  ///
  /// In en, this message translates to:
  /// **'According to swisstopo, VHI v100 will be replaced by v200 by the end of 2026. Until the verified conversion, the current layer is a transitional solution.'**
  String get mobilityVhiVWirdLaute6dca0e6;

  /// Legacy key: View OSM source
  ///
  /// In en, this message translates to:
  /// **'View OSM source'**
  String get mobilityViewOsmSource395c9b71;

  /// Legacy key: Web availability depends on the public endpoint’s CORS policy; direct requests may fail in browsers. No proxy or intermediary is configured. This search does not download OSM map tiles.
  ///
  /// In en, this message translates to:
  /// **'Web availability depends on the public endpoint’s CORS policy; direct requests may fail in browsers. No proxy or intermediary is configured. This search does not download OSM map tiles.'**
  String get mobilityWebAvailabilityDependsOna0047196;

  /// Legacy key: Web: CORS nicht verifiziert. Bei Browser-Sperre ist ein eigener Proxy erforderlich; keiner eingerichtet.
  ///
  /// In en, this message translates to:
  /// **'Web: CORS not verified. Browser lock requires a proprietary proxy; none is set up.'**
  String get mobilityWebCorsNichtVerifiziert29e7d189;

  /// Legacy key: Web: OJP-CORS und Browser-Zugriff nicht verifiziert. Direkte Anfrage kann fehlschlagen. Kein Relay/Proxy vorhanden; Keys im Browser sind gegenüber Seitenskripten nicht geschützt.
  ///
  /// In en, this message translates to:
  /// **'Web: OJP-CORS and browser access not verified. Direct request may fail. No relay/proxy available; keys in the browser are not protected against page scripts.'**
  String get mobilityWebOjpCorsUndd96e47d9;

  /// Legacy key: Weiter herauszoomen
  ///
  /// In en, this message translates to:
  /// **'Zoom Out More'**
  String get mobilityWeiterHerauszoomen212b4f14;

  /// Legacy key: Weitere Meldungen ({0})
  ///
  /// In en, this message translates to:
  /// **'Other messages {arg0}'**
  String mobilityWeitereMeldungenc11d95f1(String arg0);

  /// Legacy key: Weitere Messstellen
  ///
  /// In en, this message translates to:
  /// **'Other measuring points'**
  String get mobilityWeitereMessstellene0dab34a;

  /// Legacy key: Weitere STAC-Seiten vorhanden bzw. Trefferlimit erreicht. Abdeckung unvollständig.
  ///
  /// In en, this message translates to:
  /// **'More STAC pages available or hit limit reached. Cover incomplete.'**
  String get mobilityWeitereStacSeitenVorhanden8ac44f7a;

  /// Legacy key: {0} weitere / ungültige Alternativen nicht dargestellt.
  ///
  /// In en, this message translates to:
  /// **'{arg0} other / invalid alternatives not shown.'**
  String mobilityWeitereUngueltigeAlternativenNichtc1e16f33(String arg0);

  /// Legacy key: {0} weitere zugeordnete Hinweise
  ///
  /// In en, this message translates to:
  /// **'{arg0} other related references'**
  String mobilityWeitereZugeordneteHinweise883d2761(String arg0);

  /// Legacy key: Wie Karte
  ///
  /// In en, this message translates to:
  /// **'As on map'**
  String get mobilityWieKarte9cb7c6de;

  /// Legacy key: Wolkenanteil gemäss Quelle: {0} %
  ///
  /// In en, this message translates to:
  /// **'Cloud share according to source: {arg0} %'**
  String mobilityWolkenanteilGemaessQuelle15e9a8e3(String arg0);

  /// Legacy key: Wolkenanteil: nicht angegeben
  ///
  /// In en, this message translates to:
  /// **'Cloud share: not specified'**
  String get mobilityWolkenanteilNichtAngegeben76ffb608;

  /// Legacy key: Zählstellen-Token entfernen
  ///
  /// In en, this message translates to:
  /// **'Remove Counting Point Token'**
  String get mobilityZaehlstellenTokenEntfernen15b8092b;

  /// Legacy key: Zählstellen-Token speichern
  ///
  /// In en, this message translates to:
  /// **'Save Count Tokens'**
  String get mobilityZaehlstellenTokenSpeichern6579a132;

  /// Legacy key: Zählstellenzugang freigeschaltet und ASTRA-Bedingungen akzeptiert
  ///
  /// In en, this message translates to:
  /// **'Count access unlocked and ASTRA conditions accepted'**
  String get mobilityZaehlstellenzugangFreigeschaltetUndAstraa64cddb1;

  /// Legacy key: Ziel
  ///
  /// In en, this message translates to:
  /// **'Objective'**
  String get mobilityZiel44d12621;

  /// Legacy key: Ziel: {0}
  ///
  /// In en, this message translates to:
  /// **'Objective: {arg0}'**
  String mobilityZiel85926175(String arg0);

  /// Legacy key: Ziel suchen
  ///
  /// In en, this message translates to:
  /// **'Search Target'**
  String get mobilityZielSuchen5a773b38;

  /// Legacy key: Zuerst im Traffic-Tab den Token für Road traffic - traffic situations speichern und die Anbieterbedingungen akzeptieren.
  ///
  /// In en, this message translates to:
  /// **'First in the traffic tab store the token for road traffic - traffic situations and accept the provider conditions.'**
  String get mobilityZuerstImTrafficTab4547f06d;

  /// Legacy key: Zuerst werden Routen mit zugeordneten Sperrmeldungen nachrangig angezeigt. Danach zählen OSRM-Basiszeit und der größte publizierte Verzögerungswert. Verzögerungen werden nicht summiert und verändern die angezeigte Ankunftszeit nicht.
  ///
  /// In en, this message translates to:
  /// **'First, routes with associated blocking messages are displayed subordinately. After that, OSRM base time and the largest published delay value count. Delays are not summed up and do not change the displayed arrival time.'**
  String get mobilityZuerstWerdenRoutenMit9d2c4bb2;

  /// Legacy key: {0} zugeordnete Detektoren · {1} ohne passende Metadaten
  ///
  /// In en, this message translates to:
  /// **'{arg0} associated detectors · {arg1} without matching metadata'**
  String mobilityZugeordneteDetektorenOhnePassende637e378d(
    String arg0,
    String arg1,
  );

  /// Legacy key: {0} zugeordnete Sperrmeldungen · {1} zugeordnete Quellenhinweise
  ///
  /// In en, this message translates to:
  /// **'Release messages associated with {arg0} · {arg1}'**
  String mobilityZugeordneteSperrmeldungenZugeordneteQuellenhinweiseee632e99(
    String arg0,
    String arg1,
  );

  /// Legacy key: Zuordnung und Quellen
  ///
  /// In en, this message translates to:
  /// **'Allocation and sources'**
  String get mobilityZuordnungUndQuellend088f13c;

  /// Legacy key: Zusätzliche Datenebenen · Angaben können unvollständig oder veraltet sein.
  ///
  /// In en, this message translates to:
  /// **'Additional data levels · Information may be incomplete or outdated.'**
  String get mobilityZusaetzlicheDatenebenenAngabenKoennen3a7acd85;

  /// Legacy key: Abgerufen: {0}
  /// Zuletzt geprüft: {1}
  ///
  /// In en, this message translates to:
  /// **'Called: {arg0} Last checked: {arg1}'**
  String observationsAbgerufenZuletztGeprueft118070fc(String arg0, String arg1);

  /// Legacy key: Abrufen sendet bei BAFU eine Auswahl naher Stationsnummern; MeteoSwiss wird als landesweite Datei geladen.
  ///
  /// In en, this message translates to:
  /// **'Retrieving sends a selection of nearby station numbers at BAFU; MeteoSwiss is loaded as a national file.'**
  String get observationsAbrufenSendetBeiBafu0559cc82;

  /// Legacy key: Daten nicht verfügbar
  ///
  /// In en, this message translates to:
  /// **'Data not available'**
  String get observationsDatenNichtVerfuegbar85f19360;

  /// Legacy key: Gemessene Stationswerte · keine Prognose
  ///
  /// In en, this message translates to:
  /// **'Station values measured · no forecast'**
  String get observationsGemesseneStationswerteKeinePrognosef2d35acc;

  /// Legacy key: Keine verfügbaren Messstationen im gewählten Umfeld. Fehlende Werte bedeuten keine Entwarnung.
  ///
  /// In en, this message translates to:
  /// **'No available measuring stations in the selected environment. Missing values do not mean no warning.'**
  String get observationsKeineVerfuegbarenMessstationenImb3c601f8;

  /// Legacy key: Lokalen Snapshot löschen
  ///
  /// In en, this message translates to:
  /// **'Delete Local Snapshot'**
  String get observationsLokalenSnapshotLoeschen500f4bea;

  /// Legacy key: Messwerte abrufen
  ///
  /// In en, this message translates to:
  /// **'Retrieve readings'**
  String get observationsMesswerteAbrufen404711d9;

  /// Legacy key: Offizielle Stationsdetails
  ///
  /// In en, this message translates to:
  /// **'Official Station Details'**
  String get observationsOffizielleStationsdetails03ee57d0;

  /// Legacy key: Quelle: BAFU · Hydrologische Beobachtungen. Live ist unkorrigiert; 10-Minuten-Mittel und Freigabestatus bleiben getrennt.
  ///
  /// In en, this message translates to:
  /// **'Source: BAFU · Hydrological observations. Live is uncorrected; 10-minute mean and release status remain separate.'**
  String get observationsQuelleBafuHydrologischeBeobachtungenc7f7e996;

  /// Legacy key: Quelle: MeteoSchweiz · SwissMetNet · CC BY 4.0. Wind/Böen in km/h; Niederschlag als 10-Minuten-Summe.
  ///
  /// In en, this message translates to:
  /// **'Source: MeteoSchweiz · SwissMetNet · CC BY 4.0. Wind/bodies in km/h; precipitation as a 10-minute sum.'**
  String get observationsQuelleMeteoschweizSwissmetnetCcd346cfc9;

  /// Legacy key: Quelle und Produktbeschreibung
  ///
  /// In en, this message translates to:
  /// **'Source and product description'**
  String get observationsQuelleUndProduktbeschreibunga056e6fd;

  /// Legacy key: Stationen auf der Karte
  ///
  /// In en, this message translates to:
  /// **'Stations on the map'**
  String get observationsStationenAufDerKarte6bbce8f0;

  /// Legacy key: {0} Stationen ohne zuordenbare Metadaten.
  ///
  /// In en, this message translates to:
  /// **'{arg0} stations without assignable metadata.'**
  String observationsStationenOhneZuordenbareMetadaten7a9052fc(String arg0);

  /// Legacy key: Unvollständiger Datenauszug; weitere Messwerte können fehlen.
  ///
  /// In en, this message translates to:
  /// **'Incomplete data extract; further readings may be missing.'**
  String get observationsUnvollstaendigerDatenauszugWeitereMesswerte5c0b8d49;

  /// Legacy key: {0} · {1} verfügbare Werte{2}{3}
  ///
  /// In en, this message translates to:
  /// **'{arg0} · {arg1} available values{arg2}{arg3}'**
  String observationsVerfuegbareWerte3495e1b4(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  );

  /// Legacy key: Amtlicher Datensatz · nach Import offline verfügbar.
  ///
  /// In en, this message translates to:
  /// **'Official record · available offline after import.'**
  String get obstaclesAmtlicherDatensatzNachImportd2d6162d;

  /// Legacy key: Approximate geometry: straight connections / polygon outlines from the source. Actual cable sag and obstacle surfaces are not defined.
  ///
  /// In en, this message translates to:
  /// **'Approximate geometry: straight connections / polygon outlines from the source. Actual cable sag and obstacle surfaces are not defined.'**
  String get obstaclesApproximateGeometryStraightConnectionsbd84ea99;

  /// Legacy key: BAZL obstacle legend
  ///
  /// In en, this message translates to:
  /// **'BAZL obstacle legend'**
  String get obstaclesBazlObstacleLegend85da8229;

  /// Legacy key: Check source for updates
  ///
  /// In en, this message translates to:
  /// **'Check source for updates'**
  String get obstaclesCheckSourceForUpdates9b2adfd6;

  /// Legacy key: Close obstacle details
  ///
  /// In en, this message translates to:
  /// **'Close obstacle details'**
  String get obstaclesCloseObstacleDetails12608787;

  /// Legacy key: 3D obstacle models
  ///
  /// In en, this message translates to:
  /// **'3D obstacle models'**
  String get obstaclesDObstacleModels82a00838;

  /// Legacy key: Data status: {0}
  ///
  /// In en, this message translates to:
  /// **'Data status: {arg0}'**
  String obstaclesDataStatusef822b6e(String arg0);

  /// Legacy key: Daten & Höhenbezug
  ///
  /// In en, this message translates to:
  /// **'Data & Height Reference'**
  String get obstaclesDatenHoehenbezug36af217e;

  /// Legacy key: Download vector dataset
  ///
  /// In en, this message translates to:
  /// **'Download vector dataset'**
  String get obstaclesDownloadVectorDataset689316d7;

  /// Legacy key: Effective date: {0} UTC
  ///
  /// In en, this message translates to:
  /// **'Effective date: {arg0} UTC'**
  String obstaclesEffectiveDateUtc90780bc8(String arg0);

  /// Legacy key: First source vertex height: {0} m · {1}
  ///
  /// In en, this message translates to:
  /// **'First source vertex height: {arg0} m · {arg1}'**
  String obstaclesFirstSourceVertexHeight6eebb9de(String arg0, String arg1);

  /// Legacy key: Highlight hazard areas
  ///
  /// In en, this message translates to:
  /// **'Highlight hazard areas'**
  String get obstaclesHighlightHazardAreas0d0a655e;

  /// Legacy key: Horizontal buffer: {0} m
  ///
  /// In en, this message translates to:
  /// **'Horizontal buffer: {arg0} m'**
  String obstaclesHorizontalBufferMc4e67f2c(String arg0);

  /// Legacy key: {0} imported objects · {1} unsupported records
  ///
  /// In en, this message translates to:
  /// **'{arg0} imported objects · {arg1} unsupported records'**
  String obstaclesImportedObjectsUnsupportedRecords947e6f13(
    String arg0,
    String arg1,
  );

  /// Legacy key: Legend unavailable. Open the official link below.
  ///
  /// In en, this message translates to:
  /// **'Legend unavailable. Open the official link below.'**
  String get obstaclesLegendUnavailableOpenThe1690ecec;

  /// Legacy key: Local cache: {0} · source validity: {1}
  ///
  /// In en, this message translates to:
  /// **'Local cache: {arg0} · source validity: {arg1}'**
  String obstaclesLocalCacheSourceValidity2bcad0a6(String arg0, String arg1);

  /// Legacy key: Metadata checked: {0}
  ///
  /// In en, this message translates to:
  /// **'Metadata checked: {arg0}'**
  String obstaclesMetadataChecked61ccc766(String arg0);

  /// Legacy key: Not supplied
  ///
  /// In en, this message translates to:
  /// **'Not supplied'**
  String get obstaclesNotSupplied25fa1c12;

  /// Legacy key: Nur veröffentlichte Hindernisse · fehlende Objekte möglich.
  ///
  /// In en, this message translates to:
  /// **'Only published obstacles · missing objects possible.'**
  String get obstaclesNurVeroeffentlichteHindernisseFehlende874c23fc;

  /// Legacy key: Obstacle imagery opacity: {0}%
  ///
  /// In en, this message translates to:
  /// **'Obstacle imagery opacity: {arg0}%'**
  String obstaclesObstacleImageryOpacity83ec0630(String arg0);

  /// Legacy key: Official WMS legend
  ///
  /// In en, this message translates to:
  /// **'Official WMS legend'**
  String get obstaclesOfficialWmsLegenda55cc700;

  /// Legacy key: Planungshilfe · keine Freigabe oder Abstandsprüfung.
  ///
  /// In en, this message translates to:
  /// **'Planning assistance · no clearance or distance check.'**
  String get obstaclesPlanungshilfeKeineFreigabeOder3f2c05b6;

  /// Legacy key: Published obstacles · WMS
  ///
  /// In en, this message translates to:
  /// **'Published obstacles · WMS'**
  String get obstaclesPublishedObstaclesWms03371ce2;

  /// Legacy key: Published: {0} UTC
  ///
  /// In en, this message translates to:
  /// **'Published: {arg0} UTC'**
  String obstaclesPublishedUtcc490142e(String arg0);

  /// Legacy key: Published validity: {0} → {1} UTC
  ///
  /// In en, this message translates to:
  /// **'Published validity: {arg0} → {arg1} UTC'**
  String obstaclesPublishedValidityUtcb1c25560(String arg0, String arg1);

  /// Legacy key: Retry obstacle imagery
  ///
  /// In en, this message translates to:
  /// **'Retry obstacle imagery'**
  String get obstaclesRetryObstacleImagerya63bb8aa;

  /// Legacy key: Selectable obstacles · 3D vector
  ///
  /// In en, this message translates to:
  /// **'Selectable obstacles · 3D vector'**
  String get obstaclesSelectableObstaclesDVectore21d36db;

  /// Legacy key: Source asset unavailable
  ///
  /// In en, this message translates to:
  /// **'Source asset unavailable'**
  String get obstaclesSourceAssetUnavailablebc4a043d;

  /// Legacy key: Source attributes
  ///
  /// In en, this message translates to:
  /// **'Source attributes'**
  String get obstaclesSourceAttributesf0c00259;

  /// Legacy key: Source ID: {0}
  /// UUID: {1}
  ///
  /// In en, this message translates to:
  /// **'Source ID: {arg0}\nUUID: {arg1}'**
  String obstaclesSourceIdUuidc30a2ed8(String arg0, String arg1);

  /// Legacy key: Source maximum height: {0}
  ///
  /// In en, this message translates to:
  /// **'Source maximum height: {arg0}'**
  String obstaclesSourceMaximumHeight03ba5af5(String arg0);

  /// Legacy key: Source updated: {0}
  ///
  /// In en, this message translates to:
  /// **'Source updated: {arg0}'**
  String obstaclesSourceUpdated81b6e983(String arg0);

  /// Legacy key: Source updated: {0}
  /// Retrieved: {1}
  ///
  /// In en, this message translates to:
  /// **'Source updated: {arg0}\nRetrieved: {arg1}'**
  String obstaclesSourceUpdatedRetrieved4bba5e9c(String arg0, String arg1);

  /// Legacy key: Swiss aviation obstacles
  ///
  /// In en, this message translates to:
  /// **'Swiss aviation obstacles'**
  String get obstaclesSwissAviationObstacles1befa7cf;

  /// Legacy key: Top elevation: {0}
  ///
  /// In en, this message translates to:
  /// **'Top elevation: {arg0}'**
  String obstaclesTopElevation140c7227(String arg0);

  /// Legacy key: Type: {0} · {1}
  ///
  /// In en, this message translates to:
  /// **'Type: {arg0} · {arg1}'**
  String obstaclesTypeab721b15(String arg0, String arg1);

  /// Legacy key: Veröffentlichte Höhe · Form und Breite geschätzt.
  ///
  /// In en, this message translates to:
  /// **'Published height · shape and width estimated.'**
  String get obstaclesVeroeffentlichteHoeheFormUnd8f84873d;

  /// Legacy key: {0}: {1} vertices · altitude mode: {2} · {3}
  ///
  /// In en, this message translates to:
  /// **'{arg0}: {arg1} vertices · altitude mode: {arg2} · {arg3}'**
  String obstaclesVerticesAltitudeModeddeefe8a(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  );

  /// Legacy key: Add offline region
  ///
  /// In en, this message translates to:
  /// **'Add offline region'**
  String get offlineAddOfflineRegion6d71cdd8;

  /// Legacy key: Ansichtspuffer und optionaler Laptop-Export
  ///
  /// In en, this message translates to:
  /// **'View buffer and optional laptop export'**
  String get offlineAnsichtspufferUndOptionalerLaptop62f2efd5;

  /// Legacy key: Bereich offline vorbereiten
  ///
  /// In en, this message translates to:
  /// **'Preparing the offline area'**
  String get offlineBereichOfflineVorbereiten91421709;

  /// Legacy key: Cached base map & terrain · coverage may be incomplete or outdated. Live overlays and API actions require separate verification.
  ///
  /// In en, this message translates to:
  /// **'Cached base map & terrain · coverage may be incomplete or outdated. Live overlays and API actions require separate verification.'**
  String get offlineCachedBaseMapTerrainecfb9aaf;

  /// Legacy key: Centre latitude
  ///
  /// In en, this message translates to:
  /// **'Centre latitude'**
  String get offlineCentreLatitudea76075f4;

  /// Legacy key: Centre longitude
  ///
  /// In en, this message translates to:
  /// **'Centre longitude'**
  String get offlineCentreLongitude1cbc4661;

  /// Legacy key: 3D-Gelände
  ///
  /// In en, this message translates to:
  /// **'3D sites'**
  String get offlineDGelaende41d0aed9;

  /// Legacy key: Der zusätzliche Ansichtspuffer enthält nur tatsächlich betrachtete Kacheln und kann unvollständig bleiben. Er ist unabhängig vom automatischen offiziellen Regionsdownload oben.
  ///
  /// In en, this message translates to:
  /// **'The additional view buffer contains only actually viewed tiles and can remain incomplete. It is independent of the automatic official region download above.'**
  String get offlineDerZusaetzlicheAnsichtspufferEnthaeltb23a8c6c;

  /// Legacy key: Geländedetail für Offline-Paket
  ///
  /// In en, this message translates to:
  /// **'Terrain Detail for Offline Package'**
  String get offlineGelaendedetailFuerOfflinePaketcbde183b;

  /// Legacy key: Gesamte Schweiz
  ///
  /// In en, this message translates to:
  /// **'Total Switzerland'**
  String get offlineGesamteSchweiz533dc2ed;

  /// Legacy key: Gesamte Schweiz offline vorbereiten
  ///
  /// In en, this message translates to:
  /// **'Prepare all Switzerland offline'**
  String get offlineGesamteSchweizOfflineVorbereiten7cb30202;

  /// Legacy key: Geschätzter lokaler Speicher: {0} MiB · {1} Kacheln. Originaldaten und Karteninhalt beeinflussen Downloadmenge und Dauer. Vorhandene Region bleibt bis zum erfolgreichen Abschluss aktiv.
  ///
  /// In en, this message translates to:
  /// **'Estimated local memory: {arg0} MiB · {arg1} Tile. Original data and map content influence download quantity and duration. Existing region remains active until successful completion.'**
  String offlineGeschaetzterLokalerSpeicherMibae938fa8(
    String arg0,
    String arg1,
  );

  /// Legacy key: Gespeicherte Kartendaten: {0} MiB. Der zusätzliche Puffer für beim Betrachten geladene Kacheln ist auf 256 MiB begrenzt.
  ///
  /// In en, this message translates to:
  /// **'Stored map data: {arg0} MiB. The additional buffer for tiles loaded during viewing is limited to 256 MiB.'**
  String offlineGespeicherteKartendatenMibDerf8af680d(String arg0);

  /// Legacy key: Gewünschten Mittelpunkt auf dem Globe antippen.
  ///
  /// In en, this message translates to:
  /// **'Tap desired center on the globe.'**
  String get offlineGewuenschtenMittelpunktAufDem999be642;

  /// Legacy key: Großer Download. Detail und Ebenen bestimmen den Speicherbedarf; der Browser prüft seinen verfügbaren Speicher vor dem Start.
  ///
  /// In en, this message translates to:
  /// **'Large download. Detail and levels determine the storage requirement; the browser checks its available memory before starting.'**
  String get offlineGrosserDownloadDetailUnd759ef111;

  /// Legacy key: Höhen aus swissALTI3D; gewählte Detailstufe bestimmt die Auflösung im Globe.
  ///
  /// In en, this message translates to:
  /// **'Heights from swissALTI3D; selected detail level determines the resolution in the globe.'**
  String get offlineHoehenAusSwissaltiD5966fff3;

  /// Legacy key: Maximum imagery detail
  ///
  /// In en, this message translates to:
  /// **'Maximum imagery detail'**
  String get offlineMaximumImageryDetaile83a21f6;

  /// Legacy key: Mittelpunkt auf Globe markieren
  ///
  /// In en, this message translates to:
  /// **'Mark Center on Globe'**
  String get offlineMittelpunktAufGlobeMarkierenec84f922;

  /// Legacy key: Mittelpunkt auf Karte wählen
  ///
  /// In en, this message translates to:
  /// **'Select Center on Map'**
  String get offlineMittelpunktAufKarteWaehlen0129acc2;

  /// Legacy key: Mittelpunkt übernehmen
  ///
  /// In en, this message translates to:
  /// **'Take centre'**
  String get offlineMittelpunktUebernehmen654f1ce1;

  /// Legacy key: Neue Vorbereitungsdatei
  ///
  /// In en, this message translates to:
  /// **'New Preparing File'**
  String get offlineNeueVorbereitungsdateif618c1fc;

  /// Legacy key: Offline-Bereich vorbereiten
  ///
  /// In en, this message translates to:
  /// **'Prepare offline area'**
  String get offlineOfflineBereichVorbereitene86172db;

  /// Legacy key: Offline map regions
  ///
  /// In en, this message translates to:
  /// **'Offline map regions'**
  String get offlineOfflineMapRegionse6d5c4de;

  /// Legacy key: Offline-Paket importieren
  ///
  /// In en, this message translates to:
  /// **'Import Offline Package'**
  String get offlineOfflinePaketImportieren3e6d35a5;

  /// Legacy key: Offline verfügbare Kartenebenen
  ///
  /// In en, this message translates to:
  /// **'Offline map borders available'**
  String get offlineOfflineVerfuegbareKartenebenen3eca4f37;

  /// Legacy key: Refresh storage status
  ///
  /// In en, this message translates to:
  /// **'Refresh storage status'**
  String get offlineRefreshStorageStatus889bb274;

  /// Legacy key: Region aktualisieren
  ///
  /// In en, this message translates to:
  /// **'Update Region'**
  String get offlineRegionAktualisieren789dbcf6;

  /// Legacy key: Remove cached region
  ///
  /// In en, this message translates to:
  /// **'Remove cached region'**
  String get offlineRemoveCachedRegion3fb1230e;

  /// Legacy key: Save region for caching
  ///
  /// In en, this message translates to:
  /// **'Save region for caching'**
  String get offlineSaveRegionForCaching87de5600;

  /// Legacy key: Speicherlimit für diesen Download
  ///
  /// In en, this message translates to:
  /// **'Memory limit for this download'**
  String get offlineSpeicherlimitFuerDiesenDownload142a1d01;

  /// Legacy key: Stufe {0}{1}
  ///
  /// In en, this message translates to:
  /// **'Level {arg0}{arg1}'**
  String offlineStufed0ed7705(String arg0, String arg1);

  /// Legacy key: Supported map
  ///
  /// In en, this message translates to:
  /// **'Supported map'**
  String get offlineSupportedMapb531fbb7;

  /// Legacy key: {0} / {1} tiles · {2} MiB
  /// {3} · {4}
  /// {5}
  ///
  /// In en, this message translates to:
  /// **'{arg0} / {arg1} tiles · {arg2} MiB\n{arg3} · {arg4}\n{arg5}'**
  String offlineTilesMib2f032565(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
  );

  /// Legacy key: Topographic
  ///
  /// In en, this message translates to:
  /// **'Topographic'**
  String get offlineTopographicd28af3fe;

  /// Legacy key: Unterbrochene Aufbereitung verwerfen
  ///
  /// In en, this message translates to:
  /// **'Discard interrupted treatment'**
  String get offlineUnterbrocheneAufbereitungVerwerfenf0149e36;

  /// Legacy key: Use cached base map and terrain
  ///
  /// In en, this message translates to:
  /// **'Use cached base map and terrain'**
  String get offlineUseCachedBaseMapcac83b59;

  /// Legacy key: Vorbereitungsdatei für Laptop speichern
  ///
  /// In en, this message translates to:
  /// **'Save Laptop Preparation File'**
  String get offlineVorbereitungsdateiFuerLaptopSpeichern42dca4b8;

  /// Legacy key: Zoom {0}
  ///
  /// In en, this message translates to:
  /// **'Zoom {arg0}'**
  String offlineZoomb67baf86(String arg0);

  /// Legacy key: Zusätzliche datierte Momentaufnahmen aktualisieren
  ///
  /// In en, this message translates to:
  /// **'Update additional dated snapshots'**
  String get offlineZusaetzlicheDatierteMomentaufnahmenAktualisieren66eddff9;

  /// Legacy key: Abgerufen: {0} · amtliches Publikationsdatum nicht mitgeteilt
  ///
  /// In en, this message translates to:
  /// **'Called up: {arg0} · official publication date not reported'**
  String outdoorAbgerufenAmtlichesPublikationsdatumNicht1eb563a2(String arg0);

  /// Legacy key: Amtliche Legende und Quelle
  ///
  /// In en, this message translates to:
  /// **'Official legend and source'**
  String get outdoorAmtlicheLegendeUndQuelle17cac2a2;

  /// Legacy key: Amtliche Wegenetze
  ///
  /// In en, this message translates to:
  /// **'Official networks'**
  String get outdoorAmtlicheWegenetzeee6981c0;

  /// Legacy key: Amtlicher Outdoor-Kontext
  ///
  /// In en, this message translates to:
  /// **'Official outdoor context'**
  String get outdoorAmtlicherOutdoorKontextab221e59;

  /// Legacy key: Ausgewählter Kartenpunkt
  ///
  /// In en, this message translates to:
  /// **'Selected map point'**
  String get outdoorAusgewaehlterKartenpunktd902892e;

  /// Legacy key: Auszug aktualisieren
  ///
  /// In en, this message translates to:
  /// **'Update Extract'**
  String get outdoorAuszugAktualisieren55f223d5;

  /// Legacy key: Auszug auf Karte anzeigen
  ///
  /// In en, this message translates to:
  /// **'Show excerpt on map'**
  String get outdoorAuszugAufKarteAnzeigen9105f450;

  /// Legacy key: Bezug wählen
  ///
  /// In en, this message translates to:
  /// **'Select Reference'**
  String get outdoorBezugWaehlendcf73635;

  /// Legacy key: Details um den Kartenpunkt abrufen
  ///
  /// In en, this message translates to:
  /// **'Retrieve details around the map point'**
  String get outdoorDetailsUmDenKartenpunktdbe266e7;

  /// Legacy key: Diese Detailauszüge werden nur im Arbeitsspeicher gehalten. Kantonsübergreifende Vektorpakete und deren Weitergabe benötigen jeweils passende Nutzungsbedingungen.
  ///
  /// In en, this message translates to:
  /// **'These detail extracts are only kept in memory. Cross-Canton vector packages and their transmission require appropriate terms of use.'**
  String get outdoorDieseDetailauszuegeWerdenNur71ff8d83;

  /// Legacy key: Ergebnisgrenze erreicht · weitere Objekte können fehlen.
  ///
  /// In en, this message translates to:
  /// **'Result limit reached · other objects may be missing.'**
  String get outdoorErgebnisgrenzeErreichtWeitereObjektefa8b4a21;

  /// Legacy key: Flugroute auswählen · letzte 100
  ///
  /// In en, this message translates to:
  /// **'Select route · last 100'**
  String get outdoorFlugrouteAuswaehlenLetzteeb04100f;

  /// Legacy key: Gespeicherte Flugroute
  ///
  /// In en, this message translates to:
  /// **'Stored flight route'**
  String get outdoorGespeicherteFlugroutede6dec82;

  /// Legacy key: Gespeicherter Ort
  ///
  /// In en, this message translates to:
  /// **'Stored place'**
  String get outdoorGespeicherterOrt25ce06f0;

  /// Legacy key: Kartenebene: {0} · Quelldatum nicht vom Dienst mitgeteilt
  ///
  /// In en, this message translates to:
  /// **'Map level: {arg0} · Source date not reported by service'**
  String outdoorKartenebeneQuelldatumNichtVom78282b34(String arg0);

  /// Legacy key: Kartenkacheln erneut laden
  ///
  /// In en, this message translates to:
  /// **'Re-load map tiles'**
  String get outdoorKartenkachelnErneutLadend22d2379;

  /// Legacy key: Keine Objekte im Auszug gefunden. Das bestätigt keine offene oder freie Route.
  ///
  /// In en, this message translates to:
  /// **'No objects found in the extract. This does not confirm an open or free route.'**
  String get outdoorKeineObjekteImAuszug3e189c68;

  /// Legacy key: Natur und Wildruhezonen
  ///
  /// In en, this message translates to:
  /// **'Nature and wild recreation areas'**
  String get outdoorNaturUndWildruhezonen7304b9ec;

  /// Legacy key: Noch keine Flugrouten gespeichert
  ///
  /// In en, this message translates to:
  /// **'No flight routes saved yet'**
  String get outdoorNochKeineFlugroutenGespeichertc7aeb7bc;

  /// Legacy key: Offizielle Details
  ///
  /// In en, this message translates to:
  /// **'Official details'**
  String get outdoorOffizielleDetails573452dd;

  /// Legacy key: Online-Ebene · Offline-Kacheldownload nicht freigegeben. Abdeckung und Aktualität können lückenhaft sein.
  ///
  /// In en, this message translates to:
  /// **'Online level · Offline tile download not released. Coverage and up-to-dateness can be incomplete.'**
  String get outdoorOnlineEbeneOfflineKacheldownload52ce6e5a;

  /// Legacy key: Originalattribute
  ///
  /// In en, this message translates to:
  /// **'Originalattribute'**
  String get outdoorOriginalattribute38290624;

  /// Legacy key: Outdoor-Ebene konnte nicht geändert werden. Erneut versuchen.
  ///
  /// In en, this message translates to:
  /// **'Outdoor level could not be changed. Try again.'**
  String get outdoorOutdoorEbeneKonnteNichtdae0b0f9;

  /// Legacy key: Quellen-ID: {0}
  /// {1}
  ///
  /// In en, this message translates to:
  /// **'Source ID: {arg0} {arg1}'**
  String outdoorQuellenIdba307a43(String arg0, String arg1);

  /// Legacy key: Route oder Auszug überschreiten das Größenlimit für den vollständigen Einzelabgleich. Bitte einen kürzeren Abschnitt wählen. Die Originalgeometrie bleibt erhalten.
  ///
  /// In en, this message translates to:
  /// **'Route or extract exceed the size limit for the complete single adjustment. Please select a shorter section. The original geometry is retained.'**
  String get outdoorRouteOderAuszugUeberschreitene46a9d8f;

  /// Legacy key: Sperrungen und Umleitungen
  ///
  /// In en, this message translates to:
  /// **'Blocks and redirections'**
  String get outdoorSperrungenUndUmleitungenc019df11;

  /// Legacy key: Any drone
  ///
  /// In en, this message translates to:
  /// **'Any drone'**
  String get preflightAnyDrone97497506;

  /// Legacy key: Any flight plan
  ///
  /// In en, this message translates to:
  /// **'Any flight plan'**
  String get preflightAnyFlightPlan5d58f177;

  /// Legacy key: Checklist could not be saved: {0}
  ///
  /// In en, this message translates to:
  /// **'Checklist could not be saved: {arg0}'**
  String preflightChecklistCouldNotBe467e09ff(String arg0);

  /// Legacy key: Checklist template
  ///
  /// In en, this message translates to:
  /// **'Checklist template'**
  String get preflightChecklistTemplate9368b50e;

  /// Legacy key: Completion is saved on this device. Start a new checklist for each flight; completing it does not grant flight authorization.
  ///
  /// In en, this message translates to:
  /// **'Completion is saved on this device. Start a new checklist for each flight; completing it does not grant flight authorization.'**
  String get preflightCompletionIsSavedOna7956e8f;

  /// Legacy key: Edit items & associations
  ///
  /// In en, this message translates to:
  /// **'Edit items & associations'**
  String get preflightEditItemsAssociations032f939c;

  /// Legacy key: Flight plan
  ///
  /// In en, this message translates to:
  /// **'Flight plan'**
  String get preflightFlightPlan4cb79e47;

  /// Legacy key: Items · one per line
  ///
  /// In en, this message translates to:
  /// **'Items · one per line'**
  String get preflightItemsOnePerLinee1c97f47;

  /// Legacy key: Local checklists unavailable. Reopen this screen to retry.
  ///
  /// In en, this message translates to:
  /// **'Local checklists unavailable. Reopen this screen to retry.'**
  String get preflightLocalChecklistsUnavailableReopende49292a;

  /// Legacy key: New template
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get preflightNewTemplate865095cf;

  /// Legacy key: Preflight & Telemetry
  ///
  /// In en, this message translates to:
  /// **'Preflight & Telemetry'**
  String get preflightPreflightTelemetry0632b0c8;

  /// Legacy key: Reusable template · {0} items
  ///
  /// In en, this message translates to:
  /// **'Reusable template · {arg0} items'**
  String preflightReusableTemplateItems8ec2077a(String arg0);

  /// Legacy key: Save locally
  ///
  /// In en, this message translates to:
  /// **'Save locally'**
  String get preflightSaveLocally87522ab5;

  /// Legacy key: Start with all items unchecked
  ///
  /// In en, this message translates to:
  /// **'Start with all items unchecked'**
  String get preflightStartWithAllItems29c20291;

  /// Legacy key: Unsupported checklist data
  ///
  /// In en, this message translates to:
  /// **'Unsupported checklist data'**
  String get preflightUnsupportedChecklistDatabe2cc486;

  /// Legacy key: Up to 100 items. Changed items or associations must be checked again.
  ///
  /// In en, this message translates to:
  /// **'Up to 100 items. Changed items or associations must be checked again.'**
  String get preflightUpToItemsChangeda0ae0a06;

  /// Legacy key: Änderungen verwerfen?
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get profilesAnderungenVerwerfen9af398c1;

  /// Legacy key: Aus Vorlage
  ///
  /// In en, this message translates to:
  /// **'From template'**
  String get profilesAusVorlage7a27bf2c;

  /// Legacy key: Bearbeiten
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profilesBearbeiten104f3bfd;

  /// Legacy key: Beibehalten
  ///
  /// In en, this message translates to:
  /// **'Maintain'**
  String get profilesBeibehalten94ebabfe;

  /// Legacy key: Duplizieren
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get profilesDuplizieren8524c5cd;

  /// Legacy key: Eigenes Profil
  ///
  /// In en, this message translates to:
  /// **'Own profile'**
  String get profilesEigenesProfila1a7ad19;

  /// Legacy key: Exportieren
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get profilesExportieren4e4a0d71;

  /// Legacy key: Hintergrundkarte
  ///
  /// In en, this message translates to:
  /// **'Background map'**
  String get profilesHintergrundkarte2f67406f;

  /// Legacy key: Kartenstartwerte beim Aktivieren
  ///
  /// In en, this message translates to:
  /// **'Card start values when enabled'**
  String get profilesKartenstartwerteBeimAktivierenf2e700fc;

  /// Legacy key: Maximal 32 Profile. Zum Hinzufügen zuerst ein Profil löschen.
  ///
  /// In en, this message translates to:
  /// **'Maximum 32 profiles. To add, first delete a profile.'**
  String get profilesMaximalProfileZumHinzufuegene6d6ba7e;

  /// Legacy key: Ohne Profil · alle Werkzeuge
  ///
  /// In en, this message translates to:
  /// **'Without profile · all tools'**
  String get profilesOhneProfilAlleWerkzeuge5ab1fd0c;

  /// Legacy key: Profil bearbeiten
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profilesProfilBearbeitend4e69e62;

  /// Legacy key: Profil speichern
  ///
  /// In en, this message translates to:
  /// **'Save Profile'**
  String get profilesProfilSpeichernfeda7fb0;

  /// Legacy key: Profil wurde nicht gespeichert. Dein Entwurf bleibt erhalten; bitte erneut versuchen.
  ///
  /// In en, this message translates to:
  /// **'Profile has not been saved. Your design is retained; please try again.'**
  String get profilesProfilWurdeNichtGespeichert24e088e3;

  /// Legacy key: Profilaktion fehlgeschlagen. Bitte erneut versuchen.
  ///
  /// In en, this message translates to:
  /// **'Profile action failed. Please try again.'**
  String get profilesProfilaktionFehlgeschlagenBitteErneutfc851528;

  /// Legacy key: Satellit
  ///
  /// In en, this message translates to:
  /// **'Satellite'**
  String get profilesSatellit6020d8ce;

  /// Legacy key: Topografisch
  ///
  /// In en, this message translates to:
  /// **'Topographic'**
  String get profilesTopografisch52f1415e;

  /// Legacy key: Überspringen · alle Werkzeuge
  ///
  /// In en, this message translates to:
  /// **'Skip · all tools'**
  String get profilesUberspringenAlleWerkzeuge95410f7f;

  /// Legacy key: Vorlage wählen
  ///
  /// In en, this message translates to:
  /// **'Select Template'**
  String get profilesVorlageWaehlen7df6eb54;

  /// Legacy key: Vorlagen sind frei anpassbar. Alle Werkzeuge bleiben erreichbar.
  ///
  /// In en, this message translates to:
  /// **'Templates are freely customizable. All tools remain accessible.'**
  String get profilesVorlagenSindFreiAnpassbarff309b1d;

  /// Legacy key: Werkzeuge passend zu deiner Aktivität
  ///
  /// In en, this message translates to:
  /// **'Tools to match your activity'**
  String get profilesWerkzeugePassendZuDeiner8e101852;

  /// Legacy key: {0} Werkzeuge · {1} Schnellaktionen
  ///
  /// In en, this message translates to:
  /// **'{arg0} tools · {arg1} Rapid actions'**
  String profilesWerkzeugeSchnellaktionenc271b295(String arg0, String arg1);

  /// Legacy key: Wird gespeichert…
  ///
  /// In en, this message translates to:
  /// **'Saving..'**
  String get profilesWirdGespeichert129ed064;

  /// Legacy key: Womit möchtest du starten?
  ///
  /// In en, this message translates to:
  /// **'What do you want to start with?'**
  String get profilesWomitMoechtestDuStartenee1d09d8;

  /// Legacy key: A drone can use several independent configurations.
  ///
  /// In en, this message translates to:
  /// **'A drone can use several independent configurations.'**
  String get radioADroneCanUsea385a1c2;

  /// Legacy key: Add equipment profile
  ///
  /// In en, this message translates to:
  /// **'Add equipment profile'**
  String get radioAddEquipmentProfile85022529;

  /// Legacy key: Add equipment
  ///
  /// In en, this message translates to:
  /// **'Add equipment'**
  String get radioAddEquipmentda5d2801;

  /// Legacy key: Create independent control and video configurations. Leave unknown values empty. Maximum power is the transmitter output before antenna gain and cable loss; record the applicable mode and source below.
  ///
  /// In en, this message translates to:
  /// **'Create independent control and video configurations. Leave unknown values empty. Maximum power is the transmitter output before antenna gain and cable loss; record the applicable mode and source below.'**
  String get radioCreateIndependentControlAndf7437069;

  /// Legacy key: Delete equipment profile?
  ///
  /// In en, this message translates to:
  /// **'Delete equipment profile?'**
  String get radioDeleteEquipmentProfile0d5a874b;

  /// Legacy key: Edit equipment
  ///
  /// In en, this message translates to:
  /// **'Edit equipment'**
  String get radioEditEquipment92a5da88;

  /// Legacy key: Edit equipment profile
  ///
  /// In en, this message translates to:
  /// **'Edit equipment profile'**
  String get radioEditEquipmentProfilef984d1a0;

  /// Legacy key: Equipment details
  ///
  /// In en, this message translates to:
  /// **'Equipment details'**
  String get radioEquipmentDetailse402502a;

  /// Legacy key: No drone profiles yet. You can assign this equipment later.
  ///
  /// In en, this message translates to:
  /// **'No drone profiles yet. You can assign this equipment later.'**
  String get radioNoDroneProfilesYetd1f93a9e;

  /// Legacy key: Permanently delete "{0}" and its assignments? Drone profiles and other equipment configurations are kept.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete \"{arg0}\" and its assignments? Drone profiles and other equipment configurations are kept.'**
  String radioPermanentlyDeleteAndIts53a62100(String arg0);

  /// Legacy key: Radio & video equipment
  ///
  /// In en, this message translates to:
  /// **'Radio & video equipment'**
  String get radioRadioVideoEquipment93933cea;

  /// Legacy key: Recorded specifications. Unknown values remain unrecorded. Maximum transmitter power is before antenna gain and cable loss; the operating setting may be lower.
  ///
  /// In en, this message translates to:
  /// **'Recorded specifications. Unknown values remain unrecorded. Maximum transmitter power is before antenna gain and cable loss; the operating setting may be lower.'**
  String get radioRecordedSpecificationsUnknownValues7c5d9e94;

  /// Legacy key: Refresh drones
  ///
  /// In en, this message translates to:
  /// **'Refresh drones'**
  String get radioRefreshDronesc1a9ec7c;

  /// Legacy key: Removed drone (#{0}) — uncheck to continue
  ///
  /// In en, this message translates to:
  /// **'Removed drone (#{arg0}) — uncheck to continue'**
  String radioRemovedDroneUncheckTo9fe8cb40(String arg0);

  /// Legacy key: System category
  ///
  /// In en, this message translates to:
  /// **'System category'**
  String get radioSystemCategorycc8be0ee;

  /// Legacy key: This equipment profile no longer exists.
  ///
  /// In en, this message translates to:
  /// **'This equipment profile no longer exists.'**
  String get radioThisEquipmentProfileNo59977e24;

  /// Legacy key: Unable to load equipment profiles.
  ///
  /// In en, this message translates to:
  /// **'Unable to load equipment profiles.'**
  String get radioUnableToLoadEquipment2a0842d8;

  /// Legacy key: Unable to load this equipment profile.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this equipment profile.'**
  String get radioUnableToLoadThise6da0797;

  /// Legacy key: Above terrain (AGL)
  ///
  /// In en, this message translates to:
  /// **'Above terrain (AGL)'**
  String get routesAboveTerrainAgle2867f26;

  /// Legacy key: Airspeed (m/s); power (W)
  ///
  /// In en, this message translates to:
  /// **'Airspeed (m/s); power (W)'**
  String get routesAirspeedMSPower705d4a92;

  /// Legacy key: Apply equipment
  ///
  /// In en, this message translates to:
  /// **'Apply equipment'**
  String get routesApplyEquipmente3cb5483;

  /// Legacy key: Apply height and speed to all waypoints
  ///
  /// In en, this message translates to:
  /// **'Apply height and speed to all waypoints'**
  String get routesApplyHeightAndSpeed4746e071;

  /// Legacy key: Apply planning assumptions
  ///
  /// In en, this message translates to:
  /// **'Apply planning assumptions'**
  String get routesApplyPlanningAssumptions8576b420;

  /// Legacy key: Apply route constraints
  ///
  /// In en, this message translates to:
  /// **'Apply route constraints'**
  String get routesApplyRouteConstraintsf13386d6;

  /// Legacy key: Apply waypoint settings
  ///
  /// In en, this message translates to:
  /// **'Apply waypoint settings'**
  String get routesApplyWaypointSettingsd66af84a;

  /// Legacy key: Approximate drone radius
  ///
  /// In en, this message translates to:
  /// **'Approximate drone radius'**
  String get routesApproximateDroneRadiuse7919b03;

  /// Legacy key: Approximate great-circle distances. Recorded segment times are used when available; modeled times ignore gusts and manoeuvres. Confirm the drone can achieve the required speed and climb rate.
  ///
  /// In en, this message translates to:
  /// **'Approximate great-circle distances. Recorded segment times are used when available; modeled times ignore gusts and manoeuvres. Confirm the drone can achieve the required speed and climb rate.'**
  String get routesApproximateGreatCircleDistances9807e68d;

  /// Legacy key: Assign an individual battery in Route equipment to compare capacity and reserve. Capacities of alternative packs are never added.
  ///
  /// In en, this message translates to:
  /// **'Assign an individual battery in Route equipment to compare capacity and reserve. Capacities of alternative packs are never added.'**
  String get routesAssignAnIndividualBatteryb5d65676;

  /// Legacy key: Back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get routesBackb52b36b7;

  /// Legacy key: Batteries are alternative packs for one flight. Their capacities are assessed individually.
  ///
  /// In en, this message translates to:
  /// **'Batteries are alternative packs for one flight. Their capacities are assessed individually.'**
  String get routesBatteriesAreAlternativePackse90e4726;

  /// Legacy key: Battery to inspect and highlight
  ///
  /// In en, this message translates to:
  /// **'Battery to inspect and highlight'**
  String get routesBatteryToInspectAnde2d405d0;

  /// Legacy key: BAZL / FOCA · {0} · published {1} · retrieved {2}
  ///
  /// In en, this message translates to:
  /// **'BAZL / FOCA · {arg0} · published {arg1} · retrieved {arg2}'**
  String routesBazlFocaPublishedRetrievedede87b71(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: Buffer {0} m · selected categories: {1}
  ///
  /// In en, this message translates to:
  /// **'Buffer {arg0} m · selected categories: {arg1}'**
  String routesBufferMSelectedCategories6b55c391(String arg0, String arg1);

  /// Legacy key: BVLOS planned: verify the required operating category and authorisation with FOCA.
  ///
  /// In en, this message translates to:
  /// **'BVLOS planned: verify the required operating category and authorisation with FOCA.'**
  String get routesBvlosPlannedVerifyThe1d105130;

  /// Legacy key: Calculate current route
  ///
  /// In en, this message translates to:
  /// **'Calculate current route'**
  String get routesCalculateCurrentRoutea1896281;

  /// Legacy key: Calculating route…
  ///
  /// In en, this message translates to:
  /// **'Calculating route…'**
  String get routesCalculatingRoute9e861349;

  /// Legacy key: Cancel checks
  ///
  /// In en, this message translates to:
  /// **'Cancel checks'**
  String get routesCancelChecks480fd8da;

  /// Legacy key: Cancel move
  ///
  /// In en, this message translates to:
  /// **'Cancel move'**
  String get routesCancelMove23385b79;

  /// Legacy key: Check current route
  ///
  /// In en, this message translates to:
  /// **'Check current route'**
  String get routesCheckCurrentRoute87fb7469;

  /// Legacy key: Check route airspace
  ///
  /// In en, this message translates to:
  /// **'Check route airspace'**
  String get routesCheckRouteAirspaced4d383e6;

  /// Legacy key: Checking…
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get routesChecking820d6004;

  /// Legacy key: Choose a spot to add the first waypoint at its saved coordinates.
  ///
  /// In en, this message translates to:
  /// **'Choose a spot to add the first waypoint at its saved coordinates.'**
  String get routesChooseASpotToc0d9ecad;

  /// Legacy key: Clearance is incomplete: set a height for every waypoint. Absolute heights need WGS84 ellipsoid reference; other datums cannot be converted here.
  ///
  /// In en, this message translates to:
  /// **'Clearance is incomplete: set a height for every waypoint. Absolute heights need WGS84 ellipsoid reference; other datums cannot be converted here.'**
  String get routesClearanceIsIncompleteSet1a518685;

  /// Legacy key: Click the new position on the map.
  ///
  /// In en, this message translates to:
  /// **'Click the new position on the map.'**
  String get routesClickTheNewPosition88166db4;

  /// Legacy key: Close analysis
  ///
  /// In en, this message translates to:
  /// **'Close analysis'**
  String get routesCloseAnalysis232a00e4;

  /// Legacy key: Configure constraints
  ///
  /// In en, this message translates to:
  /// **'Configure constraints'**
  String get routesConfigureConstraintsf3a3a710;

  /// Legacy key: Configured heights are shown in 3D. Points marked * use a 30 m AGL preview because their height is missing or uses an unsupported datum. Selected routes stay visible in ground view.
  ///
  /// In en, this message translates to:
  /// **'Configured heights are shown in 3D. Points marked * use a 30 m AGL preview because their height is missing or uses an unsupported datum. Selected routes stay visible in ground view.'**
  String get routesConfiguredHeightsAreShowna9eb24e8;

  /// Legacy key: Configured legal ceiling: {0} m AGL · operational ceiling: {1} m AGL
  ///
  /// In en, this message translates to:
  /// **'Configured legal ceiling: {arg0} m AGL · operational ceiling: {arg1} m AGL'**
  String routesConfiguredLegalCeilingMe4d4520c(String arg0, String arg1);

  /// Legacy key: Copy available drone values for review
  ///
  /// In en, this message translates to:
  /// **'Copy available drone values for review'**
  String get routesCopyAvailableDroneValues12ac7ef8;

  /// Legacy key: Create battery profiles in Equipment first.
  ///
  /// In en, this message translates to:
  /// **'Create battery profiles in Equipment first.'**
  String get routesCreateBatteryProfilesIn4e35a626;

  /// Legacy key: Critical conservative segments: {0}
  ///
  /// In en, this message translates to:
  /// **'Critical conservative segments: {arg0}'**
  String routesCriticalConservativeSegmentsfecdcba2(String arg0);

  /// Legacy key: Curve source / measurement conditions
  ///
  /// In en, this message translates to:
  /// **'Curve source / measurement conditions'**
  String get routesCurveSourceMeasurementConditions241dc3af;

  /// Legacy key: 3D Infrastructure Clearance (advisory)
  ///
  /// In en, this message translates to:
  /// **'3D Infrastructure Clearance (advisory)'**
  String get routesDInfrastructureClearanceAdvisory02222668;

  /// Legacy key: 3D route preview is hidden until detailed terrain is available.
  ///
  /// In en, this message translates to:
  /// **'3D route preview is hidden until detailed terrain is available.'**
  String get routesDRoutePreviewIs18af1855;

  /// Legacy key: Delete point
  ///
  /// In en, this message translates to:
  /// **'Delete point'**
  String get routesDeletePoint24dc6e65;

  /// Legacy key: Discard route changes?
  ///
  /// In en, this message translates to:
  /// **'Discard route changes?'**
  String get routesDiscardRouteChanges71a9dbd8;

  /// Legacy key: Edit planning assumptions
  ///
  /// In en, this message translates to:
  /// **'Edit planning assumptions'**
  String get routesEditPlanningAssumptions84735a68;

  /// Legacy key: Empty means unknown. Applies to the next segment.
  ///
  /// In en, this message translates to:
  /// **'Empty means unknown. Applies to the next segment.'**
  String get routesEmptyMeansUnknownApplies42bd9aa3;

  /// Legacy key: Empty means unverified / not configured.
  ///
  /// In en, this message translates to:
  /// **'Empty means unverified / not configured.'**
  String get routesEmptyMeansUnverifiedNotb3d057c4;

  /// Legacy key: Examined up to {0} model samples; {1} unknown-altitude probes.
  ///
  /// In en, this message translates to:
  /// **'Examined up to {arg0} model samples; {arg1} unknown-altitude probes.'**
  String routesExaminedUpToModel89dfac48(String arg0, String arg1);

  /// Legacy key: Export {0}
  ///
  /// In en, this message translates to:
  /// **'Export {arg0}'**
  String routesExport98e40159(String arg0);

  /// Legacy key: Export GeoJSON
  ///
  /// In en, this message translates to:
  /// **'Export GeoJSON'**
  String get routesExportGeojsonbdc0686f;

  /// Legacy key: Export GPX
  ///
  /// In en, this message translates to:
  /// **'Export GPX'**
  String get routesExportGpxed2fd89b;

  /// Legacy key: Fertig
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get routesFertig708ad54e;

  /// Legacy key: Filter saved spots
  ///
  /// In en, this message translates to:
  /// **'Filter saved spots'**
  String get routesFilterSavedSpotsf0054cfd;

  /// Legacy key: Flight routes
  ///
  /// In en, this message translates to:
  /// **'Flight routes'**
  String get routesFlightRoutescf03df8f;

  /// Legacy key: FPV with observer
  ///
  /// In en, this message translates to:
  /// **'FPV with observer'**
  String get routesFpvWithObserver0eb784aa;

  /// Legacy key: Height constraints
  ///
  /// In en, this message translates to:
  /// **'Height constraints'**
  String get routesHeightConstraintseeba8204;

  /// Legacy key: Height not specified
  ///
  /// In en, this message translates to:
  /// **'Height not specified'**
  String get routesHeightNotSpecifiedfec716ae;

  /// Legacy key: Height reference
  ///
  /// In en, this message translates to:
  /// **'Height reference'**
  String get routesHeightReferenceec9764fc;

  /// Legacy key: Height & speed
  ///
  /// In en, this message translates to:
  /// **'Height & speed'**
  String get routesHeightSpeedd20ac922;

  /// Legacy key: {0} horizontal · {1} 3D
  /// Airspeed {2} m/s ({3}) · {4} ({5}) · clearance {6}
  /// Groundspeed: {7} m/s (simulated)
  ///
  /// In en, this message translates to:
  /// **'{arg0} horizontal · {arg1} 3D\nAirspeed {arg2} m/s ({arg3}) · {arg4} ({arg5}) · clearance {arg6}\nGroundspeed: {arg7} m/s (simulated)'**
  String routesHorizontalDAirspeedMeb450600(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
    String arg6,
    String arg7,
  );

  /// Legacy key: Horizontal obstacle proximity
  ///
  /// In en, this message translates to:
  /// **'Horizontal obstacle proximity'**
  String get routesHorizontalObstacleProximityb3d4572a;

  /// Legacy key: Import local bridge/support geometry (JSON)
  ///
  /// In en, this message translates to:
  /// **'Import local bridge/support geometry (JSON)'**
  String get routesImportLocalBridgeSupport8cc6480f;

  /// Legacy key: Import {0} routes?
  ///
  /// In en, this message translates to:
  /// **'Import {arg0} routes?'**
  String routesImportRoutes1b71c46b(String arg0);

  /// Legacy key: Import routes
  ///
  /// In en, this message translates to:
  /// **'Import routes'**
  String get routesImportRoutesbbcd66ff;

  /// Legacy key: Include return to takeoff
  ///
  /// In en, this message translates to:
  /// **'Include return to takeoff'**
  String get routesIncludeReturnToTakeoff90a464ac;

  /// Legacy key: Include steady wind
  ///
  /// In en, this message translates to:
  /// **'Include steady wind'**
  String get routesIncludeSteadyWind4a449918;

  /// Legacy key: Infrastructure import failed: {0}
  ///
  /// In en, this message translates to:
  /// **'Infrastructure import failed: {arg0}'**
  String routesInfrastructureImportFailed68671f9d(String arg0);

  /// Legacy key: Keep editing
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get routesKeepEditingd4d9e382;

  /// Legacy key: Level-flight power curve
  ///
  /// In en, this message translates to:
  /// **'Level-flight power curve'**
  String get routesLevelFlightPowerCurve5cf82060;

  /// Legacy key: Local bridge/support surfaces: {0}. Imported dimensions are not independently verified.
  ///
  /// In en, this message translates to:
  /// **'Local bridge/support surfaces: {arg0}. Imported dimensions are not independently verified.'**
  String routesLocalBridgeSupportSurfacesc5994174(String arg0);

  /// Legacy key: Local geometry loaded. Re-run Check current route. Source claims remain unverified.
  ///
  /// In en, this message translates to:
  /// **'Local geometry loaded. Re-run Check current route. Source claims remain unverified.'**
  String get routesLocalGeometryLoadedRe52972d93;

  /// Legacy key: * = 30 m AGL preview only
  ///
  /// In en, this message translates to:
  /// **'* = 30 m AGL preview only'**
  String get routesMAglPreviewOnly1b6aeb60;

  /// Legacy key: Manual verification required
  ///
  /// In en, this message translates to:
  /// **'Manual verification required'**
  String get routesManualVerificationRequireda6416489;

  /// Legacy key: Map command failed. Please retry.
  ///
  /// In en, this message translates to:
  /// **'Map command failed. Please retry.'**
  String get routesMapCommandFailedPleasea043b9a7;

  /// Legacy key: Move point
  ///
  /// In en, this message translates to:
  /// **'Move point'**
  String get routesMovePoint4cfb85e2;

  /// Legacy key: New local copies are created. Existing routes and equipment assignments are preserved.
  ///
  /// In en, this message translates to:
  /// **'New local copies are created. Existing routes and equipment assignments are preserved.'**
  String get routesNewLocalCopiesArec3efa17b;

  /// Legacy key: New route
  ///
  /// In en, this message translates to:
  /// **'New route'**
  String get routesNewRoutef39fa269;

  /// Legacy key: No configured limit exceedance detected in the evaluated inputs.
  ///
  /// In en, this message translates to:
  /// **'No configured limit exceedance detected in the evaluated inputs.'**
  String get routesNoConfiguredLimitExceedance5e7f8c0c;

  /// Legacy key: No conflict found in the available local models. Infrastructure clearance remains unassessed elsewhere.
  ///
  /// In en, this message translates to:
  /// **'No conflict found in the available local models. Infrastructure clearance remains unassessed elsewhere.'**
  String get routesNoConflictFoundIn4baaf950;

  /// Legacy key: No current infrastructure assessment. Use Check current route.
  ///
  /// In en, this message translates to:
  /// **'No current infrastructure assessment. Use Check current route.'**
  String get routesNoCurrentInfrastructureAssessmentc3d9ef92;

  /// Legacy key: No drone assigned
  ///
  /// In en, this message translates to:
  /// **'No drone assigned'**
  String get routesNoDroneAssigned1a3203b5;

  /// Legacy key: No horizontal match in the checked dataset. Unrestricted airspace is not established.
  ///
  /// In en, this message translates to:
  /// **'No horizontal match in the checked dataset. Unrestricted airspace is not established.'**
  String get routesNoHorizontalMatchIne04da067;

  /// Legacy key: No matching saved spots.
  ///
  /// In en, this message translates to:
  /// **'No matching saved spots.'**
  String get routesNoMatchingSavedSpots783f2c6f;

  /// Legacy key: No proximity detected in the evaluated data. This does not establish an obstacle-free route.
  ///
  /// In en, this message translates to:
  /// **'No proximity detected in the evaluated data. This does not establish an obstacle-free route.'**
  String get routesNoProximityDetectedIn75f77f3a;

  /// Legacy key: No saved flight routes yet. Create a route and place waypoints on the map.
  ///
  /// In en, this message translates to:
  /// **'No saved flight routes yet. Create a route and place waypoints on the map.'**
  String get routesNoSavedFlightRoutesa271a04f;

  /// Legacy key: No saved routes. Create one in Flight routes.
  ///
  /// In en, this message translates to:
  /// **'No saved routes. Create one in Flight routes.'**
  String get routesNoSavedRoutesCreateca237d75;

  /// Legacy key: No saved spots yet. Use the place search or tap the map.
  ///
  /// In en, this message translates to:
  /// **'No saved spots yet. Use the place search or tap the map.'**
  String get routesNoSavedSpotsYet044a3542;

  /// Legacy key: Official FOCA flight rules
  ///
  /// In en, this message translates to:
  /// **'Official FOCA flight rules'**
  String get routesOfficialFocaFlightRulesa3ad892e;

  /// Legacy key: Opt-in. Only available local surface geometry is inspected; 3D Tiles alone do not prove clearance.
  ///
  /// In en, this message translates to:
  /// **'Opt-in. Only available local surface geometry is inspected; 3D Tiles alone do not prove clearance.'**
  String get routesOptInOnlyAvailable291368ee;

  /// Legacy key: Optimistic ×{0} · conservative ×{1} · reserve {2}% of nominal capacity.
  ///
  /// In en, this message translates to:
  /// **'Optimistic ×{arg0} · conservative ×{arg1} · reserve {arg2}% of nominal capacity.'**
  String routesOptimisticConservativeReserveOf8919c819(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: Outgoing airspeed (m/s)
  ///
  /// In en, this message translates to:
  /// **'Outgoing airspeed (m/s)'**
  String get routesOutgoingAirspeedMS43d6115b;

  /// Legacy key: Planned visibility scenario
  ///
  /// In en, this message translates to:
  /// **'Planned visibility scenario'**
  String get routesPlannedVisibilityScenario8c3dd9f7;

  /// Legacy key: Planning assumptions
  ///
  /// In en, this message translates to:
  /// **'Planning assumptions'**
  String get routesPlanningAssumptions61ebf317;

  /// Legacy key: Power curve source: {0}
  ///
  /// In en, this message translates to:
  /// **'Power curve source: {arg0}'**
  String routesPowerCurveSource26cb2f6e(String arg0);

  /// Legacy key: Power is interpolated by airspeed and scaled by (takeoff mass / reference mass)^1.5. Climb adds m·g·height / efficiency. Descent does not recover energy. This assumes multirotor-like behaviour.
  ///
  /// In en, this message translates to:
  /// **'Power is interpolated by airspeed and scaled by (takeoff mass / reference mass)^1.5. Climb adds m·g·height / efficiency. Descent does not recover energy. This assumes multirotor-like behaviour.'**
  String get routesPowerIsInterpolatedBy90df4a57;

  /// Legacy key: Processing limit reached. The assessment or result list is incomplete.
  ///
  /// In en, this message translates to:
  /// **'Processing limit reached. The assessment or result list is incomplete.'**
  String get routesProcessingLimitReachedThe59278caf;

  /// Legacy key: Published coverage is incomplete. {0} unsupported source records. Missing objects and cables may exist; category filters exclude other objects.
  ///
  /// In en, this message translates to:
  /// **'Published coverage is incomplete. {arg0} unsupported source records. Missing objects and cables may exist; category filters exclude other objects.'**
  String routesPublishedCoverageIsIncomplete8fda9cde(String arg0);

  /// Legacy key: Recalculate route
  ///
  /// In en, this message translates to:
  /// **'Recalculate route'**
  String get routesRecalculateRoute3aa2250f;

  /// Legacy key: Recorded charge: {0}% · pack status: {1}.
  ///
  /// In en, this message translates to:
  /// **'Recorded charge: {arg0}% · pack status: {arg1}.'**
  String routesRecordedChargePackStatus6e905850(String arg0, String arg1);

  /// Legacy key: Recording details unavailable
  ///
  /// In en, this message translates to:
  /// **'Recording details unavailable'**
  String get routesRecordingDetailsUnavailable028143fa;

  /// Legacy key: Red segments: terrain / reserve estimates · Open analysis
  ///
  /// In en, this message translates to:
  /// **'Red segments: terrain / reserve estimates · Open analysis'**
  String get routesRedSegmentsTerrainReservefbd059b9;

  /// Legacy key: Replaces existing height and speed settings for this draft. Undo is available.
  ///
  /// In en, this message translates to:
  /// **'Replaces existing height and speed settings for this draft. Undo is available.'**
  String get routesReplacesExistingHeightAndbb3345ca;

  /// Legacy key: Reserve and uncertainty
  ///
  /// In en, this message translates to:
  /// **'Reserve and uncertainty'**
  String get routesReserveAndUncertainty53aafdf4;

  /// Legacy key: {0} · {1} · retrieved {2}
  ///
  /// In en, this message translates to:
  /// **'{arg0} · {arg1} · retrieved {arg2}'**
  String routesRetrieved06b37dcd(String arg0, String arg1, String arg2);

  /// Legacy key: Retry loading
  ///
  /// In en, this message translates to:
  /// **'Retry loading'**
  String get routesRetryLoading54b15f12;

  /// Legacy key: Retry route list
  ///
  /// In en, this message translates to:
  /// **'Retry route list'**
  String get routesRetryRouteListd4c0bbae;

  /// Legacy key: Retry route preview
  ///
  /// In en, this message translates to:
  /// **'Retry route preview'**
  String get routesRetryRoutePreview25273ee7;

  /// Legacy key: Return energy is unknown; no complete feasibility estimate is available.
  ///
  /// In en, this message translates to:
  /// **'Return energy is unknown; no complete feasibility estimate is available.'**
  String get routesReturnEnergyIsUnknownb2869d98;

  /// Legacy key: Return flight is excluded from the budget.
  ///
  /// In en, this message translates to:
  /// **'Return flight is excluded from the budget.'**
  String get routesReturnFlightIsExcluded22c87afc;

  /// Legacy key: Review coordinates and height references before planning a flight.
  ///
  /// In en, this message translates to:
  /// **'Review coordinates and height references before planning a flight.'**
  String get routesReviewCoordinatesAndHeight88280ee0;

  /// Legacy key: Route analysis
  ///
  /// In en, this message translates to:
  /// **'Route analysis'**
  String get routesRouteAnalysise04589ed;

  /// Legacy key: Route constraints
  ///
  /// In en, this message translates to:
  /// **'Route constraints'**
  String get routesRouteConstraints7de90cfc;

  /// Legacy key: Route editor
  ///
  /// In en, this message translates to:
  /// **'Route editor'**
  String get routesRouteEditor9c06eac0;

  /// Legacy key: Route equipment
  ///
  /// In en, this message translates to:
  /// **'Route equipment'**
  String get routesRouteEquipmentc4206690;

  /// Legacy key: Route options
  ///
  /// In en, this message translates to:
  /// **'Route options'**
  String get routesRouteOptions55d80b02;

  /// Legacy key: Route saved locally
  ///
  /// In en, this message translates to:
  /// **'Route saved locally'**
  String get routesRouteSavedLocally324d209a;

  /// Legacy key: {0}S · {1} mAh · {2}
  ///
  /// In en, this message translates to:
  /// **'{arg0} · {arg1} mAh · {arg2}'**
  String routesSMah1c86b217(String arg0, String arg1, String arg2);

  /// Legacy key: {0} samples have unknown clearance; intermediate height limits remain unassessed.
  ///
  /// In en, this message translates to:
  /// **'{arg0} samples have unknown clearance; intermediate height limits remain unassessed.'**
  String routesSamplesHaveUnknownClearance53029fc6(String arg0);

  /// Legacy key: Saved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get routesSavedc0ae8f6e;

  /// Legacy key: Search place
  ///
  /// In en, this message translates to:
  /// **'Search place'**
  String get routesSearchPlace48c850ed;

  /// Legacy key: Segment {0}
  ///
  /// In en, this message translates to:
  /// **'{arg0} segment'**
  String routesSegment2e9d80c3(String arg0);

  /// Legacy key: Segment {0} · {1} m horizontal
  /// {2}
  /// Source ID: {3}{4}
  ///
  /// In en, this message translates to:
  /// **'Segment {arg0} · {arg1} m horizontal\n{arg2}\nSource ID: {arg3}{arg4}'**
  String routesSegmentMHorizontalSource0f6d6b0d(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
  );

  /// Legacy key: Segment {0} · simulated separation {1} m
  /// {2} · {3} · {4} / {5}
  /// Model geometry only; not real-world flight clearance.
  ///
  /// In en, this message translates to:
  /// **'Segment {arg0} · simulated separation {arg1} m\n{arg2} · {arg3} · {arg4} / {arg5}\nModel geometry only; not real-world flight clearance.'**
  String routesSegmentSimulatedSeparationM10cc26fd(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
    String arg4,
    String arg5,
  );

  /// Legacy key: {0}
  /// Segments {1}
  /// {2}
  ///
  /// In en, this message translates to:
  /// **'{arg0} segments {arg1} {arg2}'**
  String routesSegments5ae8cd98(String arg0, String arg1, String arg2);

  /// Legacy key: Show 3D Infrastructure Clearance findings on map
  ///
  /// In en, this message translates to:
  /// **'Show 3D Infrastructure Clearance findings on map'**
  String get routesShowDInfrastructureClearancedcae1002;

  /// Legacy key: Show entire route
  ///
  /// In en, this message translates to:
  /// **'Show entire route'**
  String get routesShowEntireRoute7e936417;

  /// Legacy key: Show {0} on map
  ///
  /// In en, this message translates to:
  /// **'Show {arg0} on map'**
  String routesShowOnMapa1a4e0a9(String arg0);

  /// Legacy key: Simulate flight: {0}
  ///
  /// In en, this message translates to:
  /// **'Simulate flight: {arg0}'**
  String routesSimulateFlight6c31fd20(String arg0);

  /// Legacy key: Sonnen- und Mondzeit
  ///
  /// In en, this message translates to:
  /// **'Sun and moon time'**
  String get routesSonnenUndMondzeit1999dfbc;

  /// Legacy key: Sonnen- und Mondzeit der Route
  ///
  /// In en, this message translates to:
  /// **'Sun and moon time of the route'**
  String get routesSonnenUndMondzeitDer90b0d9c4;

  /// Legacy key: Steady wind assumption: {0} m/s from {1}° true. Crosswind compensation is included; an unachievable track remains unknown.
  ///
  /// In en, this message translates to:
  /// **'Steady wind assumption: {arg0} m/s from {arg1}° true. Crosswind compensation is included; an unachievable track remains unknown.'**
  String routesSteadyWindAssumptionM2884cea1(String arg0, String arg1);

  /// Legacy key: Stored on this device
  ///
  /// In en, this message translates to:
  /// **'Stored on this device'**
  String get routesStoredOnThisDevicece3661a2;

  /// Legacy key: Tap map to add · Select a waypoint to edit
  ///
  /// In en, this message translates to:
  /// **'Tap map to add · Select a waypoint to edit'**
  String get routesTapMapToAdddf97da9f;

  /// Legacy key: Tap the profile to inspect a sample. Planned altitude uses the primary colour; terrain uses grey.
  ///
  /// In en, this message translates to:
  /// **'Tap the profile to inspect a sample. Planned altitude uses the primary colour; terrain uses grey.'**
  String get routesTapTheProfileTo8cbd2ae2;

  /// Legacy key: Terrain and planned altitude · WGS84 ellipsoid
  ///
  /// In en, this message translates to:
  /// **'Terrain and planned altitude · WGS84 ellipsoid'**
  String get routesTerrainAndPlannedAltitude8cc1136a;

  /// Legacy key: Terrain clearance remains unknown. The energy budget does not establish route safety.
  ///
  /// In en, this message translates to:
  /// **'Terrain clearance remains unknown. The energy budget does not establish route safety.'**
  String get routesTerrainClearanceRemainsUnknown8f8dbef8;

  /// Legacy key: Terrain samples {0}/{1}
  ///
  /// In en, this message translates to:
  /// **'Terrain samples {arg0}/{arg1}'**
  String routesTerrainSamples14ad50c1(String arg0, String arg1);

  /// Legacy key: Terrain sampling: {0}. WGS84 ellipsoid heights.
  ///
  /// In en, this message translates to:
  /// **'Terrain sampling: {arg0}. WGS84 ellipsoid heights.'**
  String routesTerrainSamplingWgsEllipsoide722c804(String arg0);

  /// Legacy key: The assigned drone was deleted. Choose another profile or clear the assignment.
  ///
  /// In en, this message translates to:
  /// **'The assigned drone was deleted. Choose another profile or clear the assignment.'**
  String get routesTheAssignedDroneWas08ea7895;

  /// Legacy key: The current draft has unsaved changes.
  ///
  /// In en, this message translates to:
  /// **'The current draft has unsaved changes.'**
  String get routesTheCurrentDraftHas0d9d9939;

  /// Legacy key: The level-flight power curve is interpolated without extrapolation and scaled by mass^1.5. Climb work is added with the configured efficiency; descent has no energy recovery.
  ///
  /// In en, this message translates to:
  /// **'The level-flight power curve is interpolated without extrapolation and scaled by mass^1.5. Climb work is added with the configured efficiency; descent has no energy recovery.'**
  String get routesTheLevelFlightPower308a2473;

  /// Legacy key: The same configured takeoff mass is used for alternative packs. Adjust it for the installed battery.
  ///
  /// In en, this message translates to:
  /// **'The same configured takeoff mass is used for alternative packs. Adjust it for the installed battery.'**
  String get routesTheSameConfiguredTakeoff20e0843f;

  /// Legacy key: UAS zone intersections
  ///
  /// In en, this message translates to:
  /// **'UAS zone intersections'**
  String get routesUasZoneIntersections5bc17c8d;

  /// Legacy key: Unable to frame this route. Please retry.
  ///
  /// In en, this message translates to:
  /// **'Unable to frame this route. Please retry.'**
  String get routesUnableToFrameThisbad8013a;

  /// Legacy key: Unable to load saved spots. Retry
  ///
  /// In en, this message translates to:
  /// **'Unable to load saved spots. Retry'**
  String get routesUnableToLoadSaved7cf6f705;

  /// Legacy key: Unable to load saved routes.
  ///
  /// In en, this message translates to:
  /// **'Unable to load saved routes.'**
  String get routesUnableToLoadSavedda813904;

  /// Legacy key: Undo waypoint change
  ///
  /// In en, this message translates to:
  /// **'Undo waypoint change'**
  String get routesUndoWaypointChange8a12e7bc;

  /// Legacy key: Unsaved
  ///
  /// In en, this message translates to:
  /// **'Unsaved'**
  String get routesUnsaved2ab06e25;

  /// Legacy key: Unverified
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get routesUnverifiedeb27a190;

  /// Legacy key: Visibility scenario unverified. Confirm VLOS/FPV observer requirements and any BVLOS authorisation.
  ///
  /// In en, this message translates to:
  /// **'Visibility scenario unverified. Confirm VLOS/FPV observer requirements and any BVLOS authorisation.'**
  String get routesVisibilityScenarioUnverifiedConfirmd7996cb0;

  /// Legacy key: VLOS planned: verify actual visibility and surrounding airspace on site. A map radius does not establish VLOS.
  ///
  /// In en, this message translates to:
  /// **'VLOS planned: verify actual visibility and surrounding airspace on site. A map radius does not establish VLOS.'**
  String get routesVlosPlannedVerifyActual5fbdce06;

  /// Legacy key: Waypoint {0}
  ///
  /// In en, this message translates to:
  /// **'Waypoint {arg0}'**
  String routesWaypoint2315aa1f(String arg0);

  /// Legacy key: Waypoint actions
  ///
  /// In en, this message translates to:
  /// **'Waypoint actions'**
  String get routesWaypointActionsf5f1d082;

  /// Legacy key: Waypoint {0} · {1} · {2} m/s
  ///
  /// In en, this message translates to:
  /// **'Waypoint {arg0} · {arg1} · {arg2} m/s'**
  String routesWaypointMS5220bb0f(String arg0, String arg1, String arg2);

  /// Legacy key: {0} · {1} waypoints
  ///
  /// In en, this message translates to:
  /// **'{arg0} · {arg1} waypoints'**
  String routesWaypoints31c92956(String arg0, String arg1);

  /// Legacy key: Waypoints
  ///
  /// In en, this message translates to:
  /// **'Waypoints'**
  String get routesWaypoints8de9ac08;

  /// Legacy key: {0} waypoints
  ///
  /// In en, this message translates to:
  /// **'{arg0} waypoints'**
  String routesWaypointsbc27edbc(String arg0);

  /// Legacy key: Wind is excluded. Enable a manual wind assumption in Planning assumptions.
  ///
  /// In en, this message translates to:
  /// **'Wind is excluded. Enable a manual wind assumption in Planning assumptions.'**
  String get routesWindIsExcludedEnablee95610f8;

  /// Legacy key: Wird mit der Route gespeichert. Eine feste Zeit bleibt stehen; „Jetzt“ läuft mit der Gerätezeit.
  ///
  /// In en, this message translates to:
  /// **'Saved with the route. A fixed time stops; \"Now\" runs with the device time.'**
  String get routesWirdMitDerRoutece20d1c9;

  /// Legacy key: Einstellung konnte nicht übernommen werden. Bitte erneut versuchen.
  ///
  /// In en, this message translates to:
  /// **'Could not apply the setting. Try again.'**
  String get settingsEinstellungKonnteNichtUebernommenf7be0131;

  /// Legacy key: Flugsimulator & Controller
  ///
  /// In en, this message translates to:
  /// **'Flight simulator & controller'**
  String get settingsFlugsimulatorControllerb56cd9ea;

  /// Legacy key: Für die nächste Simulation
  ///
  /// In en, this message translates to:
  /// **'For the next simulation'**
  String get settingsFuerDieNaechsteSimulationfde989c1;

  /// Legacy key: Hilfe
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get settingsHilfeb74af50b;

  /// Legacy key: Karteneinstellungen zurücksetzen
  ///
  /// In en, this message translates to:
  /// **'Reset Map Settings'**
  String get settingsKarteneinstellungenZuruecksetzen65775760;

  /// Legacy key: Luftraumquellen
  ///
  /// In en, this message translates to:
  /// **'Airspace sources'**
  String get settingsLuftraumquellene57512f8;

  /// Legacy key: Offline-Karten & Daten
  ///
  /// In en, this message translates to:
  /// **'Offline maps & data'**
  String get settingsOfflineKartenDatenefa573cc;

  /// Legacy key: Open-Source-Lizenzen
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get settingsOpenSourceLizenzen225c9494;

  /// Legacy key: Privacy policy
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy7ceacdca;

  /// Legacy key: Sprache
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsSprache3d9f5cb4;

  /// Legacy key: Standortanzeige
  ///
  /// In en, this message translates to:
  /// **'Location display'**
  String get settingsStandortanzeige3f41a9ee;

  /// Legacy key: Touch-Steuerung anzeigen
  ///
  /// In en, this message translates to:
  /// **'Show touch controls'**
  String get settingsTouchSteuerungAnzeigen41a3a9f0;

  /// Legacy key: Verkehr & Zugänge
  ///
  /// In en, this message translates to:
  /// **'Traffic & access'**
  String get settingsVerkehrZugaenge27db3ea6;

  /// Legacy key: Wetteranbieter
  ///
  /// In en, this message translates to:
  /// **'Weather providers'**
  String get settingsWetteranbietera62920c2;

  /// Legacy key: Analyze applies inputs; Save the route to keep them
  ///
  /// In en, this message translates to:
  /// **'Analyze applies inputs; Save the route to keep them'**
  String get signalAnalyzeAppliesInputsSave2af97340;

  /// Legacy key: Analyze radio paths
  ///
  /// In en, this message translates to:
  /// **'Analyze radio paths'**
  String get signalAnalyzeRadioPathsf3709ab3;

  /// Legacy key: Apply radio preview
  ///
  /// In en, this message translates to:
  /// **'Apply radio preview'**
  String get signalApplyRadioPreview1e94fdf7;

  /// Legacy key: Cancel analysis
  ///
  /// In en, this message translates to:
  /// **'Cancel analysis'**
  String get signalCancelAnalysisdf18d195;

  /// Legacy key: Clear observations
  ///
  /// In en, this message translates to:
  /// **'Clear observations'**
  String get signalClearObservationsc6114e52;

  /// Legacy key: Close signal analysis
  ///
  /// In en, this message translates to:
  /// **'Close signal analysis'**
  String get signalCloseSignalAnalysisad376625;

  /// Legacy key: Current flight launch point
  ///
  /// In en, this message translates to:
  /// **'Current flight launch point'**
  String get signalCurrentFlightLaunchPointb1e984c0;

  /// Legacy key: Enable live radio preview
  ///
  /// In en, this message translates to:
  /// **'Enable live radio preview'**
  String get signalEnableLiveRadioPreview96c70f99;

  /// Legacy key: Fixed spot / coordinates
  ///
  /// In en, this message translates to:
  /// **'Fixed spot / coordinates'**
  String get signalFixedSpotCoordinatese71de0f9;

  /// Legacy key: Import surface CSV
  ///
  /// In en, this message translates to:
  /// **'Import surface CSV'**
  String get signalImportSurfaceCsv07954aaf;

  /// Legacy key: {0} imported observations
  ///
  /// In en, this message translates to:
  /// **'{arg0} imported observations'**
  String signalImportedObservations6dc74f21(String arg0);

  /// Legacy key: Include imported observations
  ///
  /// In en, this message translates to:
  /// **'Include imported observations'**
  String get signalIncludeImportedObservations2e110738;

  /// Legacy key: Include imported surface observations
  ///
  /// In en, this message translates to:
  /// **'Include imported surface observations'**
  String get signalIncludeImportedSurfaceObservations3dc9dc80;

  /// Legacy key: Inspect communication path
  ///
  /// In en, this message translates to:
  /// **'Inspect communication path'**
  String get signalInspectCommunicationPath2fdd77fe;

  /// Legacy key: Last completed profile: {0} · {1}
  ///
  /// In en, this message translates to:
  /// **'Last completed profile: {arg0} · {arg1}'**
  String signalLastCompletedProfileaec2638b(String arg0, String arg1);

  /// Legacy key: Latitude · WGS84
  ///
  /// In en, this message translates to:
  /// **'Latitude · WGS84'**
  String get signalLatitudeWgsd5f5cf6c;

  /// Legacy key: Live radio line of sight
  ///
  /// In en, this message translates to:
  /// **'Live radio line of sight'**
  String get signalLiveRadioLineOfb3b60fda;

  /// Legacy key: {0} local observations · {1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} local observations · {arg1}'**
  String signalLocalObservationsb6dacb84(String arg0, String arg1);

  /// Legacy key: Local surface observations
  ///
  /// In en, this message translates to:
  /// **'Local surface observations'**
  String get signalLocalSurfaceObservations5f83fa58;

  /// Legacy key: Longitude · WGS84
  ///
  /// In en, this message translates to:
  /// **'Longitude · WGS84'**
  String get signalLongitudeWgs63c0ff8c;

  /// Legacy key: {0} · {1} m AGL · {2} m radius
  ///
  /// In en, this message translates to:
  /// **'{arg0} · {arg1} m AGL · {arg2} m radius'**
  String signalMAglMRadiuscfb648b3(String arg0, String arg1, String arg2);

  /// Legacy key: Map targets {0}–{1} of {2}
  ///
  /// In en, this message translates to:
  /// **'Map targets {arg0}–{arg1} of {arg2}'**
  String signalMapTargetsOf0a2ebaa0(String arg0, String arg1, String arg2);

  /// Legacy key: Minimum configured Fresnel margin: {0} m
  ///
  /// In en, this message translates to:
  /// **'Minimum configured Fresnel margin: {arg0} m'**
  String signalMinimumConfiguredFresnelMargin119fbdcf(String arg0);

  /// Legacy key: Minimum sampled geometric clearance: {0} m
  ///
  /// In en, this message translates to:
  /// **'Minimum sampled geometric clearance: {arg0} m'**
  String signalMinimumSampledGeometricClearancecf242d36(String arg0);

  /// Legacy key: Minimum sampled LOS clearance: {0} m
  ///
  /// In en, this message translates to:
  /// **'Minimum sampled LOS clearance: {arg0} m'**
  String signalMinimumSampledLosClearance8c03754f(String arg0);

  /// Legacy key: Optional building / vegetation observations
  ///
  /// In en, this message translates to:
  /// **'Optional building / vegetation observations'**
  String get signalOptionalBuildingVegetationObservations7a6fce33;

  /// Legacy key: Periodic geometric preview between the transmitter and the simulated drone. This is not measured signal quality or a guaranteed communication range.
  ///
  /// In en, this message translates to:
  /// **'Periodic geometric preview between the transmitter and the simulated drone. This is not measured signal quality or a guaranteed communication range.'**
  String get signalPeriodicGeometricPreviewBetweenb75cb376;

  /// Legacy key: Pilot & frequency
  ///
  /// In en, this message translates to:
  /// **'Pilot & frequency'**
  String get signalPilotFrequency12dc826d;

  /// Legacy key: Profile: brown terrain/surface · cyan LOS · purple lower Fresnel boundary. Heights in WGS84 ellipsoid.
  ///
  /// In en, this message translates to:
  /// **'Profile: brown terrain/surface · cyan LOS · purple lower Fresnel boundary. Heights in WGS84 ellipsoid.'**
  String get signalProfileBrownTerrainSurface4924cb6b;

  /// Legacy key: Radio line of sight
  ///
  /// In en, this message translates to:
  /// **'Radio line of sight'**
  String get signalRadioLineOfSight3d11d898;

  /// Legacy key: Remove observations
  ///
  /// In en, this message translates to:
  /// **'Remove observations'**
  String get signalRemoveObservationsa17d9d68;

  /// Legacy key: {0} / {1} route targets checked
  ///
  /// In en, this message translates to:
  /// **'{arg0} / {arg1} route targets checked'**
  String signalRouteTargetsCheckedf545b613(String arg0, String arg1);

  /// Legacy key: {0} route targets · terrain: {1}
  ///
  /// In en, this message translates to:
  /// **'{arg0} route targets · terrain: {arg1}'**
  String signalRouteTargetsTerraind0166c82(String arg0, String arg1);

  /// Legacy key: Sampling and limits
  ///
  /// In en, this message translates to:
  /// **'Sampling and limits'**
  String get signalSamplingAndLimits81b895c4;

  /// Legacy key: Selected map point
  ///
  /// In en, this message translates to:
  /// **'Selected map point'**
  String get signalSelectedMapPoint1717e7f7;

  /// Legacy key: swisstopo terrain via Cesium · fixed terrain level 12 · profile points at most 25 m apart · live range 1 m–6 km. A new profile is attempted at most every 2 seconds. Sample heights may be reused for up to 30 seconds. Narrow or finer terrain features may be missed.
  ///
  /// In en, this message translates to:
  /// **'swisstopo terrain via Cesium · fixed terrain level 12 · profile points at most 25 m apart · live range 1 m–6 km. A new profile is attempted at most every 2 seconds. Sample heights may be reused for up to 30 seconds. Narrow or finer terrain features may be missed.'**
  String get signalSwisstopoTerrainViaCesium5961555e;

  /// Legacy key: Transmitter height is above sampled terrain. The receiving endpoint is the drone’s simulated WGS84 ellipsoidal height.
  ///
  /// In en, this message translates to:
  /// **'Transmitter height is above sampled terrain. The receiving endpoint is the drone’s simulated WGS84 ellipsoidal height.'**
  String get signalTransmitterHeightIsAboveb50b536b;

  /// Legacy key: Transmitter position
  ///
  /// In en, this message translates to:
  /// **'Transmitter position'**
  String get signalTransmitterPositiond87196e3;

  /// Legacy key: Acro-Drehraten
  ///
  /// In en, this message translates to:
  /// **'Acro rotation rates'**
  String get simulationAcroDrehratenf7001f19;

  /// Legacy key: Acro · freie Drehraten
  ///
  /// In en, this message translates to:
  /// **'Acro · direct rate control'**
  String get simulationAcroFreieDrehratena37d7b4c;

  /// Legacy key: Acro hat keine Selbststabilisierung oder Höhenhaltung. Schub folgt der Drohnenlage; geringer Schub lässt sie frei fallen.
  ///
  /// In en, this message translates to:
  /// **'Acro has no self-stabilization or elevation. Push follows the drone position; low thrust lets it fall free.'**
  String get simulationAcroHatKeineSelbststabilisierung83a2e981;

  /// Legacy key: Acro-Physik
  ///
  /// In en, this message translates to:
  /// **'Acro physics'**
  String get simulationAcroPhysikdf296beb;

  /// Legacy key: AGL follows the terrain between waypoints and may differ from the recorded absolute trajectory.
  ///
  /// In en, this message translates to:
  /// **'AGL follows the terrain between waypoints and may differ from the recorded absolute trajectory.'**
  String get simulationAglFollowsTheTerrain71243353;

  /// Legacy key: Akkuprofil
  ///
  /// In en, this message translates to:
  /// **'Battery profile'**
  String get simulationAkkuprofilf5c68edf;

  /// Legacy key: Angle · selbststabilisierend
  ///
  /// In en, this message translates to:
  /// **'Angle · Self-stabilizing'**
  String get simulationAngleSelbststabilisierenddb3cdc71;

  /// Legacy key: Angle stabilisiert die Lage und begrenzt die Neigung auf 50°. Bei Neigung ist mehr Gas zum Halten der Höhe nötig.
  ///
  /// In en, this message translates to:
  /// **'Angle stabilizes the position and limits the inclination to 50°. More gas is needed to hold the height when tilting.'**
  String get simulationAngleStabilisiertDieLage73f2f597;

  /// Legacy key: Balanced
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get simulationBalanced03342dbb;

  /// Legacy key: Based on terrain loaded during recording.
  ///
  /// In en, this message translates to:
  /// **'Based on terrain loaded during recording.'**
  String get simulationBasedOnTerrainLoaded058810aa;

  /// Legacy key: Betaflight
  ///
  /// In en, this message translates to:
  /// **'Betaflight'**
  String get simulationBetaflightaaa2dc4d;

  /// Legacy key: Compatibility
  ///
  /// In en, this message translates to:
  /// **'Compatibility'**
  String get simulationCompatibility5d60c7dd;

  /// Legacy key: Continuous section
  ///
  /// In en, this message translates to:
  /// **'Continuous section'**
  String get simulationContinuousSection1042d718;

  /// Legacy key: Controller
  ///
  /// In en, this message translates to:
  /// **'Controller'**
  String get simulationControllera36a5ffa;

  /// Legacy key: Controllertyp
  ///
  /// In en, this message translates to:
  /// **'Controller type'**
  String get simulationControllertyp247db158;

  /// Legacy key: Die niedrige Zellspannung muss höher als die kritische Zellspannung sein.
  ///
  /// In en, this message translates to:
  /// **'Low voltage warning must be above the critical cell voltage.'**
  String get simulationDieNiedrigeZellspannungMuss653c3f34;

  /// Legacy key: Discard
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get simulationDiscard36fff63c;

  /// Legacy key: Discard recording?
  ///
  /// In en, this message translates to:
  /// **'Discard recording?'**
  String get simulationDiscardRecording76dde3d6;

  /// Legacy key: Drohnenprofil
  ///
  /// In en, this message translates to:
  /// **'Drone profile'**
  String get simulationDrohnenprofil2c80fbb6;

  /// Legacy key: Drohnenprofile übernehmen Geschwindigkeit und Steigrate für Angle und GPS. Acro-Physik und Beschleunigung bleiben geschätzte Modellwerte. Die Kamera beeinflusst nur die Ansicht.
  ///
  /// In en, this message translates to:
  /// **'Drone profiles provide the speed and climb rate for Angle and GPS modes. Acro physics and acceleration use estimated model values. Camera settings affect the view.'**
  String get simulationDrohnenprofileUebernehmenGeschwindigkeitUndb7b1010f;

  /// Legacy key: Flug einstellen
  ///
  /// In en, this message translates to:
  /// **'Flight settings'**
  String get simulationFlugEinstellenf142a101;

  /// Legacy key: Flug starten
  ///
  /// In en, this message translates to:
  /// **'Take off flight'**
  String get simulationFlugStarten8846a2e4;

  /// Legacy key: Flugeinstellungen schließen
  ///
  /// In en, this message translates to:
  /// **'Close flight settings'**
  String get simulationFlugeinstellungenSchliessen974d8874;

  /// Legacy key: Flugmodus
  ///
  /// In en, this message translates to:
  /// **'Flight mode'**
  String get simulationFlugmodus699cac43;

  /// Legacy key: Flugsimulator
  ///
  /// In en, this message translates to:
  /// **'Flight simulator'**
  String get simulationFlugsimulatore761527e;

  /// Legacy key: Gamepad
  ///
  /// In en, this message translates to:
  /// **'Gamepad'**
  String get simulationGamepad4dde0030;

  /// Legacy key: Gas null: Mitte (50 %)
  ///
  /// In en, this message translates to:
  /// **'Gas zero: middle (50%)'**
  String get simulationGasNullMitte62e44939;

  /// Legacy key: Gas null: unten (0 %)
  ///
  /// In en, this message translates to:
  /// **'Gas zero: lower (0%)'**
  String get simulationGasNullUntenc2617787;

  /// Legacy key: Gas-Nullstellung
  ///
  /// In en, this message translates to:
  /// **'Zero-throttle position'**
  String get simulationGasNullstellungd92cd012;

  /// Legacy key: Gelände und unterstützte Modellflächen können die Bewegung stoppen. Hindernisse und Kollisionen sind nicht vollständig erfasst. Die Simulation ist keine reale Leistungs- oder Sicherheitsprüfung.
  ///
  /// In en, this message translates to:
  /// **'Terrain and supported model surfaces can stop movement. Obstacle and collision coverage is incomplete. Use the simulator only for simulated flight.'**
  String get simulationGelaendeUndUnterstuetzteModellflaechen2d8c2c0b;

  /// Legacy key: Geschätzte Akkuspannung anzeigen
  ///
  /// In en, this message translates to:
  /// **'Show estimated battery voltage'**
  String get simulationGeschaetzteAkkuspannungAnzeigen3fc4417b;

  /// Legacy key: Geschätztes Horizontaltempo bei Vollgas: {0} km/h. Höherer Luftwiderstand senkt diesen Wert; Sturzflug kann ihn überschreiten.
  ///
  /// In en, this message translates to:
  /// **'Estimated level speed at full throttle: {arg0} km/h. Higher drag lowers this speed. A dive can exceed it.'**
  String simulationGeschaetztesHorizontaltempoBeiVollgasbf685b25(String arg0);

  /// Legacy key: Goggles
  ///
  /// In en, this message translates to:
  /// **'Goggles'**
  String get simulationGoggles0b34f86f;

  /// Legacy key: GPS bremst automatisch. Linker Stick: Bewegung; rechter Stick: Blickrichtung.
  ///
  /// In en, this message translates to:
  /// **'GPS brakes automatically. Left stick: movement; right stick: direction of view.'**
  String get simulationGpsBremstAutomatischLinker62b42159;

  /// Legacy key: GPS · unterstützt
  ///
  /// In en, this message translates to:
  /// **'GPS · supported'**
  String get simulationGpsUnterstuetzt4fba7ae2;

  /// Legacy key: Grafikprofil
  ///
  /// In en, this message translates to:
  /// **'Graphics profile'**
  String get simulationGrafikprofile6062f50;

  /// Legacy key: Gültige Schub- und Widerstandswerte eingeben.
  ///
  /// In en, this message translates to:
  /// **'Enter valid thrust and drag values.'**
  String get simulationGueltigeSchubUndWiderstandswerted87ecf7c;

  /// Legacy key: Gültige Schubwerte für die Schwebeschätzung eingeben.
  ///
  /// In en, this message translates to:
  /// **'Enter valid thrust values to estimate hover throttle.'**
  String get simulationGueltigeSchubwerteFuerDie9f739082;

  /// Legacy key: HUD-Stil
  ///
  /// In en, this message translates to:
  /// **'HUD style'**
  String get simulationHudStil9e126e51;

  /// Legacy key: Kanal {0}
  ///
  /// In en, this message translates to:
  /// **'Channel {arg0}'**
  String simulationKanale8c667fd(String arg0);

  /// Legacy key: Keep all samples
  ///
  /// In en, this message translates to:
  /// **'Keep all samples'**
  String get simulationKeepAllSamples1900da8c;

  /// Legacy key: Keep for later
  ///
  /// In en, this message translates to:
  /// **'Keep for later'**
  String get simulationKeepForLatera212630b;

  /// Legacy key: Keep recording
  ///
  /// In en, this message translates to:
  /// **'Keep recording'**
  String get simulationKeepRecording77ccc1b0;

  /// Legacy key: Kein Akku ausgewählt
  ///
  /// In en, this message translates to:
  /// **'No battery selected'**
  String get simulationKeinAkkuAusgewaehltce2c46d1;

  /// Legacy key: Keine automatische Aufzeichnung oder Ausfuhr. Online-Karten- und Geländeabrufe übermitteln den betrachteten Bereich an die Anbieter.
  ///
  /// In en, this message translates to:
  /// **'No automatic recording or export. Online map and site calls transmit the area considered to the providers.'**
  String get simulationKeineAutomatischeAufzeichnungOder98df029c;

  /// Legacy key: Koordinaten im HUD anzeigen
  ///
  /// In en, this message translates to:
  /// **'Show coordinates in HUD'**
  String get simulationKoordinatenImHudAnzeigen5180787d;

  /// Legacy key: {0} m in 3D
  ///
  /// In en, this message translates to:
  /// **'{arg0} in 3D'**
  String simulationMInD2d9450e4(String arg0);

  /// Legacy key: {0} m in 3D · {1} s · {2} samples → {3} waypoints
  ///
  /// In en, this message translates to:
  /// **'{arg0} m in 3D · {arg1} s · {arg2} samples → {arg3} waypoints'**
  String simulationMInDSeefbaac5(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  );

  /// Legacy key: Manuelle Werte
  ///
  /// In en, this message translates to:
  /// **'Manual values'**
  String get simulationManuelleWerte24267a01;

  /// Legacy key: Maximum simplification deviation
  ///
  /// In en, this message translates to:
  /// **'Maximum simplification deviation'**
  String get simulationMaximumSimplificationDeviationd255b933;

  /// Legacy key: 50 % · Mitte (Gamepad)
  ///
  /// In en, this message translates to:
  /// **'50% · middle (Gamepad)'**
  String get simulationMitteGamepad3ed3bc49;

  /// Legacy key: More than 1000 waypoints: increase simplification or trim the section.
  ///
  /// In en, this message translates to:
  /// **'More than 1000 waypoints: increase simplification or trim the section.'**
  String get simulationMoreThanWaypointsIncrease766de83d;

  /// Legacy key: Performance
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get simulationPerformance63c90455;

  /// Legacy key: Quality
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get simulationQualitya60f2c73;

  /// Legacy key: Record or select at least two positions with movement.
  ///
  /// In en, this message translates to:
  /// **'Record or select at least two positions with movement.'**
  String get simulationRecordOrSelectAt4a275e16;

  /// Legacy key: Recorded ground speed: {0} · Terrain samples: {1}/{2}
  ///
  /// In en, this message translates to:
  /// **'Recorded ground speed: {arg0} · Terrain samples: {arg1}/{arg2}'**
  String simulationRecordedGroundSpeedTerrainb2579dd6(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: Review simulated flight
  ///
  /// In en, this message translates to:
  /// **'Review simulated flight'**
  String get simulationReviewSimulatedFlight21515c9f;

  /// Legacy key: Save a continuous section as a new planning route. Unsaved recordings are lost when closing the app.
  ///
  /// In en, this message translates to:
  /// **'Save a continuous section as a new planning route. Unsaved recordings are lost when closing the app.'**
  String get simulationSaveAContinuousSectionead8234c;

  /// Legacy key: Save as route
  ///
  /// In en, this message translates to:
  /// **'Save as route'**
  String get simulationSaveAsRouteb13386ba;

  /// Legacy key: Saved height reference: WGS84 ellipsoid. Recorded absolute heights are preserved.
  ///
  /// In en, this message translates to:
  /// **'Saved height reference: WGS84 ellipsoid. Recorded absolute heights are preserved.'**
  String get simulationSavedHeightReferenceWgs6f44e746;

  /// Legacy key: Schwebeschätzung: {0} % Gas
  ///
  /// In en, this message translates to:
  /// **'Estimated hover throttle: {arg0}%'**
  String simulationSchwebeschaetzungGas487da692(String arg0);

  /// Legacy key: Section {0} · {1} samples
  ///
  /// In en, this message translates to:
  /// **'Section {arg0} · {arg1} samples'**
  String simulationSectionSamplesb76afcf0(String arg0, String arg1);

  /// Legacy key: Simulation · keine realen Flugeigenschaften
  ///
  /// In en, this message translates to:
  /// **'Simulation · no real flight characteristics'**
  String get simulationSimulationKeineRealenFlugeigenschaften596363e0;

  /// Legacy key: Start am markierten Punkt.
  ///
  /// In en, this message translates to:
  /// **'Start at the marked point.'**
  String get simulationStartAmMarkiertenPunktded1ae8f;

  /// Legacy key: Start unter der Kartenmitte.
  ///
  /// In en, this message translates to:
  /// **'Start under the center of the card.'**
  String get simulationStartUnterDerKartenmitted55a2a7c;

  /// Legacy key: The unsaved simulated flight will be removed.
  ///
  /// In en, this message translates to:
  /// **'The unsaved simulated flight will be removed.'**
  String get simulationTheUnsavedSimulatedFlight363d0ff5;

  /// Legacy key: Track: north ↑ · Profile: height in metres
  ///
  /// In en, this message translates to:
  /// **'Track: north ↑ · Profile: height in metres'**
  String get simulationTrackNorthProfileHeight13701f87;

  /// Legacy key: Trim section · samples {0}–{1}
  ///
  /// In en, this message translates to:
  /// **'Trim section · samples {arg0}–{arg1}'**
  String simulationTrimSectionSamples9e88a826(String arg0, String arg1);

  /// Legacy key: Übernehmen
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get simulationUbernehmen59430842;

  /// Legacy key: Umkehren
  ///
  /// In en, this message translates to:
  /// **'Reverse'**
  String get simulationUmkehren1e1918e6;

  /// Legacy key: {0} umkehren
  ///
  /// In en, this message translates to:
  /// **'Reverse {arg0}'**
  String simulationUmkehren7b06e49a(String arg0);

  /// Legacy key: Unavailable: terrain height is missing for part of this section.
  ///
  /// In en, this message translates to:
  /// **'Unavailable: terrain height is missing for part of this section.'**
  String get simulationUnavailableTerrainHeightIs1122a292;

  /// Legacy key: 0 % · unten (Fernsteuerung)
  ///
  /// In en, this message translates to:
  /// **'0 % · bottom (remote control)'**
  String get simulationUntenFernsteuerungb976566f;

  /// Legacy key: USB-Fernsteuerung
  ///
  /// In en, this message translates to:
  /// **'USB remote control'**
  String get simulationUsbFernsteuerungdab5ef74;

  /// Legacy key: Use height above terrain (AGL)
  ///
  /// In en, this message translates to:
  /// **'Use height above terrain (AGL)'**
  String get simulationUseHeightAboveTerrain0cc4fd11;

  /// Legacy key: UTC start: {0} · Per-point elapsed time retained
  ///
  /// In en, this message translates to:
  /// **'UTC start: {arg0} · Per-point elapsed time retained'**
  String simulationUtcStartPerPoint7a1f6f82(String arg0);

  /// Legacy key: Wert von {0} bis {1} eingeben.
  ///
  /// In en, this message translates to:
  /// **'Enter a value from {arg0} to {arg1}.'**
  String simulationWertVonBisEingeben87edf0e9(String arg0, String arg1);

  /// Legacy key: Zellspannung zusätzlich anzeigen
  ///
  /// In en, this message translates to:
  /// **'Show per-cell voltage'**
  String get simulationZellspannungZusaetzlichAnzeigenb25b8602;

  /// Legacy key: Zum Verbinden oder Fortsetzen Gas auf null und die übrigen Sticks zentrieren. R / Controller A setzt zurück; Escape / B beendet den Flug. Ein Moduswechsel startet am Ausgangspunkt neu.
  ///
  /// In en, this message translates to:
  /// **'To connect or resume gas to zero and center the remaining sticks. R / Controller A resets; Escape / B terminates the flight. A mode change restarts at the starting point.'**
  String get simulationZumVerbindenOderFortsetzenb43ff5ab;

  /// Legacy key: Add favorite
  ///
  /// In en, this message translates to:
  /// **'Add favorite'**
  String get spotsAddFavorite4914d44e;

  /// Legacy key: Add photo
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get spotsAddPhotod1434930;

  /// Legacy key: Add Spot
  ///
  /// In en, this message translates to:
  /// **'Add Spot'**
  String get spotsAddSpot7e93bac9;

  /// Legacy key: Add Test Spot
  ///
  /// In en, this message translates to:
  /// **'Add Test Spot'**
  String get spotsAddTestSpotd92ef505;

  /// Legacy key: Alle {0} Spots geladen.
  ///
  /// In en, this message translates to:
  /// **'All {arg0} spots loaded.'**
  String spotsAlleSpotsGeladen5c20251b(String arg0);

  /// Legacy key: Apply
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get spotsApplycfea419c;

  /// Legacy key: Categories / tags{0}
  ///
  /// In en, this message translates to:
  /// **'Categories / tags{arg0}'**
  String spotsCategoriesTags7627b3f2(String arg0);

  /// Legacy key: Category
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get spotsCategorya3c686e7;

  /// Legacy key: Category: {0}
  ///
  /// In en, this message translates to:
  /// **'Category: {arg0}'**
  String spotsCategorybe4f88dd(String arg0);

  /// Legacy key: Clear filters
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get spotsClearFilters41222671;

  /// Legacy key: Clear search
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get spotsClearSearch67300d0f;

  /// Legacy key: Database error: {0}
  ///
  /// In en, this message translates to:
  /// **'Database error: {arg0}'**
  String spotsDatabaseErrora227b5c8(String arg0);

  /// Legacy key: Delete failed: {0}
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {arg0}'**
  String spotsDeleteFailedfc2c6c69(String arg0);

  /// Legacy key: Delete spot?
  ///
  /// In en, this message translates to:
  /// **'Delete spot?'**
  String get spotsDeleteSpot17e145be;

  /// Legacy key: Description / notes (optional)
  ///
  /// In en, this message translates to:
  /// **'Description / notes (optional)'**
  String get spotsDescriptionNotesOptionalcfd33085;

  /// Legacy key: Driving route
  ///
  /// In en, this message translates to:
  /// **'Driving route'**
  String get spotsDrivingRoute9ffe00fc;

  /// Legacy key: Edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get spotsEdit5301648d;

  /// Legacy key: Edit Spot
  ///
  /// In en, this message translates to:
  /// **'Edit Spot'**
  String get spotsEditSpot082811c9;

  /// Legacy key: Latitude (WGS84)
  ///
  /// In en, this message translates to:
  /// **'Latitude (WGS84)'**
  String get spotsLatitudeWgs060b3235;

  /// Legacy key: Local Storage Test
  ///
  /// In en, this message translates to:
  /// **'Local Storage Test'**
  String get spotsLocalStorageTest1337323b;

  /// Legacy key: Locating…
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get spotsLocatinge46bab00;

  /// Legacy key: Longitude (WGS84)
  ///
  /// In en, this message translates to:
  /// **'Longitude (WGS84)'**
  String get spotsLongitudeWgs39118820;

  /// Legacy key: Matches the category and every selected tag. Search and favorites also apply.
  ///
  /// In en, this message translates to:
  /// **'Matches the category and every selected tag. Search and favorites also apply.'**
  String get spotsMatchesTheCategoryAnd2b0693e2;

  /// Legacy key: No description added.
  ///
  /// In en, this message translates to:
  /// **'No description added.'**
  String get spotsNoDescriptionAdded0dc3dae3;

  /// Legacy key: No photos yet. Edit this spot to add photos.
  ///
  /// In en, this message translates to:
  /// **'No photos yet. Edit this spot to add photos.'**
  String get spotsNoPhotosYetEdit1cb7ab6f;

  /// Legacy key: No spots found. Add a spot or adjust your filters.
  ///
  /// In en, this message translates to:
  /// **'No spots found. Add a spot or adjust your filters.'**
  String get spotsNoSpotsFoundAdd55a4157e;

  /// Legacy key: No spots saved yet.
  /// Add a test spot to verify persistence.
  ///
  /// In en, this message translates to:
  /// **'No spots saved yet.\nAdd a test spot to verify persistence.'**
  String get spotsNoSpotsSavedYet3b576669;

  /// Legacy key: Open spot photo
  ///
  /// In en, this message translates to:
  /// **'Open spot photo'**
  String get spotsOpenSpotPhoto9410015a;

  /// Legacy key: OpenStreetMap source: {0}
  ///
  /// In en, this message translates to:
  /// **'OpenStreetMap source: {arg0}'**
  String spotsOpenstreetmapSource9af4238e(String arg0);

  /// Legacy key: Optional · up to 40 characters
  ///
  /// In en, this message translates to:
  /// **'Optional · up to 40 characters'**
  String get spotsOptionalUpToCharactersbcc00326;

  /// Legacy key: Original OSM source reference is kept separately from personal edits.
  ///
  /// In en, this message translates to:
  /// **'Original OSM source reference is kept separately from personal edits.'**
  String get spotsOriginalOsmSourceReferenceebdb9f0a;

  /// Legacy key: Permanently delete "{0}" and its photos?
  ///
  /// In en, this message translates to:
  /// **'Permanently delete \"{arg0}\" and its photos?'**
  String spotsPermanentlyDeleteAndIts798ab781(String arg0);

  /// Legacy key: Photos: {0}
  ///
  /// In en, this message translates to:
  /// **'Photos: {arg0}'**
  String spotsPhotosa324a5d2(String arg0);

  /// Legacy key: Photos ({0}/{1})
  ///
  /// In en, this message translates to:
  /// **'Photos ({arg0}/{arg1})'**
  String spotsPhotosc4363ac9(String arg0, String arg1);

  /// Legacy key: Remove favorite
  ///
  /// In en, this message translates to:
  /// **'Remove favorite'**
  String get spotsRemoveFavorite8b9da771;

  /// Legacy key: Remove photo {0}
  ///
  /// In en, this message translates to:
  /// **'Remove photo {arg0}'**
  String spotsRemovePhoto67e118ac(String arg0);

  /// Legacy key: Retry loading photos
  ///
  /// In en, this message translates to:
  /// **'Retry loading photos'**
  String get spotsRetryLoadingPhotos2e5d214a;

  /// Legacy key: Saved spot photo
  ///
  /// In en, this message translates to:
  /// **'Saved spot photo'**
  String get spotsSavedSpotPhoto279ddf6a;

  /// Legacy key: Search spots
  ///
  /// In en, this message translates to:
  /// **'Search spots'**
  String get spotsSearchSpotsd3145737;

  /// Legacy key: Show on map
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get spotsShowOnMap5ed4f4c1;

  /// Legacy key: Spot details
  ///
  /// In en, this message translates to:
  /// **'Spot details'**
  String get spotsSpotDetailse32d6442;

  /// Legacy key: Spot name
  ///
  /// In en, this message translates to:
  /// **'Spot name'**
  String get spotsSpotName811bf0db;

  /// Legacy key: Spot photo
  ///
  /// In en, this message translates to:
  /// **'Spot photo'**
  String get spotsSpotPhoto590ebf66;

  /// Legacy key: This photo is no longer available.
  ///
  /// In en, this message translates to:
  /// **'This photo is no longer available.'**
  String get spotsThisPhotoIsNo08b26948;

  /// Legacy key: This spot no longer exists.
  ///
  /// In en, this message translates to:
  /// **'This spot no longer exists.'**
  String get spotsThisSpotNoLongeraffbf566;

  /// Legacy key: Unable to display this photo.
  ///
  /// In en, this message translates to:
  /// **'Unable to display this photo.'**
  String get spotsUnableToDisplayThis38f897ec;

  /// Legacy key: Unable to load photos. Close this window and try again.
  ///
  /// In en, this message translates to:
  /// **'Unable to load photos. Close this window and try again.'**
  String get spotsUnableToLoadPhotos634c2fc3;

  /// Legacy key: Unable to load spot details.
  ///
  /// In en, this message translates to:
  /// **'Unable to load spot details.'**
  String get spotsUnableToLoadSpot827d0e55;

  /// Legacy key: Unable to load this photo.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this photo.'**
  String get spotsUnableToLoadThisc9e4faa4;

  /// Legacy key: Unable to update favorite. Please retry.
  ///
  /// In en, this message translates to:
  /// **'Unable to update favorite. Please retry.'**
  String get spotsUnableToUpdateFavorite3001cf8d;

  /// Legacy key: Use current location
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get spotsUseCurrentLocation622c745f;

  /// Legacy key: Weitere Spots werden beim Scrollen geladen.
  ///
  /// In en, this message translates to:
  /// **'More spots are loaded while scrolling.'**
  String get spotsWeitereSpotsWerdenBeim1f25ff94;

  /// Legacy key: Apply route calibration?
  ///
  /// In en, this message translates to:
  /// **'Apply route calibration?'**
  String get telemetryApplyRouteCalibration5c654485;

  /// Legacy key: Apply to this route
  ///
  /// In en, this message translates to:
  /// **'Apply to this route'**
  String get telemetryApplyToThisRoute1635cca9;

  /// Legacy key: Approximation for a still-air recording only
  ///
  /// In en, this message translates to:
  /// **'Approximation for a still-air recording only'**
  String get telemetryApproximationForAStill90100705;

  /// Legacy key: Delete local telemetry
  ///
  /// In en, this message translates to:
  /// **'Delete local telemetry'**
  String get telemetryDeleteLocalTelemetryfa6452e1;

  /// Legacy key: Delete raw telemetry?
  ///
  /// In en, this message translates to:
  /// **'Delete raw telemetry?'**
  String get telemetryDeleteRawTelemetryad6e4046;

  /// Legacy key: Different drones are associated with the log and route. Calibration is disabled.
  ///
  /// In en, this message translates to:
  /// **'Different drones are associated with the log and route. Calibration is disabled.'**
  String get telemetryDifferentDronesAreAssociated17ab6eae;

  /// Legacy key: Duration includes all recorded idle/hover time. Trim the log to one flight before importing.
  ///
  /// In en, this message translates to:
  /// **'Duration includes all recorded idle/hover time. Trim the log to one flight before importing.'**
  String get telemetryDurationIncludesAllRecordedb1545492;

  /// Legacy key: Flight plan for comparison
  ///
  /// In en, this message translates to:
  /// **'Flight plan for comparison'**
  String get telemetryFlightPlanForComparison6e3eb9d5;

  /// Legacy key: Import one continuous flight. Raw CSV stays in the local database. No telemetry is uploaded.
  ///
  /// In en, this message translates to:
  /// **'Import one continuous flight. Raw CSV stays in the local database. No telemetry is uploaded.'**
  String get telemetryImportOneContinuousFlight94f89be2;

  /// Legacy key: Import telemetry CSV
  ///
  /// In en, this message translates to:
  /// **'Import telemetry CSV'**
  String get telemetryImportTelemetryCsveb2d1023;

  /// Legacy key: Import telemetry locally?
  ///
  /// In en, this message translates to:
  /// **'Import telemetry locally?'**
  String get telemetryImportTelemetryLocallyf7626443;

  /// Legacy key: Imported {0}
  ///
  /// In en, this message translates to:
  /// **'Imported {arg0}'**
  String telemetryImportedbd3c3768(String arg0);

  /// Legacy key: Local telemetry unavailable. Reopen this screen to retry.
  ///
  /// In en, this message translates to:
  /// **'Local telemetry unavailable. Reopen this screen to retry.'**
  String get telemetryLocalTelemetryUnavailableReopencb8a0598;

  /// Legacy key: Measured energy: {0} Wh · average power {1} W
  ///
  /// In en, this message translates to:
  /// **'Measured energy: {arg0} Wh · average power {arg1} W'**
  String telemetryMeasuredEnergyWhAverage9acf6860(String arg0, String arg1);

  /// Legacy key: Measured − modeled: {0} Wh ({1}%)
  ///
  /// In en, this message translates to:
  /// **'Measured − modeled: {arg0} Wh ({arg1}%)'**
  String telemetryMeasuredModeledWhae99a8d2(String arg0, String arg1);

  /// Legacy key: Model comparison
  ///
  /// In en, this message translates to:
  /// **'Model comparison'**
  String get telemetryModelComparisondaa80a44;

  /// Legacy key: Model energy over recorded speeds: {0} Wh
  ///
  /// In en, this message translates to:
  /// **'Model energy over recorded speeds: {arg0} Wh'**
  String telemetryModelEnergyOverRecorded6bf1955f(String arg0);

  /// Legacy key: No associated flight plan is available. Associate a plan when importing to compare its model.
  ///
  /// In en, this message translates to:
  /// **'No associated flight plan is available. Associate a plan when importing to compare its model.'**
  String get telemetryNoAssociatedFlightPlan5a0a6161;

  /// Legacy key: Preview & apply calibration
  ///
  /// In en, this message translates to:
  /// **'Preview & apply calibration'**
  String get telemetryPreviewApplyCalibrationa8b7db04;

  /// Legacy key: Recorded duration: {0} s
  ///
  /// In en, this message translates to:
  /// **'Recorded duration: {arg0} s'**
  String telemetryRecordedDurationSe198ddeb(String arg0);

  /// Legacy key: Route comparison unavailable. Check the saved route inputs.
  ///
  /// In en, this message translates to:
  /// **'Route comparison unavailable. Check the saved route inputs.'**
  String get telemetryRouteComparisonUnavailableCheck13192917;

  /// Legacy key: Route comparisons assume the recording covers the same outbound path. Return flights and idle time are not automatically removed.
  ///
  /// In en, this message translates to:
  /// **'Route comparisons assume the recording covers the same outbound path. Return flights and idle time are not automatically removed.'**
  String get telemetryRouteComparisonsAssumeThed64d19cc;

  /// Legacy key: {0} · {1} samples
  ///
  /// In en, this message translates to:
  /// **'{arg0} · {arg1} samples'**
  String telemetrySamples49577d36(String arg0, String arg1);

  /// Legacy key: Saved outbound route duration: {0}
  ///
  /// In en, this message translates to:
  /// **'Saved outbound route duration: {arg0}'**
  String telemetrySavedOutboundRouteDuration18b87ca4(String arg0);

  /// Legacy key: Saved outbound route mean {0} speed: {1}
  ///
  /// In en, this message translates to:
  /// **'Saved outbound route mean {arg0} speed: {arg1}'**
  String telemetrySavedOutboundRouteMean0818ac58(String arg0, String arg1);

  /// Legacy key: Supported formats
  ///
  /// In en, this message translates to:
  /// **'Supported formats'**
  String get telemetrySupportedFormatsdf1bdc5f;

  /// Legacy key: Telemetry: {0}
  ///
  /// In en, this message translates to:
  /// **'Telemetry: {arg0}'**
  String telemetryTelemetry9ac39ce5(String arg0);

  /// Legacy key: The route power curve is evaluated at every recorded speed with its mass correction. Energy uses trapezoidal integration of voltage × current. No climb or maneuver correction is inferred.
  ///
  /// In en, this message translates to:
  /// **'The route power curve is evaluated at every recorded speed with its mass correction. Energy uses trapezoidal integration of voltage × current. No climb or maneuver correction is inferred.'**
  String get telemetryTheRoutePowerCurvee9b27f2a;

  /// Legacy key: Unassigned
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get telemetryUnassignede57016ed;

  /// Legacy key: Use ground speed as airspeed
  ///
  /// In en, this message translates to:
  /// **'Use ground speed as airspeed'**
  String get telemetryUseGroundSpeedAs5bb04e27;

  /// Legacy key: Abgelaufen: Pfeile und Windeinfluss sind ausgesetzt.
  ///
  /// In en, this message translates to:
  /// **'Expired: Arrows and wind influence are exposed.'**
  String get weatherAbgelaufenPfeileUndWindeinfluss1572fe42;

  /// Legacy key: Abgerufen: {0} · {1}/9 Rasterpunkte
  ///
  /// In en, this message translates to:
  /// **'Retrieved: {arg0} · {arg1}/9 Grid points'**
  String weatherAbgerufenRasterpunkte7532c53d(String arg0, String arg1);

  /// Legacy key: Active forecast provider
  ///
  /// In en, this message translates to:
  /// **'Active forecast provider'**
  String get weatherActiveForecastProvider589a3851;

  /// Legacy key: Aktueller Modellwind
  ///
  /// In en, this message translates to:
  /// **'Current model wind'**
  String get weatherAktuellerModellwind402bf323;

  /// Legacy key: All comparison results use the selected provider and identical flight time and criteria; missing data never yields a positive result.
  ///
  /// In en, this message translates to:
  /// **'All comparison results use the selected provider and identical flight time and criteria; missing data never yields a positive result.'**
  String get weatherAllComparisonResultsUse418051c7;

  /// Legacy key: Angle/Acro: Abdrift. GPS: Gegenhalten bis zur Leistungsgrenze.
  ///
  /// In en, this message translates to:
  /// **'Angle/Acro: Drift. GPS: Restraint to power limit.'**
  String get weatherAngleAcroAbdriftGps88b761bf;

  /// Legacy key: Ausschnitt um den gewählten Punkt
  ///
  /// In en, this message translates to:
  /// **'Section around the selected point'**
  String get weatherAusschnittUmDenGewaehlten25af0329;

  /// Legacy key: Automatic observations (from 2023) and historical manual measurements are separate methods. Historical/manual series are not loaded here.
  ///
  /// In en, this message translates to:
  /// **'Automatic observations (from 2023) and historical manual measurements are separate methods. Historical/manual series are not loaded here.'**
  String get weatherAutomaticObservationsFromAnda1a45d31;

  /// Legacy key: Choose a saved flying spot or a globe coordinate to inspect nearby monitoring stations.
  ///
  /// In en, this message translates to:
  /// **'Choose a saved flying spot or a globe coordinate to inspect nearby monitoring stations.'**
  String get weatherChooseASavedFlyingba7ecae9;

  /// Legacy key: Clear radar
  ///
  /// In en, this message translates to:
  /// **'Clear radar'**
  String get weatherClearRadar66544d4d;

  /// Legacy key: Compare saved spots
  ///
  /// In en, this message translates to:
  /// **'Compare saved spots'**
  String get weatherCompareSavedSpotsc7ce5e7e;

  /// Legacy key: 3D-Pfeile aktiv
  ///
  /// In en, this message translates to:
  /// **'Active 3D arrows'**
  String get weatherDPfeileAktivbfcd3c26;

  /// Legacy key: 3D-Wind und Flugwind
  ///
  /// In en, this message translates to:
  /// **'3D wind and flying wind'**
  String get weatherDWindUndFlugwinda2d72644;

  /// Legacy key: 3D-Wind und Prognose
  ///
  /// In en, this message translates to:
  /// **'3D wind and forecast'**
  String get weatherDWindUndPrognose6efb0829;

  /// Legacy key: 3D-Windpfeile anzeigen
  ///
  /// In en, this message translates to:
  /// **'Show 3D Wind Arrows'**
  String get weatherDWindpfeileAnzeigenbc5f17dc;

  /// Legacy key: Data state: {0}{1}{2}
  ///
  /// In en, this message translates to:
  /// **'Data state: {arg0}{arg1}{arg2}'**
  String weatherDataState98888b0e(String arg0, String arg1, String arg2);

  /// Legacy key: Daten und Grenzen
  ///
  /// In en, this message translates to:
  /// **'Data and borders'**
  String get weatherDatenUndGrenzen98079772;

  /// Legacy key: Diesen Ausschnitt aktualisieren
  ///
  /// In en, this message translates to:
  /// **'Update this section'**
  String get weatherDiesenAusschnittAktualisierenf0435deb;

  /// Legacy key: Dieses Raster ausblenden
  ///
  /// In en, this message translates to:
  /// **'Hide this grid'**
  String get weatherDiesesRasterAusblendenc09fe0a2;

  /// Legacy key: Direction {0}
  ///
  /// In en, this message translates to:
  /// **'Direction {arg0}'**
  String weatherDirection2373dfc9(String arg0);

  /// Legacy key: Discover published radar times
  ///
  /// In en, this message translates to:
  /// **'Discover published radar times'**
  String get weatherDiscoverPublishedRadarTimes9528700a;

  /// Legacy key: Downloaded: {0} UTC
  ///
  /// In en, this message translates to:
  /// **'Downloaded: {arg0} UTC'**
  String weatherDownloadedUtc177de02a(String arg0);

  /// Legacy key: Drone profile (user thresholds)
  ///
  /// In en, this message translates to:
  /// **'Drone profile (user thresholds)'**
  String get weatherDroneProfileUserThresholdsf3e5ce7b;

  /// Legacy key: Evaluate saved spots
  ///
  /// In en, this message translates to:
  /// **'Evaluate saved spots'**
  String get weatherEvaluateSavedSpotsbdd72b2d;

  /// Legacy key: Find monitoring stations
  ///
  /// In en, this message translates to:
  /// **'Find monitoring stations'**
  String get weatherFindMonitoringStations4d511534;

  /// Legacy key: Forecast issue time: not supplied by provider
  ///
  /// In en, this message translates to:
  /// **'Forecast issue time: not supplied by provider'**
  String get weatherForecastIssueTimeNot72c0daa9;

  /// Legacy key: Forecast issued: {0}
  ///
  /// In en, this message translates to:
  /// **'Forecast issued: {arg0}'**
  String weatherForecastIssued2ab834ac(String arg0);

  /// Legacy key: FPV suitability thresholds
  ///
  /// In en, this message translates to:
  /// **'FPV suitability thresholds'**
  String get weatherFpvSuitabilityThresholdsd468f61f;

  /// Legacy key: Gemessene Wetter- und Gewässerstationen
  ///
  /// In en, this message translates to:
  /// **'Measured weather and water stations'**
  String get weatherGemesseneWetterUndGewaesserstationen70b38f8d;

  /// Legacy key: Hourly precipitation refers to the preceding hour ending at the forecast timestamp.
  ///
  /// In en, this message translates to:
  /// **'Hourly precipitation refers to the preceding hour ending at the forecast timestamp.'**
  String get weatherHourlyPrecipitationRefersTob7611db2;

  /// Legacy key: {0} independent Open-Meteo samples shown on globe.
  ///
  /// In en, this message translates to:
  /// **'{arg0} independent Open-Meteo samples shown on globe.'**
  String weatherIndependentOpenMeteoSamples4c5f32a2(String arg0);

  /// Legacy key: Inspect hourly observation (UTC)
  ///
  /// In en, this message translates to:
  /// **'Inspect hourly observation (UTC)'**
  String get weatherInspectHourlyObservationUtcae90e45a;

  /// Legacy key: Inspect local terrain
  ///
  /// In en, this message translates to:
  /// **'Inspect local terrain'**
  String get weatherInspectLocalTerrainc851b2af;

  /// Legacy key: Kartenebene konnte nicht aktualisiert werden. Bitte erneut versuchen.
  ///
  /// In en, this message translates to:
  /// **'Could not update map level. Please try again.'**
  String get weatherKartenebeneKonnteNichtAktualisiertab47fc9e;

  /// Legacy key: 1 km local
  ///
  /// In en, this message translates to:
  /// **'1 km local'**
  String get weatherKmLocal5e8c161b;

  /// Legacy key: Latest station observation: {0} · {1} · hourly average
  ///
  /// In en, this message translates to:
  /// **'Latest station observation: {arg0} · {arg1} · hourly average'**
  String weatherLatestStationObservationHourly1d766dcb(
    String arg0,
    String arg1,
  );

  /// Legacy key: Letzte Aktualisierung fehlgeschlagen. Die vorherigen Daten bleiben bis zum Ablauf verfügbar.
  ///
  /// In en, this message translates to:
  /// **'Last update failed. The previous data will remain available until expiry.'**
  String get weatherLetzteAktualisierungFehlgeschlagenDie140dfc53;

  /// Legacy key: Load hourly observations
  ///
  /// In en, this message translates to:
  /// **'Load hourly observations'**
  String get weatherLoadHourlyObservations7bc23c4c;

  /// Legacy key: Local terrain exposure
  ///
  /// In en, this message translates to:
  /// **'Local terrain exposure'**
  String get weatherLocalTerrainExposuref78de89b;

  /// Legacy key: Location: {0}{1}
  ///
  /// In en, this message translates to:
  /// **'Location: {arg0}{arg1}'**
  String weatherLocation77d72845(String arg0, String arg1);

  /// Legacy key: MeteoSwiss E4 does not provide this parameter.
  ///
  /// In en, this message translates to:
  /// **'MeteoSwiss E4 does not provide this parameter.'**
  String get weatherMeteoswissEDoesNota574859d;

  /// Legacy key: MeteoSwiss station details
  ///
  /// In en, this message translates to:
  /// **'MeteoSwiss station details'**
  String get weatherMeteoswissStationDetails565885c8;

  /// Legacy key: Native model resolution: not supplied by this API response. The selected spacing only sets the display sample grid.
  ///
  /// In en, this message translates to:
  /// **'Native model resolution: not supplied by this API response. The selected spacing only sets the display sample grid.'**
  String get weatherNativeModelResolutionNot32f4a5e7;

  /// Legacy key: Nearby relief {0} m from {1} terrain samples. {2}
  ///
  /// In en, this message translates to:
  /// **'Nearby relief {arg0} m from {arg1} terrain samples. {arg2}'**
  String weatherNearbyReliefMFrom3afbc3bf(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: Nearest monitoring station
  ///
  /// In en, this message translates to:
  /// **'Nearest monitoring station'**
  String get weatherNearestMonitoringStationb112be37;

  /// Legacy key: Niederschlag {0}
  ///
  /// In en, this message translates to:
  /// **'Precipitation {arg0}'**
  String weatherNiederschlagf18088c2(String arg0);

  /// Legacy key: No drone profiles saved; configure generic thresholds below.
  ///
  /// In en, this message translates to:
  /// **'No drone profiles saved; configure generic thresholds below.'**
  String get weatherNoDroneProfilesSaved1b2919fa;

  /// Legacy key: No official severity classes are inferred. Missing is not zero. Readings describe the monitoring station only.
  ///
  /// In en, this message translates to:
  /// **'No official severity classes are inferred. Missing is not zero. Readings describe the monitoring station only.'**
  String get weatherNoOfficialSeverityClasses2d4def34;

  /// Legacy key: No published quality flag for this frame (quality unknown).
  ///
  /// In en, this message translates to:
  /// **'No published quality flag for this frame (quality unknown).'**
  String get weatherNoPublishedQualityFlag88577e1e;

  /// Legacy key: No saved spot selected. Select a point on the globe or save a spot.
  ///
  /// In en, this message translates to:
  /// **'No saved spot selected. Select a point on the globe or save a spot.'**
  String get weatherNoSavedSpotSelected8861bd5c;

  /// Legacy key: No valid automatic observations published in this file.
  ///
  /// In en, this message translates to:
  /// **'No valid automatic observations published in this file.'**
  String get weatherNoValidAutomaticObservationse3251aaa;

  /// Legacy key: Observed: {0} · {1}
  ///
  /// In en, this message translates to:
  /// **'Observed: {arg0} · {arg1}'**
  String weatherObserved6b54f9ec(String arg0, String arg1);

  /// Legacy key: Official airspace verification
  ///
  /// In en, this message translates to:
  /// **'Official airspace verification'**
  String get weatherOfficialAirspaceVerification1376fb67;

  /// Legacy key: Official MeteoSwiss files are large; comparison is limited to 3 spots per request to reduce traffic.
  ///
  /// In en, this message translates to:
  /// **'Official MeteoSwiss files are large; comparison is limited to 3 spots per request to reduce traffic.'**
  String get weatherOfficialMeteoswissFilesAre0450722a;

  /// Legacy key: Official MeteoSwiss pollen stations
  ///
  /// In en, this message translates to:
  /// **'Official MeteoSwiss pollen stations'**
  String get weatherOfficialMeteoswissPollenStations0d04b249;

  /// Legacy key: Official MeteoSwiss precipitation radar
  ///
  /// In en, this message translates to:
  /// **'Official MeteoSwiss precipitation radar'**
  String get weatherOfficialMeteoswissPrecipitationRadar58cad390;

  /// Legacy key: Optional Cesium relief check within 300 m (centre and four neighbours). Not an aerodynamic turbulence model.
  ///
  /// In en, this message translates to:
  /// **'Optional Cesium relief check within 300 m (centre and four neighbours). Not an aerodynamic turbulence model.'**
  String get weatherOptionalCesiumReliefCheckff9531d9;

  /// Legacy key: Optional · Winddaten noch nicht geladen
  ///
  /// In en, this message translates to:
  /// **'Optional · Wind data not yet loaded'**
  String get weatherOptionalWinddatenNochNicht638f2548;

  /// Legacy key: Planned flight time (local)
  ///
  /// In en, this message translates to:
  /// **'Planned flight time (local)'**
  String get weatherPlannedFlightTimeLocal410bf657;

  /// Legacy key: Play forward
  ///
  /// In en, this message translates to:
  /// **'Play forward'**
  String get weatherPlayForward4b395db1;

  /// Legacy key: Prognose: {0}
  /// Abgerufen: {1} · {2} fehlende Stichproben
  ///
  /// In en, this message translates to:
  /// **'Forecast: {arg0} Retrieved: {arg1} · {arg2} missing samples'**
  String weatherPrognoseAbgerufenFehlendeStichproben23fbbb89(
    String arg0,
    String arg1,
    String arg2,
  );

  /// Legacy key: Provider terms / data source
  ///
  /// In en, this message translates to:
  /// **'Provider terms / data source'**
  String get weatherProviderTermsDataSource3870b023;

  /// Legacy key: Published CPC quality flag: {0}/9
  ///
  /// In en, this message translates to:
  /// **'Published CPC quality flag: {arg0}/9'**
  String weatherPublishedCpcQualityFlagdf44398e(String arg0);

  /// Legacy key: {0} published frames (maximum 12). Irregular timestamp gaps are retained.
  ///
  /// In en, this message translates to:
  /// **'{arg0} published frames (maximum 12). Irregular timestamp gaps are retained.'**
  String weatherPublishedFramesMaximumIrregular94a6ff40(String arg0);

  /// Legacy key: Radar product
  ///
  /// In en, this message translates to:
  /// **'Radar product'**
  String get weatherRadarProducte1ab732e;

  /// Legacy key: Raster abgelaufen · auf der Karte ausgeblendet
  ///
  /// In en, this message translates to:
  /// **'Grid expired · hidden on the map'**
  String get weatherRasterAbgelaufenAufDer98608088;

  /// Legacy key: Refresh forecast
  ///
  /// In en, this message translates to:
  /// **'Refresh forecast'**
  String get weatherRefreshForecastfe3dbc62;

  /// Legacy key: Refresh station metadata
  ///
  /// In en, this message translates to:
  /// **'Refresh station metadata'**
  String get weatherRefreshStationMetadataa5976bc4;

  /// Legacy key: Require visibility forecast
  ///
  /// In en, this message translates to:
  /// **'Require visibility forecast'**
  String get weatherRequireVisibilityForecastc232c2a0;

  /// Legacy key: Resolution: {0}
  ///
  /// In en, this message translates to:
  /// **'Resolution: {arg0}'**
  String weatherResolutiona39d34b8(String arg0);

  /// Legacy key: Saved flying spot
  ///
  /// In en, this message translates to:
  /// **'Saved flying spot'**
  String get weatherSavedFlyingSpotedf5fa9d;

  /// Legacy key: Selected observation: {0}
  ///
  /// In en, this message translates to:
  /// **'Selected observation: {arg0}'**
  String weatherSelectedObservation26593d3f(String arg0);

  /// Legacy key: Show on globe
  ///
  /// In en, this message translates to:
  /// **'Show on globe'**
  String get weatherShowOnGlobe8ee06550;

  /// Legacy key: Show selected frame
  ///
  /// In en, this message translates to:
  /// **'Show selected frame'**
  String get weatherShowSelectedFrame26955c78;

  /// Legacy key: Source: MeteoSwiss · FSDI STAC · online HDF5/WASM · EPSG:2056. Radar can be unavailable on Web or Android if data or decoder access is blocked.
  ///
  /// In en, this message translates to:
  /// **'Source: MeteoSwiss · FSDI STAC · online HDF5/WASM · EPSG:2056. Radar can be unavailable on Web or Android if data or decoder access is blocked.'**
  String get weatherSourceMeteoswissFsdiStacb55f0dac;

  /// Legacy key: Source publication time: not provided
  ///
  /// In en, this message translates to:
  /// **'Source publication time: not provided'**
  String get weatherSourcePublicationTimeNot23697f29;

  /// Legacy key: Source STAC updated: {0}
  ///
  /// In en, this message translates to:
  /// **'Source STAC updated: {arg0}'**
  String weatherSourceStacUpdateddde9e800(String arg0);

  /// Legacy key: STAC updated: {0}
  ///
  /// In en, this message translates to:
  /// **'STAC updated: {arg0}'**
  String weatherStacUpdated73855d9d(String arg0);

  /// Legacy key: Station directory: cached; last metadata refresh failed (original publication time unavailable).
  ///
  /// In en, this message translates to:
  /// **'Station directory: cached; last metadata refresh failed (original publication time unavailable).'**
  String get weatherStationDirectoryCachedLastf07e00ef;

  /// Legacy key: Station directory: locally cached (original publication time unavailable).
  ///
  /// In en, this message translates to:
  /// **'Station directory: locally cached (original publication time unavailable).'**
  String get weatherStationDirectoryLocallyCached005bbea0;

  /// Legacy key: Station directory: retrieved {0}
  ///
  /// In en, this message translates to:
  /// **'Station directory: retrieved {arg0}'**
  String weatherStationDirectoryRetrieved72729476(String arg0);

  /// Legacy key: {0}
  /// {1}
  /// {2}
  /// {3} · Terrain and legal airspace not assessed.
  ///
  /// In en, this message translates to:
  /// **'{arg0}\n{arg1}\n{arg2}\n{arg3} · Terrain and legal airspace not assessed.'**
  String weatherTerrainAndLegalAirspacedb03e335(
    String arg0,
    String arg1,
    String arg2,
    String arg3,
  );

  /// Legacy key: Unsupported source parameters not classified: {0}
  ///
  /// In en, this message translates to:
  /// **'Unsupported source parameters not classified: {arg0}'**
  String weatherUnsupportedSourceParametersNot75db504a(String arg0);

  /// Legacy key: Visibility {0}
  ///
  /// In en, this message translates to:
  /// **'Visibility {arg0}'**
  String weatherVisibility1b929d6e(String arg0);

  /// Legacy key: Weather & FPV suitability
  ///
  /// In en, this message translates to:
  /// **'Weather & FPV suitability'**
  String get weatherWeatherFpvSuitabilitye893355f;

  /// Legacy key: Weather map (Open-Meteo sample grid)
  ///
  /// In en, this message translates to:
  /// **'Weather map (Open-Meteo sample grid)'**
  String get weatherWeatherMapOpenMeteodb0c967f;

  /// Legacy key: Weather overlay unavailable: {0}
  ///
  /// In en, this message translates to:
  /// **'Weather overlay unavailable: {arg0}'**
  String weatherWeatherOverlayUnavailablef9e466e1(String arg0);

  /// Legacy key: Weather preferences could not be saved
  ///
  /// In en, this message translates to:
  /// **'Weather preferences could not be saved'**
  String get weatherWeatherPreferencesCouldNot1aa91b1b;

  /// Legacy key: Wind beeinflusst den Simulator
  ///
  /// In en, this message translates to:
  /// **'Wind affects the simulator'**
  String get weatherWindBeeinflusstDenSimulator0792a00b;

  /// Legacy key: Wind im Flug
  ///
  /// In en, this message translates to:
  /// **'Wind in flight'**
  String get weatherWindImFlugeffc2149;

  /// Legacy key: Wind im Flugsimulator berücksichtigen
  ///
  /// In en, this message translates to:
  /// **'Take wind into account in flight simulator'**
  String get weatherWindImFlugsimulatorBeruecksichtigen2a47223c;

  /// Legacy key: Winddarstellung und Einfluss aus
  ///
  /// In en, this message translates to:
  /// **'Wind display and influence from'**
  String get weatherWinddarstellungUndEinflussAus5d5ce187;

  /// Legacy key: Winddaten abgelaufen
  ///
  /// In en, this message translates to:
  /// **'Wind data expired'**
  String get weatherWinddatenAbgelaufend96548ce;

  /// Legacy key: Winddaten für Punkt / Ansicht laden
  ///
  /// In en, this message translates to:
  /// **'Load wind data for point / view'**
  String get weatherWinddatenFuerPunktAnsichtfa5e2d66;

  /// Legacy key: Windpfeile warten auf geladenes 3D-Gelände.
  ///
  /// In en, this message translates to:
  /// **'Wind arrows are waiting for loaded 3D terrain.'**
  String get weatherWindpfeileWartenAufGeladenes9bd078a7;

  /// Legacy key: Windquelle / Zeit
  ///
  /// In en, this message translates to:
  /// **'Wind source / time'**
  String get weatherWindquelleZeitfc844a65;

  /// Legacy key: Zusätzliches Prognoseraster
  ///
  /// In en, this message translates to:
  /// **'Additional forecast grid'**
  String get weatherZusaetzlichesPrognoseraster279c3ee9;

  /// Pluralized number of saved routes for future route summaries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No saved routes} =1{One saved route} other{{count} saved routes}}'**
  String commonSavedRouteCount(int count);

  /// Locale-aware date formatting in optional status labels.
  ///
  /// In en, this message translates to:
  /// **'Updated on {date}'**
  String commonUpdatedOn(DateTime date);

  /// Live simulation ground station setting.
  ///
  /// In en, this message translates to:
  /// **'Show ground station marker'**
  String get signalShowGroundStationMarker;

  /// Live simulation ground station setting.
  ///
  /// In en, this message translates to:
  /// **'Show live line of sight'**
  String get signalShowLiveSignalPath;

  /// Live simulation ground station setting.
  ///
  /// In en, this message translates to:
  /// **'Reset to takeoff position'**
  String get signalUseTakeoffAsGroundStation;

  /// Live simulation ground station setting.
  ///
  /// In en, this message translates to:
  /// **'Select a point on the 3D map, then reopen this panel and choose “Selected map point”.'**
  String get signalChooseGroundStationFromMap;

  /// Simulation signal HUD settings (issue #128).
  ///
  /// In en, this message translates to:
  /// **'DJI: bottom-edge signal warning'**
  String get signalHudDjiWarning;

  /// Simulation signal HUD settings (issue #128).
  ///
  /// In en, this message translates to:
  /// **'Betaflight: signal bars'**
  String get signalHudBetaflightBars;

  /// Simulation signal HUD settings (issue #128).
  ///
  /// In en, this message translates to:
  /// **'Betaflight: analog video interference'**
  String get signalHudAnalogNoise;

  /// Simulation signal HUD settings (issue #128).
  ///
  /// In en, this message translates to:
  /// **'Visualize terrain risk as video interference'**
  String get signalHudTerrainIllustration;

  /// Simulation signal HUD settings (issue #128).
  ///
  /// In en, this message translates to:
  /// **'Illustration only, not an RF measurement. RC quality remains unknown.'**
  String get signalHudTerrainDisclaimer;

  /// Simulation signal HUD settings (issue #128).
  ///
  /// In en, this message translates to:
  /// **'Analog noise intensity'**
  String get signalHudIntensity;

  /// Simulation signal HUD settings (issue #128).
  ///
  /// In en, this message translates to:
  /// **'Weak signal threshold'**
  String get signalHudWeakThreshold;

  /// Simulation signal HUD settings (issue #128).
  ///
  /// In en, this message translates to:
  /// **'Critical signal threshold'**
  String get signalHudCriticalThreshold;

  /// Simulation signal HUD settings (issue #128).
  ///
  /// In en, this message translates to:
  /// **'Signal loss threshold'**
  String get signalHudLostThreshold;
}

class _FpvStringsDelegate extends LocalizationsDelegate<FpvStrings> {
  const _FpvStringsDelegate();

  @override
  Future<FpvStrings> load(Locale locale) {
    return SynchronousFuture<FpvStrings>(lookupFpvStrings(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_FpvStringsDelegate old) => false;
}

FpvStrings lookupFpvStrings(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return FpvStringsDe();
    case 'en':
      return FpvStringsEn();
  }

  throw FlutterError(
    'FpvStrings.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
