import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/battery_repository.dart';
import '../../core/models/battery_profile.dart';
import 'battery_details_screen.dart';
import 'battery_editor_dialog.dart';

class BatteriesScreen extends StatefulWidget {
  const BatteriesScreen({super.key, required this.repository});
  final BatteryRepository repository;
  @override
  State<BatteriesScreen> createState() => _BatteriesScreenState();
}

class _BatteriesScreenState extends State<BatteriesScreen> {
  late Stream<List<Battery>> _batteries = widget.repository.watchBatteries();

  Future<void> _add({bool asType = false}) async {
    final id = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          BatteryEditorDialog(repository: widget.repository, asType: asType),
    );
    if (id != null && mounted) await _open(id);
  }

  Future<void> _open(int id) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) =>
          BatteryDetailsScreen(repository: widget.repository, batteryId: id),
    ),
  );

  Widget _list(List<Battery> batteries, bool types) {
    final rows = batteries.where((row) => row.isType == types).toList();
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            types
                ? context.localized(
                    "No battery types yet. Add a reusable specification template.",
                    (l10n) => l10n.batteriesNoBatteryTypesYetc908d855,
                  )
                : context.localized(
                    "No individual batteries yet. Add a pack to your inventory.",
                    (l10n) => l10n.batteriesNoIndividualBatteriesYet2f6f284a,
                  ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 176),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final battery = rows[index];
        return ListTile(
          leading: Icon(
            types ? Icons.copy_all_outlined : Icons.battery_full_outlined,
          ),
          title: Text(battery.name),
          subtitle: Text(
            '${battery.chemistry} · ${battery.cellCount}S · ${battery.capacityMah} mAh'
            '${types ? '' : '\n${BatteryAvailability.parse(battery.availability).label} · ${battery.chargePercent == null ? 'Charge not recorded' : '${battery.chargePercent}% recorded'}'}',
          ),
          isThreeLine: !types,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(battery.id),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          context.localized(
            "Battery inventory",
            (l10n) => l10n.batteriesBatteryInventory01b473c6,
          ),
        ),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Packs'),
            Tab(text: 'Types'),
          ],
        ),
      ),
      body: StreamBuilder<List<Battery>>(
        stream: _batteries,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.localized(
                      "Unable to load battery inventory.",
                      (l10n) => l10n.batteriesUnableToLoadBattery8a3276bc,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(
                      () => _batteries = widget.repository.watchBatteries(),
                    ),
                    child: Text(
                      context.localized(
                        "Retry",
                        (l10n) => l10n.commonRetry9f5cd8a2,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return TabBarView(
            children: [
              _list(snapshot.data!, false),
              _list(snapshot.data!, true),
            ],
          );
        },
      ),
      floatingActionButton: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'add-battery-type',
            onPressed: () => _add(asType: true),
            icon: const Icon(Icons.copy_all_outlined),
            label: Text(
              context.localized(
                "Add type",
                (l10n) => l10n.batteriesAddType937e2dfc,
              ),
            ),
          ),
          FloatingActionButton.extended(
            heroTag: 'add-battery',
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: Text(
              context.localized(
                "Add battery",
                (l10n) => l10n.batteriesAddBattery418deef8,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
