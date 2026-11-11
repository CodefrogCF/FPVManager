import 'dart:async';

import '../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../core/database/fpv_database.dart';
import 'data/spot_repository.dart';

class SpotStorageDebugScreen extends StatefulWidget {
  const SpotStorageDebugScreen({super.key});

  @override
  State<SpotStorageDebugScreen> createState() => _SpotStorageDebugScreenState();
}

class _SpotStorageDebugScreenState extends State<SpotStorageDebugScreen> {
  late final FpvDatabase _database = FpvDatabase.open();

  late final SpotRepository _repository = SpotRepository(_database);

  Future<void> _addTestSpot() async {
    try {
      await _repository.createSpot(
        name: 'FPVManager Test Spot',
        latitude: 46.95108,
        longitude: 7.43863,
        notes: 'Local database persistence test',
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Storage error: $error')));
    }
  }

  Future<void> _deleteSpot(int id) async {
    try {
      await _repository.deleteSpot(id);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.translate("Delete failed: {0}", [error])),
        ),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.translate("Local Storage Test"))),

      body: StreamBuilder(
        stream: _repository.watchSpots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.translate("Database error: {0}", [snapshot.error]),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final spots = snapshot.data!;

          if (spots.isEmpty) {
            return Center(
              child: Text(
                context.translate(
                  "No spots saved yet.\nAdd a test spot to verify persistence.",
                ),
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            itemCount: spots.length,
            itemBuilder: (context, index) {
              final spot = spots[index];

              return ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(spot.name),
                subtitle: Text(
                  '${spot.latitude.toStringAsFixed(5)}, '
                  '${spot.longitude.toStringAsFixed(5)}',
                ),
                trailing: IconButton(
                  tooltip: 'Delete spot',
                  onPressed: () => _deleteSpot(spot.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTestSpot,
        icon: const Icon(Icons.add),
        label: Text(context.translate("Add Test Spot")),
      ),
    );
  }
}
