import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../command_center_bloc.dart';
import '../command_center_event.dart';
import '../command_center_state.dart';

class FollowModeBanner extends StatelessWidget {
  const FollowModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommandCenterBloc, CommandCenterState>(
      builder: (context, state) {
        if (state.followTarget == null) {
          return const SizedBox.shrink();
        }

        final worker = state.workers.firstWhere(
          (w) => w.id == state.followTarget,
          orElse: () => state.workers.first,
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.gps_fixed,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Following ${worker.displayName ?? 'Worker'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  context.read<CommandCenterBloc>().add(
                    const FollowWorkerEvent(workerId: null),
                  );
                },
                child: const Text('EXIT'),
              ),
            ],
          ),
        );
      },
    );
  }
}
