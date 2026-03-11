/// Widgets barrel export - import all reusable widgets
///
/// Usage:
/// ```dart
/// import 'package:rally_point/presentation/widgets/widgets.dart';
/// ```
library;

// Core widgets
export 'app_logo.dart';
export 'bottom_nav_shell.dart';
export 'custom_button.dart';
export 'custom_text_field.dart';
export 'realtime_notification_badge.dart';
export 'role_badge.dart';
export 'session_tracking_card.dart';
// territory_map_widget removed — replaced by command_center
export 'walkie_bottom_sheet.dart';

// Card components
export 'cards/app_card.dart';

// Loading components
export 'loading/skeleton_loader.dart';

// State components (empty, error, etc.)
export 'states/empty_state.dart';

// Feedback components (snackbars, toasts)
export 'feedback/app_snackbar.dart';

// Sheet components (bottom sheets)
export 'sheets/app_bottom_sheet.dart';

// Survey widgets
export 'survey/dynamic_survey_field.dart';
export 'survey/photo_capture_widget.dart';
export 'survey/signature_pad_widget.dart';

// Stepper components
export 'stepper/step_progress_bar.dart';

// Animation components
export 'animations/staggered_fade_in.dart';
export 'animations/counting_text.dart';
export 'animations/success_check.dart';

// Help / Demo mode
export 'help/help_content.dart';
export 'help/help_fab.dart';
export 'help/help_mode_provider.dart';
export 'help/help_overlay.dart';

// Home screen widgets
export 'home/quick_action_tile.dart';
export 'home/overview_stat_card.dart';
export 'home/todays_plan_card.dart';
export 'home/target_banner.dart';
