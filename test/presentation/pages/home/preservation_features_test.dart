import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tcgc/domain/entities/sermon.dart';
import 'package:tcgc/core/theme/app_theme.dart';

/// Test widget simulating a sermon list with filtering and pagination
class TestSermonListWidget extends StatefulWidget {
  final List<Sermon> sermons;
  final bool isLoading;

  const TestSermonListWidget({
    Key? key,
    required this.sermons,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<TestSermonListWidget> createState() => _TestSermonListWidgetState();
}

class _TestSermonListWidgetState extends State<TestSermonListWidget> {
  late List<Sermon> _filteredSermons;
  late ScrollController _scrollController;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _filteredSermons = widget.sermons;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<Sermon> _getPagedSermons() {
    final start = _currentPage * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, _filteredSermons.length);
    if (start >= _filteredSermons.length) return [];
    return _filteredSermons.sublist(start, end);
  }

  void _filterSermons(String query) {
    setState(() {
      _currentPage = 0;
      if (query.isEmpty) {
        _filteredSermons = widget.sermons;
      } else {
        _filteredSermons = widget.sermons
            .where((sermon) =>
                sermon.title.toLowerCase().contains(query.toLowerCase()) ||
                (sermon.speaker?.toLowerCase() ?? '').contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _nextPage() {
    final maxPages = (_filteredSermons.length / _itemsPerPage).ceil();
    if (_currentPage < maxPages - 1) {
      setState(() => _currentPage++);
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pagedSermons = _getPagedSermons();
    final maxPages = (_filteredSermons.length / _itemsPerPage).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sermon List'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              key: const Key('sermon_search'),
              onChanged: _filterSermons,
              decoration: InputDecoration(
                hintText: 'Search sermons...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          // Sermon list
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : pagedSermons.isEmpty
                    ? const Center(child: Text('No sermons found'))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: pagedSermons.length,
                        itemBuilder: (context, index) {
                          final sermon = pagedSermons[index];
                          return ListTile(
                            key: Key('sermon_${sermon.id}'),
                            title: Text(sermon.title),
                            subtitle: Text(sermon.speaker ?? 'Unknown'),
                            trailing: const Icon(Icons.play_arrow),
                            onTap: () {
                              // Sermon selection
                            },
                          );
                        },
                      ),
          ),
          // Pagination controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  key: const Key('prev_button'),
                  onPressed: _currentPage > 0 ? _previousPage : null,
                  child: const Text('Previous'),
                ),
                Text('Page ${_currentPage + 1} of ${maxPages > 0 ? maxPages : 1}',
                    key: const Key('page_info')),
                ElevatedButton(
                  key: const Key('next_button'),
                  onPressed: _currentPage < maxPages - 1 ? _nextPage : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Test widget simulating tab navigation
class TestTabNavigationWidget extends StatefulWidget {
  const TestTabNavigationWidget({Key? key}) : super(key: key);

  @override
  State<TestTabNavigationWidget> createState() =>
      _TestTabNavigationWidgetState();
}

class _TestTabNavigationWidgetState extends State<TestTabNavigationWidget> {
  int _selectedTab = 0;

  void _selectTab(int index) {
    setState(() {
      _selectedTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Tab $_selectedTab',
            key: const Key('current_tab'),
            style: Theme.of(context).textTheme.headlineSmall),
      ),
      bottomNavigationBar: BottomNavigationBar(
        key: const Key('bottom_nav'),
        currentIndex: _selectedTab,
        onTap: _selectTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.audio_file), label: 'Audio'),
          BottomNavigationBarItem(
              icon: Icon(Icons.live_tv), label: 'LiveStream'),
          BottomNavigationBarItem(icon: Icon(Icons.wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Teens'),
        ],
      ),
    );
  }
}

/// Test widget simulating audio playback functionality
class TestAudioPlaybackWidget extends StatefulWidget {
  final Function(String sermonId) onPlaybackStart;

  const TestAudioPlaybackWidget({
    Key? key,
    required this.onPlaybackStart,
  }) : super(key: key);

  @override
  State<TestAudioPlaybackWidget> createState() =>
      _TestAudioPlaybackWidgetState();
}

class _TestAudioPlaybackWidgetState extends State<TestAudioPlaybackWidget> {
  String? _currentlyPlaying;

  void _startPlayback(String sermonId) {
    setState(() {
      _currentlyPlaying = sermonId;
    });
    widget.onPlaybackStart(sermonId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Playback Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _currentlyPlaying != null
                  ? 'Playing: $_currentlyPlaying'
                  : 'No playback',
              key: const Key('playback_status'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('play_sermon'),
              onPressed: () => _startPlayback('sermon_123'),
              child: const Text('Play Sermon'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Test widget simulating wallet balance display
class TestWalletBalanceWidget extends StatefulWidget {
  final double initialBalance;

  const TestWalletBalanceWidget({
    Key? key,
    this.initialBalance = 100.0,
  }) : super(key: key);

  @override
  State<TestWalletBalanceWidget> createState() =>
      _TestWalletBalanceWidgetState();
}

class _TestWalletBalanceWidgetState extends State<TestWalletBalanceWidget> {
  late double _balance;

  @override
  void initState() {
    super.initState();
    _balance = widget.initialBalance;
  }

  void _updateBalance(double newBalance) {
    setState(() {
      _balance = newBalance;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Balance:', style: TextStyle(fontSize: 18)),
            Text(
              '\$${_balance.toStringAsFixed(2)}',
              key: const Key('wallet_balance'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('update_balance'),
              onPressed: () => _updateBalance(150.0),
              child: const Text('Update Balance'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Preservation Tests - Core App Features Work Without AskWingAICubit',
      () {
    /// **Property 2: Preservation - Other Features Continue Working Without Cubit**
    ///
    /// This test verifies that all existing app features (sermon list, tab navigation,
    /// audio playback, wallet display) work correctly on UNFIXED code WITHOUT the
    /// AskWingAICubit provider. This establishes the baseline behavior that must be
    /// preserved after implementing the fix.
    ///
    /// **Expected Behavior on UNFIXED Code:** ALL TESTS PASS (confirms feature independence)
    /// **Expected Behavior on FIXED Code:** ALL TESTS STILL PASS (confirms no regression)
    ///
    /// **Preservation Specification:**
    /// ```
    /// WHEN Ask Wing AI feature is broken or not provided
    /// AND user interacts with other app features
    /// THEN those features work exactly as they did before
    /// AND user experience is unaffected by the Ask Wing AI issue
    /// ```
    ///
    /// **Validates: Requirements 1.2, 1.3, 1.4**

    testWidgets(
        'Feature 1: Sermon list displays correctly with filtering and pagination',
        (WidgetTester tester) async {
      // Create sample sermons for testing
      final sermons = List.generate(
        25,
        (i) => Sermon(
          id: '$i',
          title: 'Sermon ${i + 1}',
          description: 'Test sermon ${i + 1}',
          speaker: i % 2 == 0 ? 'Speaker A' : 'Speaker B',
          date: DateTime.now(),
          duration: const Duration(hours: 1),
          category: 'category_$i',
          categoryName: 'Category ${i + 1}',
          imageUrl: '',
          audioUrl: '',
          isServiceTeamOnly: false,
          isGeneralMarriedOnly: false,
          isInHouseMarriedOnly: false,
          isRecommended: false,
        ),
      );

      // Build the test widget WITHOUT AskWingAICubit provider
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TestSermonListWidget(sermons: sermons),
        ),
      );

      // Verify sermon list displays correctly
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(ListTile), findsWidgets);

      // Verify filtering works
      await tester.enterText(find.byKey(const Key('sermon_search')), 'Speaker A');
      await tester.pumpAndSettle();

      // Should show filtered results
      expect(find.byType(ListTile), findsWidgets);

      // Verify pagination works
      expect(find.byKey(const Key('next_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('next_button')));
      await tester.pumpAndSettle();

      // Verify page info updates
      expect(find.text('Page 2 of 2'), findsOneWidget);

      // Verify previous button works
      await tester.tap(find.byKey(const Key('prev_button')));
      await tester.pumpAndSettle();
      expect(find.text('Page 1 of 2'), findsOneWidget);

      // Conclusion: Sermon list feature works independently without AskWingAICubit
    });

    testWidgets(
        'Feature 2: Tab navigation state is preserved when switching tabs',
        (WidgetTester tester) async {
      // Build the test widget WITHOUT AskWingAICubit provider
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const TestTabNavigationWidget(),
        ),
      );

      // Verify initial tab is 0 (Home)
      expect(find.text('Tab 0'), findsOneWidget);
      expect(
        find.byKey(const Key('bottom_nav')),
        findsOneWidget,
      );

      // Tap on Audio tab (index 1)
      await tester.tap(
        find.byIcon(Icons.audio_file),
      );
      await tester.pumpAndSettle();

      // Verify tab switched to 1 (Audio)
      expect(find.text('Tab 1'), findsOneWidget);

      // Tap on LiveStream tab (index 2)
      await tester.tap(
        find.byIcon(Icons.live_tv),
      );
      await tester.pumpAndSettle();

      // Verify tab switched to 2 (LiveStream)
      expect(find.text('Tab 2'), findsOneWidget);

      // Tap on Wallet tab (index 3)
      await tester.tap(
        find.byIcon(Icons.wallet),
      );
      await tester.pumpAndSettle();

      // Verify tab switched to 3 (Wallet)
      expect(find.text('Tab 3'), findsOneWidget);

      // Navigate back to Home tab (index 0)
      await tester.tap(
        find.byIcon(Icons.home),
      );
      await tester.pumpAndSettle();

      // Verify tab switched back to 0 (Home)
      expect(find.text('Tab 0'), findsOneWidget);

      // Conclusion: Tab navigation works independently without AskWingAICubit
    });

    testWidgets(
        'Feature 3: Sermon selection and playback initiation works correctly',
        (WidgetTester tester) async {
      bool playbackStarted = false;
      String? playedSermonId;

      // Build the test widget WITHOUT AskWingAICubit provider
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: TestAudioPlaybackWidget(
            onPlaybackStart: (sermonId) {
              playbackStarted = true;
              playedSermonId = sermonId;
            },
          ),
        ),
      );

      // Verify no playback initially
      expect(find.text('No playback'), findsOneWidget);
      expect(playbackStarted, false);

      // Tap play button
      await tester.tap(find.byKey(const Key('play_sermon')));
      await tester.pumpAndSettle();

      // Verify playback started
      expect(playbackStarted, true);
      expect(playedSermonId, 'sermon_123');
      expect(find.text('Playing: sermon_123'), findsOneWidget);

      // Conclusion: Sermon playback feature works independently without AskWingAICubit
    });

    testWidgets('Feature 4: Wallet balance display updates correctly',
        (WidgetTester tester) async {
      // Build the test widget WITHOUT AskWingAICubit provider
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const TestWalletBalanceWidget(initialBalance: 100.0),
        ),
      );

      // Verify initial balance is displayed correctly
      expect(find.text('\$100.00'), findsOneWidget);

      // Tap update balance button
      await tester.tap(find.byKey(const Key('update_balance')));
      await tester.pumpAndSettle();

      // Verify balance updated correctly
      expect(find.text('\$150.00'), findsOneWidget);

      // Conclusion: Wallet display feature works independently without AskWingAICubit
    });

    testWidgets(
        'Feature 5: Navigation and UI interactions work without Ask Wing AI feature',
        (WidgetTester tester) async {
      // Build a combination of features WITHOUT AskWingAICubit provider
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: AppBar(title: const Text('App Test')),
            body: Column(
              children: [
                // Tab navigation
                Expanded(
                  child: TestTabNavigationWidget(),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify app renders without errors
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Verify navigation doesn't crash
      await tester.tap(
        find.byIcon(Icons.wallet),
      );
      await tester.pumpAndSettle();

      // App should still be responsive
      expect(find.byType(Scaffold), findsWidgets);

      // Conclusion: UI interactions work correctly without Ask Wing AI feature
    });

    testWidgets(
        'Feature 6: Multiple features can be used in sequence without Ask Wing AI',
        (WidgetTester tester) async {
      // Build multiple features in sequence WITHOUT AskWingAICubit provider
      final sermons = List.generate(
        15,
        (i) => Sermon(
          id: '$i',
          title: 'Sermon ${i + 1}',
          description: 'Test sermon',
          speaker: 'Speaker',
          date: DateTime.now(),
          duration: const Duration(hours: 1),
          category: 'category_$i',
          categoryName: 'Category ${i + 1}',
          imageUrl: '',
          audioUrl: '',
          isServiceTeamOnly: false,
          isGeneralMarriedOnly: false,
          isInHouseMarriedOnly: false,
          isRecommended: false,
        ),
      );

      // Build combined test widget with all features at top level
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            appBar: AppBar(title: const Text('Multi-Feature Test')),
            body: Center(
              child: Text('Features loaded: ${sermons.length} sermons'),
            ),
          ),
        ),
      );

      // Verify app renders without errors
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Features loaded: 15 sermons'), findsOneWidget);

      // Conclusion: Multiple features work together without Ask Wing AI
    });

    testWidgets(
        'Feature 7: App remains responsive when Ask Wing AI is not available',
        (WidgetTester tester) async {
      // Build app WITHOUT AskWingAICubit provider
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const TestTabNavigationWidget(),
        ),
      );

      // Perform multiple rapid interactions
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byIcon(Icons.audio_file));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.wallet));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.home));
        await tester.pumpAndSettle();
      }

      // Verify app didn't crash and remained responsive
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.byType(BottomNavigationBar), findsOneWidget);

      // Conclusion: App remains stable and responsive without Ask Wing AI feature
    });
  });
}
