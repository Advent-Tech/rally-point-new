import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/local_storage.dart';
import '../../../data/models/survey_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/survey/survey_bloc.dart';
import '../../widgets/custom_button.dart';
import 'survey_form_screen.dart';
import 'create_survey_screen.dart';
import 'survey_detail_screen.dart';

class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isTeamLeader = false;
  bool _isInitialized = false;
  String? _teamId;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _checkIfTeamLeader();
    // Leaders: 1 tab (Surveys), Workers: 2 tabs (Available, My Responses)
    _tabController = TabController(
      length: _isTeamLeader ? 1 : 2,
      vsync: this,
    );
    // Load surveys on init
    if (mounted) {
      _loadSurveys();
      setState(() => _isInitialized = true);
    }
  }

  void _loadSurveys() {
    context.read<SurveyBloc>().add(SurveyRefresh(
      isLeader: _isTeamLeader,
      teamId: _teamId,
    ));
  }

  Future<void> _checkIfTeamLeader() async {
    try {
      bool isLeader = false;
      String role = '';
      String? teamId;

      // First try to get role from AuthBloc state (most reliable)
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final user = authState.user;
        role = user.role.toLowerCase().trim();
        teamId = user.teamId;
        debugPrint('Survey Screen - Role from AuthBloc: "$role"');
        debugPrint('Survey Screen - TeamId from AuthBloc: "$teamId"');
        debugPrint('Survey Screen - User isTeamLeader: ${user.isTeamLeader}');
        debugPrint('Survey Screen - User isAdmin: ${user.isAdmin}');

        // Use built-in UserModel checks first
        isLeader = user.isTeamLeader || user.isAdmin;

        // Also check for alternative role values
        if (!isLeader) {
          isLeader = role == 'leader' ||
                     role == 'team-leader' ||
                     role == 'teamleader' ||
                     role == 'manager' ||
                     role == 'supervisor';
        }
      }

      // Fallback to LocalStorage for role and teamId
      if (role.isEmpty || teamId == null) {
        final storage = await LocalStorage.getInstance();
        final userData = storage.getUserData();

        // Debug: Print all user data keys to help diagnose
        debugPrint('Survey Screen - Full userData: $userData');
        debugPrint('Survey Screen - userData keys: ${userData?.keys.toList()}');

        if (userData != null) {
          // Check common role field names if not already set
          if (role.isEmpty) {
            role = (userData['role'] ??
                    userData['user_role'] ??
                    userData['userRole'] ??
                    userData['type'] ??
                    userData['user_type'] ??
                    '').toString().toLowerCase().trim();

            debugPrint('Survey Screen - Role from storage: "$role"');

            isLeader = role == 'team_leader' ||
                       role == 'teamleader' ||
                       role == 'admin' ||
                       role == 'leader' ||
                       role == 'team-leader' ||
                       role == 'manager' ||
                       role == 'supervisor';
          }

          // Get teamId from storage if not already set
          teamId ??= userData['team_id']?.toString() ?? userData['teamId']?.toString();
        }
      }

      debugPrint('Survey Screen - Final role: "$role", isLeader: $isLeader, teamId: $teamId');

      if (mounted) {
        setState(() {
          _isTeamLeader = isLeader;
          _teamId = teamId;
        });
      }
    } catch (e) {
      debugPrint('Error checking role: $e');
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _openCreateSurvey() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateSurveyScreen(),
      ),
    );

    if (result == true) {
      // Refresh surveys after creating a new one
      if (mounted) {
        _loadSurveys();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show loading while initializing
    if (!_isInitialized || _tabController == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surveys'),
        // Only show tabs for workers (Available + My Responses)
        // Leaders get a single view with no tabs
        bottom: _isTeamLeader
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Available'),
                  Tab(text: 'My Responses'),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSurveys,
          ),
        ],
      ),
      // FAB for team leaders to create surveys
      floatingActionButton: _isTeamLeader
          ? FloatingActionButton.extended(
              onPressed: _openCreateSurvey,
              icon: const Icon(Icons.add),
              label: const Text('Create Survey'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            )
          : null,
      body: BlocBuilder<SurveyBloc, SurveyState>(
        builder: (context, state) {
          if (state is SurveyLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SurveyError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(state.message),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<SurveyBloc>().add(SurveyRefresh(isLeader: false, teamId: null));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is SurveyLoaded) {
            // Leaders see a single list view, workers see tabs
            if (_isTeamLeader) {
              return _AvailableSurveysTab(isDark: isDark, surveys: state.availableSurveys, isLeader: true);
            }
            return TabBarView(
              controller: _tabController,
              children: [
                _AvailableSurveysTab(isDark: isDark, surveys: state.availableSurveys, isLeader: false),
                _MyResponsesTab(isDark: isDark, responses: state.myResponses),
              ],
            );
          }

          // Default empty state
          if (_isTeamLeader) {
            return _AvailableSurveysTab(isDark: isDark, surveys: const [], isLeader: true);
          }
          return TabBarView(
            controller: _tabController,
            children: [
              _AvailableSurveysTab(isDark: isDark, surveys: const [], isLeader: false),
              _MyResponsesTab(isDark: isDark, responses: const []),
            ],
          );
        },
      ),
    );
  }
}

