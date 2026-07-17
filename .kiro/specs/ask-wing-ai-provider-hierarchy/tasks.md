# Implementation Plan: Ask Wing AI Cubit Provider Hierarchy Bugfix

## Overview

This bugfix addresses the provider hierarchy issue where `AskWingAICubit` is not accessible at the MainScreen level, causing a `ProviderNotFoundError` when users try to access the Ask Wing AI feature.

**Bug Summary:**
- Users tap Ask Wing AI FAB on HomePage
- App attempts to access `AskWingAICubit` via `context.read()`
- Cubit is not in the widget tree, causing error screen
- Solution: Elevate cubit provision to MainScreen level

**Key Tasks:**
1. Write exploration tests to confirm the bug exists
2. Write preservation tests to ensure other features remain unchanged
3. Implement the fix by moving cubit to MainScreen
4. Verify tests pass after fix

---

## Tasks

### Phase 1: Bug Exploration and Understanding

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - AskWingAICubit Not Accessible in HomePage
  - **IMPORTANT**: Write this property-based test BEFORE implementing the fix
  - **GOAL**: Surface counterexamples that demonstrate the bug exists
  - **Scoped PBT Approach**: Scope the property to the concrete failing case: HomePage widget attempting to access AskWingAICubit
  - Test that `context.read<AskWingAICubit>()` fails with `ProviderNotFoundError` when called from HomePage (the bug condition)
  - Implement test cases:
    1. HomePage widget attempting to read cubit directly
    2. Floating Action Button onTap callback accessing cubit
    3. BlocListener<AskWingAICubit> in HomePage descendant failing to find provider
  - Run test on UNFIXED code - expect FAILURE (this confirms the bug exists)
  - Document counterexample: `ProviderNotFoundError: Could not find the correct Provider<AskWingAICubit> above this HomePage Widget`
  - Mark task complete when test is written, run on unfixed code, and failure is documented
  - _Requirements: 1.1, 4.1, 4.2_

### Phase 2: Preservation Testing (Before Fix)

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Other Features Continue Working Without Cubit
  - **IMPORTANT**: Follow observation-first methodology
  - Observe: HomePage loads and displays sermon list correctly on unfixed code
  - Observe: Navigation between tabs (Home, Audio, LiveStream, Wallet, Teens) works on unfixed code
  - Observe: Sermon playback functionality works on unfixed code
  - Observe: Wallet display and balance management work on unfixed code
  - Write property-based tests:
    1. Sermon list displays correctly with proper filtering and pagination
    2. Tab navigation state is preserved when switching tabs
    3. Sermon selection and playback initiation works
    4. Wallet balance display updates correctly
    5. All navigation and UI interactions work independently of Ask Wing AI feature
  - Verify tests pass on UNFIXED code (baseline behavior to preserve)
  - Mark task complete when tests are written, run on unfixed code, and passing
  - _Requirements: 1.2, 1.3, 1.4_

### Phase 3: Implementation

- [ ] 3. Provide AskWingAICubit at MainScreen level

  - [-] 3.1 Implement cubit provision in MainScreen
    - Locate `MainScreen` widget in `lib/presentation/pages/main_screen.dart`
    - Add `late AskWingAICubit _askWingAICubit;` field to `_MainScreenState`
    - Import necessary dependencies: `AskWingAICubit`, `AskWingAIService`, `BlocProvider`
    - In `initState()`, initialize `_askWingAICubit`:
      ```dart
      _askWingAICubit = AskWingAICubit(
        service: AskWingAIService(
          // Inject ApiService and other dependencies
        ),
      );
      ```
    - Ensure all required dependencies are available at MainScreen level
    - Handle any missing dependencies gracefully
    - _Bug_Condition: context.read<AskWingAICubit>() from HomePage/children fails before fix_
    - _Expected_Behavior: BlocProvider at MainScreen level provides AskWingAICubit to all descendants_
    - _Preservation: All existing features continue working with new provider structure_
    - _Requirements: 1.1, 4.1, 4.2_

  - [~] 3.2 Wrap MainScreen children with BlocProvider
    - In `_MainScreenState.build()`, wrap the widget tree with `BlocProvider<AskWingAICubit>`
    - Position `BlocProvider` at the highest point in MainScreen's widget tree
    - Use the pre-created `_askWingAICubit` instance:
      ```dart
      return BlocProvider<AskWingAICubit>(
        create: (context) => _askWingAICubit,
        child: /* existing MainScreen content */,
      );
      ```
    - Ensure all descendants (HomePage, AudioPage, LiveStreamPage, etc.) are children of BlocProvider
    - Verify widget tree structure allows access from all routes and tabs
    - _Requirements: 1.1, 4.1, 4.2_

  - [~] 3.3 Manage cubit lifecycle properly
    - In `dispose()` of `_MainScreenState`, properly close the cubit:
      ```dart
      @override
      void dispose() {
        _askWingAICubit.close();
        super.dispose();
      }
      ```
    - Ensure no memory leaks from unclosed cubit
    - Test hot reload behavior to ensure graceful handling
    - _Requirements: 1.1, 4.1_

  - [~] 3.4 Handle dependency injection correctly
    - Verify `ApiService` is available at MainScreen level (check context.read availability)
    - If `ApiService` not available, create it or pass it as MainScreen parameter
    - Handle all transitive dependencies for `AskWingAIService`
    - Test that service can be created successfully in initState
    - Log initialization success/failure for debugging
    - _Requirements: 4.1, 4.2_

  - [~] 3.5 Update HomePage FAB access pattern
    - In HomePage FAB `onPressed` callback, verify it accesses cubit correctly
    - Current code: `context.read<AskWingAICubit>()`
    - After fix, this should work without error
    - If using `BlocProvider.of()`, ensure it's the correct pattern
    - No code changes needed if HomePage is already using `context.read()` correctly
    - Test that FAB tap opens chat interface without error
    - _Requirements: 1.1, 4.1_

