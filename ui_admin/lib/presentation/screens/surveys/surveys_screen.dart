import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../data/models/survey_model.dart';
import '../../../data/models/user_model.dart';

/// Question types supported by the survey system
class QuestionType {
  static const String text = 'text';
  static const String textarea = 'textarea';
  static const String number = 'number';
  static const String date = 'date';
  static const String select = 'select';
  static const String radio = 'radio';
  static const String checkbox = 'checkbox';
  static const String rating = 'rating';
  static const String boolean = 'boolean';
  static const String photo = 'photo';
  static const String signature = 'signature';

  static const List<Map<String, String>> all = [
    {'value': text, 'label': 'Short Text', 'icon': 'text_fields'},
    {'value': textarea, 'label': 'Long Text', 'icon': 'notes'},
    {'value': number, 'label': 'Number', 'icon': 'pin'},
    {'value': date, 'label': 'Date', 'icon': 'calendar_today'},
    {'value': select, 'label': 'Dropdown', 'icon': 'arrow_drop_down_circle'},
    {'value': radio, 'label': 'Single Choice', 'icon': 'radio_button_checked'},
    {'value': checkbox, 'label': 'Multiple Choice', 'icon': 'check_box'},
    {'value': rating, 'label': 'Rating (1-5)', 'icon': 'star'},
    {'value': boolean, 'label': 'Yes/No', 'icon': 'toggle_on'},
    {'value': photo, 'label': 'Photo Upload', 'icon': 'photo_camera'},
    {'value': signature, 'label': 'Signature', 'icon': 'draw'},
  ];

  static bool hasOptions(String type) => [select, radio, checkbox].contains(type);
  static bool hasPlaceholder(String type) => [text, textarea, number].contains(type);

  static String getLabel(String type) {
    return all.firstWhere((q) => q['value'] == type, orElse: () => {'label': type})['label']!;
  }

  static IconData getIcon(String type) {
    final iconName = all.firstWhere((q) => q['value'] == type, orElse: () => {'icon': 'help'})['icon']!;
    return _iconMap[iconName] ?? Icons.help;
  }

  static final Map<String, IconData> _iconMap = {
    'text_fields': Icons.text_fields,
    'notes': Icons.notes,
    'pin': Icons.pin,
    'calendar_today': Icons.calendar_today,
    'arrow_drop_down_circle': Icons.arrow_drop_down_circle,
    'radio_button_checked': Icons.radio_button_checked,
    'check_box': Icons.check_box,
    'star': Icons.star,
    'toggle_on': Icons.toggle_on,
    'photo_camera': Icons.photo_camera,
    'draw': Icons.draw,
    'help': Icons.help,
  };
}

class SurveysScreen extends StatefulWidget {
  const SurveysScreen({super.key});

  @override
  State<SurveysScreen> createState() => _SurveysScreenState();
}

class _SurveysScreenState extends State<SurveysScreen> {
  List<SurveyModel> _surveys = [];
  List<UserModel> _workers = [];
  List<TeamModel> _teams = [];
  bool _isLoading = true;
  SurveyModel? _selectedSurvey;
  List<SurveyResponse>? _selectedSurveyResponses;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = await ApiClient.getInstance();

      // Load all surveys
      final surveysResponse = await api.get(ApiConstants.surveys);
      if (surveysResponse.statusCode == 200) {
        final data = surveysResponse.data is List
            ? surveysResponse.data
            : surveysResponse.data['surveys'] ?? [];
        _surveys = (data as List).map((json) => SurveyModel.fromJson(json)).toList();
      }

      // Load all verified workers for assignment
      try {
        final workersResponse = await api.get(ApiConstants.adminWorkersVerified);
        if (workersResponse.statusCode == 200) {
          final data = workersResponse.data is List
              ? workersResponse.data
              : workersResponse.data['workers'] ?? [];
          _workers = (data as List).map((json) => UserModel.fromJson(json)).toList();
        }
      } catch (e) {
        // Fallback: workers might not be available
        debugPrint('Could not load workers: $e');
      }

