import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/data_service.dart';
import '../../../domain/entities/teens_content.dart';
import '../../../domain/entities/event.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/event_tile.dart';
import 'teens_content_list_page.dart';

class TeensPage extends StatefulWidget {
  const TeensPage({super.key});

  @override
  State<TeensPage> createState() => _TeensPageState();
}

class _TeensPageState extends State<TeensPage> {
  final DataService _dataService = DataService();
  
  List<Event> _teensEvents = [];
  List<TeensContent> _devotionals = [];
  List<TeensContent> _retreats = [];
  List<TeensContent> _forgeCamp = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final events = await _dataService.getTeensEvents();
      final devotionals = await _dataService.getDevotionals();
      final retreats = await _dataService.getRetreats();
      final forgeCamp = await _dataService.getForgeCamp();
      
      if (mounted) {
        setState(() {
          _teensEvents = events;
          _devotionals = devotionals;
          _retreats = retreats;
          _forgeCamp = forgeCamp;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading teens data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: const CustomAppBar(title: '', showBackButton: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(bottom: 80 + bottomPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBanner(context, isDark),
                    const SizedBox(height: 24),
                    _buildEventsList(context, isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBanner(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(
          'assets/images/teens_banner.png',
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF9800),
                    Color(0xFFFFB74D),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  'YOUNG ADULTS & TEENS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventsList(BuildContext context, bool isDark) {
    if (_teensEvents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Center(
          child: Text(
            'No events available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: _teensEvents
              .map<Widget>((event) => Column(
                    children: [
                      EventTile(
                        event: event,
                        onTap: () => _navigateToContentList(context, event.title),
                      ),
                      if (_teensEvents.indexOf(event) < _teensEvents.length - 1)
                        Divider(
                          height: 1,
                          indent: 80,
                          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                        ),
                    ],
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _navigateToContentList(BuildContext context, String eventTitle) {
    String title;
    List<TeensContent> contents;
    Color accentColor;

    switch (eventTitle) {
      case 'Daily Devotional':
        title = 'Daily Devotional';
        contents = _devotionals;
        accentColor = AppColors.orange;
        break;
      case 'Teens Retreat':
        title = 'Teens Retreat';
        contents = _retreats;
        accentColor = const Color(0xFF8B0000);
        break;
      case 'The Forge Teens Camp':
        title = 'The Forge Teens Camp';
        contents = _forgeCamp;
        accentColor = AppColors.teal;
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeensContentListPage(
          title: title,
          contents: contents,
          accentColor: accentColor,
        ),
      ),
    );
  }
}
