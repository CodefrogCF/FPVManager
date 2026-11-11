import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

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
    title: Text(context.translate("Controller")),
    subtitle: Text(
      _zero == ControllerThrottleZero.bottom
          ? context.translate("Gas null: unten (0 %)")
          : context.translate("Gas null: Mitte (50 %)"),
    ),
    children: [
      DropdownButtonFormField<ControllerLayout>(
        key: const ValueKey('controller-layout'),
        initialValue: _layout,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.translate("Controllertyp"),
        ),
        items: [
          DropdownMenuItem(
            value: ControllerLayout.gamepad,
            child: Text(context.translate("Gamepad")),
          ),
          DropdownMenuItem(
            value: ControllerLayout.radio,
            child: Text(context.translate("USB-Fernsteuerung")),
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
        decoration: InputDecoration(
          labelText: context.translate("Gas-Nullstellung"),
        ),
        items: [
          DropdownMenuItem(
            value: ControllerThrottleZero.bottom,
            child: Text(context.translate("0 % · unten (Fernsteuerung)")),
          ),
          DropdownMenuItem(
            value: ControllerThrottleZero.center,
            child: Text(context.translate("50 % · Mitte (Gamepad)")),
          ),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _zero = value);
            _change();
          }
        },
      ),
      Text(
        context.translate(
          "Angle/Acro: Null unten nutzt den ganzen Gasweg; Null in der Mitte nur die obere Hälfte. Zum Verbinden oder Fortsetzen Gas auf null, übrige Sticks zentrieren.",
        ),
      ),
      if (_layout == ControllerLayout.radio) ...[
        Text(
          context.translate(
            "Roll, Pitch, Gas und Yaw benötigen vier verschiedene USB-Kanäle. Zuordnung und Richtung hängen von Fernsteuerung und Betriebssystem ab. Schalter lösen weder Zurücksetzen noch Beenden aus.",
          ),
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
                        child: Text(context.translate("Kanal {0}", [a + 1])),
                      ),
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
                semanticLabel: context.translate("{0} umkehren", [
                  ['Roll', 'Pitch', 'Gas', 'Yaw'][i],
                ]),
                onChanged: (value) {
                  setState(() => _invert[i] = value ?? false);
                  _change();
                },
              ),
              Text(context.translate("Umkehren")),
            ],
          ),
      ],
    ],
  );
}
