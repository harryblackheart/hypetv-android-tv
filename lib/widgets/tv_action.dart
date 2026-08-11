import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool isTvActivateKey(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.select ||
    key == LogicalKeyboardKey.enter ||
    key == LogicalKeyboardKey.space ||
    key == LogicalKeyboardKey.gameButtonA;

KeyEventResult activateOnTvKey(KeyEvent event, VoidCallback? action) {
  if (action == null || event is! KeyDownEvent) return KeyEventResult.ignored;
  if (!isTvActivateKey(event.logicalKey)) return KeyEventResult.ignored;
  action();
  return KeyEventResult.handled;
}
