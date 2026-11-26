/// Internal menu controls are hidden from ordinary user builds.
///
/// Developers can explicitly enable them for private test builds with:
/// `--dart-define=FPV_DEVELOPER_MENUS=true`
/// This is only the initial preference for fresh installations. Users may
/// override it in Settings. This changes presentation only; no renderer, terrain, simulation or
/// diagnostic API is disabled by this flag.
const bool kDeveloperMenusEnabled = bool.fromEnvironment(
  'FPV_DEVELOPER_MENUS',
  defaultValue: false,
);
