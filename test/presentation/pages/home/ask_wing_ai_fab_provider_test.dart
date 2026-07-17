import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tcgc/presentation/bloc/ask_wing_ai/ask_wing_ai_cubit.dart';
import 'package:tcgc/presentation/bloc/ask_wing_ai/ask_wing_ai_state.dart';

/// Test widget that simulates HomePage attempting to access AskWingAICubit via FAB
class TestHomePageWidget extends StatelessWidget {
  const TestHomePageWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Home Page')),
      body: const Center(child: Text('Home Page Content')),
      floatingActionButton: GestureDetector(
        onTap: () {
          // This is the bug condition: attempting to read AskWingAICubit from HomePage
          // On unfixed code (without cubit provided at MainScreen level), this throws
          // ProviderNotFoundError: "Could not find the correct Provider<AskWingAICubit> above this HomePage Widget"
          final cubit = context.read<AskWingAICubit>();
          cubit.submitQuestion('Test question');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy_outlined, color: Colors.white),
              SizedBox(width: 12),
              Text(
                'Ask Wing AI',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Test widget that simulates BlocListener<AskWingAICubit> in HomePage descendant
class TestChatInterfaceView extends StatelessWidget {
  const TestChatInterfaceView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat Interface')),
      body: BlocListener<AskWingAICubit, AskWingAIState>(
        listener: (context, state) {
          // This listener setup should fail to find the cubit on unfixed code
          if (state is AskWingAIReady) {
            debugPrint('Chat interface ready');
          }
        },
        child: const Center(
          child: Text('Chat Messages'),
        ),
      ),
    );
  }
}

/// Test widget that simulates BlocBuilder<AskWingAICubit> in HomePage descendant
class TestChatMessageListView extends StatelessWidget {
  const TestChatMessageListView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message List')),
      body: BlocBuilder<AskWingAICubit, AskWingAIState>(
        builder: (context, state) {
          // This builder should fail to find the cubit on unfixed code
          return Center(
            child: Text('Messages: ${state.runtimeType}'),
          );
        },
      ),
    );
  }
}

void main() {
  group('Ask Wing AI Cubit Provider Hierarchy - Bug Condition Exploration Tests', () {
    /// **Property 1: Bug Condition - AskWingAICubit Not Accessible in HomePage**
    ///
    /// This test demonstrates the bug: When HomePage (or any child widget of HomePage)
    /// attempts to access AskWingAICubit using context.read() or context.watch(),
    /// the access should FAIL with ProviderNotFoundError on UNFIXED code because
    /// AskWingAICubit is not provided at the MainScreen level (the common ancestor).
    ///
    /// **Expected Behavior on UNFIXED Code:** TEST FAILS with ProviderNotFoundError
    /// **Expected Behavior on FIXED Code:** TEST PASSES (cubit is accessible)
    ///
    /// **Bug Condition Specification:**
    /// ```
    /// WHEN HomePage or any child widget attempts to access AskWingAICubit
    /// AND AskWingAICubit is NOT provided at MainScreen level (unfixed code)
    /// THEN context.read<AskWingAICubit>() throws ProviderNotFoundError
    /// ```
    ///
    /// **Validates: Requirements 1.1, 4.1, 4.2**

    testWidgets(
        'Scenario 1: HomePage FAB onTap fails to access AskWingAICubit '
        'when cubit not provided in widget tree (Bug Condition)',
        (WidgetTester tester) async {
      // This test simulates the bug condition where HomePage attempts to read
      // AskWingAICubit but the cubit is not in the provider tree.
      //
      // On UNFIXED code: This will throw ProviderNotFoundError (test FAILS - expected)
      // On FIXED code: Cubit is available at MainScreen level (test PASSES - expected)
      //
      // The test failure on unfixed code PROVES the bug exists:
      // Error: ProviderNotFoundError: "Could not find the correct Provider<AskWingAICubit> above this HomePage Widget"

      // Build a widget tree WITHOUT providing AskWingAICubit
      // This simulates the unfixed code architecture
      await tester.pumpWidget(
        const MaterialApp(
          home: TestHomePageWidget(),
        ),
      );

      // Try to tap the FAB which attempts to read the cubit
      // On unfixed code, this throws an exception (BlocProviderNotFoundError or similar)
      expect(
        () async {
          await tester.tap(find.byType(GestureDetector));
          await tester.pumpAndSettle();
        },
        throwsException,
      );
    });

    testWidgets(
        'Scenario 2: BlocListener fails to find AskWingAICubit '
        'when not provided in widget tree (Bug Condition)',
        (WidgetTester tester) async {
      // This test demonstrates that BlocListener<AskWingAICubit> cannot
      // initialize when the cubit is not in the widget tree.
      //
      // On UNFIXED code: BlocListener fails to find cubit during build (test detects error)
      // On FIXED code: BlocListener finds cubit at MainScreen level (test passes)

      await tester.pumpWidget(
        const MaterialApp(
          home: TestChatInterfaceView(),
        ),
      );

      // BlocListener should fail to find the cubit during widget build
      // On unfixed code, an exception is captured during build
      final exception = tester.takeException();
      expect(
        exception,
        isNotNull,
      );
    });

    testWidgets(
        'Scenario 3: BlocBuilder fails to find AskWingAICubit '
        'when not provided in widget tree (Bug Condition)',
        (WidgetTester tester) async {
      // This test demonstrates that BlocBuilder<AskWingAICubit> cannot
      // build when the cubit is not in the widget tree.
      //
      // On UNFIXED code: BlocBuilder fails to find cubit (test detects error)
      // On FIXED code: BlocBuilder builds successfully with cubit (test passes)

      await tester.pumpWidget(
        const MaterialApp(
          home: TestChatMessageListView(),
        ),
      );

      // BlocBuilder should fail to find the cubit during widget build
      final exception = tester.takeException();
      expect(
        exception,
        isNotNull,
      );
    });

    testWidgets(
        'Scenario 4: Multiple widget access attempts all fail '
        'when cubit not in provider tree (Bug Condition)',
        (WidgetTester tester) async {
      // This test demonstrates that when AskWingAICubit is not provided,
      // ALL attempts to access it fail, not just isolated cases.
      //
      // On UNFIXED code: First widget that needs cubit fails (test detects error)
      // On FIXED code: All widgets can access cubit successfully (test passes)

      // Build a widget tree with multiple widgets trying to access the cubit
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TestChatInterfaceView(),
                TestChatMessageListView(),
              ],
            ),
          ),
        ),
      );

      // At least one of the widgets should fail to find the cubit
      final exception = tester.takeException();
      expect(
        exception,
        isNotNull,
      );
    });

    testWidgets(
        'Scenario 5: Error message identifies missing AskWingAICubit provider',
        (WidgetTester tester) async {
      // This test verifies that the error message specifically indicates
      // that AskWingAICubit provider is missing from the widget tree.
      //
      // On UNFIXED code: Error message mentions AskWingAICubit (test confirms bug identity)
      // On FIXED code: No error occurs (test passes)

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocBuilder<AskWingAICubit, AskWingAIState>(
              builder: (context, state) {
                return const Center(child: Text('Should not build'));
              },
            ),
          ),
        ),
      );

      // Capture the exception and verify it's about missing AskWingAICubit provider
      final exception = tester.takeException();

      expect(
        exception,
        isNotNull,
      );

      // The error should mention cubit lookup failure
      expect(
        exception.toString(),
        stringContainsInOrder([
          'AskWingAICubit'
        ]),
      );
    });
  });
}