class _AvailableSurveysTab extends StatelessWidget {
  final bool isDark;
  final List<SurveyModel> surveys;
  final bool isLeader;

  const _AvailableSurveysTab({required this.isDark, required this.surveys, this.isLeader = false});

  @override
  Widget build(BuildContext context) {
    if (surveys.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Surveys Available',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check back later for new surveys',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<SurveyBloc>().add(SurveyRefresh(isLeader: false, teamId: null));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: surveys.length,
        itemBuilder: (context, index) {
          final survey = surveys[index];
          return _SurveyCard(
            survey: survey,
            isDark: isDark,
            isLeader: isLeader,
          );
        },
      ),
    );
  }
}

class _SurveyCard extends StatelessWidget {
  final SurveyModel survey;
  final bool isDark;
  final bool isLeader;

  const _SurveyCard({
    required this.survey,
    required this.isDark,
    this.isLeader = false,
  });

  Color _getCategoryColor(String status) {
    switch (status.toLowerCase()) {
      case 'published':
        return AppColors.success;
      case 'draft':
        return AppColors.warning;
      case 'closed':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _getCategoryColor(survey.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: isLeader ? () => _openDetailScreen(context) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      survey.status.toUpperCase(),
                      style: TextStyle(
                        color: categoryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                survey.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (survey.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  survey.description!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  _InfoItem(
                    icon: Icons.quiz_outlined,
                    label: '${survey.questionCount} questions',
                    isDark: isDark,
                  ),
                  const SizedBox(width: 16),
                  _InfoItem(
                    icon: Icons.people_outline,
                    label: '${survey.responseCount} responses',
                    isDark: isDark,
                  ),
                  const Spacer(),
                  if (survey.isPublished && !isLeader)
                    CustomButton(
                      text: 'Start',
                      size: ButtonSize.small,
                      onPressed: () {
                        _showSurveyDialog(context, survey);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetailScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SurveyDetailScreen(survey: survey),
      ),
    );
  }

  void _showSurveyDialog(BuildContext context, SurveyModel survey) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start Survey'),
        content: Text('Would you like to start "${survey.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Load survey details and navigate to form
              context.read<SurveyBloc>().add(SurveyLoadDetails(surveyId: survey.id));
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider.value(
                    value: BlocProvider.of<SurveyBloc>(context),
                    child: SurveyFormScreen(survey: survey),
                  ),
                ),
              );
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

class _MyResponsesTab extends StatelessWidget {
  final bool isDark;
  final List<SurveyResponse> responses;

  const _MyResponsesTab({required this.isDark, required this.responses});

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 40,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Responses Yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete a survey to see your responses here',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<SurveyBloc>().add(const SurveyLoadResponses());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: responses.length,
        itemBuilder: (context, index) {
          final response = responses[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                ),
              ),
              title: Text(
                'Survey Response',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                response.completedAt != null
                    ? 'Completed on ${_formatDate(response.completedAt!)}'
                    : 'In Progress',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // View response details
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
