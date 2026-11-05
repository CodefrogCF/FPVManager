// Enables bounded, non-modal globe overlays only in a running Windows app.
// Browser builds and Flutter's widget-test runner retain existing semantics.
export 'desktop_globe_interaction_mode_web.dart'
    if (dart.library.io) 'desktop_globe_interaction_mode_io.dart';
