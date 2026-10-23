import 'package:flutter/material.dart';

import 'route_editor_controller.dart';

Future<void> showRouteEquipment(
  BuildContext context,
  RouteEditorController editor,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RouteEquipment(editor: editor),
  );
}

class _RouteEquipment extends StatefulWidget {
  const _RouteEquipment({required this.editor});
  final RouteEditorController editor;
  @override
  State<_RouteEquipment> createState() => _RouteEquipmentState();
}

class _RouteEquipmentState extends State<_RouteEquipment> {
  late int? _drone = widget.editor.droneId;
  late final _batteries = Set<int>.of(widget.editor.batteryIds);
  @override
  void initState() {
    super.initState();
    widget.editor.loadEquipment();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .8,
      child: ListenableBuilder(
        listenable: widget.editor,
        builder: (context, _) {
          final equipment = widget.editor.equipment;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Route equipment',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (widget.editor.equipmentError case final error?) ...[
                  Text(error),
                  TextButton(
                    onPressed: widget.editor.loadEquipment,
                    child: const Text('Retry'),
                  ),
                ] else if (equipment == null)
                  const LinearProgressIndicator(),
                if (equipment != null) ...[
                  if (_drone != null &&
                      !equipment.drones.any((d) => d.drone.id == _drone))
                    const Text(
                      'The assigned drone was deleted. Choose another profile or clear the assignment.',
                    ),
                  DropdownButtonFormField<int>(
                    initialValue:
                        equipment.drones.any((d) => d.drone.id == _drone)
                        ? _drone
                        : null,
                    isExpanded: true,
                    hint: const Text('No drone assigned'),
                    decoration: const InputDecoration(labelText: 'Drone'),
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('No drone assigned'),
                      ),
                      for (final d in equipment.drones)
                        DropdownMenuItem(
                          value: d.drone.id,
                          child: Text(d.drone.name),
                        ),
                    ],
                    onChanged: (v) => setState(() => _drone = v),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Batteries are alternative packs for one flight. Their capacities are assessed individually.',
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        if (equipment.batteries.isEmpty)
                          const ListTile(
                            title: Text(
                              'Create battery profiles in Equipment first.',
                            ),
                          ),
                        for (final b in equipment.batteries)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(b.name),
                            subtitle: Text(
                              '${b.cellCount}S · ${b.capacityMah} mAh · ${b.availability}',
                            ),
                            value: _batteries.contains(b.id),
                            onChanged: (v) => setState(() {
                              if (v!) {
                                _batteries.add(b.id);
                              } else {
                                _batteries.remove(b.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      widget.editor.assignEquipment(
                        equipment.drones.any((d) => d.drone.id == _drone)
                            ? _drone
                            : null,
                        _batteries.intersection(
                          equipment.batteries.map((b) => b.id).toSet(),
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Apply equipment'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}
