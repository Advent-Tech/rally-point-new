import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../command_center_bloc.dart';
import '../command_center_state.dart';

class OverviewStatsBar extends StatelessWidget {
  const OverviewStatsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommandCenterBloc, CommandCenterState>(
      builder: (context, state) {
        final activeWorkers = state.liveLocations.length;
        final totalDonations = state.donations
            .where((d) => d.donationType != 'book_sale')
            .length;
        final totalBookSales = state.donations
            .where((d) => d.donationType == 'book_sale')
            .length;
        final totalPrayers = state.prayerRequests.length;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(
                    context,
                    icon: Icons.people,
                    value: activeWorkers.toString(),
                    label: 'Active',
                    color: Colors.green,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor,
                  ),
                  _buildStatItem(
                    context,
                    icon: Icons.attach_money,
                    value: totalDonations.toString(),
                    label: 'Donations',
                    color: const Color(0xFF10B981),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor,
                  ),
                  _buildStatItem(
                    context,
                    icon: Icons.menu_book_rounded,
                    value: totalBookSales.toString(),
                    label: 'Books',
                    color: const Color(0xFFF59E0B),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Theme.of(context).dividerColor,
                  ),
                  _buildStatItem(
                    context,
                    icon: Icons.favorite,
                    value: totalPrayers.toString(),
                    label: 'Prayers',
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
