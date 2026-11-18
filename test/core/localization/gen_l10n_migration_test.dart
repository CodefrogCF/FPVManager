import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpvmanager/core/localization/app_localizations.dart';
import 'package:fpvmanager/core/localization/generated/fpv_strings.dart';
import 'package:fpvmanager/core/localization/generated/fpv_strings_de.dart';
import 'package:fpvmanager/core/localization/generated/fpv_strings_en.dart';

void main() {
  test(
    'generated catalogs preserve both languages and positional messages',
    () {
      expect(
        AppLocalizations.message(AppLanguage.german, 'Spawn here', const []),
        'Hier starten',
      );
      expect(
        AppLocalizations.message(AppLanguage.english, 'Spawn here', const []),
        'Spawn here',
      );
      expect(
        AppLocalizations.message(
          AppLanguage.german,
          'Average airspeed: {0} m/s · maximum {1} m/s',
          const ['10', '20'],
        ),
        'Mittlere Fluggeschwindigkeit: 10 m/s · maximal 20 m/s',
      );
      expect(
        AppLocalizations.message(AppLanguage.german, 'Not a catalog key', []),
        'Not a catalog key',
      );
    },
  );

  test('generated ICU plurals work in English and German', () {
    final en = FpvStringsEn();
    final de = FpvStringsDe();
    expect(en.commonSavedRouteCount(0), 'No saved routes');
    expect(en.commonSavedRouteCount(1), 'One saved route');
    expect(en.commonSavedRouteCount(3), '3 saved routes');
    expect(de.commonSavedRouteCount(0), 'Keine gespeicherten Routen');
    expect(de.commonSavedRouteCount(1), 'Eine gespeicherte Route');
    expect(de.commonSavedRouteCount(3), '3 gespeicherte Routen');
  });

  testWidgets('changing locale updates typed and parameterized UI strings', (
    tester,
  ) async {
    final locale = ValueNotifier(const Locale('de'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (context, current, _) => MaterialApp(
          locale: current,
          supportedLocales: FpvStrings.supportedLocales,
          localizationsDelegates: FpvStrings.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  Text(
                    context.localized(
                      'Save',
                      (l10n) => l10n.commonSaveefc007a3,
                    ),
                  ),
                  Text(
                    context.localizedWithArgs(
                      'Average airspeed: {0} m/s · maximum {1} m/s',
                      const ['10', '20'],
                      (l10n, value) => l10n.commonAverageAirspeedMS071139b2(
                        value(0),
                        value(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Speichern'), findsOneWidget);
    expect(
      find.text('Mittlere Fluggeschwindigkeit: 10 m/s · maximal 20 m/s'),
      findsOneWidget,
    );

    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);
    expect(
      find.text('Average airspeed: 10 m/s · maximum 20 m/s'),
      findsOneWidget,
    );
  });

  testWidgets('unlocalized host keeps original source labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              Text(
                context.localized(
                  'Geschätzte Akkuspannung anzeigen',
                  (l10n) =>
                      l10n.simulationGeschaetzteAkkuspannungAnzeigen3fc4417b,
                ),
              ),
              Text(
                context.localizedWithArgs(
                  'Average airspeed: {0} m/s · maximum {1} m/s',
                  const [10, 20],
                  (l10n, value) =>
                      l10n.commonAverageAirspeedMS071139b2(value(0), value(1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Geschätzte Akkuspannung anzeigen'), findsOneWidget);
    expect(
      find.text('Average airspeed: 10 m/s · maximum 20 m/s'),
      findsOneWidget,
    );
  });
}
