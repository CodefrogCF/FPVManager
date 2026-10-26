enum ControllerLayout { gamepad, radio }

enum ControllerThrottleZero { bottom, center }

/// Radio channel positions refer to the axes exposed by the operating system.
class ControllerSettings {
  const ControllerSettings({
    this.layout = ControllerLayout.gamepad,
    this.throttleZero = ControllerThrottleZero.center,
    this.rollAxis = 0,
    this.pitchAxis = 1,
    this.throttleAxis = 2,
    this.yawAxis = 3,
    this.invertRoll = false,
    this.invertPitch = false,
    this.invertThrottle = false,
    this.invertYaw = false,
  });
  final ControllerLayout layout;
  final ControllerThrottleZero throttleZero;
  final int rollAxis, pitchAxis, throttleAxis, yawAxis;
  final bool invertRoll, invertPitch, invertThrottle, invertYaw;

  void validate() {
    final axes = [rollAxis, pitchAxis, throttleAxis, yawAxis];
    if (axes.any((a) => a < 0 || a > 15) || axes.toSet().length != 4) {
      throw ArgumentError('Choose four different controller channels (1–16)');
    }
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'layout': layout.name,
      'throttleZero': throttleZero.name,
      'rollAxis': rollAxis,
      'pitchAxis': pitchAxis,
      'throttleAxis': throttleAxis,
      'yawAxis': yawAxis,
      'invertRoll': invertRoll,
      'invertPitch': invertPitch,
      'invertThrottle': invertThrottle,
      'invertYaw': invertYaw,
    };
  }

  static ControllerSettings? tryParse(Object? value) {
    if (value is! Map) return null;
    final layout = ControllerLayout.values
        .where((v) => v.name == value['layout'])
        .firstOrNull;
    final zero = ControllerThrottleZero.values
        .where((v) => v.name == value['throttleZero'])
        .firstOrNull;
    if (layout == null ||
        zero == null ||
        ![
          'rollAxis',
          'pitchAxis',
          'throttleAxis',
          'yawAxis',
        ].every((k) => value[k] is int) ||
        ![
          'invertRoll',
          'invertPitch',
          'invertThrottle',
          'invertYaw',
        ].every((k) => value[k] is bool)) {
      return null;
    }
    final settings = ControllerSettings(
      layout: layout,
      throttleZero: zero,
      rollAxis: value['rollAxis'] as int,
      pitchAxis: value['pitchAxis'] as int,
      throttleAxis: value['throttleAxis'] as int,
      yawAxis: value['yawAxis'] as int,
      invertRoll: value['invertRoll'] as bool,
      invertPitch: value['invertPitch'] as bool,
      invertThrottle: value['invertThrottle'] as bool,
      invertYaw: value['invertYaw'] as bool,
    );
    try {
      settings.validate();
      return settings;
    } on ArgumentError {
      return null;
    }
  }
}
