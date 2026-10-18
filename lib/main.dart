import 'package:flutter/material.dart';

import 'features/globe/globe_controller.dart';
import 'features/globe/globe_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FPVManagerApp());
}

class FPVManagerApp extends StatelessWidget {
  const FPVManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FPVManager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101820),
      ),
      home: const FPVHomeScreen(),
    );
  }
}

class FPVHomeScreen extends StatefulWidget {
  const FPVHomeScreen({super.key});

  @override
  State<FPVHomeScreen> createState() => _FPVHomeScreenState();
}

class _FPVHomeScreenState extends State<FPVHomeScreen> {
  final GlobeController _globeController = GlobeController();

  Future<void> _runCommand(Future<void> Function() command) async {
    try {
      await command();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Map error: $error')));
    }
  }

  Future<void> _openCoordinatesDialog() async {
    final point = await showDialog<GlobePoint>(
      context: context,
      builder: (context) => const _CoordinatesDialog(),
    );

    if (point == null || !mounted) return;

    await _runCommand(
      () => _globeController.flyTo(
        latitude: point.latitude,
        longitude: point.longitude,
        altitude: 12000,
      ),
    );
  }

  @override
  void dispose() {
    _globeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FPVManager'),
        backgroundColor: const Color(0xFF101820),
        actions: [
          ListenableBuilder(
            listenable: _globeController,
            builder: (context, child) {
              final ready = _globeController.isReady;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Home',
                    onPressed: ready
                        ? () => _runCommand(_globeController.resetCamera)
                        : null,
                    icon: const Icon(Icons.home_outlined),
                  ),
                  IconButton(
                    tooltip: 'Go to coordinates',
                    onPressed: ready ? _openCoordinatesDialog : null,
                    icon: const Icon(Icons.place_outlined),
                  ),
                  if (_globeController.uasZonesLoading)
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: _globeController.uasZonesVisible
                          ? 'Hide UAS zones'
                          : 'Show UAS zones',
                      onPressed: ready
                          ? () => _runCommand(
                              () => _globeController.setUasZonesVisible(
                                !_globeController.uasZonesVisible,
                              ),
                            )
                          : null,
                      icon: Icon(
                        _globeController.uasZonesVisible
                            ? Icons.shield
                            : Icons.shield_outlined,
                        color: _globeController.uasZonesVisible
                            ? Colors.orangeAccent
                            : null,
                      ),
                    ),
                  PopupMenuButton<GlobeMapStyle>(
                    tooltip: 'Map style',
                    enabled: ready,
                    icon: const Icon(Icons.layers_outlined),
                    onSelected: (style) =>
                        _runCommand(() => _globeController.setMapStyle(style)),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: GlobeMapStyle.satellite,
                        child: Text('Satellite'),
                      ),
                      PopupMenuItem(
                        value: GlobeMapStyle.topographic,
                        child: Text('Topographic'),
                      ),
                      PopupMenuItem(
                        value: GlobeMapStyle.relief,
                        child: Text('Relief'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: GlobeView(controller: _globeController),
      bottomNavigationBar: ListenableBuilder(
        listenable: _globeController,
        builder: (context, child) {
          final point = _globeController.selectedPoint;
          final error = _globeController.error;

          String status;

          if (error != null) {
            status = 'Map error: $error';
          } else if (!_globeController.isReady) {
            status = 'Loading globe...';
          } else if (_globeController.uasZonesError != null) {
            status = 'UAS zones: ${_globeController.uasZonesError}';
          } else if (_globeController.uasZonesLoading) {
            status = 'Loading Swiss UAS zones...';
          } else if (_globeController.uasZonesVisible) {
            status = 'Swiss UAS zones active | Source: FOCA';
          } else if (point != null) {
            status =
                '${point.latitude.toStringAsFixed(5)}, '
                '${point.longitude.toStringAsFixed(5)} | '
                '${point.altitude.toStringAsFixed(1)} m';
          } else {
            status = '3D globe ready';
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                status,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CoordinatesDialog extends StatefulWidget {
  const _CoordinatesDialog();

  @override
  State<_CoordinatesDialog> createState() => _CoordinatesDialogState();
}

class _CoordinatesDialogState extends State<_CoordinatesDialog> {
  final _formKey = GlobalKey<FormState>();

  final _latitude = TextEditingController(text: '46.7');
  final _longitude = TextEditingController(text: '8.4');

  double? _parse(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  String? _validate(String? value, double minimum, double maximum) {
    final number = _parse(value ?? '');

    if (number == null ||
        !number.isFinite ||
        number < minimum ||
        number > maximum) {
      return 'Enter a value from $minimum to $maximum';
    }

    return null;
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Go to coordinates'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _latitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Latitude'),
              validator: (value) => _validate(value, -90, 90),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _longitude,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(labelText: 'Longitude'),
              validator: (value) => _validate(value, -180, 180),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }

            Navigator.pop(
              context,
              GlobePoint(
                latitude: _parse(_latitude.text)!,
                longitude: _parse(_longitude.text)!,
                altitude: 0,
              ),
            );
          },
          child: const Text('Go'),
        ),
      ],
    );
  }
}
