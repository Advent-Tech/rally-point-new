import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/survey_model.dart';
import '../../blocs/survey/survey_bloc.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/animations/success_check.dart';
import '../../widgets/survey/dynamic_survey_field.dart';

/// Survey form screen for workers to fill out survey questions
class SurveyFormScreen extends StatefulWidget {
  final SurveyModel survey;

  const SurveyFormScreen({super.key, required this.survey});

  @override
  State<SurveyFormScreen> createState() => _SurveyFormScreenState();
}

class _SurveyFormScreenState extends State<SurveyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _textControllers = {};
  late PageController _pageController;
  bool _isSubmitting = false;
  int _currentQuestionIndex = 0;
  double? _latitude;
  double? _longitude;

  List<SurveyQuestion> get _questions {
    final questions = widget.survey.questions?.toList() ?? [];
    questions.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return questions;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _getCurrentLocation();
    // Initialize text controllers for text questions
    for (final question in _questions) {
      if (question.isTextQuestion || question.isNumberQuestion) {
        _textControllers[question.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (widget.survey.requiresLocation) {
            _showLocationError('Location permission is required for this survey');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (widget.survey.requiresLocation) {
          _showLocationError('Location permission is permanently denied. Please enable it in settings.');
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      debugPrint('Could not get location: $e');
      if (widget.survey.requiresLocation) {
        _showLocationError('Could not get your location. Please try again.');
      }
    }
  }

  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _getCurrentLocation,
        ),
      ),
    );
  }

  void _submitSurvey() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please answer all required questions'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check if location is required
    if (widget.survey.requiresLocation && (_latitude == null || _longitude == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This survey requires your GPS location'),
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: 'Get Location',
            textColor: Colors.white,
            onPressed: _getCurrentLocation,
          ),
        ),
      );
      return;
    }

    // Check required questions
    for (final question in _questions) {
      if (question.isRequired && !_hasAnswer(question)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please answer: ${question.text}'),
            backgroundColor: AppColors.error,
          ),
        );
        // Navigate to the question
        final index = _questions.indexOf(question);
        setState(() => _currentQuestionIndex = index);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    // Build answers list
    final answersList = <Map<String, dynamic>>[];
    for (final question in _questions) {
      final answer = _answers[question.id];
      if (answer != null) {
        final answerMap = <String, dynamic>{
          'question_id': question.id,
        };

        if (question.isChoiceQuestion) {
          // Radio, checkbox, select questions
          if (answer is List) {
            answerMap['selected_options'] = answer.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
          } else {
            answerMap['selected_options'] = [answer.toString()];
          }
        } else if (question.isPhotoQuestion) {
          // Photo question - list of photo paths/urls
          if (answer is List) {
            answerMap['photo_urls'] = answer.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList();
          } else {
            answerMap['photo_urls'] = <String>[];
          }
        } else if (question.isSignatureQuestion) {
          // Signature question - convert Uint8List to base64 string
          if (answer is Uint8List) {
            answerMap['signature_url'] = 'data:image/png;base64,${base64Encode(answer)}';
          } else if (answer is String && answer.isNotEmpty) {
            answerMap['signature_url'] = answer;
          } else {
            // Skip if no valid signature
            continue;
          }
        } else {
          // Text, number, date, rating, boolean questions
          final valueStr = answer.toString();
          if (valueStr.isNotEmpty) {
            answerMap['value'] = valueStr;
          } else {
            continue;
          }
        }

        answersList.add(answerMap);
      }
    }

    context.read<SurveyBloc>().add(SurveySubmit(
      surveyId: widget.survey.id,
      answers: answersList,
      latitude: _latitude,
      longitude: _longitude,
    ));
  }

  bool _hasAnswer(SurveyQuestion question) {
    final answer = _answers[question.id];
    if (answer == null) return false;
    if (answer is String && answer.isEmpty) return false;
    if (answer is List && answer.isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<SurveyBloc, SurveyState>(
      listener: (context, state) {
        if (state is SurveySubmitSuccess) {
          SuccessOverlay.show(context, message: 'Survey submitted!').then((_) {
            if (context.mounted) context.pop();
          });
        } else if (state is SurveyError) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.survey.title),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _showExitConfirmation(context),
          ),
        ),
        body: _questions.isEmpty
            ? _buildNoQuestionsState(context)
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Progress indicator
                    LinearProgressIndicator(
                      value: (_currentQuestionIndex + 1) / _questions.length,
                      backgroundColor: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          if (_latitude != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Location captured',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.success,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // Question content
                    Expanded(
                      child: PageView.builder(
                        itemCount: _questions.length,
                        onPageChanged: (index) {
                          setState(() => _currentQuestionIndex = index);
                        },
                        controller: _pageController,
                        physics: const ClampingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final question = _questions[index];
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: _buildQuestionWidget(question, isDark),
                          );
                        },
                      ),
                    ),

                    // Navigation buttons
                    Container(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          if (_currentQuestionIndex > 0)
                            Expanded(
                              child: CustomButton(
                                text: 'Previous',
                                type: ButtonType.outline,
                                onPressed: () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            ),
                          if (_currentQuestionIndex > 0)
                            const SizedBox(width: 16),
                          Expanded(
                            child: _currentQuestionIndex < _questions.length - 1
                                ? CustomButton(
                                    text: 'Next',
                                    onPressed: () {
                                      _pageController.nextPage(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                  )
                                : CustomButton(
                                    text: 'Submit',
                                    isLoading: _isSubmitting,
                                    onPressed: _isSubmitting ? null : _submitSurvey,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildNoQuestionsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz_outlined, size: 64, color: AppColors.warning),
            const SizedBox(height: 24),
            Text(
              'No Questions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This survey has no questions to answer.',
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

  Widget _buildQuestionWidget(SurveyQuestion question, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question text
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                question.text,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (question.isRequired)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),

        // Answer input based on question type
        _buildAnswerInput(question, isDark),
      ],
    );
  }

  Widget _buildAnswerInput(SurveyQuestion question, bool isDark) {
    return DynamicSurveyField(
      question: question,
      currentValue: _answers[question.id],
      textController: _textControllers[question.id],
      onValueChanged: (value) {
        setState(() {
          _answers[question.id] = value;
        });

        // Auto-advance for single-select questions (radio, boolean, select, rating)
        // but not for checkbox (multiple select) or text fields
        final isSingleSelect = question.questionType == QuestionType.radio ||
            question.questionType == QuestionType.boolean ||
            question.questionType == QuestionType.yesNo ||
            question.questionType == QuestionType.select ||
            question.questionType == QuestionType.rating;

        if (isSingleSelect && value != null && _currentQuestionIndex < _questions.length - 1) {
          // Small delay to show the selection before advancing
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      },
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit Survey?'),
        content: const Text(
          'Your progress will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}
