import 'package:flutter/material.dart';

class CoachMarksService {
  static final CoachMarksService _instance = CoachMarksService._internal();
  factory CoachMarksService() => _instance;
  CoachMarksService._internal();

  final Map<String, bool> _completedSteps = {};
  final List<CoachMarkStep> _steps = [];

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
    return isStepComplete(stepId);
  }

  Future<void> markAsShown(String stepId) async {
    markComplete(stepId);
  }

  void reset() {
    _completedSteps.clear();
    _steps.clear();
  }

  void resetStep(String stepId) {
    _completedSteps[stepId] = false;
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
