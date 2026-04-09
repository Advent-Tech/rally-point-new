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

        String displayName = 'Worker';
        for (final w in state.workers) {
          if (w.id == state.followTarget) {
            displayName = w.displayName ?? 'Worker';
            break;
          }
        }
        final isGpsLive = state.gpsLiveWorkerIds.contains(state.followTarget);

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isGpsLive ? Icons.gps_fixed : Icons.location_searching,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isGpsLive
                      ? 'Following $displayName'
                      : 'Following $displayName (last known)',
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
                child: const Text('STOP'),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}
