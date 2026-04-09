import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoachMarksService {
  static final CoachMarksService _instance = CoachMarksService._internal();
  factory CoachMarksService() => _instance;
  CoachMarksService._internal();
  static const String _keyPrefix = 'coach_mark_shown_';

  final Map<String, bool> _completedSteps = {};
  final List<CoachMarkStep> _steps = [];
  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String _storageKey(String stepId) => '$_keyPrefix$stepId';

  List<CoachMarkStep> get steps => _steps;
  Map<String, bool> get completedSteps => _completedSteps;

  void addStep(CoachMarkStep step) {
    _steps.add(step);
  }

  void markComplete(String stepId) {
    _completedSteps[stepId] = true;
  }

  bool isStepComplete(String stepId) {
    return _completedSteps[stepId] ?? false;
  }

  Future<bool> hasBeenShown(String stepId) async {
    if (isStepComplete(stepId)) return true;
    final prefs = await _getPrefs();
    final shown = prefs.getBool(_storageKey(stepId)) ?? false;
    if (shown) {
      _completedSteps[stepId] = true;
    }
    return shown;
  }

  Future<void> markAsShown(String stepId) async {
    markComplete(stepId);
    final prefs = await _getPrefs();
    await prefs.setBool(_storageKey(stepId), true);
  }

  Future<void> reset() async {
    _completedSteps.clear();
    _steps.clear();
    final prefs = await _getPrefs();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(_keyPrefix))
        .toList(growable: false);
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  Future<void> resetStep(String stepId) async {
    _completedSteps[stepId] = false;
    final prefs = await _getPrefs();
    await prefs.remove(_storageKey(stepId));
  }

  CoachMarkStep? getCurrentStep() {
    for (final step in _steps) {
      if (!isStepComplete(step.id)) {
        return step;
      }
    }
    return null;
  }

  int get totalSteps => _steps.length;
  int get completedCount => _completedSteps.values.where((v) => v).length;
  double get progress => totalSteps > 0 ? completedCount / totalSteps : 0;
}

class CoachMarkStep {
  final String id;
  final String title;
  final String? description;
  final GlobalKey targetKey;
  final CoachMarkPosition position;
  final String? icon;

  const CoachMarkStep({
    required this.id,
    required this.title,
    this.description,
    required this.targetKey,
    this.position = CoachMarkPosition.bottom,
    this.icon,
  });
}

enum CoachMarkPosition { top, bottom, left, right, center }
