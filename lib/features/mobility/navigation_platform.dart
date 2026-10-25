import 'package:flutter/services.dart';

class NavigationPlatform {
  const NavigationPlatform();
  static const _channel = MethodChannel(
    'com.codefrog.fpvmanager/road_navigation',
  );
  Future<void> keepAwake(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('keepAwake', enabled);
    } on MissingPluginException {
      /* Desktop tests and unsupported platforms. */
    } on PlatformException {
      /* Guidance remains usable without display control. */
    }
  }

  Future<bool> speak(String text) async {
    try {
      return await _channel.invokeMethod<bool>('speak', text) ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> stopVoice() async {
    try {
      await _channel.invokeMethod<void>('stopVoice');
    } on MissingPluginException {
      /* No speech engine. */
    } on PlatformException {
      /* Already stopped. */
    }
  }
}
