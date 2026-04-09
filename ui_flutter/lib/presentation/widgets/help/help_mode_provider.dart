import 'package:flutter/material.dart';

class HelpModeProvider extends InheritedNotifier<ValueNotifier<bool>> {
  const HelpModeProvider({
    super.key,
    required ValueNotifier<bool> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static bool of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<HelpModeProvider>();
    return provider?.notifier?.value ?? false;
  }

  static ValueNotifier<bool>? notifierOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<HelpModeProvider>();
    return provider?.notifier;
  }

  static void show(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<HelpModeProvider>();
    provider?.notifier?.value = true;
  }

  static void hide(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<HelpModeProvider>();
    provider?.notifier?.value = false;
  }

  static void toggle(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<HelpModeProvider>();
    if (provider?.notifier != null) {
      provider!.notifier!.value = !provider.notifier!.value;
    }
  }
}
