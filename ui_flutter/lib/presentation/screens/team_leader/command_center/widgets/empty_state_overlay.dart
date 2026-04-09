import '../command_center_state.dart' as cc;
import 'package:flutter/material.dart';

class EmptyStateOverlay extends StatelessWidget {
  final cc.MapMode mode;
  final VoidCallback onAction;

  const EmptyStateOverlay({
    super.key,
    required this.mode,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: Colors.black.withAlpha(128),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIcon(),
                size: 64,
                color: theme.colorScheme.primary.withAlpha(128),
              ),
              const SizedBox(height: 16),
              Text(
                _getTitle(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _getMessage(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(179),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_getActionLabel()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (mode) {
      case cc.MapMode.overview:
        return Icons.map_outlined;
      case cc.MapMode.workers:
        return Icons.people_outline;
      case cc.MapMode.territories:
        return Icons.layers_outlined;
    }
  }

  String _getTitle() {
    switch (mode) {
      case cc.MapMode.overview:
        return 'No Map Activity Yet';
      case cc.MapMode.workers:
        return 'No Workers Active';
      case cc.MapMode.territories:
        return 'No Territories Assigned';
    }
  }

  String _getMessage() {
    switch (mode) {
      case cc.MapMode.overview:
        return 'No territory or worker location data is available yet. Ask admin to assign territories, then refresh.';
      case cc.MapMode.workers:
        return 'No workers are currently sharing live location. They may be offline or not checked in yet.';
      case cc.MapMode.territories:
        return 'Your team has no territory allocations yet. Contact admin to assign territories to this leader/team.';
    }
  }

  String _getActionLabel() {
    switch (mode) {
      case cc.MapMode.overview:
        return 'REFRESH';
      case cc.MapMode.workers:
        return 'REFRESH';
      case cc.MapMode.territories:
        return 'REFRESH';
    }
  }
}
