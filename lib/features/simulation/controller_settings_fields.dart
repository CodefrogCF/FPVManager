import 'package:flutter/material.dart';

import 'controller_settings.dart';

class ControllerSettingsFields extends StatefulWidget {
  const ControllerSettingsFields({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final ControllerSettings initial;
  final ValueChanged<ControllerSettings> onChanged;
  @override
  State<ControllerSettingsFields> createState() =>
      _ControllerSettingsFieldsState();
}

class _ControllerSettingsFieldsState extends State<ControllerSettingsFields> {
  late var _layout = widget.initial.layout;
  late var _zero = widget.initial.throttleZero;
  late final _axes = [
    widget.initial.rollAxis,
    widget.initial.pitchAxis,
    widget.initial.throttleAxis,
    widget.initial.yawAxis,
  ];
  late final _invert = [
    widget.initial.invertRoll,
    widget.initial.invertPitch,
    widget.initial.invertThrottle,
    widget.initial.invertYaw,
  ];
  void _change() => widget.onChanged(
    ControllerSettings(
      layout: _layout,
      throttleZero: _zero,
      rollAxis: _axes[0],
      pitchAxis: _axes[1],
      throttleAxis: _axes[2],
      yawAxis: _axes[3],
      invertRoll: _invert[0],
      invertPitch: _invert[1],
      invertThrottle: _invert[2],
      invertYaw: _invert[3],
    ),
  );

  @override
  Widget build(BuildContext context) => ExpansionTile(
    maintainState: true,
    title: const Text('Controller'),
    subtitle: Text(
      _zero == ControllerThrottleZero.bottom
          ? 'Gas null: unten (0 %)'
          : 'Gas null: Mitte (50 %)',
    ),
    children: [
      DropdownButtonFormField<ControllerLayout>(
        key: const ValueKey('controller-layout'),
        initialValue: _layout,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Controllertyp'),
        items: const [
          DropdownMenuItem(
            value: ControllerLayout.gamepad,
            child: Text('Gamepad'),
          ),
          DropdownMenuItem(
            value: ControllerLayout.radio,
            child: Text('USB-Fernsteuerung'),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _layout = value;
              _zero = value == ControllerLayout.radio
                  ? ControllerThrottleZero.bottom
                  : ControllerThrottleZero.center;
            });
            _change();
          }
        },
      ),
      DropdownButtonFormField<ControllerThrottleZero>(
        key: const ValueKey('controller-throttle-zero'),
        initialValue: _zero,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Gas-Nullstellung'),
        items: const [
          DropdownMenuItem(
            value: ControllerThrottleZero.bottom,
            child: Text('0 % · unten (Fernsteuerung)'),
          ),
          DropdownMenuItem(
            value: ControllerThrottleZero.center,
            child: Text('50 % · Mitte (Gamepad)'),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _zero = value);
            _change();
          }
        },
      ),
      const Text(
        'Angle/Acro: Null unten nutzt den ganzen Gasweg; Null in der Mitte nur die obere Hälfte. Zum Verbinden oder Fortsetzen Gas auf null, übrige Sticks zentrieren.',
      ),
      if (_layout == ControllerLayout.radio) ...[
        const Text(
          'Roll, Pitch, Gas und Yaw benötigen vier verschiedene USB-Kanäle. Zuordnung und Richtung hängen von Fernsteuerung und Betriebssystem ab. Schalter lösen weder Zurücksetzen noch Beenden aus.',
        ),
        for (var i = 0; i < 4; i++)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('controller-axis-$i'),
                  initialValue: _axes[i],
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: ['Roll', 'Pitch', 'Throttle', 'Yaw'][i],
                  ),
                  items: [
                    for (var a = 0; a < 16; a++)
                      DropdownMenuItem(value: a, child: Text('Kanal ${a + 1}')),
                  ],
                  validator: (_) => _axes.toSet().length != 4
                      ? 'Verschiedene Kanäle wählen'
                      : null,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        final other = _axes.indexOf(value), previous = _axes[i];
                        if (other >= 0 && other != i) _axes[other] = previous;
                        _axes[i] = value;
                      });
                      _change();
                    }
                  },
                ),
              ),
              Checkbox(
                value: _invert[i],
                semanticLabel: '${['Roll', 'Pitch', 'Gas', 'Yaw'][i]} umkehren',
                onChanged: (value) {
                  setState(() => _invert[i] = value ?? false);
                  _change();
                },
              ),
              const Text('Umkehren'),
            ],
          ),
      ],
    ],
  );
}
