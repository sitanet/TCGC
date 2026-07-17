# Ask Wing AI Cubit Provider Hierarchy Bugfix Design

## Overview

The Ask Wing AI feature is currently failing because `AskWingAICubit` is provided at a scoped level (locally to a particular widget), making it inaccessible throughout the app hierarchy. When `HomePage` or other child widgets try to access the cubit, they fail with a `ProviderNotFoundError` because the provider is out of scope.

This bugfix addresses the architecture issue by elevating `AskWingAICubit` provision to the `MainScreen` level, making it available to all child widgets in the app hierarchy. This enables proper dependency injection across the entire application.

**Impact of the Bug:**
- Users cannot access the Ask Wing AI feature from HomePage
- The chat interface fails to load with error screen
- No graceful fallback or alternative access path
- Feature is completely broken for end users

**Fix Strategy:**
- Move `AskWingAICubit` initialization from local scope to `MainScreen`
- Wrap `MainScreen` children with `BlocProvider` for the cubit
- Initialize `AskWingAIService` once at app startup
- Ensure cubit is available to all descendant widgets

---

## Glossary

- **Bug_Condition (C)**: When any child widget of `MainScreen` attempts to access `AskWingAICubit` using `context.read()` or `context.watch()`
- **Property (P)**: The `AskWingAICubit` should be successfully provided and accessible without throwing `ProviderNotFoundError`
- **Preservation**: All existing functionality of other features (sermon list, wallet, etc.) must continue working unchanged
- **MainScreen**: The root screen widget that contains all main app navigation and content
- **BlocProvider**: Flutter Bloc package provider widget for dependency injection
- **AskWingAICubit**: State management cubit handling Ask Wing AI chat functionality
- **AskWingAIService**: HTTP service for communicating with Ask Wing AI backend API
- **ProviderNotFoundError**: Flutter error thrown when trying to access a provider that's not in the widget tree

---

## Bug Details

### Bug Condition

The bug manifests when a user taps the Ask Wing AI Floating Action Button on the HomePage, triggering an attempt to access `AskWingAICubit` from within `HomePage` widget context.

**Current Implementation Issue:**
- `AskWingAICubit` is likely provided at a lower scope (within HomePage or a specific feature module)
- Child widgets are attempting to read the cubit from a context where it doesn't exist
- The provider cannot traverse up the widget tree to find the cubit because it's not at a common ancestor level

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type BuildContext (from HomePage or child widget)
  OUTPUT: boolean
  
  RETURN input.widget IS ChildOf(MainScreen)
         AND context.read<AskWingAICubit>() attempts to execute
         AND AskWingAICubit NOT PROVIDED at MainScreen or ancestor level
END FUNCTION
```

### Examples

**Example 1: HomePage accessing AskWingAICubit**
```dart
// In HomePage.build() or onPressed callback
void _openAskWingAI() {
  // This fails because AskWingAICubit is not in the provider tree
  final cubit = context.read<AskWingAICubit>();
  cubit.submitQuestion(questionText);
}

// Error Output:
// Could not find the correct Provider<AskWingAICubit> above this HomePage Widget
// Stack trace includes: Provider.of -> ReadContext.read -> _HomePageState.build
```

**Example 2: Chat interface initialization**
```dart
// In ChatInterfaceView
@override
Widget build(BuildContext context) {
  // This fails when ChatInterfaceView is a child of HomePage
  return BlocListener<AskWingAICubit, AskWingAIState>(
    listener: (context, state) {
      // Listener never registered because cubit not found
    },
    child: ChatMessageList(),
  );
}
```

**Example 3: Working scenario after fix**
```dart
// In MainScreen (after fix)
@override
Widget build(BuildContext context) {
  return BlocProvider<AskWingAICubit>(
    create: (context) => AskWingAICubit(
      service: AskWingAIService(context.read<ApiService>()),
    ),
    child: _buildMainContent(),
  );
}