### Phase 4: Verification

- [~] 4. Verify bug condition exploration test now passes
  - **Property 1: Expected Behavior** - AskWingAICubit Available at MainScreen
  - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
  - The test from task 1 encodes the expected behavior
  - When this test passes, it confirms the expected behavior is satisfied
  - Run the following test scenarios on FIXED code:
    1. HomePage widget can access cubit via `context.read<AskWingAICubit>()`
    2. Floating Action Button `onTap` callback successfully accesses cubit
    3. BlocListener<AskWingAICubit> in HomePage descendant finds provider
    4. Multiple widgets can access cubit simultaneously
  - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
  - Document: Cubit is now accessible, no ProviderNotFoundError thrown
  - Mark task complete when test passes on fixed code
  - _Requirements: 1.1, 4.1, 4.2_

- [~] 5. Verify preservation tests still pass
  - **Property 2: Preservation** - Other Features Remain Unaffected
  - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
  - Run preservation property tests on FIXED code:
    1. Sermon list displays correctly with filtering and pagination
    2. Tab navigation works correctly (state preserved)
    3. Sermon selection and playback work correctly
    4. Wallet balance display works correctly
    5. All UI interactions work independently of Ask Wing AI
  - **EXPECTED OUTCOME**: All tests PASS (confirms no regressions)
  - Verify no app crashes or unexpected behavior changes
  - Test hot reload/hot restart with new provider structure
  - Mark task complete when all preservation tests pass
  - _Requirements: 1.2, 1.3, 1.4_

- [ ] 6. Manual end-to-end testing
  - [~] 6.1 Test Ask Wing AI Feature Access
    - Login to the app
    - Navigate to HomePage (tab 0)
    - Verify Ask Wing AI FAB is visible
    - Tap FAB
    - **EXPECTED**: Chat interface opens without red error screen
    - **EXPECTED**: AskWingAICubit is accessible and initialized
    - **EXPECTED**: No ProviderNotFoundError in logs
    - Mark complete when FAB opens chat interface successfully

  - [~] 6.2 Test Other Features Still Work
    - Verify sermon list displays correctly
    - Verify audio playback works
    - Verify wallet tab displays balance
    - Verify live stream tab loads
    - Verify teens tab displays content
    - Verify navigation between tabs works smoothly
    - Verify no crashes or errors during navigation
    - Mark complete when all features work without regression

  - [~] 6.3 Test Navigation and Routing
    - Open Ask Wing AI chat
    - Navigate back to HomePage
    - Tap FAB again to open chat again
    - Verify cubit state is properly maintained
    - Navigate to different tab and back to Home
    - Verify FAB access still works
    - Test deep linking to different tabs
    - Mark complete when navigation flows work correctly

  - [~] 6.4 Test State Management
    - Open Ask Wing AI chat
    - Submit a question
    - Verify response appears
    - Navigate to another tab and back
    - Verify chat history is preserved
    - Test cubit state watchers update UI correctly
    - Mark complete when state management works correctly

### Phase 5: Checkpoint

- [~] 7. Checkpoint - Verify all tests pass and feature works
  - Ensure exploration test from task 1 PASSES on fixed code
  - Ensure all preservation tests from task 2 PASS on fixed code
  - Ensure manual testing from task 6 shows no errors
  - Ensure app logs show no ProviderNotFoundError or related exceptions
  - Ensure hot reload works without crashes
  - Confirm Ask Wing AI FAB opens chat interface without red error screen
  - Confirm all other app features continue working normally
  - Ask the user if they notice any remaining issues or unexpected behavior

---

## Implementation Notes

### Files to Modify

1. **`lib/presentation/pages/main_screen.dart`**
   - Add AskWingAICubit field to _MainScreenState
   - Initialize cubit in initState()
   - Wrap widget tree with BlocProvider
   - Dispose cubit in dispose()

### Verification Checklist

- [~] Exploration test fails on unfixed code (confirms bug exists)
- [~] Exploration test passes on fixed code (confirms bug is fixed)
- [~] All preservation tests pass on fixed code (confirms no regressions)
- [~] Ask Wing AI FAB opens chat interface without error
- [~] Other features work normally (sermon list, playback, wallet, etc.)
- [~] No ProviderNotFoundError in app logs
- [~] Hot reload/hot restart works correctly
- [~] Navigation between tabs works smoothly
- [~] Chat history persists when navigating away and back

### Common Issues and Solutions

**Issue**: "Could not find Provider<AskWingAICubit> above MainScreen"
- **Cause**: BlocProvider positioned incorrectly in widget tree
- **Solution**: Ensure BlocProvider wraps all children that need access

**Issue**: ProviderNotFoundError still appears after fix
- **Cause**: Cubit not initialized in initState before build
- **Solution**: Ensure initialization happens before first frame

**Issue**: Cubit null pointer on access
- **Cause**: AskWingAIService dependencies not available
- **Solution**: Verify ApiService and other dependencies are accessible at MainScreen level

**Issue**: Hot reload crashes app
- **Cause**: Cubit not properly disposed or re-created
- **Solution**: Implement reassemble() or test hot reload with new structure
