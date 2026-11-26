import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/custom_app_bar.dart';

class WordQuizPage extends StatefulWidget {
  const WordQuizPage({super.key});

  @override
  State<WordQuizPage> createState() => _WordQuizPageState();
}

class _WordQuizPageState extends State<WordQuizPage> {
  final ApiService _api = ApiService();

  bool _isLoading = true;
  String? _error;
  String _title = '';
  String _speakerName = '';
  String _categoryName = '';
  List<Map<String, dynamic>> _questions = [];

  int _currentIndex = 0;
  final Map<int, int> _selectedAnswers = {};
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _api.get(ApiConstants.wordQuiz);
      if (!mounted) return;

      if (res.isSuccess) {
        final data = res.data;
        final rawQuestions = (data['questions'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        if (rawQuestions.isEmpty) {
          setState(() {
            _error = 'No quiz questions available yet.';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _title = (data['title'] ?? 'Latest Message').toString();
          _speakerName = (data['speaker_name'] ?? 'The CityGate Church').toString();
          _categoryName = (data['category_name'] ?? 'General').toString();
          _questions = rawQuestions;
          _currentIndex = 0;
          _selectedAnswers.clear();
          _showResults = false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res.errorMessage ?? 'Could not load Word Quiz. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load Word Quiz. Please check your connection.';
        _isLoading = false;
      });
    }
  }

  int get _score {
    int total = 0;
    for (int i = 0; i < _questions.length; i++) {
      final correctIdx = _questions[i]['correct_index'] as int? ?? -1;
      if (_selectedAnswers[i] == correctIdx) {
        total++;
      }
    }
    return total;
  }

  void _selectOption(int optionIndex) {
    if (_selectedAnswers.containsKey(_currentIndex)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedAnswers[_currentIndex] = optionIndex;
    });
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      setState(() {
        _showResults = true;
      });
    }
  }

  void _retakeQuiz() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentIndex = 0;
      _selectedAnswers.clear();
      _showResults = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFFDFBF5),
        appBar: const CustomAppBar(
          title: 'Word Quiz',
          showBackButton: true,
          lightBackground: true,
        ),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? _buildLoadingState(isDark)
              : (_error != null
                  ? _buildErrorState(isDark)
                  : (_showResults
                      ? _buildResultsView(isDark)
                      : _buildQuizView(isDark))),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: AppColors.primaryGold,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Preparing Your Word Quiz',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wing AI is loading 5 questions from the latest transcript...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 54,
              color: AppColors.primaryGold.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 14),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadQuiz,
              icon: const Icon(Icons.refresh_rounded, color: Colors.black),
              label: const Text(
                'Try Again',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizView(bool isDark) {
    final q = _questions[_currentIndex];
    final options = (q['options'] as List? ?? []).map((e) => e.toString()).toList();
    final correctIndex = q['correct_index'] as int? ?? 0;
    final explanation = (q['explanation'] ?? '').toString();
    final selected = _selectedAnswers[_currentIndex];
    final isAnswered = selected != null;
    final progress = (_currentIndex + 1) / _questions.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Latest Transcript Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2B2412), AppColors.cardDark]
                    : [const Color(0xFFFFF8E1), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryGold.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LATEST TRANSCRIPT',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'By $_speakerName',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Progress Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentIndex + 1} of ${_questions.length}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              Text(
                'Score: $_score/${_questions.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryGold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
            ),
          ),

          const SizedBox(height: 20),

          // Question Text
          Text(
            (q['question'] ?? '').toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.35,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),

          const SizedBox(height: 18),

          // 4 Options
          ...List.generate(options.length, (idx) {
            final letter = String.fromCharCode(65 + idx);
            final isChosen = selected == idx;
            final isRightOption = idx == correctIndex;

            Color bgColor = isDark ? AppColors.cardDark : Colors.white;
            Color borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
            Color badgeBg = AppColors.primaryGold.withValues(alpha: 0.14);
            Color badgeText = AppColors.primaryGold;
            IconData? trailingIcon;
            Color? trailingColor;

            if (isAnswered) {
              if (isRightOption) {
                bgColor = const Color(0xFF22C55E).withValues(alpha: isDark ? 0.18 : 0.1);
                borderColor = const Color(0xFF22C55E);
                badgeBg = const Color(0xFF22C55E);
                badgeText = Colors.white;
                trailingIcon = Icons.check_circle_rounded;
                trailingColor = const Color(0xFF22C55E);
              } else if (isChosen) {
                bgColor = Colors.redAccent.withValues(alpha: isDark ? 0.18 : 0.09);
                borderColor = Colors.redAccent;
                badgeBg = Colors.redAccent;
                badgeText = Colors.white;
                trailingIcon = Icons.cancel_rounded;
                trailingColor = Colors.redAccent;
              }
            }

            return GestureDetector(
              onTap: isAnswered ? null : () => _selectOption(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: borderColor,
                    width: (isAnswered && (isRightOption || isChosen)) ? 1.6 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          letter,
                          style: TextStyle(
                            color: badgeText,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        options[idx],
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      Icon(trailingIcon, color: trailingColor, size: 22),
                    ],
                  ],
                ),
              ),
            );
          }),

          // Wing AI Explanation
          if (isAnswered) ...[
            if (explanation.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6, bottom: 18),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: isDark ? 0.12 : 0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: AppColors.primaryGold, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        explanation,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _currentIndex < _questions.length - 1
                      ? 'Next Question'
                      : 'See Results',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsView(bool isDark) {
    final score = _score;
    final total = _questions.length;
    final ratio = total > 0 ? score / total : 0.0;
    final encouragement = ratio >= 0.8
        ? 'Excellent grasp of the Word!'
        : (ratio >= 0.6
            ? 'Well done! Keep meditating on the message.'
            : 'Keep pressing into the Word—review the takeaways below!');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF3C65F), AppColors.primaryGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: Colors.black, size: 44),
                const SizedBox(height: 10),
                Text(
                  '$score / $total',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  encouragement,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _retakeQuiz,
                  icon: const Icon(Icons.replay_rounded, color: AppColors.primaryGold),
                  label: const Text(
                    'Retake Quiz',
                    style: TextStyle(
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: AppColors.primaryGold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Review Answers',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(_questions.length, (i) {
            final q = _questions[i];
            final opts = (q['options'] as List? ?? []).map((e) => e.toString()).toList();
            final cIdx = q['correct_index'] as int? ?? 0;
            final userIdx = _selectedAnswers[i];
            final isRight = userIdx == cIdx;
            final exp = (q['explanation'] ?? '').toString();

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isRight ? const Color(0xFF22C55E) : Colors.redAccent)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isRight ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isRight ? const Color(0xFF22C55E) : Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Q${i + 1}: ${q['question']}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (cIdx >= 0 && cIdx < opts.length)
                    Text(
                      'Answer: ${opts[cIdx]}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  if (exp.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      exp,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
