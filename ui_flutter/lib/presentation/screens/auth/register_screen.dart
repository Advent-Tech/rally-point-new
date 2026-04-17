import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/team_model.dart';
import '../../../data/repositories/team_repository.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/feedback/app_snackbar.dart';

// Global navigator key for showing dialogs from stream subscription
final _registerNavigatorKey = GlobalKey<NavigatorState>();

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _teamSearchController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'worker';

  // Team search state
  final TeamRepository _teamRepository = TeamRepository();
  List<TeamModel> _teamSearchResults = [];
  TeamModel? _selectedTeam;
  bool _isSearchingTeams = false;
  bool _isSelectingTeam = false; // Flag to prevent re-search after selection
  Timer? _searchDebounce;
  final FocusNode _teamSearchFocusNode = FocusNode();
  final LayerLink _teamSearchLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  // Auth state subscription
  StreamSubscription<AuthState>? _authSubscription;
  bool _dialogShown = false;
  bool _isLoading = false;

  late final AuthBloc _authBloc;

  @override
  void initState() {
    super.initState();
    _teamSearchController.addListener(_onTeamSearchChanged);
    _teamSearchFocusNode.addListener(_onTeamSearchFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set up subscription only once when context is available
    if (_authSubscription == null) {
      _authBloc = context.read<AuthBloc>();
      _authSubscription = _authBloc.stream.listen(_handleAuthState);
      print('📱 Stream subscription set up');
    }
  }

  void _handleAuthState(AuthState state) {
    print('📱 Stream received state: ${state.runtimeType}');
    if (!mounted) {
      print('📱 Widget not mounted, ignoring');
      return;
    }
    if (_dialogShown) {
      print('📱 Dialog already shown, ignoring');
      return;
    }

    if (state is AuthRegistrationSuccess) {
      _dialogShown = true;
      print('📱 Showing registration success dialog');
      _showRegistrationSuccessDialog(state);
    } else if (state is AuthPendingVerification) {
      _dialogShown = true;
      print('📱 Showing pending verification dialog');
      _showPendingVerificationDialog(state);
    } else if (state is AuthError) {
      print('📱 Showing error snackbar');
      AppSnackbar.error(context, message: state.message);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _teamNameController.dispose();
    _teamSearchController.dispose();
    _searchDebounce?.cancel();
    _teamSearchFocusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onTeamSearchFocusChanged() {
    if (!mounted) return;
    if (!_teamSearchFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _removeOverlay();
      });
    }
  }

  void _onTeamSearchChanged() {
    if (!mounted) return;

    // Skip search if we're programmatically setting text after selection
    if (_isSelectingTeam) {
      _isSelectingTeam = false;
      return;
    }

    final query = _teamSearchController.text;

    _searchDebounce?.cancel();

    if (query.length < 2) {
      setState(() {
        _teamSearchResults = [];
      });
      _removeOverlay();
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _searchTeams(query);
    });
  }

  Future<void> _searchTeams(String query) async {
    if (!mounted) return;
    // Don't search if team already selected
    if (_selectedTeam != null) return;

    setState(() => _isSearchingTeams = true);

    try {
      final result = await _teamRepository.searchTeams(query: query, limit: 10);

      if (!mounted) return;

      switch (result) {
        case ApiSuccess<List<TeamModel>>(:final data):
          setState(() {
            _teamSearchResults = data;
            _isSearchingTeams = false;
          });
          if (data.isNotEmpty) {
            _showOverlay();
          } else {
            _removeOverlay();
          }
        case ApiFailure<List<TeamModel>>():
          setState(() {
            _teamSearchResults = [];
            _isSearchingTeams = false;
          });
          _removeOverlay();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _teamSearchResults = [];
        _isSearchingTeams = false;
      });
      _removeOverlay();
    }
  }

  void _selectTeam(TeamModel team) {
    _isSelectingTeam = true; // Prevent re-search when setting text
    _searchDebounce?.cancel(); // Cancel any pending search
    setState(() {
      _selectedTeam = team;
      _teamSearchController.text = team.name;
      _teamSearchResults = []; // Clear search results
    });
    _removeOverlay();
    _teamSearchFocusNode.unfocus();
  }

  void _showOverlay() {
    // Don't show overlay if a team is already selected
    if (_selectedTeam != null) return;

    _removeOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: renderBox.size.width - 48, // Account for padding
        child: CompositedTransformFollower(
          link: _teamSearchLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: _teamSearchResults.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No teams found'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _teamSearchResults.length,
                      itemBuilder: (context, index) {
                        final team = _teamSearchResults[index];
                        return InkWell(
                          onTap: () => _selectTeam(team),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  team.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${team.memberCount} members${team.leaderName != null ? ' • Led by ${team.leaderName}' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _pasteTeamLink() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text ?? '';

      // Parse team link formats:
      // rallypoint://team/{teamId}
      // https://rallypoint.app/team/{teamId}
      String? teamId;
      String? invitationToken;

      if (text.startsWith('rallypoint://team/')) {
        teamId = text.replaceFirst('rallypoint://team/', '');
      } else if (text.contains('rallypoint.app/team/')) {
        final match = RegExp(r'rallypoint\.app/team/([^/?]+)').firstMatch(text);
        teamId = match?.group(1);
      } else {
        // Parse invitation token formats:
        // https://backend.lightsquads.com/api/invitations/join/{token}
        // https://.../join-team?token={token}
        // rallypoint://join-team?token={token}
        final joinPathMatch = RegExp(
          r'/api/invitations/join/([A-Za-z0-9]+)',
        ).firstMatch(text);
        if (joinPathMatch != null) {
          invitationToken = joinPathMatch.group(1);
        } else {
          final tokenQueryMatch = RegExp(
            r'[?&]token=([A-Za-z0-9]+)',
          ).firstMatch(text);
          invitationToken = tokenQueryMatch?.group(1);
        }

        // Accept plain token pasted directly
        invitationToken ??= RegExp(r'^[A-Za-z0-9]{32,}$').hasMatch(text.trim())
            ? text.trim()
            : null;
      }

      if (invitationToken != null && invitationToken.isNotEmpty) {
        final apiClient = await ApiClient.getInstance();
        final infoResponse = await apiClient.get(
          '/api/invitations/info',
          queryParameters: {'token': invitationToken},
        );
        final data = (infoResponse.data as Map<String, dynamic>? ?? {});
        final isValid = data['valid'] == true;
        if (!isValid) {
          if (mounted) {
            AppSnackbar.error(
              context,
              message:
                  data['message']?.toString() ?? 'Invalid invitation link.',
            );
          }
          return;
        }

        final invitedTeamId = data['team_id']?.toString() ?? '';
        if (invitedTeamId.isEmpty) {
          if (mounted) {
            AppSnackbar.error(
              context,
              message: 'Invitation is missing team information.',
            );
          }
          return;
        }

        final invitedEmail = data['email']?.toString();
        if ((invitedEmail ?? '').isNotEmpty &&
            _emailController.text.trim().isEmpty) {
          _emailController.text = invitedEmail!;
        }

        final result = await _teamRepository.getTeamById(invitedTeamId);
        switch (result) {
          case ApiSuccess<TeamModel>(:final data):
            _selectTeam(data);
            if (mounted) {
              AppSnackbar.success(
                context,
                message: 'Invitation accepted for team: ${data.name}',
              );
            }
          case ApiFailure<TeamModel>(:final message):
            if (mounted) {
              AppSnackbar.error(context, message: 'Team not found: $message');
            }
        }
        return;
      }

      if (teamId != null && teamId.isNotEmpty) {
        // Fetch team by ID
        final result = await _teamRepository.getTeamById(teamId);
        switch (result) {
          case ApiSuccess<TeamModel>(:final data):
            _selectTeam(data);
            if (mounted) {
              AppSnackbar.success(context, message: 'Found team: ${data.name}');
            }
          case ApiFailure<TeamModel>(:final message):
            if (mounted) {
              AppSnackbar.error(context, message: 'Team not found: $message');
            }
        }
      } else {
        if (mounted) {
          AppSnackbar.warning(
            context,
            message:
                'Invalid team link. Please paste a valid team invite link.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.error(context, message: 'Failed to access clipboard');
      }
    }
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Validate team requirements for workers
      if (_selectedRole == 'worker' && _selectedTeam == null) {
        AppSnackbar.error(
          context,
          message: 'Please select a team to request joining',
        );
        return;
      }

      // Show loading
      setState(() => _isLoading = true);

      try {
        final apiClient = await ApiClient.getInstance();
        final response = await apiClient.post(
          '/api/auth/register',
          data: {
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
            'display_name': _nameController.text.trim(),
            'role': _selectedRole,
            if (_selectedRole == 'worker' && _selectedTeam != null)
              'team_id': _selectedTeam!.id,
          },
        );

        if (!mounted) return;

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Show success dialog immediately
          _showVerificationEmailSentDialog();
        }
      } catch (e) {
        if (!mounted) return;
        // Extract error message
        String errorMessage = 'Registration failed. Please try again.';
        if (e is DioException && e.response?.data is Map) {
          errorMessage =
              e.response?.data['error'] ??
              e.response?.data['message'] ??
              errorMessage;
        }
        AppSnackbar.error(context, message: errorMessage);
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showVerificationEmailSentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mark_email_read, color: AppColors.success),
            const SizedBox(width: 12),
            const Expanded(child: Text('Verify Your Email')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registration successful! Please check your email to verify your account.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A verification link has been sent to ${_emailController.text.trim()}. '
                      'Please check your inbox and click the link to verify your email.',
                      style: TextStyle(fontSize: 13, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.schedule, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedRole == 'team_leader'
                          ? 'After verifying your email, an admin will review your account.'
                          : 'After verifying your email, the team leader will review your join request.',
                      style: TextStyle(fontSize: 13, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/login');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRegistrationSuccessDialog(AuthRegistrationSuccess state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mark_email_read, color: AppColors.success),
            const SizedBox(width: 12),
            const Expanded(child: Text('Verify Your Email')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A verification link has been sent to ${state.email}. '
                      'Please check your inbox and click the link to verify your email.',
                      style: TextStyle(fontSize: 13, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.schedule, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.role == 'team_leader'
                          ? 'After verifying your email, an admin will review your account.'
                          : 'After verifying your email, the team leader will review your join request.',
                      style: TextStyle(fontSize: 13, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/login');
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  void _showPendingVerificationDialog(AuthPendingVerification state) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(
              state.role == 'team_leader' ? Icons.hourglass_empty : Icons.send,
              color: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Text(
              state.role == 'team_leader'
                  ? 'Pending Verification'
                  : 'Request Sent',
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.role == 'team_leader'
                          ? 'An admin will review your account.'
                          : 'The team leader will review your request.',
                      style: TextStyle(fontSize: 13, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.go('/login');
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Text(
                    'Create Account',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join Rally Point today',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Role Selection
                  Text(
                    'I am registering as a:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          icon: Icons.person,
                          title: 'Worker',
                          subtitle: 'Field work & deliveries',
                          isSelected: _selectedRole == 'worker',
                          onTap: () => setState(() => _selectedRole = 'worker'),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoleCard(
                          icon: Icons.shield,
                          title: 'Team Leader',
                          subtitle: 'Manage a team',
                          isSelected: _selectedRole == 'team_leader',
                          onTap: () =>
                              setState(() => _selectedRole = 'team_leader'),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Name Field
                  CustomTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    prefixIcon: Icons.person_outlined,
                    realtimeValidation: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    realtimeValidation: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Team Leader Info Message
                  if (_selectedRole == 'team_leader') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.info,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Verification Required',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.info,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'After registration, your account will be reviewed by an admin. '
                            'Once verified, you will be assigned to manage a team and receive territory allocations.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  height: 1.4,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Team Search (for Workers)
                  if (_selectedRole == 'worker') ...[
                    Text(
                      'Request to Join a Team *',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your request will be sent to the team leader for approval',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CompositedTransformTarget(
                            link: _teamSearchLayerLink,
                            child: TextFormField(
                              controller: _teamSearchController,
                              focusNode: _teamSearchFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Search for your team...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _isSearchingTeams
                                    ? const Padding(
                                        padding: EdgeInsets.all(12),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.surfaceDark
                                    : AppColors.surfaceLight,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _pasteTeamLink,
                            icon: const Icon(Icons.content_paste, size: 18),
                            label: const Text(
                              'Paste\nLink',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedTeam != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Selected: ${_selectedTeam!.name}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  if (_selectedTeam!.leaderName != null)
                                    Text(
                                      'Led by ${_selectedTeam!.leaderName}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.success.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                setState(() {
                                  _selectedTeam = null;
                                  _teamSearchController.clear();
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Password Field
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Create a password',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outlined,
                    realtimeValidation: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hint: 'Confirm your password',
                    obscureText: _obscureConfirmPassword,
                    prefixIcon: Icons.lock_outlined,
                    realtimeValidation: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Register Button
                  CustomButton(
                    text: _selectedRole == 'team_leader'
                        ? 'Register as Team Leader'
                        : 'Request to Join Team',
                    onPressed: _isLoading ? null : _handleRegister,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
