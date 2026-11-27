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
  bool _isSubmitting = false;
  String? _error;
  int _transcriptId = 0;
  String _title = '';
  String _speakerName = '';
  String _categoryName = '';
  List<Map<String, dynamic>> _questions = [];

  int _currentIndex = 0;
  final Map<int, int> _selectedAnswers = {};
  int _score = 0;
  int _pointsEarned = 0;
  int _totalPoints = 0;
  int _pointsPerQuestion = 10;
  bool _isCompleted = false;
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

        final parsedAnswers = <int, int>{};
        final rawAnswers = data['answers'];
        if (rawAnswers is Map) {
          rawAnswers.forEach((k, v) {
            final idx = int.tryParse(k.toString());
            final opt = v is int ? v : int.tryParse(v.toString());
            if (idx != null && opt != null) {
              parsedAnswers[idx] = opt;
            }
          });
        }

        int startIndex = 0;
        for (int i = 0; i < rawQuestions.length; i++) {
          if (!parsedAnswers.containsKey(i)) {
            startIndex = i;
            break;
          }
        }
        final completed = data['is_completed'] == true ||
            parsedAnswers.length >= rawQuestions.length;

        setState(() {
          _transcriptId = (data['transcript_id'] as int?) ?? 0;
          _title = (data['title'] ?? 'Latest Message').toString();
          _speakerName = (data['speaker_name'] ?? 'The CityGate Church').toString();
          _categoryName = (data['category_name'] ?? 'General').toString();
          _questions = rawQuestions;
          _selectedAnswers
            ..clear()
            ..addAll(parsedAnswers);
          _score = (data['score'] as int?) ?? 0;
          _pointsEarned = (data['points_earned'] as int?) ?? 0;
          _totalPoints = (data['total_points'] as int?) ?? 0;
          _pointsPerQuestion = (data['points_per_question'] as int?) ?? 10;
          _isCompleted = completed;
          _showResults = completed;
          _currentIndex = startIndex;
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

  Future<void> _selectOption(int optionIndex) async {
    if (_isCompleted || _isSubmitting || _selectedAnswers.containsKey(_currentIndex)) {
      return;
    }
    HapticFeedback.selectionClick();
    final qIdx = _currentIndex;

    setState(() {
      _selectedAnswers[qIdx] = optionIndex;
      _isSubmitting = true;
    });

    try {
      final res = await _api.post(ApiConstants.wordQuizAnswer, {
        'transcript_id': _transcriptId,
        'question_index': qIdx,
        'selected_index': optionIndex,
      });
      if (!mounted) return;
      if (res.isSuccess) {
        final d = res.data;
        setState(() {
          _score = (d['score'] as int?) ?? _score;
          _pointsEarned = (d['points_earned'] as int?) ?? _pointsEarned;
          _totalPoints = (d['total_points'] as int?) ?? _totalPoints;
          _isCompleted = d['is_completed'] == true;
          _isSubmitting = false;
        });
      } else {
        setState(() {
          _selectedAnswers.remove(qIdx);
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? 'Could not save your answer.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedAnswers.remove(qIdx);
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error saving answer. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9F6EE),
        appBar: CustomAppBar(
          title: 'Word Quiz',
          showBackButton: true,
          lightBackground: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Quiz History',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WordQuizHistoryPage()),
                );
              },
            ),
          ],
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primaryGold.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGold.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF3C65F), AppColors.primaryGold],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.black, size: 30),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppColors.primaryGold,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Preparing Your 20-Question Word Quiz',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Wing AI is crafting your personalized questions from the latest transcript...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.primaryGold.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.quiz_outlined,
                  size: 42,
                  color: AppColors.primaryGold,
                ),
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
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Gold Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B2110), Color(0xFF473616), Color(0xFF6B501C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 12, color: Colors.black),
                          SizedBox(width: 5),
                          Text(
                            'LATEST MESSAGE',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primaryGold.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stars_rounded,
                              size: 14, color: AppColors.primaryGold),
                          const SizedBox(width: 4),
                          Text(
                            '$_totalPoints pts',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFF6D982),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$_categoryName  •  $_speakerName',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Progress & Score Bar Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryGold.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Question ${_currentIndex + 1} / ${_questions.length}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryGold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Score: $_score/${_questions.length}  •  +$_pointsPerQuestion pts',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween(begin: 0, end: progress),
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Elevated Question Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primaryGold.withValues(alpha: isDark ? 0.22 : 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUESTION ${_currentIndex + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.primaryGold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  (q['question'] ?? '').toString(),
                  style: TextStyle(
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4 Tactile Option Cards
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
              onTap: (isAnswered || _isSubmitting) ? null : () => _selectOption(idx),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.only(bottom: 11),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: borderColor,
                    width: (isAnswered && (isRightOption || isChosen)) ? 1.7 : 1,
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
                      width: 32,
                      height: 32,
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
                          height: 1.35,
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

          // Wing AI Explanation + Next Button
          if (isAnswered) ...[
            if (explanation.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6, bottom: 18),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF282112), AppColors.cardDark]
                        : [const Color(0xFFFFF8E4), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryGold.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: AppColors.primaryGold, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Wing AI Insight',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryGold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      explanation,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentIndex < _questions.length - 1
                          ? 'Next Question (${_currentIndex + 2}/${_questions.length})'
                          : 'View Final Results',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.black, size: 19),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsView(bool isDark) {
    final total = _questions.length;
    final ratio = total > 0 ? _score / total : 0.0;
    final percent = (ratio * 100).round();
    final encouragement = ratio >= 0.8
        ? 'Excellent grasp of the Word!'
        : (ratio >= 0.6
            ? 'Well done! Keep meditating on the message.'
            : 'Keep pressing into the Word—review your takeaways below!');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF5CF6B), AppColors.primaryGold, Color(0xFFB88E22)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: Colors.black, size: 40),
                ),
                const SizedBox(height: 12),
                Text(
                  '$_score / $total  ($percent%)',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+$_pointsEarned pts earned  •  Total: $_totalPoints pts',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  encouragement,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
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
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryGold.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_rounded,
                    size: 18, color: AppColors.primaryGold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quiz completed! New questions unlock automatically when the next transcript is published.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WordQuizHistoryPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_rounded,
                      color: AppColors.primaryGold),
                  label: const Text(
                    'History',
                    style: TextStyle(
                      color: AppColors.primaryGold,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                      fontSize: 15,
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
              'Your Answers (${_questions.length})',
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
                borderRadius: BorderRadius.circular(15),
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
                  if (userIdx != null && userIdx >= 0 && userIdx < opts.length)
                    Text(
                      'Your Answer: ${opts[userIdx]}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isRight ? const Color(0xFF22C55E) : Colors.redAccent,
                      ),
                    ),
                  if (cIdx >= 0 && cIdx < opts.length)
                    Text(
                      'Correct Answer: ${opts[cIdx]}',
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

class WordQuizHistoryPage extends StatefulWidget {
  const WordQuizHistoryPage({super.key});

  @override
  State<WordQuizHistoryPage> createState() => _WordQuizHistoryPageState();
}

class _WordQuizHistoryPageState extends State<WordQuizHistoryPage> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _error;
  int _totalPoints = 0;
  int _totalQuizzes = 0;
  int _completedQuizzes = 0;
  List<Map<String, dynamic>> _attempts = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get(ApiConstants.wordQuizHistory);
      if (!mounted) return;
      if (res.isSuccess) {
        final d = res.data;
        setState(() {
          _totalPoints = (d['total_points'] as int?) ?? 0;
          _totalQuizzes = (d['total_quizzes'] as int?) ?? 0;
          _completedQuizzes = (d['completed_quizzes'] as int?) ?? 0;
          _attempts = (d['attempts'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res.errorMessage ?? 'Could not load quiz history.';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load quiz history. Check your connection.';
        _isLoading = false;
      });
    }
  }

  void _openAttemptReview(Map<String, dynamic> attempt, bool isDark) {
    final questions = (attempt['questions'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final answersRaw = attempt['answers'];
    final answers = <int, int>{};
    if (answersRaw is Map) {
      answersRaw.forEach((k, v) {
        final idx = int.tryParse(k.toString());
        final opt = v is int ? v : int.tryParse(v.toString());
        if (idx != null && opt != null) answers[idx] = opt;
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : const Color(0xFFF9F6EE),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (attempt['title'] ?? 'Word Quiz').toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Score: ${attempt['score']}/${attempt['total_questions']}  •  +${attempt['points_earned']} pts',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: questions.length,
                  itemBuilder: (_, i) {
                    final q = questions[i];
                    final opts = (q['options'] as List? ?? [])
                        .map((e) => e.toString())
                        .toList();
                    final cIdx = q['correct_index'] as int? ?? 0;
                    final userIdx = answers[i];
                    final isRight = userIdx != null && userIdx == cIdx;
                    final exp = (q['explanation'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.cardDark : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: (isRight
                                  ? const Color(0xFF22C55E)
                                  : Colors.redAccent)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q${i + 1}: ${q['question']}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          if (userIdx != null &&
                              userIdx >= 0 &&
                              userIdx < opts.length)
                            Text(
                              'Your Answer: ${opts[userIdx]}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isRight
                                    ? const Color(0xFF22C55E)
                                    : Colors.redAccent,
                              ),
                            ),
                          if (cIdx >= 0 && cIdx < opts.length)
                            Text(
                              'Correct Answer: ${opts[cIdx]}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF22C55E),
                              ),
                            ),
                          if (exp.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              exp,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9F6EE),
        appBar: const CustomAppBar(
          title: 'Word Quiz History',
          showBackButton: true,
          lightBackground: true,
        ),
        body: SafeArea(
          top: false,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryGold),
                )
              : (_error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: _loadHistory,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGold,
                              ),
                              child: const Text('Retry',
                                  style: TextStyle(color: Colors.black)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadHistory,
                      color: AppColors.primaryGold,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2B2110),
                                  Color(0xFF473616),
                                  Color(0xFF6B501C),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGold
                                      .withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGold,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.stars_rounded,
                                      color: Colors.black, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$_totalPoints Points',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$_completedQuizzes completed of $_totalQuizzes quiz${_totalQuizzes == 1 ? '' : 'zes'}',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_attempts.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Column(
                                children: [
                                  Icon(Icons.history_rounded,
                                      size: 48,
                                      color: isDark
                                          ? Colors.white24
                                          : Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No quiz history yet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your completed Word Quiz scores and points will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._attempts.map((att) {
                              final score = att['score'] ?? 0;
                              final totalQ = att['total_questions'] ?? 20;
                              final pts = att['points_earned'] ?? 0;
                              final done = att['is_completed'] == true;
                              return GestureDetector(
                                onTap: () => _openAttemptReview(att, isDark),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.cardDark
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: AppColors.primaryGold
                                          .withValues(alpha: 0.25),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                            alpha: isDark ? 0.14 : 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGold
                                              .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$score/$totalQ',
                                            style: const TextStyle(
                                              color: AppColors.primaryGold,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (att['title'] ?? 'Word Quiz')
                                                  .toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              (att['speaker_name'] ?? '')
                                                  .toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppColors.textSecondaryDark
                                                    : AppColors
                                                        .textSecondaryLight,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primaryGold
                                                        .withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    '+$pts pts',
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.primaryGold,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: (done
                                                            ? const Color(
                                                                0xFF22C55E)
                                                            : Colors.orange)
                                                        .withValues(
                                                            alpha: 0.14),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Text(
                                                    done
                                                        ? 'Completed'
                                                        : 'In Progress',
                                                    style: TextStyle(
                                                      color: done
                                                          ? const Color(
                                                              0xFF22C55E)
                                                          : Colors.orange,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    )),
        ),
      ),
    );
  }
}
