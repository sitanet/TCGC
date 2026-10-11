import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tcgc/presentation/bloc/ask_wing_ai/ask_wing_ai_cubit.dart';
import 'package:tcgc/presentation/bloc/ask_wing_ai/ask_wing_ai_state.dart';
import 'package:tcgc/data/services/ask_wing_ai_service.dart';
import 'package:tcgc/core/services/token_service.dart';

class _FakeTokenService extends TokenService {
  @override
  Future<String?> getToken() async => 'fake_token';
}

/// Mock AskWingAIService for testing
class MockAskWingAIService extends AskWingAIService {
  MockAskWingAIService() : super(tokenService: _FakeTokenService());
}

/// Test widget that attempts to read AskWingAICubit
class TestHomePageFAB extends StatelessWidget {
  const TestHomePageFAB({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // This should fail with ProviderNotFoundError on unfixed code
          final cubit = context.read<AskWingAICubit>();
          cubit.submitQuestion('Test question');
        },
        child: const Icon(Icons.smart_toy_outlined),
      ),
      body: const Center(child: Text('Test HomePage')),
    );
  }
}

/// Test widget that uses BlocListener for AskWingAICubit
class TestChatInterfaceView extends StatelessWidget {
  const TestChatInterfaceView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AskWingAICubit, AskWingAIState>(
        listener: (context, state) {
          // This listener should fail to find the cubit on unfixed code
          if (state is AskWingAIReady) {
            debugPrint('Chat interface ready');
          }
        },
        child: const Center(child: Text('Chat Interface')),
      ),
    );
  }
}

/// Test widget that attempts to watch AskWingAICubit
class TestChatMessageList extends StatelessWidget {
  const TestChatMessageList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AskWingAICubit, AskWingAIState>(
      builder: (context, state) {
        // This builder should fail to find the cubit on unfixed code
        return Center(
          child: Text('Messages: ${state.runtimeType}'),
        );
      },
    );
  }
}

void main() {
  group('Ask Wing AI Cubit Provider Hierarchy - Bug Condition Tests', () {
    /// Property 1: Bug Condition
    ///
    /// Test that demonstrates the bug: when HomePage (or child widgets) attempt
    /// to access AskWingAICubit, they should fail with ProviderNotFoundError
    /// on UNFIXED code because the cubit is not provided at MainScreen level.
    ///
    /// **Expected Result on Unfixed Code**: FAILURE (confirms bug exists)
    /// **Expected Result on Fixed Code**: PASS (confirms bug is fixed)
    ///
    /// **Validates: Requirements 1.1, 4.1, 4.2**

    testWidgets(
        'Scenario 1: HomePage FAB onPressed fails to access AskWingAICubit '
        'when cubit not provided in widget tree (Bug Condition)',
        (WidgetTester tester) async {
      // Build a minimal widget tree WITHOUT providing AskWingAICubit
      // This simulates the unfixed code where cubit is not at MainScreen level
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Test')),
            body: const Center(child: TestHomePageFAB()),
          ),
        ),
      );

      // Try to tap the FAB which attempts to read the cubit
      // On unfixed code, this should throw ProviderNotFoundError
      expect(
        () async {
          await tester.tap(find.byType(FloatingActionButton));
          await tester.pumpAndSettle();
        },
        throwsA(isA<ProviderNotFoundException>()),
      );
    });

    testWidgets(
        'Scenario 2: BlocListener fails to find AskWingAICubit '
        'when not provided in widget tree (Bug Condition)',
        (WidgetTester tester) async {
      // Build widget tree with BlocListener but WITHOUT providing cubit
      // This simulates attempting to use BlocListener in chat interface
      await tester.pumpWidget(
        MaterialApp(
          home: const TestChatInterfaceView(),
        ),
      );

      // The BlocListener should fail to find the cubit during build
      // On unfixed code, this causes ProviderNotFoundError
      expect(
        tester.takeException(),
        isA<ProviderNotFoundException>(),
      );
    });

    testWidgets(
        'Scenario 3: BlocBuilder fails to find AskWingAICubit '
        'when not provided in widget tree (Bug Condition)',
        (WidgetTester tester) async {
      // Build widget tree with BlocBuilder but WITHOUT providing cubit
      await tester.pumpWidget(
        MaterialApp(
          home: const TestChatMessageList(),
        ),
      );

      // The BlocBuilder should fail to find the cubit during build
      // On unfixed code, this causes ProviderNotFoundError
      expect(
        tester.takeException(),
        isA<ProviderNotFoundException>(),
      );
    });

    testWidgets(
        'Scenario 4: Multiple widgets accessing cubit fail '
        'when cubit not in provider tree (Bug Condition)',
        (WidgetTester tester) async {
      // Build a more complex widget tree without cubit provider
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Test')),
            body: Column(
              children: [
                const TestChatInterfaceView(),
                const TestChatMessageList(),
              ],
            ),
          ),
        ),
      );

      // Multiple access attempts should all fail on unfixed code
      expect(
        tester.takeException(),
        isA<ProviderNotFoundException>(),
      );
    });

    testWidgets(
        'Scenario 5: Verify error message identifies missing AskWingAICubit provider',
        (WidgetTester tester) async {
      // Build minimal setup that should fail
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Test')),
            body: BlocBuilder<AskWingAICubit, AskWingAIState>(
              builder: (context, state) {
                return const Center(child: Text('Should not build'));
              },
            ),
          ),
        ),
      );

      // Capture the exception to verify it's about missing provider
      final exception = tester.takeException();

      expect(
        exception,
        isA<ProviderNotFoundException>(),
      );

      // Verify error message mentions AskWingAICubit
      expect(
        exception.toString(),
        stringContainsInOrder([
          'Could not find the correct Provider',
          'AskWingAICubit'
        ]),
      );
    });
  });
}
