import 'package:flutter/material.dart';

import '../globe/globe_controller.dart';

class CoordinatesDialog extends StatefulWidget {
  const CoordinatesDialog({super.key});

  @override
  State<CoordinatesDialog> createState() => CoordinatesDialogState();
}

class CoordinatesDialogState extends State<CoordinatesDialog> {
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
