import 'package:flutter/material.dart';
import '../../../core/network/api_result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/survey_model.dart';
import '../../../data/repositories/survey_repository.dart';
import '../../widgets/navigation/app_back_button.dart';

class SurveyDetailScreen extends StatefulWidget {
  final SurveyModel survey;

  const SurveyDetailScreen({super.key, required this.survey});

  @override
  State<SurveyDetailScreen> createState() => _SurveyDetailScreenState();
}

class _SurveyDetailScreenState extends State<SurveyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SurveyResponse> _responses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadResponses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadResponses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final repository = SurveyRepository();
    final result = await repository.getSurveyResponses(widget.survey.id);

    result.when(
      success: (responses) {
        setState(() {
          _responses = responses;
          _isLoading = false;
        });
      },
      failure: (message, _) {
        setState(() {
          _error = message;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.leading(context, fallbackRoute: '/surveys'),
        title: Text(widget.survey.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Responses'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadResponses,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(
            survey: widget.survey,
            responses: _responses,
            isDark: isDark,
          ),
          _ResponsesTab(
            survey: widget.survey,
            responses: _responses,
            isLoading: _isLoading,
            error: _error,
            isDark: isDark,
            onRetry: _loadResponses,
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final SurveyModel survey;
  final List<SurveyResponse> responses;
  final bool isDark;

  const _OverviewTab({
    required this.survey,
    required this.responses,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final questions = survey.questions ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Survey Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: survey.isActive
                              ? AppColors.success.withAlpha(30)
                              : AppColors.error.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          survey.isActive ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(
                            color: survey.isActive
                                ? AppColors.success
                                : AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (survey.requiresLocation)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppColors.info,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'GPS Required',
                                style: TextStyle(
                                  color: AppColors.info,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (survey.description != null) ...[
                    Text(
                      survey.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.quiz_outlined,
                        value: '${questions.length}',
                        label: 'Questions',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.people_outline,
                        value: '${responses.length}',
                        label: 'Responses',
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Questions Analysis
          Text(
            'Questions Analysis',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (questions.isEmpty)
            Center(
              child: Text(
                'No questions in this survey',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            )
          else
            ...questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              return _QuestionAnalysisCard(
                index: index + 1,
                question: question,
                responses: responses,
                isDark: isDark,
              );
            }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

class _QuestionAnalysisCard extends StatelessWidget {
  final int index;
  final SurveyQuestion question;
  final List<SurveyResponse> responses;
  final bool isDark;

  const _QuestionAnalysisCard({
    required this.index,
    required this.question,
    required this.responses,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Extract answers for this question from all responses
    final answers = <String>[];
    for (final response in responses) {
      final responseAnswers = response.answers ?? [];
      final matchingAnswer = responseAnswers
          .where((a) => a.questionId == question.id)
          .toList();
      if (matchingAnswer.isNotEmpty) {
        final answer = matchingAnswer.first;
        if (answer.value != null && answer.value!.isNotEmpty) {
          answers.add(answer.value!);
        } else if (answer.selectedOptions != null &&
            answer.selectedOptions!.isNotEmpty) {
          answers.addAll(answer.selectedOptions!);
        }
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.text,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    question.questionType.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.info,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${answers.length} responses',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
            if (_isChoiceQuestion(question.questionType) &&
                question.options != null)
              _buildChoiceAnalysis(context, question.options!, answers)
            else if (answers.isNotEmpty)
              _buildTextAnswers(context, answers),
          ],
        ),
      ),
    );
  }

  bool _isChoiceQuestion(String type) {
    return [
      'radio',
      'checkbox',
      'select',
      'boolean',
    ].contains(type.toLowerCase());
  }

  Widget _buildChoiceAnalysis(
    BuildContext context,
    List<String> options,
    List<String> answers,
  ) {
    final counts = <String, int>{};
    for (final option in options) {
      counts[option] = 0;
    }
    for (final answer in answers) {
      if (counts.containsKey(answer)) {
        counts[answer] = counts[answer]! + 1;
      }
    }

    final total = answers.length;

    return Column(
      children: options.map((option) {
        final count = counts[option] ?? 0;
        final percentage = total > 0 ? (count / total * 100) : 0.0;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(option, style: const TextStyle(fontSize: 13)),
                  Text(
                    '$count (${percentage.toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: AppColors.primary.withAlpha(30),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextAnswers(BuildContext context, List<String> answers) {
    // Show first 3 answers as preview
    final preview = answers.take(3).toList();
    final remaining = answers.length - 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...preview.map(
          (answer) => Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              answer,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+ $remaining more responses',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResponsesTab extends StatelessWidget {
  final SurveyModel survey;
  final List<SurveyResponse> responses;
  final bool isLoading;
  final String? error;
  final bool isDark;
  final VoidCallback onRetry;

  const _ResponsesTab({
    required this.survey,
    required this.responses,
    required this.isLoading,
    required this.error,
    required this.isDark,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(error!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (responses.isEmpty) {
      return Center(
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
                Icons.inbox_outlined,
                size: 40,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Responses Yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Responses will appear here once workers submit',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: responses.length,
      itemBuilder: (context, index) {
        final response = responses[index];
        return _ResponseCard(
          response: response,
          survey: survey,
          index: index + 1,
          isDark: isDark,
        );
      },
    );
  }
}

class _ResponseCard extends StatelessWidget {
  final SurveyResponse response;
  final SurveyModel survey;
  final int index;
  final bool isDark;

  const _ResponseCard({
    required this.response,
    required this.survey,
    required this.index,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            '#$index',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          'Response #$index',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (response.completedAt != null)
              Text(
                'Submitted: ${_formatDateTime(response.completedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            if (response.latitude != null && response.longitude != null)
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 12,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${response.latitude!.toStringAsFixed(4)}, ${response.longitude!.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.info),
                  ),
                ],
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (context) {
                debugPrint('ResponseCard: Response ID: ${response.id}');
                debugPrint(
                  'ResponseCard: Answers count: ${response.answers?.length ?? 0}',
                );
                debugPrint(
                  'ResponseCard: Survey questions count: ${survey.questions?.length ?? 0}',
                );
                if (response.answers != null) {
                  for (final a in response.answers!) {
                    debugPrint(
                      'ResponseCard: Answer - questionId: ${a.questionId}, value: ${a.value}',
                    );
                  }
                }

                final answers = response.answers ?? [];
                if (answers.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No answers recorded for this response',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...answers.map((answer) {
                      final question = survey.questions?.firstWhere(
                        (q) => q.id == answer.questionId,
                        orElse: () => SurveyQuestion(
                          id: answer.questionId,
                          surveyId: survey.id,
                          text: 'Unknown Question',
                          questionType: 'text',
                        ),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              question?.text ?? 'Question',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                answer.value ??
                                    answer.selectedOptions?.join(', ') ??
                                    'No answer',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
