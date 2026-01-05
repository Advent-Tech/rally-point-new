import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/work_session/work_session_bloc.dart';

/// A card widget that displays current session status and auto-tracking toggle
class SessionTrackingCard extends StatelessWidget {
  const SessionTrackingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkSessionBloc, WorkSessionState>(
      builder: (context, state) {
        if (state is WorkSessionLoading) {
          return _buildLoadingCard(context);
        }

        if (state is WorkSessionActive) {
          return _buildActiveSessionCard(context, state);
        }

        if (state is WorkSessionInactive) {
          return _buildInactiveCard(context, state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(
              'Loading session...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard(BuildContext context, WorkSessionActive state) {
    final theme = Theme.of(context);
    final session = state.session;

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Active Session',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildAutoTrackingToggle(context, state.autoTrackingEnabled),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              session.territoryName,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  session.formattedDuration,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.home_work_outlined,
                  size: 16,
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  '${state.todayVisits.length} visits',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            if (state.currentLatitude != null && state.currentLongitude != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${state.currentLatitude!.toStringAsFixed(5)}, ${state.currentLongitude!.toStringAsFixed(5)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCheckOutDialog(context),
                icon: const Icon(Icons.logout),
                label: const Text('End Session'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveCard(BuildContext context, WorkSessionInactive state) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'No Active Session',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildAutoTrackingToggle(context, state.autoTrackingEnabled),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              state.autoTrackingEnabled
                  ? 'Auto-tracking enabled. Session will start automatically when you enter an assigned territory.'
                  : 'Enable auto-tracking to automatically start sessions when you enter territories.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (state.lastSession != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Last session:',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${state.lastSession!.territoryName} - ${state.lastSession!.formattedDuration}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAutoTrackingToggle(BuildContext context, bool enabled) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Auto',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: enabled ? Colors.green : Colors.grey,
          ),
        ),
        const SizedBox(width: 4),
        Switch(
          value: enabled,
          onChanged: (value) {
            context.read<WorkSessionBloc>().add(
              WorkSessionToggleAutoTracking(enabled: value),
            );
          },
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  void _showCheckOutDialog(BuildContext context) {
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to end this session?'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add any notes about your session...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<WorkSessionBloc>().add(
                WorkSessionCheckOut(
                  notes: notesController.text.isNotEmpty
                      ? notesController.text
                      : null,
                ),
              );
            },
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }
}
