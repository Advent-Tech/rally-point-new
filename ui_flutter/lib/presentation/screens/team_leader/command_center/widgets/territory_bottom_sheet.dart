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
  static const double _collapsedSize = 0.12;
  static const double _midSize = 0.32;
  static const double _maxSize = 0.60;
  double _currentSize = _midSize;

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
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              if (_currentSize > _collapsedSize + 0.01) {
                _controller.animateTo(
                  _collapsedSize,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                );
              }
            },
            child: const SizedBox.expand(),
          ),
        ),
        NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            _currentSize = notification.extent;
            return false;
          },
          child: DraggableScrollableSheet(
            controller: _controller,
            initialChildSize: _midSize,
            minChildSize: _collapsedSize,
            maxChildSize: _maxSize,
            snap: true,
            snapSizes: const [_collapsedSize, _midSize, _maxSize],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                      child: Row(
                        children: [
                          Text(
                            'Territories',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          BlocBuilder<CommandCenterBloc, CommandCenterState>(
                            builder: (context, state) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${state.territories.length} Total',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            onPressed: () {
                              final size = _controller.size;
                              final target = size > _midSize
                                  ? _midSize
                                  : _collapsedSize;
                              _controller.animateTo(
                                target,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              );
                            },
                            icon: const Icon(Icons.keyboard_arrow_down),
                            visualDensity: VisualDensity.compact,
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
                            padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                            itemCount: state.territories.length,
                            itemBuilder: (context, index) {
                              final territory = state.territories[index];
                              final isSelected =
                                  state.selectedTerritoryId == territory.id;
                              final title = territory.entityName.isNotEmpty
                                  ? territory.entityName
                                  : 'Territory';
                              final units = territory.housingUnits ?? 0;
                              final shortId = territory.id.length > 8
                                  ? territory.id.substring(0, 8)
                                  : territory.id;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
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
                                    borderRadius: BorderRadius.circular(14),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                              : Theme.of(context).dividerColor
                                                    .withValues(alpha: 0.45),
                                          width: isSelected ? 1.6 : 1,
                                        ),
                                        color: isSelected
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.06)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.surface,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withValues(alpha: 0.10),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              territory.solid.toLowerCase() ==
                                                      'true'
                                                  ? Icons.layers
                                                  : Icons.layers_outlined,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
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
                                                  title,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w600,
                                                    fontSize: 16,
                                                    height: 1.25,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                            .withValues(
                                                              alpha: 0.09,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              99,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '$units Units',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      '#$shortId',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.color
                                                                    ?.withValues(
                                                                      alpha:
                                                                          0.65,
                                                                    ),
                                                          ),
                                                    ),
                                                  ],
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
          ),
        ),
      ],
    );
  }
}
