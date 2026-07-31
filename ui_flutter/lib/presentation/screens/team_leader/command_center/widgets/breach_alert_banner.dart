import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../command_center_bloc.dart';
import '../command_center_state.dart';

class BreachAlertBanner extends StatelessWidget {
  const BreachAlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommandCenterBloc, CommandCenterState>(
      builder: (context, state) {
        if (state.breachedWorkerIds.isEmpty) {
          return const SizedBox.shrink();
        }

        final breachedWorkers = state.workers
            .where((w) => state.breachedWorkerIds.contains(w.id))
            .toList();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 20,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  breachedWorkers.length == 1
                      ? '${breachedWorkers.first.displayName ?? 'Light Squad'} is outside assigned territory'
                      : '${breachedWorkers.length} light squads outside territories',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Show details or navigate to workers view
                },
                child: Text(
                  'VIEW',
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
