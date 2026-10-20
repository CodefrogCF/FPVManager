import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import '../../core/database/repositories/drone_repository.dart';
import 'drone_details_screen.dart';
import 'drone_editor_dialog.dart';

class DronesScreen extends StatefulWidget {
  const DronesScreen({super.key, required this.repository});
  final DroneRepository repository;
  @override
  State<DronesScreen> createState() => _DronesScreenState();
}

class _DronesScreenState extends State<DronesScreen> {
  late Stream<List<Drone>> _drones = widget.repository.watchDrones();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Drone profiles')),
    body: StreamBuilder<List<Drone>>(
      stream: _drones,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load drone profiles.'),
                TextButton(
                  onPressed: () =>
                      setState(() => _drones = widget.repository.watchDrones()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final drones = snapshot.data!;
        if (drones.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No drone profiles saved yet. Add a profile to record your equipment.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: drones.length,
          itemBuilder: (context, index) {
            final drone = drones[index];
            return ListTile(
              leading: const Icon(Icons.flight_outlined),
              title: Text(drone.name),
              subtitle: Text(drone.type),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (context) => DroneDetailsScreen(
                    repository: widget.repository,
                    droneId: drone.id,
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => DroneEditorDialog(repository: widget.repository),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Add drone'),
    ),
  );
}
