import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../command_center_bloc.dart';
import '../command_center_event.dart';
import '../command_center_state.dart';

class WorkerBottomSheet extends StatefulWidget {
  const WorkerBottomSheet({super.key});

  @override
  State<WorkerBottomSheet> createState() => _WorkerBottomSheetState();
}

class _WorkerBottomSheetState extends State<WorkerBottomSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: 0.3,
      minChildSize: 0.1,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Team Members',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    BlocBuilder<CommandCenterBloc, CommandCenterState>(
                      builder: (context, state) {
                        final liveCount = state.liveLocations.length;
                        return Chip(
                          label: Text('$liveCount Live'),
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Worker list
              Expanded(
                child: BlocBuilder<CommandCenterBloc, CommandCenterState>(
                  builder: (context, state) {
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: state.workers.length,
                      itemBuilder: (context, index) {
                        final worker = state.workers[index];
                        final hasAnyLocation = state.liveLocations.containsKey(
                          worker.id,
                        );
                        final isGpsLive = state.gpsLiveWorkerIds.contains(
                          worker.id,
                        );
                        final isApiOnline = worker.isOnline;
                        final isFollowing = state.followTarget == worker.id;
                        final isBreached = state.breachedWorkerIds.contains(
                          worker.id,
                        );

                        final pos = state.liveLocations[worker.id];

                        return ListTile(
                          onTap: () {
                            context.read<CommandCenterBloc>().add(
                              ShowMapPopupEvent(
                                popup: MapPopup(
                                  kind: MapPopupKind.worker,
                                  id: worker.id,
                                  latitude: pos?.latitude,
                                  longitude: pos?.longitude,
                                ),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: isGpsLive
                                ? Colors.green
                                : (isApiOnline
                                      ? Colors.orange
                                      : Colors.grey.shade400),
                            child: Text(
                              (worker.displayName ?? 'W')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(worker.displayName ?? 'Team Member'),
                          subtitle: Text(
                            isGpsLive
                                ? 'GPS Live'
                                : (hasAnyLocation
                                      ? 'Last known (entry)'
                                      : (isApiOnline
                                            ? 'Online (no GPS)'
                                            : 'Offline')),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isBreached)
                                Icon(
                                  Icons.warning,
                                  color: Colors.red.shade700,
                                  size: 20,
                                ),
                              if (isGpsLive)
                                IconButton(
                                  icon: Icon(
                                    isFollowing
                                        ? Icons.gps_fixed
                                        : Icons.gps_not_fixed,
                                    color: isFollowing
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                  onPressed: () {
                                    context.read<CommandCenterBloc>().add(
                                      FollowWorkerEvent(
                                        workerId: isFollowing
                                            ? null
                                            : worker.id,
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
