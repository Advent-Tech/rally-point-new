import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/network/api_result.dart';
import '../../../data/models/survey_model.dart';
import '../../../data/repositories/survey_repository.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

/// Screen for team leaders to create new surveys
class CreateSurveyScreen extends StatefulWidget {
  const CreateSurveyScreen({super.key});

  @override
  State<CreateSurveyScreen> createState() => _CreateSurveyScreenState();
}

class _CreateSurveyScreenState extends State<CreateSurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _repository = SurveyRepository();

  String? _teamId;
  bool _isLoading = false;
  bool _isLoadingTeam = true;
  bool _requiresLocation = true;
  final List<_QuestionData> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadTeamId();
    // Add one default question
    _addQuestion();
  }

  Future<void> _loadTeamId() async {
    try {
      final storage = await LocalStorage.getInstance();
      final userData = storage.getUserData();
      setState(() {
        _teamId = userData?['team_id']?.toString() ?? userData?['teamId']?.toString();
        _isLoadingTeam = false;
      });
    } catch (e) {
      setState(() => _isLoadingTeam = false);
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_QuestionData(
        textController: TextEditingController(),
        questionType: 'text',
        isRequired: false,
        options: [],
      ));
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() {
        _questions[index].textController.dispose();
        _questions.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Survey must have at least one question'),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  Future<void> _createSurvey() async {
    if (!_formKey.currentState!.validate()) return;

    if (_teamId == null || _teamId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be part of a team to create surveys'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate questions
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.textController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question ${i + 1} text is required'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (q.isChoiceType && q.options.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question ${i + 1} needs at least one option'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    final questions = _questions.asMap().entries.map((entry) {
      final index = entry.key;
      final q = entry.value;
      return CreateQuestionRequest(
        text: q.textController.text.trim(),
        questionType: q.questionType,
        isRequired: q.isRequired,
        orderIndex: index,
        placeholder: q.placeholder?.isNotEmpty == true ? q.placeholder : null,
        options: q.isChoiceType ? q.options : null,
      );
    }).toList();

    final request = CreateSurveyRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      teamId: _teamId!,
      requiresLocation: _requiresLocation,
      questions: questions,
    );

    final result = await _repository.createSurvey(request);

    setState(() => _isLoading = false);

    result.when(
      success: (survey) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Survey created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true); // Return true to indicate success
      },
      failure: (error, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final q in _questions) {
      q.textController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Survey'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _createSurvey,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Save'),
          ),
        ],
      ),
      body: _isLoadingTeam
          ? const Center(child: CircularProgressIndicator())
          : _teamId == null || _teamId!.isEmpty
              ? _buildNoTeamState(context)
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Survey Details Section
                      _buildSectionHeader('Survey Details', Icons.info_outline),
                      const SizedBox(height: 12),
                      CustomTextField(
                        controller: _titleController,
                        label: 'Survey Title',
                        hint: 'Enter a descriptive title',
                        prefixIcon: Icons.title,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        controller: _descriptionController,
                        label: 'Description (Optional)',
                        hint: 'Describe the purpose of this survey',
                        prefixIcon: Icons.description_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Requires Location Toggle
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Require GPS Location',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Light squads must be at the location to submit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _requiresLocation,
                              onChanged: (value) {
                                setState(() => _requiresLocation = value);
                              },
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Questions Section
                      Row(
                        children: [
                          Expanded(
                            child: _buildSectionHeader('Questions', Icons.quiz_outlined),
                          ),
                          TextButton.icon(
                            onPressed: _addQuestion,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Question'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Drag hint
                      if (_questions.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.drag_indicator,
                                size: 16,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Drag to reorder questions',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Questions List with drag-drop reordering
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _questions.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = _questions.removeAt(oldIndex);
                            _questions.insert(newIndex, item);
                          });
                        },
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            elevation: 4,
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: child,
                          );
                        },
                        itemBuilder: (context, index) {
                          return ReorderableDragStartListener(
                            key: ValueKey('question_${_questions[index].hashCode}'),
                            index: index,
                            child: _QuestionCard(
                              index: index,
                              data: _questions[index],
                              isDark: isDark,
                              onRemove: () => _removeQuestion(index),
                              onChanged: () => setState(() {}),
                              showDragHandle: _questions.length > 1,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Add Question Button
                      OutlinedButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Another Question'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Create Button
                      CustomButton(
                        text: 'Create Survey',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _createSurvey,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildNoTeamState(BuildContext context) {
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
                Icons.group_off,
                size: 40,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Team',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You must be part of a team to create surveys.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Go Back',
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    if (_titleController.text.isEmpty && _questions.length == 1 && _questions[0].textController.text.isEmpty) {
      context.pop();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Survey?'),
        content: const Text('Your survey will not be saved. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }
}

// Data class to hold question state
class _QuestionData {
  final TextEditingController textController;
  String questionType;
  bool isRequired;
  List<String> options;
  String? placeholder;

  _QuestionData({
    required this.textController,
    required this.questionType,
    required this.isRequired,
    required this.options,
    this.placeholder,
  });

  bool get isChoiceType =>
      questionType == 'radio' ||
      questionType == 'checkbox' ||
      questionType == 'select';

  bool get needsPlaceholder =>
      questionType == 'text' ||
      questionType == 'textarea' ||
      questionType == 'number';
}

// Question card widget
class _QuestionCard extends StatefulWidget {
  final int index;
  final _QuestionData data;
  final bool isDark;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final bool showDragHandle;

  const _QuestionCard({
    required this.index,
    required this.data,
    required this.isDark,
    required this.onRemove,
    required this.onChanged,
    this.showDragHandle = false,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  final _optionController = TextEditingController();

  static const List<Map<String, dynamic>> _questionTypes = [
    {'value': 'text', 'label': 'Short Text', 'icon': Icons.short_text},
    {'value': 'textarea', 'label': 'Long Text', 'icon': Icons.notes},
    {'value': 'number', 'label': 'Number', 'icon': Icons.numbers},
    {'value': 'date', 'label': 'Date', 'icon': Icons.calendar_today},
    {'value': 'select', 'label': 'Dropdown', 'icon': Icons.arrow_drop_down_circle},
    {'value': 'radio', 'label': 'Single Choice', 'icon': Icons.radio_button_checked},
    {'value': 'checkbox', 'label': 'Multiple Choice', 'icon': Icons.check_box},
    {'value': 'boolean', 'label': 'Yes/No', 'icon': Icons.toggle_on},
    {'value': 'rating', 'label': 'Rating (1-5)', 'icon': Icons.star},
    {'value': 'photo', 'label': 'Photo Upload', 'icon': Icons.camera_alt},
    {'value': 'signature', 'label': 'Signature', 'icon': Icons.draw},
  ];

  void _addOption() {
    final text = _optionController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        widget.data.options.add(text);
        _optionController.clear();
      });
      widget.onChanged();
    }
  }

  void _removeOption(int index) {
    setState(() {
      widget.data.options.removeAt(index);
    });
    widget.onChanged();
  }

  @override
  void dispose() {
    _optionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with question number, drag handle, and delete
            Row(
              children: [
                // Drag handle
                if (widget.showDragHandle)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.drag_indicator,
                      color: widget.isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Question ${widget.index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: widget.onRemove,
                  tooltip: 'Remove question',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Question text
            CustomTextField(
              controller: widget.data.textController,
              label: 'Question Text',
              hint: 'Enter your question',
              onChanged: (_) => widget.onChanged(),
            ),
            const SizedBox(height: 16),

            // Question type dropdown
            DropdownButtonFormField<String>(
              value: widget.data.questionType,
              decoration: InputDecoration(
                labelText: 'Question Type',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(
                  _questionTypes.firstWhere(
                    (t) => t['value'] == widget.data.questionType,
                  )['icon'] as IconData,
                ),
              ),
              items: _questionTypes.map((type) {
                return DropdownMenuItem(
                  value: type['value'] as String,
                  child: Row(
                    children: [
                      Icon(type['icon'] as IconData, size: 20),
                      const SizedBox(width: 8),
                      Text(type['label'] as String),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    widget.data.questionType = value;
                    // Clear options if switching away from choice type
                    if (!widget.data.isChoiceType) {
                      widget.data.options.clear();
                    }
                  });
                  widget.onChanged();
                }
              },
            ),
            const SizedBox(height: 16),

            // Placeholder for text-based questions
            if (widget.data.needsPlaceholder) ...[
              TextField(
                decoration: InputDecoration(
                  labelText: 'Placeholder Text (Optional)',
                  hintText: 'Hint shown to respondent',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.text_fields),
                ),
                onChanged: (value) {
                  widget.data.placeholder = value;
                  widget.onChanged();
                },
              ),
              const SizedBox(height: 16),
            ],

            // Options for choice questions
            if (widget.data.isChoiceType) ...[
              const Text(
                'Options',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...List.generate(widget.data.options.length, (index) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.data.questionType == 'radio'
                            ? Icons.radio_button_off
                            : widget.data.questionType == 'select'
                                ? Icons.circle_outlined
                                : Icons.check_box_outline_blank,
                        size: 18,
                        color: AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.data.options[index])),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _removeOption(index),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _optionController,
                      decoration: InputDecoration(
                        hintText: 'Add option',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => _addOption(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addOption,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Required toggle
            SwitchListTile(
              title: const Text('Required'),
              subtitle: const Text('Respondent must answer this question'),
              value: widget.data.isRequired,
              onChanged: (value) {
                setState(() => widget.data.isRequired = value);
                widget.onChanged();
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
