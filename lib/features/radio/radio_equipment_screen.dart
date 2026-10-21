import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/radio_equipment_repository.dart';
import '../../core/models/radio_profile.dart';
import 'radio_details_screen.dart';
import 'radio_editor_dialog.dart';

class RadioEquipmentScreen extends StatefulWidget {
  const RadioEquipmentScreen({super.key, required this.repository});
  final RadioEquipmentRepository repository;
  @override
  State<RadioEquipmentScreen> createState() => _RadioEquipmentScreenState();
}

class _RadioEquipmentScreenState extends State<RadioEquipmentScreen> {
  late Stream<List<RadioEquipmentData>> _equipment = widget.repository
      .watchEquipment();

  Future<void> _open(int id) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) =>
          RadioDetailsScreen(repository: widget.repository, equipmentId: id),
    ),
  );

  Future<void> _add() async {
    final id = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RadioEditorDialog(repository: widget.repository),
    );
    if (id != null && mounted) await _open(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Radio & video equipment')),
    body: StreamBuilder<List<RadioEquipmentData>>(
      stream: _equipment,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load equipment profiles.'),
                TextButton(
                  onPressed: () => setState(
                    () => _equipment = widget.repository.watchEquipment(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No equipment profiles yet. Add separate configurations for radio control, video or telemetry.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final row = snapshot.data![index];
            return ListTile(
              leading: Icon(
                row.category == 'video'
                    ? Icons.videocam_outlined
                    : Icons.settings_input_antenna,
              ),
              title: Text(row.name),
              subtitle: Text(
                '${radioCategoryLabel(row.category)}${row.protocol == null ? '' : ' · ${row.protocol}'}\n${row.frequencyMhz == null ? 'Frequency not recorded' : '${row.frequencyMhz} MHz'}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(row.id),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.add),
      label: const Text('Add equipment'),
    ),
  );
}
