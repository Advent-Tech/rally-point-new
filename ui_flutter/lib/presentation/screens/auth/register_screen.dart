import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/team_model.dart';
import '../../../data/repositories/team_repository.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

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
  Timer? _searchDebounce;
  final FocusNode _teamSearchFocusNode = FocusNode();
  final LayerLink _teamSearchLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _teamSearchController.addListener(_onTeamSearchChanged);
    _teamSearchFocusNode.addListener(_onTeamSearchFocusChanged);
  }

  @override
  void dispose() {
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
    setState(() {
      _selectedTeam = team;
      _teamSearchController.text = team.name;
    });
    _removeOverlay();
    _teamSearchFocusNode.unfocus();
  }

  void _showOverlay() {
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

      if (text.startsWith('rallypoint://team/')) {
        teamId = text.replaceFirst('rallypoint://team/', '');
      } else if (text.contains('rallypoint.app/team/')) {
        final match = RegExp(r'rallypoint\.app/team/([^/?]+)').firstMatch(text);
        teamId = match?.group(1);
      }

      if (teamId != null && teamId.isNotEmpty) {
        // Fetch team by ID
        final result = await _teamRepository.getTeamById(teamId);
        switch (result) {
          case ApiSuccess<TeamModel>(:final data):
            _selectTeam(data);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Found team: ${data.name}'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          case ApiFailure<TeamModel>(:final message):
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Team not found: $message'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid team link. Please paste a valid team invite link.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to access clipboard'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleRegister() {
    if (_formKey.currentState?.validate() ?? false) {
      // Validate team requirements
      if (_selectedRole == 'worker' && _selectedTeam == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a team to join as a worker'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (_selectedRole == 'team_leader' && _teamNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a team name to create'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      context.read<AuthBloc>().add(AuthRegister(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim(),
        role: _selectedRole,
        teamName: _selectedRole == 'team_leader' ? _teamNameController.text.trim() : null,
        teamId: _selectedRole == 'worker' && _selectedTeam != null
            ? _selectedTeam!.id
            : null,
      ));
    }
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
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
                          onTap: () => setState(() => _selectedRole = 'team_leader'),
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Team Name (for Team Leaders)
                  if (_selectedRole == 'team_leader') ...[
                    CustomTextField(
                      controller: _teamNameController,
                      label: 'Create Your Team *',
                      hint: 'Enter your team name',
                      prefixIcon: Icons.groups_outlined,
                      validator: (value) {
                        if (_selectedRole == 'team_leader' && (value == null || value.isEmpty)) {
                          return 'Please enter a team name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'As a team leader, you\'ll create and manage your own team',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Team Search (for Workers)
                  if (_selectedRole == 'worker') ...[
                    Text(
                      'Select Your Team *',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
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
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
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
                            label: const Text('Paste\nLink', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.success.withAlpha(50)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: AppColors.success, size: 18),
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
                                        color: AppColors.success.withAlpha(180),
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
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
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
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      return CustomButton(
                        text: _selectedRole == 'team_leader'
                            ? 'Create Team & Account'
                            : 'Create Account',
                        onPressed: _handleRegister,
                        isLoading: state is AuthLoading,
                      );
                    },
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
              ? AppColors.primary.withAlpha(20)
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
                    ? AppColors.primary.withAlpha(30)
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
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
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