      // Load all teams for survey assignment
      try {
        final teamsResponse = await api.get(ApiConstants.teams);
        if (teamsResponse.statusCode == 200) {
          final data = teamsResponse.data is List
              ? teamsResponse.data
              : teamsResponse.data['teams'] ?? [];
          _teams = (data as List).map((json) => TeamModel.fromJson(json)).toList();
        }
      } catch (e) {
        debugPrint('Could not load teams: $e');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Failed to load surveys: $e');
    }
  }

  void _showCreateSurveyDialog() async {
    // Reload workers to get fresh data before showing dialog
    try {
      final api = await ApiClient.getInstance();
      debugPrint('Fetching verified workers from: ${ApiConstants.adminWorkersVerified}');
      final workersResponse = await api.get(ApiConstants.adminWorkersVerified);
      debugPrint('Workers response status: ${workersResponse.statusCode}');
      debugPrint('Workers response data: ${workersResponse.data}');
      if (workersResponse.statusCode == 200) {
        final data = workersResponse.data is List
            ? workersResponse.data
            : workersResponse.data['workers'] ?? [];
        debugPrint('Parsed workers count: ${(data as List).length}');
        setState(() {
          _workers = data.map((json) => UserModel.fromJson(json)).toList();
        });
        debugPrint('_workers list length: ${_workers.length}');
      }
    } catch (e) {
      debugPrint('Could not refresh workers: $e');
    }

    final titleController = TextEditingController();
    final descController = TextEditingController();
    bool requiresLocation = false;
    bool assignToAllWorkers = false;
    bool assignToAllTeams = false;
    List<_QuestionData> questions = [];
    List<TeamModel> selectedTeams = [];
    List<UserModel> selectedWorkers = [];

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          child: Container(
            width: 800,
            height: MediaQuery.of(context).size.height * 0.9,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.assignment_add, size: 28, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Text(
                      'Create Survey',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Survey Details Section
                        _SectionHeader(title: 'Survey Details', icon: Icons.info_outline),
                        const SizedBox(height: 12),
                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Survey Title *',
                            hintText: 'Enter a descriptive title for this survey',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText: 'Describe the purpose of this survey',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        // Team Assignment Section
                        _SectionHeader(title: 'Assign to Teams', icon: Icons.groups_outlined),
                        const SizedBox(height: 12),
                        if (_teams.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: AppColors.warning),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No teams available. Please create a team first.',
                                    style: TextStyle(color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          // Assign to all teams toggle
                          Container(
                            decoration: BoxDecoration(
                              color: assignToAllTeams ? AppColors.primary.withAlpha(20) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: assignToAllTeams ? Border.all(color: AppColors.primary) : null,
                            ),
                            child: CheckboxListTile(
                              title: const Text('Assign to all teams'),
                              subtitle: Text(
                                assignToAllTeams
                                    ? 'Survey will be available to all ${_teams.length} teams'
                                    : 'Select this to assign to all teams at once',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: assignToAllTeams ? AppColors.primary : Colors.grey.shade600,
                                ),
                              ),
                              value: assignToAllTeams,
                              onChanged: (v) => setDialogState(() {
                                assignToAllTeams = v ?? false;
                                if (assignToAllTeams) {
                                  selectedTeams = List.from(_teams);
                                } else {
                                  selectedTeams = [];
                                }
                              }),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Individual team selection (only shown when not assigning to all)
                          if (!assignToAllTeams)
                            DropdownSearch<TeamModel>.multiSelection(
                              popupProps: PopupPropsMultiSelection.menu(
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: 'Search teams by name...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                constraints: const BoxConstraints(maxHeight: 300),
                              ),
                              items: _teams,
                              itemAsString: (item) => item.name,
                              filterFn: (item, filter) {
                                return item.name.toLowerCase().contains(filter.toLowerCase());
                              },
                              dropdownDecoratorProps: const DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  labelText: 'Select Teams *',
                                  hintText: 'Choose teams for this survey',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              selectedItems: selectedTeams,
                              onChanged: (v) => setDialogState(() => selectedTeams = v),
                              dropdownBuilder: (context, items) {
                                if (items.isEmpty) return const Text('No teams selected');
                                return Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: items.map((t) => Chip(
                                    label: Text(t.name, style: const TextStyle(fontSize: 12)),
                                    onDeleted: () => setDialogState(() => selectedTeams.remove(t)),
                                  )).toList(),
                                );
                              },
                            ),
                        ],
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Require GPS Location'),
                          subtitle: const Text('Workers must share location when completing this survey'),
                          value: requiresLocation,
                          onChanged: (v) => setDialogState(() => requiresLocation = v),
                          contentPadding: EdgeInsets.zero,
                        ),

                        const SizedBox(height: 24),

                        // Worker Assignment Section
                        _SectionHeader(title: 'Assign to Workers', icon: Icons.people_outline),
                        const SizedBox(height: 12),
                        if (_workers.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: AppColors.warning),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No verified workers available. Survey will be created but not assigned.',
                                    style: TextStyle(color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          // Assign to all workers toggle
                          Container(
                            decoration: BoxDecoration(
                              color: assignToAllWorkers ? AppColors.primary.withAlpha(20) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: assignToAllWorkers ? Border.all(color: AppColors.primary) : null,
                            ),
                            child: CheckboxListTile(
                              title: const Text('Assign to all workers'),
                              subtitle: Text(
                                assignToAllWorkers
                                    ? 'Survey will be assigned to all ${_workers.length} verified workers'
                                    : 'Select this to assign to everyone at once',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: assignToAllWorkers ? AppColors.primary : Colors.grey.shade600,
                                ),
                              ),
                              value: assignToAllWorkers,
                              onChanged: (v) => setDialogState(() {
                                assignToAllWorkers = v ?? false;
                                if (assignToAllWorkers) {
                                  selectedWorkers = List.from(_workers);
                                } else {
                                  selectedWorkers = [];
                                }
                              }),
                              controlAffinity: ListTileControlAffinity.leading,
                              activeColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Individual worker selection (only shown when not assigning to all)
                          if (!assignToAllWorkers)
                            DropdownSearch<UserModel>.multiSelection(
                              popupProps: PopupPropsMultiSelection.menu(
                                showSearchBox: true,
                                searchFieldProps: TextFieldProps(
                                  decoration: InputDecoration(
                                    hintText: 'Search workers by name or email...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                constraints: const BoxConstraints(maxHeight: 300),
                              ),
                              items: _workers,
                              itemAsString: (item) => '${item.fullName} (${item.email})',
                              filterFn: (item, filter) {
                                final q = filter.toLowerCase();
                                return item.fullName.toLowerCase().contains(q) ||
                                    item.email.toLowerCase().contains(q);
                              },
                              dropdownDecoratorProps: const DropDownDecoratorProps(
                                dropdownSearchDecoration: InputDecoration(
                                  labelText: 'Select Workers (Optional)',
                                  hintText: 'Choose specific workers to assign this survey',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              selectedItems: selectedWorkers,
                              onChanged: (v) => setDialogState(() => selectedWorkers = v),
                              dropdownBuilder: (context, items) {
                                if (items.isEmpty) return const Text('No workers selected');
                                return Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: items.map((w) => Chip(
                                    label: Text(w.fullName, style: const TextStyle(fontSize: 12)),
                                    onDeleted: () => setDialogState(() => selectedWorkers.remove(w)),
                                  )).toList(),
                                );
                              },
                            ),
                        ],

                        const SizedBox(height: 24),

                        // Questions Section
                        Row(
                          children: [
                            _SectionHeader(title: 'Questions', icon: Icons.quiz_outlined),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  questions.add(_QuestionData());
                                });
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Question'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (questions.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.quiz_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No questions yet',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Click "Add Question" to create your first question',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: questions.length,
                            onReorder: (oldIndex, newIndex) {
                              setDialogState(() {
                                if (newIndex > oldIndex) newIndex--;
                                final item = questions.removeAt(oldIndex);
                                questions.insert(newIndex, item);
                              });
                            },
                            itemBuilder: (context, index) {
                              return _QuestionCard(
                                key: ValueKey(questions[index].id),
                                index: index,
                                data: questions[index],
                                onDelete: () => setDialogState(() => questions.removeAt(index)),
                                onUpdate: () => setDialogState(() {}),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Footer
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        // Validation
                        if (titleController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a survey title')),
                          );
                          return;
                        }
                        if (!assignToAllTeams && selectedTeams.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select at least one team or assign to all teams')),
                          );
                          return;
                        }
                        if (questions.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please add at least one question')),
                          );
                          return;
                        }
                        // Validate questions
                        for (var i = 0; i < questions.length; i++) {
                          if (questions[i].textController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Question ${i + 1} is missing text')),
                            );
                            return;
                          }
                          if (QuestionType.hasOptions(questions[i].type) && questions[i].options.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Question ${i + 1} needs at least one option')),
                            );
                            return;
                          }
                        }

                        Navigator.pop(context);
                        _createSurvey(
                          title: titleController.text,
                          description: descController.text,
                          teamIds: selectedTeams.map((t) => t.id).toList(),
                          assignToAllTeams: assignToAllTeams,
                          requiresLocation: requiresLocation,
                          questions: questions,
                          workerIds: selectedWorkers.map((w) => w.id).toList(),
                        );
                      },
                      child: const Text('Create Survey'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createSurvey({
    required String title,
    required String description,
    required List<String> teamIds,
    required bool assignToAllTeams,
    required bool requiresLocation,
    required List<_QuestionData> questions,
    required List<String> workerIds,
  }) async {
    try {
      final api = await ApiClient.getInstance();

      // Build questions list
      final questionsList = questions.asMap().entries.map((entry) {
        final q = entry.value;
        return {
          'question_text': q.textController.text,
          'question_type': q.type,
          'is_required': q.isRequired,
          'order_index': entry.key,
          if (q.placeholderController.text.isNotEmpty) 'placeholder': q.placeholderController.text,
          if (QuestionType.hasOptions(q.type)) 'options': q.options,
        };
      }).toList();

      // Create survey with multi-team support
      final response = await api.post(
        ApiConstants.surveys,
        data: {
          'title': title,
          'description': description,
          'team_ids': teamIds,
          'assign_to_all_teams': assignToAllTeams,
          'requires_location': requiresLocation,
          'questions': questionsList,
        },
      );

      // Assign to workers if any selected
      if (workerIds.isNotEmpty && response.statusCode == 201) {
        final surveyId = response.data['id'] ?? response.data['survey']?['id'];
        if (surveyId != null) {
          await api.post(
            '${ApiConstants.surveys}/$surveyId/assignments',
            data: {'worker_ids': workerIds},
          );
        }
      }

      if (mounted && response.statusCode == 201) {
        final teamText = assignToAllTeams ? 'all teams' : '${teamIds.length} team${teamIds.length > 1 ? 's' : ''}';
        final workerText = workerIds.isNotEmpty ? ' and assigned to ${workerIds.length} workers' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Survey created successfully for $teamText$workerText'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create survey: $e')),
        );
      }
    }
  }

  Future<void> _loadSurveyDetails(SurveyModel survey) async {
    try {
      final api = await ApiClient.getInstance();
      final response = await api.get('${ApiConstants.surveys}/${survey.id}/responses');
      if (response.statusCode == 200) {
        final data = response.data is List
            ? response.data
            : response.data['responses'] ?? [];
        setState(() {
          _selectedSurvey = survey;
          _selectedSurveyResponses = (data as List)
              .map((json) => SurveyResponse.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load survey responses: $e');
      setState(() {
        _selectedSurvey = survey;
        _selectedSurveyResponses = [];
      });
    }
  }

  Future<void> _deleteSurvey(SurveyModel survey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Survey'),
        content: Text('Are you sure you want to delete "${survey.title}"? This will also delete all responses.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = await ApiClient.getInstance();
        await api.delete('${ApiConstants.surveys}/${survey.id}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Survey deleted'), backgroundColor: AppColors.success),
          );
        }
        if (_selectedSurvey?.id == survey.id) {
          setState(() {
            _selectedSurvey = null;
            _selectedSurveyResponses = null;
          });
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete survey: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Survey Management'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showCreateSurveyDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create Survey'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Survey List (Left Panel)
                SizedBox(
                  width: 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Surveys (${_surveys.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: _surveys.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _surveys.length,
                                itemBuilder: (context, index) {
                                  final survey = _surveys[index];
                                  final isSelected = _selectedSurvey?.id == survey.id;
                                  return Card(
                                    color: isSelected ? AppColors.primary.withAlpha(20) : null,
                                    child: ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withAlpha(30),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.assignment, color: AppColors.primary),
                                      ),
                                      title: Text(survey.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (survey.description != null)
                                            Text(survey.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              _StatBadge(icon: Icons.quiz_outlined, value: '${survey.questions?.length ?? 0}'),
                                              const SizedBox(width: 8),
                                              _StatBadge(icon: Icons.check_circle_outline, value: '${survey.responseCount}'),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: PopupMenuButton(
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                        ],
                                        onSelected: (value) {
                                          if (value == 'delete') _deleteSurvey(survey);
                                        },
                                      ),
                                      onTap: () => _loadSurveyDetails(survey),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                // Divider
                const VerticalDivider(width: 1),

                // Survey Details (Right Panel)
                Expanded(
                  child: _selectedSurvey == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'Select a survey to view details',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : _SurveyDetailsPanel(
                          survey: _selectedSurvey!,
                          responses: _selectedSurveyResponses ?? [],
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('No surveys yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _showCreateSurveyDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Survey'),
          ),
        ],
      ),
    );
  }
}

// Helper Widgets

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;

  const _StatBadge({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _QuestionData {
  final String id = UniqueKey().toString();
  final TextEditingController textController = TextEditingController();
  final TextEditingController placeholderController = TextEditingController();
  String type = QuestionType.text;
  bool isRequired = false;
  List<String> options = [];
}

class _QuestionCard extends StatefulWidget {
  final int index;
  final _QuestionData data;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  const _QuestionCard({
    super.key,
    required this.index,
    required this.data,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  final _optionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: const Icon(Icons.drag_handle, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Q${widget.index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.data.type,
                    decoration: const InputDecoration(
                      labelText: 'Question Type',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: QuestionType.all.map((q) => DropdownMenuItem(
                      value: q['value'],
                      child: Row(
                        children: [
                          Icon(QuestionType.getIcon(q['value']!), size: 18),
                          const SizedBox(width: 8),
                          Text(q['label']!),
                        ],
                      ),
                    )).toList(),
                    onChanged: (v) {
                      setState(() {
                        widget.data.type = v!;
                        if (!QuestionType.hasOptions(v)) {
                          widget.data.options.clear();
                        }
                      });
                      widget.onUpdate();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: widget.onDelete,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Question Text
            TextField(
              controller: widget.data.textController,
              decoration: const InputDecoration(
                labelText: 'Question Text *',
                hintText: 'Enter your question here',
                border: OutlineInputBorder(),
              ),
            ),

            // Placeholder (for text types)
            if (QuestionType.hasPlaceholder(widget.data.type)) ...[
              const SizedBox(height: 12),
              TextField(
                controller: widget.data.placeholderController,
                decoration: const InputDecoration(
                  labelText: 'Placeholder (Optional)',
                  hintText: 'Hint text shown to respondent',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],

            // Options (for choice types)
            if (QuestionType.hasOptions(widget.data.type)) ...[
              const SizedBox(height: 16),
              const Text('Options', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _optionController,
                      decoration: const InputDecoration(
                        hintText: 'Enter option text',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addOption(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addOption,
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.data.options.asMap().entries.map((entry) {
                  return Chip(
                    label: Text(entry.value),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => widget.data.options.removeAt(entry.key));
                      widget.onUpdate();
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),

            // Required toggle
            Row(
              children: [
                Checkbox(
                  value: widget.data.isRequired,
                  onChanged: (v) {
                    setState(() => widget.data.isRequired = v!);
                    widget.onUpdate();
                  },
                ),
                const Text('Required'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addOption() {
    if (_optionController.text.isNotEmpty) {
      setState(() {
        widget.data.options.add(_optionController.text);
        _optionController.clear();
      });
      widget.onUpdate();
    }
  }
}

class _SurveyDetailsPanel extends StatelessWidget {
  final SurveyModel survey;
  final List<SurveyResponse> responses;

  const _SurveyDetailsPanel({required this.survey, required this.responses});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(survey.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      if (survey.description != null)
                        Text(survey.description!, style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: survey.isActive ? AppColors.success.withAlpha(30) : Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    survey.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: survey.isActive ? AppColors.success : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stats Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatCard(icon: Icons.quiz, label: 'Questions', value: '${survey.questions?.length ?? 0}'),
                const SizedBox(width: 16),
                _StatCard(icon: Icons.check_circle, label: 'Responses', value: '${responses.length}'),
                const SizedBox(width: 16),
                _StatCard(
                  icon: Icons.location_on,
                  label: 'Location',
                  value: survey.requiresLocation ? 'Required' : 'Optional',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tabs
          const TabBar(
            tabs: [
              Tab(text: 'Questions'),
              Tab(text: 'Responses'),
              Tab(text: 'Analytics'),
            ],
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              children: [
                _QuestionsTab(questions: survey.questions ?? []),
                _ResponsesTab(responses: responses, questions: survey.questions ?? []),
                _AnalyticsTab(responses: responses, questions: survey.questions ?? []),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionsTab extends StatelessWidget {
  final List<SurveyQuestion> questions;

  const _QuestionsTab({required this.questions});

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return const Center(child: Text('No questions'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withAlpha(30),
              child: Text('${index + 1}', style: const TextStyle(color: AppColors.primary)),
            ),
            title: Text(q.questionText),
            subtitle: Row(
              children: [
                Icon(QuestionType.getIcon(q.questionType), size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(QuestionType.getLabel(q.questionType)),
                if (q.isRequired) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Required', style: TextStyle(fontSize: 10, color: AppColors.error)),
                  ),
                ],
              ],
            ),
            trailing: q.options != null && q.options!.isNotEmpty
                ? Tooltip(
                    message: q.options!.join(', '),
                    child: Text('${q.options!.length} options', style: TextStyle(color: Colors.grey.shade600)),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _ResponsesTab extends StatelessWidget {
  final List<SurveyResponse> responses;
  final List<SurveyQuestion> questions;

  const _ResponsesTab({required this.responses, required this.questions});

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No responses yet', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: responses.length,
      itemBuilder: (context, index) {
        final response = responses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withAlpha(30),
              child: Text('${index + 1}', style: const TextStyle(color: AppColors.primary)),
            ),
            title: Text(response.userName ?? 'Anonymous'),
            subtitle: Text(
              response.createdAt != null
                  ? '${response.createdAt!.day}/${response.createdAt!.month}/${response.createdAt!.year}'
                  : 'Unknown date',
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (response.latitude != null && response.longitude != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text('${response.latitude!.toStringAsFixed(6)}, ${response.longitude!.toStringAsFixed(6)}'),
                          ],
                        ),
                      ),
                    ...?response.answers?.map((answer) {
                      final question = questions.firstWhere(
                        (q) => q.id == answer.questionId,
                        orElse: () => SurveyQuestion(
                          id: answer.questionId,
                          surveyId: response.surveyId,
                          questionText: 'Unknown Question',
                          questionType: 'text',
                        ),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                question.questionText,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 3,
                              child: Text(answer.displayValue.isEmpty ? '(No answer)' : answer.displayValue),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  final List<SurveyResponse> responses;
  final List<SurveyQuestion> questions;

  const _AnalyticsTab({required this.responses, required this.questions});

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No data for analytics', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text('Responses will appear here', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        return _QuestionAnalyticsCard(
          question: question,
          responses: responses,
        );
      },
    );
  }
}

class _QuestionAnalyticsCard extends StatelessWidget {
  final SurveyQuestion question;
  final List<SurveyResponse> responses;

  const _QuestionAnalyticsCard({required this.question, required this.responses});

  @override
  Widget build(BuildContext context) {
    final isChoiceQuestion = QuestionType.hasOptions(question.questionType) ||
        question.questionType == QuestionType.boolean ||
        question.questionType == QuestionType.rating;

    // Collect answers for this question
    final answers = <String>[];
    for (final response in responses) {
      final answer = response.answers?.firstWhere(
        (a) => a.questionId == question.id,
        orElse: () => SurveyAnswer(id: '', responseId: '', questionId: ''),
      );
      if (answer != null && answer.id.isNotEmpty) {
        if (answer.selectedOptions != null && answer.selectedOptions!.isNotEmpty) {
          answers.addAll(answer.selectedOptions!);
        } else if (answer.answer != null && answer.answer!.isNotEmpty) {
          answers.add(answer.answer!);
        }
      }
    }

    // Count occurrences for choice questions
    final optionCounts = <String, int>{};
    if (isChoiceQuestion) {
      for (final answer in answers) {
        optionCounts[answer] = (optionCounts[answer] ?? 0) + 1;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(QuestionType.getIcon(question.questionType), color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.questionText,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${answers.length} responses',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (isChoiceQuestion && optionCounts.isNotEmpty) ...[
              // Bar chart for choice questions
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: optionCounts.values.fold(0, (max, v) => v > max ? v : max).toDouble() + 1,
                    barGroups: optionCounts.entries.toList().asMap().entries.map((entry) {
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value.value.toDouble(),
                            color: AppColors.primary,
                            width: 20,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final keys = optionCounts.keys.toList();
                            if (value.toInt() < keys.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  keys[value.toInt()].length > 10
                                      ? '${keys[value.toInt()].substring(0, 10)}...'
                                      : keys[value.toInt()],
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Legend
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: optionCounts.entries.map((entry) {
                  final percentage = (entry.value / answers.length * 100).toStringAsFixed(1);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('${entry.key}: ${entry.value} ($percentage%)', style: const TextStyle(fontSize: 13)),
                    ],
                  );
                }).toList(),
              ),
            ] else ...[
              // Text answers preview
              ...answers.take(5).map((answer) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(answer, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              )),
              if (answers.length > 5)
                Text(
                  '+${answers.length - 5} more responses',
                  style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
