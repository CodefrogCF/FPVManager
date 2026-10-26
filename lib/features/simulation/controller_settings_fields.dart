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
    title: const Text('External controller'),
    subtitle: Text(
      _zero == ControllerThrottleZero.bottom
          ? 'Zero throttle: stick bottom (0%)'
          : 'Zero throttle: stick centre (50%)',
    ),
    children: [
      DropdownButtonFormField<ControllerLayout>(
        key: const ValueKey('controller-layout'),
        initialValue: _layout,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Controller type'),
        items: const [
          DropdownMenuItem(
            value: ControllerLayout.gamepad,
            child: Text('Standard gamepad'),
          ),
          DropdownMenuItem(
            value: ControllerLayout.radio,
            child: Text('USB radio · Tango 2 / custom'),
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
        decoration: const InputDecoration(
          labelText: 'Zero-throttle stick position',
        ),
        items: const [
          DropdownMenuItem(
            value: ControllerThrottleZero.bottom,
            child: Text('0% · bottom (RC radio)'),
          ),
          DropdownMenuItem(
            value: ControllerThrottleZero.center,
            child: Text('50% · centre (gamepad)'),
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
        'External inputs in Angle/Acro: bottom zero uses the full stick travel; centre zero uses only the upper half. Touch and keyboard keep their existing controls. Connect or resume with zero throttle and the other sticks centred.',
      ),
      if (_layout == ControllerLayout.radio) ...[
        const Text(
          'Starting assignment: roll, pitch, throttle, yaw on channels 1–4. USB channel order depends on the radio model and operating system. Assign four different channels and reverse directions as needed. No radio switches are mapped to Reset or Exit.',
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
                      DropdownMenuItem(
                        value: a,
                        child: Text('Channel ${a + 1}'),
                      ),
                  ],
                  validator: (_) => _axes.toSet().length != 4
                      ? 'Choose different channels'
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
                semanticLabel:
                    'Reverse ${['roll', 'pitch', 'throttle', 'yaw'][i]}',
                onChanged: (value) {
                  setState(() => _invert[i] = value ?? false);
                  _change();
                },
              ),
              const Text('Reverse'),
            ],
          ),
      ],
    ],
  );
}
