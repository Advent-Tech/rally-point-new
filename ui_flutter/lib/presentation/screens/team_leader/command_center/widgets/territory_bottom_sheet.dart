import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../command_center_bloc.dart';
import '../command_center_event.dart';
import '../command_center_state.dart';

class TerritoryBottomSheet extends StatefulWidget {
  const TerritoryBottomSheet({super.key});

  @override
  State<TerritoryBottomSheet> createState() => _TerritoryBottomSheetState();
}

class _TerritoryBottomSheetState extends State<TerritoryBottomSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
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
      minChildSize: 0.12,
      maxChildSize: 0.8,
      snap: true,
      snapSizes: const [0.12, 0.3, 0.8],
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
                      'Territories',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        final size = _controller.size;
                        final target = size > 0.3 ? 0.3 : 0.12;
                        _controller.animateTo(
                          target,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        );
                      },
                      icon: const Icon(Icons.keyboard_arrow_down),
                      visualDensity: VisualDensity.compact,
                    ),
                    BlocBuilder<CommandCenterBloc, CommandCenterState>(
                      builder: (context, state) {
                        return Chip(
                          label: Text('${state.territories.length} Total'),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Territory list
              Expanded(
                child: BlocBuilder<CommandCenterBloc, CommandCenterState>(
                  builder: (context, state) {
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: state.territories.length,
                      itemBuilder: (context, index) {
                        final territory = state.territories[index];
                        final isSelected =
                            state.selectedTerritoryId == territory.id;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                context.read<CommandCenterBloc>().add(
                                  SelectTerritoryEvent(
                                    territoryId: isSelected
                                        ? null
                                        : territory.id,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(
                                            context,
                                          ).dividerColor.withValues(alpha: 0.5),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.05)
                                      : Theme.of(context).colorScheme.surface,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            (territory.solid.toLowerCase() ==
                                                        'true'
                                                    ? Theme.of(
                                                        context,
                                                      ).colorScheme.primary
                                                    : Colors.grey)
                                                .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        territory.solid.toLowerCase() == 'true'
                                            ? Icons.layers
                                            : Icons.layers_outlined,
                                        color:
                                            territory.solid.toLowerCase() ==
                                                'true'
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            territory.entityName.isNotEmpty
                                                ? territory.entityName
                                                : 'Territory ${territory.id}',
                                            style: TextStyle(
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ID: ${territory.id} • ${territory.housingUnits ?? 0} Units',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color
                                                      ?.withValues(alpha: 0.7),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
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
