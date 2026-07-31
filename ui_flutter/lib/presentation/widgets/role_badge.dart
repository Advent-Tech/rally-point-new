import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class RoleBadge extends StatelessWidget {
  final String role;
  final bool isSmall;

  const RoleBadge({super.key, this.role = 'worker', this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roleConfig = _getRoleConfig(role);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 4 : 6,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [roleConfig.color, roleConfig.color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isSmall ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: roleConfig.color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(roleConfig.icon, color: Colors.white, size: isSmall ? 12 : 16),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                roleConfig.label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmall ? 10 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _RoleConfig _getRoleConfig(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return _RoleConfig(
          label: 'Admin',
          icon: Icons.admin_panel_settings,
          color: AppColors.error,
        );
      case 'leader':
      case 'team_leader':
      case 'team-leader':
        return _RoleConfig(
          label: 'Light House',
          icon: Icons.supervisor_account,
          color: AppColors.warning,
        );
      case 'worker':
        return _RoleConfig(
          label: 'Light Squad',
          icon: Icons.person,
          color: AppColors.success,
        );
      default:
        return _RoleConfig(
          label: role,
          icon: Icons.person,
          color: AppColors.primary,
        );
    }
  }
}

class _RoleConfig {
  final String label;
  final IconData icon;
  final Color color;

  _RoleConfig({required this.label, required this.icon, required this.color});
}