// Now HomePage can access it successfully
void _openAskWingAI(BuildContext context) {
  final cubit = context.read<AskWingAICubit>();
  cubit.submitQuestion(questionText); // Works!
}
```

**Edge Case: Nested route navigation**
```dart
// If navigating to a new route, that route may lose access
// if BlocProvider not at a high enough level
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AskWingAIPage(),
    // Without MainScreen-level provider, context here doesn't have access
  ),
);
```

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- All existing sermon list functionality (search, filter, download) must continue working
- Wallet display and balance management must remain unaffected
- Navigation drawer and bottom tabs must function normally
- Other bottom sheet modals and dialogs must display correctly
- Authentication state management must be preserved
- Device registration and Firebase messaging must continue working
- Offline-first sermon caching must work as before

**Scope:**
All app functionality unrelated to Ask Wing AI should be completely unaffected by this fix. The change is architectural—moving the provider location in the widget tree—and should not impact any business logic or other features.

---

## Hypothesized Root Cause

Based on the error message and Flutter provider patterns, the most likely issues are:

1. **Incorrect Provider Scope**: `AskWingAICubit` is provided via `BlocProvider` at a scope (like HomePage level) that is too low in the widget tree
   - HomePage doesn't have the provider in its ancestors
   - Sibling routes don't have access to the cubit
   - New routes pushed by Navigator lose access

2. **Missing Provider Initialization**: The `BlocProvider` for `AskWingAICubit` may not be in `main.dart` or `MainScreen` build
   - It might only be added to specific feature modules
   - It could be conditionally provided in a way that excludes HomePage

3. **Widget Tree Structure**: MainScreen wraps HomePage, but AskWingAICubit is provided inside HomePage
   - Creates a scope issue where sibling or parent widgets can't access it
   - Breaks the typical provider pattern where dependencies are provided at the highest common ancestor

4. **Initialization Timing**: `AskWingAIService` might not be initialized at app startup
   - Service could be `null` or unavailable when cubit tries to use it
   - Creates initialization dependency issues

5. **Missing MultiProvider Wrapper**: MainScreen may not use `MultiProvider` to combine all app-level providers
   - Only certain providers might be registered at MainScreen level
   - AskWingAICubit is overlooked in the provider list

---

## Correctness Properties

Property 1: Bug Condition - AskWingAICubit Availability at MainScreen

_For any_ child widget of `MainScreen` that needs to access `AskWingAICubit` (such as HomePage when Ask Wing AI FAB is tapped), the cubit SHALL be available via `context.read<AskWingAICubit>()` and `context.watch<AskWingAICubit>()` without throwing a `ProviderNotFoundError`.

**Validates: Requirements 1.1, 4.1, 4.2**

Property 2: Preservation - Other Features Remain Unaffected

_For any_ app functionality not related to Ask Wing AI (sermon browsing, wallet management, navigation, authentication), the fixed provider hierarchy SHALL produce exactly the same behavior as the original code, preserving all existing functionality and state management.

**Validates: Requirements 1.2, 1.3, 1.4**

---

## Fix Implementation

### Changes Required

**File**: `lib/presentation/pages/main_screen.dart` (or equivalent main app widget)

**Current Structure** (Likely):
```dart
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Other providers but NOT AskWingAICubit
        ChangeNotifierProvider(create: (_) => OtherProvider()),
      ],
      child: Scaffold(
        // AppBar, BottomNav, etc.
        body: _buildPageContent(),
      ),
    );
  }
}
```

**Fixed Structure**:
```dart
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late AskWingAICubit _askWingAICubit;

  @override
  void initState() {
    super.initState();
    // Initialize AskWingAIService and AskWingAICubit
    _askWingAICubit = AskWingAICubit(
      service: AskWingAIService(
        apiService: context.read<ApiService>(),
        // Inject other dependencies as needed
      ),
    );
  }

  @override
  void dispose() {
    _askWingAICubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AskWingAICubit>(
      create: (context) => _askWingAICubit,
      child: MultiProvider(
        providers: [
          // Existing other providers
          ChangeNotifierProvider(create: (_) => OtherProvider()),
          // AskWingAICubit now accessible via BlocProvider above
        ],
        child: Scaffold(
          appBar: _buildAppBar(),
          body: _buildPageContent(),
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }
}
```

### Specific Changes

1. **Initialize AskWingAICubit at MainScreen Level**
   - Create instance in `initState()` of MainScreen state class
   - Pass required dependencies (ApiService, etc.)
   - Ensure it's available before first frame render

2. **Wrap MainScreen children with BlocProvider**
   - Use `BlocProvider<AskWingAICubit>` to expose cubit
   - Position BlocProvider at root of MainScreen widget tree
   - Ensure all child widgets can access via context

3. **Manage cubit lifecycle**
   - Create cubit in `initState()` to match widget lifecycle
   - Dispose cubit in `dispose()` to prevent memory leaks
   - Handle hot reload gracefully (consider `reassemble()`)

4. **Verify dependency injection chain**
   - Confirm `AskWingAIService` can be created with current context
   - Ensure `ApiService` is available at MainScreen level
   - Check all transitive dependencies are injectable

5. **Update HomePage access pattern** (if needed)
   - Verify HomePage uses `context.read<AskWingAICubit>()` correctly
   - Ensure context is from MainScreen descendant
   - No changes needed if HomePage already uses correct pattern

---

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples demonstrating the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm that the root cause analysis is correct.

**Test Plan**: Write tests that simulate HomePage attempting to access `AskWingAICubit`. Run these tests on the UNFIXED code to observe the ProviderNotFoundError and confirm root cause.

**Test Cases**:
1. **HomePage FAB Access Test**: Simulate tapping Ask Wing AI FAB in HomePage (will fail on unfixed code with ProviderNotFoundError)
2. **Chat Interface Widget Access Test**: Create ChatInterfaceView as HomePage child and attempt to access cubit (will fail)
3. **BlocListener Access Test**: Use BlocListener<AskWingAICubit> in HomePage descendant (will fail to find cubit)
4. **Multiple Route Navigation Test**: Navigate to new route and try to access cubit from HomePage context (will fail)

**Expected Counterexamples**:
- `ProviderNotFoundError: Could not find the correct Provider<AskWingAICubit> above this HomePage Widget`
- Stack trace shows Provider.of → ReadContext.read → HomePage.build
- Confirms cubit is not in widget tree at HomePage level

### Fix Checking

**Goal**: Verify that after the fix, any child widget of `MainScreen` can successfully access `AskWingAICubit`.

**Pseudocode:**
```
FOR ALL child_widget IN MainScreen.children DO
  result := child_widget.context.read<AskWingAICubit>()
  ASSERT result IS NOT null
  ASSERT result IS instance_of AskWingAICubit
  ASSERT child_widget.context.watch<AskWingAICubit>() works
END FOR
```

### Preservation Checking

**Goal**: Verify that all other app features continue working exactly as before after moving the provider.

**Pseudocode:**
```
FOR ALL non_ask_wing_ai_feature IN [SermonList, Wallet, Navigation, Auth] DO
  ASSERT feature.behavior_original = feature.behavior_fixed
  ASSERT feature.state_management unchanged
  ASSERT feature.ui_rendering unchanged
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many user interaction scenarios automatically
- It catches edge cases with navigation, route changes, widget rebuilds
- It provides strong guarantees that existing features are unaffected

**Test Plan**: Run existing test suite for other features to ensure no regression. Add targeted tests for widget tree access patterns.

**Test Cases**:
1. **HomePage Widget Access Test**: Verify HomePage can access AskWingAICubit without error after fix
2. **BlocProvider Scoping Test**: Verify cubit is accessible to all MainScreen descendants
3. **Service Injection Test**: Verify AskWingAIService is correctly injected and accessible
4. **Multiple Access Test**: Verify multiple widgets can access cubit simultaneously
5. **State Management Test**: Verify cubit state changes are properly broadcast to listeners
6. **Navigation Test**: Verify cubit access works when navigating between routes
7. **Hot Reload Test**: Verify app doesn't crash on hot reload with cubit in state

### Unit Tests

- Test AskWingAICubit can be created with injected dependencies
- Test AskWingAIService initialization with ApiService
- Test cubit state emissions on question submission
- Test error handling when service is unavailable
- Test cubit disposal doesn't cause memory leaks

### Widget/Integration Tests

- Test MainScreen correctly provides BlocProvider
- Test HomePage FAB tap successfully accesses cubit
- Test ChatInterfaceView renders when cubit is available
- Test navigation to new routes maintains cubit access
- Test other features (SermonList, Wallet) still work after fix
- Test app doesn't crash on hot reload/hot restart

### Integration Tests

- Test full user flow: tap FAB → open chat → submit question → receive response
- Test with real ApiService to verify end-to-end data flow
- Test authentication errors are handled correctly
- Test rate limiting display updates correctly
- Test error scenarios (network down, service failure)

---

## Implementation Checklist

- [ ] Locate MainScreen widget file
- [ ] Identify current provider structure
- [ ] Create AskWingAICubit instance in MainScreen.initState()
- [ ] Initialize AskWingAIService with ApiService dependency
- [ ] Wrap MainScreen children with BlocProvider<AskWingAICubit>
- [ ] Dispose cubit properly in dispose()
- [ ] Update HomePage to access cubit via context.read/watch
- [ ] Verify ChatInterfaceView can access cubit
- [ ] Run app and verify Ask Wing AI FAB no longer shows error
- [ ] Test HomePage and other features continue working
- [ ] Run test suite to verify no regressions
- [ ] Verify hot reload behavior with new provider structure
